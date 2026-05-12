//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

extension VideoPlayer {

    struct PlaybackControls: View {

        @EnvironmentObject
        private var containerState: VideoPlayerContainerState
        @EnvironmentObject
        private var manager: MediaPlayerManager
        @EnvironmentObject
        private var scrubbedSecondsBox: PublishedBox<Duration>

        @OnPressEvent
        private var onPressEvent

        @Router
        private var router

        @FocusState
        private var focusedControl: ControlFocus?

        @State
        private var scrubSeekTask: Task<Void, Never>?

        private static let headerGradientColors: [Color] = [.black.opacity(0.8), .clear]
        private static let controlsGradientColors: [Color] = [.clear, .black.opacity(0.85)]
        private static let rowSpacing: CGFloat = 20

        enum ControlFocus: Hashable {
            case seekbar
            case playPause
            case rewind
            case fastForward
            case closedCaptions
            case audioTrack
            case previous
            case next
            case aspectFill
        }

        private var isPlaying: Bool {
            manager.rate > 0
        }

        private var isLiveTV: Bool {
            manager.item.isLiveStream
        }

        private var isScrubbing: Bool {
            containerState.isScrubbing
        }

        private var isPresentingOverlay: Bool {
            containerState.isPresentingOverlay
        }

        private var isPresentingSupplement: Bool {
            containerState.isPresentingSupplement
        }

        private var initialFocus: ControlFocus {
            isLiveTV ? .playPause : .seekbar
        }

        private var scrubFraction: Float {
            guard let runtime = manager.item.runtime, runtime > .zero else { return 0 }
            let current = isScrubbing ? scrubbedSecondsBox.value : manager.seconds
            return Float(max(0, min(1, current.seconds / runtime.seconds)))
        }

        var body: some View {
            ZStack {
                if isPresentingOverlay {
                    overlayContent
                        .focusSection()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isPresentingOverlay)
            .onReceive(onPressEvent) { handlePress($0) }
            .onReceive(manager.secondsBox.$value.receive(on: DispatchQueue.main)) { seconds in
                guard !containerState.isScrubbing else { return }
                scrubbedSecondsBox.value = seconds
            }
            .onReceive(containerState.timer) { _ in
                guard isPresentingOverlay, !isScrubbing, !isPresentingSupplement else { return }
                containerState.isPresentingOverlay = false
            }
        }

        private var overlayContent: some View {
            VStack {
                headerSection
                Spacer()
                if !isPresentingSupplement {
                    controlsSection
                }
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 60)
            .onAppear { focusedControl = initialFocus }
            .defaultFocus($focusedControl, initialFocus)
            .onChange(of: focusedControl) { _, newFocus in
                containerState.timer.poke()
                if newFocus != .seekbar && isScrubbing {
                    commitScrub()
                }
            }
        }

        // MARK: - Header

        private var headerSection: some View {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(manager.item.displayTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if let subtitle = manager.item.subtitle {
                        Text(subtitle)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isLiveTV { liveBadge }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: Self.headerGradientColors, startPoint: .top, endPoint: .bottom)
                    .padding(.horizontal, -80)
                    .padding(.top, -60)
                    .frame(height: 200)
            )
        }

        private var liveBadge: some View {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill").font(.callout)
                Text("LIVE").font(.callout).fontWeight(.bold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.red.opacity(0.95)))
        }

        // MARK: - Controls

        private var controlsSection: some View {
            VStack(spacing: 12) {
                primaryControlRow
                if !isLiveTV { seekbarRow }
                secondaryControlRow
            }
            .background(
                LinearGradient(colors: Self.controlsGradientColors, startPoint: .top, endPoint: .bottom)
                    .padding(.horizontal, -80)
                    .padding(.bottom, -60)
                    .frame(height: 340)
                    .offset(y: 60),
                alignment: .bottom
            )
        }

        private var primaryControlRow: some View {
            HStack(spacing: Self.rowSpacing) {
                overlayButton(icon: isPlaying ? "pause.fill" : "play.fill", focus: .playPause) {
                    manager.togglePlayPause()
                }

                if !isLiveTV {
                    overlayButton(icon: "backward.fill", focus: .rewind) {
                        manager.proxy?.jumpBackward(.seconds(10))
                    }

                    overlayButton(icon: "forward.fill", focus: .fastForward) {
                        manager.proxy?.jumpForward(.seconds(10))
                    }

                    if let playbackItem = manager.playbackItem {
                        if playbackItem.subtitleStreams.isNotEmpty {
                            NavigationBar.ActionButtons.Subtitles()
                                .focused($focusedControl, equals: .closedCaptions)
                        }

                        if playbackItem.audioStreams.isNotEmpty {
                            NavigationBar.ActionButtons.Audio()
                                .focused($focusedControl, equals: .audioTrack)
                        }
                    }
                }

                Spacer()

                if !isLiveTV, let runtime = manager.item.runtime {
                    let remaining = runtime - scrubbedSecondsBox.value
                    let endsAt = Date.now.addingTimeInterval(remaining.seconds)
                    let timeString = endsAt.formatted(date: .omitted, time: .shortened)
                    Text(L10n.endsAt(timeString))
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .playerOverlayButtonStyle()
        }

        private var seekbarRow: some View {
            PlayerSeekBar(
                progress: scrubFraction,
                bufferProgress: 0,
                isFocused: focusedControl == .seekbar
            )
            .focusable()
            .focused($focusedControl, equals: .seekbar)
            .focusEffectDisabled()
            .onMoveCommand { direction in
                switch direction {
                case .left:
                    if !isScrubbing { beginScrub() }
                    updateScrub(bySeconds: -10)
                    containerState.timer.poke()
                case .right:
                    if !isScrubbing { beginScrub() }
                    updateScrub(bySeconds: 10)
                    containerState.timer.poke()
                case .up, .down:
                    if isScrubbing { commitScrub() }
                @unknown default:
                    break
                }
            }
            .onTapGesture {
                manager.togglePlayPause()
                containerState.timer.poke()
            }
        }

        private var secondaryControlRow: some View {
            HStack(spacing: Self.rowSpacing) {
                NavigationBar.ActionButtons.PlayPreviousItem()
                    .focused($focusedControl, equals: .previous)

                NavigationBar.ActionButtons.PlayNextItem()
                    .focused($focusedControl, equals: .next)

                NavigationBar.ActionButtons.AspectFill()
                    .focused($focusedControl, equals: .aspectFill)

                Spacer()

                if !isLiveTV, let runtime = manager.item.runtime {
                    HStack(spacing: 4) {
                        Text(scrubbedSecondsBox.value, format: .runtime)
                        Text(verbatim: "/")
                        Text(runtime, format: .runtime)
                    }
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.7))
                }
            }
            .playerOverlayButtonStyle()
        }

        // MARK: - Button helper

        private func overlayButton(icon: String, focus: ControlFocus, action: @escaping () -> Void) -> some View {
            Button {
                action()
                containerState.timer.poke()
            } label: {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 46, height: 46)
                    .contentShape(Circle())
            }
            .focused($focusedControl, equals: focus)
        }

        // MARK: - Scrub helpers

        private func beginScrub() {
            scrubbedSecondsBox.value = manager.seconds
            containerState.isScrubbing = true
        }

        private func updateScrub(bySeconds delta: Double) {
            let maxSeconds = (manager.item.runtime ?? .zero).seconds
            let clamped = max(0, min(maxSeconds, scrubbedSecondsBox.value.seconds + delta))
            scrubbedSecondsBox.value = .seconds(clamped)
            debouncedSeek()
        }

        private func debouncedSeek() {
            scrubSeekTask?.cancel()
            let target = scrubbedSecondsBox.value
            scrubSeekTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled, containerState.isScrubbing else { return }
                // Auto-commit after idle so the bridge resumes pushing live seconds into the display.
                manager.seconds = target
                manager.proxy?.setSeconds(target)
                containerState.isScrubbing = false
                containerState.timer.poke()
            }
        }

        private func commitScrub() {
            scrubSeekTask?.cancel()
            let target = scrubbedSecondsBox.value
            manager.seconds = target
            manager.proxy?.setSeconds(target)
            containerState.isScrubbing = false
            containerState.timer.poke()
        }

        private func cancelScrub() {
            scrubSeekTask?.cancel()
            scrubbedSecondsBox.value = manager.seconds
            containerState.isScrubbing = false
            containerState.timer.poke()
        }

        // MARK: - Press handling

        private func handlePress(_ press: (type: UIPress.PressType, phase: UIPress.Phase)) {
            switch press {
            case (.playPause, .began):
                if isScrubbing { commitScrub() } else { manager.togglePlayPause() }
                containerState.isPresentingOverlay = true
                containerState.timer.poke()

            case (.select, .began):
                if !isPresentingOverlay {
                    containerState.isPresentingOverlay = true
                }

            case (.leftArrow, .began):
                if isPresentingOverlay && focusedControl == .seekbar {
                    if !isScrubbing { beginScrub() }
                    updateScrub(bySeconds: -10)
                    containerState.timer.poke()
                } else if !isPresentingOverlay {
                    containerState.isPresentingOverlay = true
                }

            case (.rightArrow, .began):
                if isPresentingOverlay && focusedControl == .seekbar {
                    if !isScrubbing { beginScrub() }
                    updateScrub(bySeconds: 10)
                    containerState.timer.poke()
                } else if !isPresentingOverlay {
                    containerState.isPresentingOverlay = true
                }

            case (.upArrow, .began), (.downArrow, .began):
                if isPresentingOverlay {
                    if isScrubbing { commitScrub() }
                } else {
                    containerState.isPresentingOverlay = true
                }

            case (.menu, _):
                if isScrubbing {
                    cancelScrub()
                } else if isPresentingSupplement {
                    containerState.selectedSupplement = nil
                } else if isPresentingOverlay {
                    containerState.isPresentingOverlay = false
                } else {
                    manager.proxy?.stop()
                    router.dismiss()
                }

            default: ()
            }
        }
    }
}
