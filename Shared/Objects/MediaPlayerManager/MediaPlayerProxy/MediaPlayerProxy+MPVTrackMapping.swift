//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI

/// Maps Jellyfin's global stream indexes to mpv's per-type, 1-based track IDs
/// (`aid 1, 2, 3...` / `sid 1, 2, 3...`) in the order tracks appear in the file.
extension MPVMediaPlayerProxy {

    func audioTrackPosition(for index: Int, mediaSource: MediaSourceInfo) -> Int? {
        let audioStreams = mediaSource.mediaStreams?
            .filter { $0.type == .audio && !isExternalStream($0) } ?? []
        return audioStreams.firstIndex(where: { $0.index == index })
    }

    func subtitleTrackID(for index: Int, mediaSource: MediaSourceInfo) -> Int? {
        let subtitleStreams = mediaSource.mediaStreams?
            .filter { $0.type == .subtitle } ?? []
        guard let stream = subtitleStreams.first(where: { $0.index == index }) else { return nil }
        // A burned-in subtitle is already part of the picture; selecting a
        // track on top of it would draw a second, unrelated one.
        if stream.deliveryMethod == .encode {
            return nil
        }
        // A transcode's HLS stream carries no subtitle tracks of its own (see
        // MediaTrackIndexMap.build): every selectable subtitle arrives as a
        // sidecar through `sub-add`, so mpv numbers them from 1 regardless of
        // where they sat in the original file.
        let internalSubs = mediaSource.transcodingURL == nil
            ? subtitleStreams.filter { !isExternalStream($0) }
            : []
        if let position = internalSubs.firstIndex(where: { $0.index == index }) {
            return position + 1
        }
        // Mirrors the `sub-add` order in MPVController.loadFile.
        let externalSubs = subtitleStreams.filter { $0.deliveryMethod == .external }
        if let position = externalSubs.firstIndex(where: { $0.index == index }) {
            return internalSubs.count + position + 1
        }
        return nil
    }

    func isExternalStream(_ stream: MediaStream) -> Bool {
        (stream.isExternal ?? false) || stream.deliveryMethod == .external
    }

    func resolvedStreamIndex(
        for stream: MediaStream,
        streamType: MediaStreamType,
        playbackItem: MediaPlayerItem
    ) -> Int? {
        if let type = stream.type, type != streamType {
            return nil
        }
        if let index = stream.index,
           let direct = playbackItem.mediaSource.mediaStreams?
               .first(where: { $0.type == streamType && $0.index == index })
        {
            return direct.index
        }
        if let index = stream.index,
           let resolvedByPosition = resolvedStreamIndex(
               forIndex: index,
               streamType: streamType,
               playbackItem: playbackItem
           )
        {
            return resolvedByPosition
        }
        return originalStreamIndex(for: stream, mediaSource: playbackItem.mediaSource)
    }

    func resolvedStreamIndex(
        forIndex index: Int,
        streamType: MediaStreamType,
        playbackItem: MediaPlayerItem
    ) -> Int? {
        if let direct = playbackItem.mediaSource.mediaStreams?
            .first(where: { $0.type == streamType && $0.index == index })
        {
            return direct.index
        }
        switch streamType {
        case .audio:
            guard let position = playbackItem.audioStreams.firstIndex(where: { $0.index == index }) else { return nil }
            let audioStreams = playbackItem.mediaSource.mediaStreams?
                .filter { $0.type == .audio && !isExternalStream($0) } ?? []
            guard position < audioStreams.count else { return nil }
            return audioStreams[position].index
        case .subtitle:
            guard let position = playbackItem.subtitleStreams.firstIndex(where: { $0.index == index }) else { return nil }
            let subtitleStreams = playbackItem.mediaSource.mediaStreams?
                .filter { $0.type == .subtitle } ?? []
            let internalSubs = subtitleStreams.filter { !isExternalStream($0) }
            let externalSubs = subtitleStreams.filter { isExternalStream($0) }
            if position < internalSubs.count {
                return internalSubs[position].index
            }
            let externalIndex = position - internalSubs.count
            guard externalIndex < externalSubs.count else { return nil }
            return externalSubs[externalIndex].index
        default:
            return nil
        }
    }

    func originalStreamIndex(for stream: MediaStream, mediaSource: MediaSourceInfo) -> Int? {
        guard let streams = mediaSource.mediaStreams else { return nil }
        let isExternal = isExternalStream(stream)
        let candidates = streams.filter {
            $0.type == stream.type && isExternalStream($0) == isExternal
        }
        if let match = candidates.first(where: { matchesStream($0, stream) }) {
            return match.index
        }
        if let match = candidates.first(where: { $0.displayTitle == stream.displayTitle && $0.language == stream.language }) {
            return match.index
        }
        return nil
    }

    func matchesStream(_ lhs: MediaStream, _ rhs: MediaStream) -> Bool {
        lhs.displayTitle == rhs.displayTitle &&
            lhs.language == rhs.language &&
            lhs.codec == rhs.codec &&
            lhs.channels == rhs.channels &&
            lhs.channelLayout == rhs.channelLayout &&
            lhs.bitRate == rhs.bitRate &&
            lhs.sampleRate == rhs.sampleRate &&
            lhs.isDefault == rhs.isDefault &&
            lhs.isForced == rhs.isForced
    }
}
