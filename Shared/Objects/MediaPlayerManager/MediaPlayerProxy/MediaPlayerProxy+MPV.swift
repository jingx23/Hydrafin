//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import Defaults
import FactoryKit
import JellyfinAPI
import MPVUI
import SwiftUI

// SPIKE (spike/mpvui): MPVUI replaces the hand-rolled MPVKit controller.
// MPVUI owns rendering (Metal or AVSampleBufferDisplayLayer), surface resizing,
// the audio output (AVFoundation, AC3/EAC3 bitstream), Dolby Vision and tvOS
// display matching. This proxy keeps Hydrafin's Jellyfin track mapping and the
// bridges into the fork's player UI.

@MainActor
class MPVMediaPlayerProxy: VideoMediaPlayerProxy,
    MediaPlayerOffsetConfigurable,
    MediaPlayerSubtitleConfigurable
{

    let isBuffering: PublishedBox<Bool> = .init(initialValue: false)
    let videoSize: PublishedBox<CGSize> = .init(initialValue: .zero)
    let droppedFrames: PublishedBox<Int> = .init(initialValue: 0)
    /// mpv has no counterpart to VLC's corrupted-frame statistic.
    let corruptedFrames: PublishedBox<Int> = .init(initialValue: 0)

    let player = MPVPlayer(configuration: MPVMediaPlayerProxy.makeConfiguration())

    /// Track selection for the loaded item, applied once mpv reports its tracks.
    private var pendingAudioTrackID: Int?
    private var pendingSubtitleTrackID: Int?
    private var hasPendingTrackSelection = false

    private var managerItemObserver: AnyCancellable?
    private var managerStateObserver: AnyCancellable?

    weak var manager: MediaPlayerManager? {
        didSet {
            for var o in observers {
                o.manager = manager
            }

            if let manager {
                managerItemObserver = manager.$playbackItem
                    .sink { [weak self] playbackItem in
                        if let playbackItem {
                            self?.playNew(item: playbackItem)
                        }
                    }

                managerStateObserver = manager.$state
                    .sink { [weak self] state in
                        if state == .stopped {
                            self?.player.stop()
                        }
                    }
            } else {
                managerItemObserver?.cancel()
                managerStateObserver?.cancel()
            }
        }
    }

    var observers: [any MediaPlayerObserver] = [
        NowPlayableObserver(),
    ]

    init() {
        #if os(iOS)
        player.pictureInPicture.allowsAutomaticStartFromInline = true
        #endif
    }

    // MARK: - Playback Controls

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func stop() {
        player.stop()
    }

    func jumpForward(_ seconds: Duration) {
        player.seek(by: seconds)
    }

    func jumpBackward(_ seconds: Duration) {
        player.seek(by: .zero - seconds)
    }

    func setRate(_ rate: Float) {
        player.setPlaybackRate(Double(rate))
    }

    func setSeconds(_ seconds: Duration) {
        player.seek(to: seconds)
    }

    func setAudioStream(_ stream: MediaStream) {
        guard let playbackItem = manager?.playbackItem else { return }
        // Transcodes contain a single audio track, so the only valid ID is 1.
        // Changing tracks while transcoding rebuilds the item server-side
        // (see MediaPlayerItem.isRebuildRequired) rather than switching here.
        if playbackItem.mediaSource.transcodingURL != nil {
            selectTrack(type: .audio, mpvID: 1)
            return
        }
        guard let resolvedIndex = resolvedStreamIndex(for: stream, streamType: .audio, playbackItem: playbackItem),
              let position = audioTrackPosition(for: resolvedIndex, mediaSource: playbackItem.mediaSource)
        else { return }
        selectTrack(type: .audio, mpvID: position + 1)
    }

    func setSubtitleStream(_ stream: MediaStream) {
        guard let index = stream.index else { return }
        guard index >= 0 else {
            player.selectSubtitle(nil)
            return
        }
        guard let playbackItem = manager?.playbackItem,
              let resolvedIndex = resolvedStreamIndex(for: stream, streamType: .subtitle, playbackItem: playbackItem),
              let id = subtitleTrackID(for: resolvedIndex, mediaSource: playbackItem.mediaSource)
        else { return }
        selectTrack(type: .subtitle, mpvID: id)
    }

    func setAspectFill(_ aspectFill: Bool) {
        player.setProperty("panscan", to: aspectFill ? "1.0" : "0.0")
    }

    // MARK: - Offset Configuration

    func setAudioOffset(_ seconds: Duration) {
        player.setAudioDelay(seconds)
    }

    func setSubtitleOffset(_ seconds: Duration) {
        player.setSubtitleDelay(seconds)
    }

    // MARK: - Subtitle Configuration

    func setSubtitleConfiguration(_ configuration: SubtitleConfiguration) {
        for (name, value) in Self.subtitleOptions(configuration) {
            player.setProperty(name, to: value)
        }
    }

    // MARK: - Video Player Body

    var videoPlayerBody: some View {
        MPVPlayerBodyView(proxy: self)
    }

    // MARK: - Loading

    private func playNew(item: MediaPlayerItem) {
        let baseItem = item.baseItem

        let startSeconds = max(
            .zero,
            (baseItem.startSeconds ?? .zero) - Duration.seconds(Defaults[.VideoPlayer.resumeOffset])
        )

        pendingAudioTrackID = initialAudioTrackID(for: item)
        pendingSubtitleTrackID = initialSubtitleTrackID(for: item)
        hasPendingTrackSelection = !baseItem.isLiveStream
        isBuffering.value = true
        droppedFrames.value = 0

        player.load(item.url, autoPlay: true, startTime: baseItem.isLiveStream ? nil : startSeconds)
        setRate(manager?.rate ?? Defaults[.VideoPlayer.Playback.playbackRate])

        // Sidecars are numbered after the embedded subtitles in `sub-add` order,
        // which `subtitleTrackID(for:mediaSource:)` relies on.
        for url in externalSubtitleURLs(for: item) {
            player.loadExternalSubtitle(url, selecting: nil)
        }
    }

    private func initialAudioTrackID(for item: MediaPlayerItem) -> Int? {
        let mediaSource = item.mediaSource
        guard !item.baseItem.isLiveStream else { return nil }
        // A transcode carries exactly one audio track — the one the server was
        // asked to encode. Positions from the original file don't apply.
        if mediaSource.transcodingURL != nil {
            return 1
        }
        let defaultIndex = item.selectedAudioStreamIndex ?? mediaSource.defaultAudioStreamIndex
        guard let defaultIndex, defaultIndex >= 0 else { return nil }
        if let resolvedIndex = resolvedStreamIndex(forIndex: defaultIndex, streamType: .audio, playbackItem: item),
           let position = audioTrackPosition(for: resolvedIndex, mediaSource: mediaSource)
        {
            return position + 1
        }
        let fallbackStreams = mediaSource.mediaStreams?.filter { $0.type == .audio && !isExternalStream($0) } ?? []
        return fallbackStreams.isEmpty ? nil : 1
    }

    private func initialSubtitleTrackID(for item: MediaPlayerItem) -> Int? {
        let mediaSource = item.mediaSource
        guard !item.baseItem.isLiveStream,
              let defaultIndex = item.selectedSubtitleStreamIndex ?? mediaSource.defaultSubtitleStreamIndex,
              defaultIndex >= 0,
              let resolvedIndex = resolvedStreamIndex(forIndex: defaultIndex, streamType: .subtitle, playbackItem: item)
        else { return nil }
        return subtitleTrackID(for: resolvedIndex, mediaSource: mediaSource)
    }

    private func externalSubtitleURLs(for item: MediaPlayerItem) -> [URL] {
        guard let client = Container.shared.currentUserSession()?.client else { return [] }
        return item.subtitleStreams
            .filter { $0.deliveryMethod == .external }
            .compactMap { $0.url(with: client) }
    }

    // MARK: - Track Selection

    /// Applies the item's initial audio/subtitle choice once mpv has listed the
    /// file's tracks. Selecting through MPVUI (rather than setting `aid`/`sid`
    /// directly) lets it request native subtitle composition for sample-buffer output.
    fileprivate func applyPendingTrackSelectionIfPossible() {
        guard hasPendingTrackSelection, player.mediaInformation.tracks.isNotEmpty else { return }

        let externalCount = manager?.playbackItem?.subtitleStreams.count(where: { $0.deliveryMethod == .external }) ?? 0
        if let subtitleID = pendingSubtitleTrackID,
           player.subtitleTracks.count(where: { $0.mpvID == subtitleID }) == 0,
           player.subtitleTracks.count(where: \.isExternal) < externalCount
        {
            // The wanted sidecar is still loading; retry on the next track update.
            return
        }

        hasPendingTrackSelection = false
        if let audioID = pendingAudioTrackID {
            selectTrack(type: .audio, mpvID: audioID)
        }
        if let subtitleID = pendingSubtitleTrackID {
            selectTrack(type: .subtitle, mpvID: subtitleID)
        } else {
            player.selectSubtitle(nil)
        }
    }

    private func selectTrack(type: MPVTrackType, mpvID: Int) {
        guard let track = player.mediaInformation.tracks.first(where: { $0.type == type && $0.mpvID == mpvID }) else {
            return
        }
        switch type {
        case .subtitle:
            if track.subtitleRole != .primary {
                player.selectSubtitle(track.id)
            }
        default:
            if !track.isSelected {
                player.selectTrack(track.id)
            }
        }
    }

    // MARK: - State

    fileprivate func handleStateChange(_ state: MPVPlaybackState) {
        isBuffering.value = state.isTransient

        switch state {
        case .playing:
            manager?.setPlaybackRequestStatus(status: .playing)
        case .paused:
            manager?.setPlaybackRequestStatus(status: .paused)
        case .ended:
            guard let manager, manager.playbackItem?.baseItem.isLiveStream == false else { return }
            manager.seconds = player.position
            manager.ended()
        case let .failed(error):
            manager?.error(ErrorMessage("\(error)"))
        case .idle, .loading, .ready, .buffering, .seeking, .stopped:
            break
        }
    }

    fileprivate func handleDiagnosticsChange(_ diagnostics: MPVPlaybackDiagnostics) {
        let dropped = (diagnostics.outputDroppedFrames ?? 0) + (diagnostics.decoderDroppedFrames ?? 0)
        droppedFrames.value = Int(clamping: dropped)
    }

    fileprivate func handleDimensionsChange(_ dimensions: MPVVideoDimensions?) {
        videoSize.value = CGSize(width: dimensions?.effectiveWidth ?? 0, height: dimensions?.effectiveHeight ?? 0)
    }
}

// MARK: - Configuration

extension MPVMediaPlayerProxy {

    /// Tuning knobs under test in the spike.
    private enum Spike {
        /// `.sampleBuffer` enables native Dolby Vision and iOS PiP; MPVUI falls
        /// back to Metal per file when the format needs it.
        static let videoOutput: MPVPlayerConfiguration.VideoOutput = .sampleBuffer
        /// `.profile7Compatibility` converts DV Profile 7 (lossy) so it plays as DV
        /// instead of its HDR10 base layer.
        static let dolbyVisionPolicy: MPVDolbyVisionPolicy = .strict
    }

    static func makeConfiguration() -> MPVPlayerConfiguration {
        MPVPlayerConfiguration(
            additionalOptions: baseOptions.merging(
                subtitleOptions(Defaults[.VideoPlayer.Subtitle.configuration]),
                uniquingKeysWith: { _, new in new }
            ),
            audio: .init(),
            dolbyVisionPolicy: Spike.dolbyVisionPolicy,
            networkCacheSeconds: .seconds(120),
            playbackRate: Double(Defaults[.VideoPlayer.Playback.playbackRate]),
            videoOutput: Spike.videoOutput
        )
    }

    /// Carried over from the MPVKit controller; rendering, hwdec and sync
    /// options are now MPVUI's responsibility.
    private static let baseOptions: [String: String] = [
        "network-timeout": "30",
        "demuxer-max-bytes": "250MiB",
        "demuxer-max-back-bytes": "75MiB",
        "demuxer-readahead-secs": "30",
        // Ride out short network drops by reconnecting the HTTP stream in place.
        "stream-lavf-o": "reconnect=1,reconnect_streamed=1,reconnect_delay_max=5",
        "subs-match-os-language": "no",
        "subs-fallback": "no",
    ]

    fileprivate static func subtitleOptions(_ configuration: SubtitleConfiguration) -> [String: String] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(configuration.color).getRed(&r, green: &g, blue: &b, alpha: &a)
        let hex = String(format: "#%02X%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255), Int(a * 255))
        return [
            "sub-color": hex,
            "sub-font": configuration.fontName,
            "sub-font-size": "\(25 - configuration.size)",
        ]
    }
}

// MARK: - MPVPlayerBodyView

extension MPVMediaPlayerProxy {

    /// Bridges MPVUI player state and manager/settings state, mirroring what
    /// upstream's VLC player view does inline:
    /// - position → `manager.seconds` and `containerState.scrubbedSeconds`
    ///   (drives the progress bar and timestamps)
    /// - `manager.rate` → mpv speed (playback speed menu)
    /// - subtitle configuration changes → mpv sub options (live updates)
    struct MPVPlayerBodyView: View {

        let proxy: MPVMediaPlayerProxy

        @Default(.VideoPlayer.Subtitle.configuration)
        private var subtitleConfiguration

        @EnvironmentObject
        private var containerState: VideoPlayerContainerState
        @EnvironmentObject
        private var manager: MediaPlayerManager

        private var player: MPVPlayer {
            proxy.player
        }

        var body: some View {
            MPVVideoPlayer(player: player)
                .onChange(of: player.position) {
                    manager.seconds = player.position
                }
                .onReceive(manager.secondsBox.$value.receive(on: DispatchQueue.main)) { seconds in
                    guard !containerState.isScrubbing else { return }
                    containerState.scrubbedSeconds.value = seconds
                }
                .onChange(of: player.state) {
                    proxy.handleStateChange(player.state)
                }
                .onChange(of: player.mediaInformation.tracks) {
                    proxy.applyPendingTrackSelectionIfPossible()
                }
                .onChange(of: player.mediaInformation.dimensions) {
                    proxy.handleDimensionsChange(player.mediaInformation.dimensions)
                }
                .onChange(of: player.playbackDiagnostics) {
                    proxy.handleDiagnosticsChange(player.playbackDiagnostics)
                }
                .onChange(of: manager.rate) {
                    proxy.setRate(manager.rate)
                }
                .onChange(of: subtitleConfiguration) {
                    proxy.setSubtitleConfiguration(subtitleConfiguration)
                }
        }
    }
}
