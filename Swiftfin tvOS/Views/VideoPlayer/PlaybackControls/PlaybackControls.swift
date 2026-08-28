//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

extension VideoPlayer {

    struct PlaybackControls: View {

        @Default(.VideoPlayer.jumpBackwardInterval)
        var jumpBackwardInterval
        @Default(.VideoPlayer.jumpForwardInterval)
        var jumpForwardInterval
        @Default(.VideoPlayer.showSkipButtons)
        var showSkipButtons

        @EnvironmentObject
        var containerState: VideoPlayerContainerState
        @EnvironmentObject
        var manager: MediaPlayerManager

        @Toaster
        var toaster: ToastProxy

        @FocusState
        private var isPlaybackProgressFocused: Bool

        @FocusState
        var isSkipButtonFocused: Bool

        // Drives re-evaluation of `activeOutro` while the overlay is hidden.
        @State
        var currentSeconds: Duration = .zero

        @State
        var speedBoostTimer: Timer?
        @State
        var isSpeedBoosting: Bool = false
        @State
        var pendingJumpWork: DispatchWorkItem?

        var body: some View {
            ZStack {
                VStack(spacing: 30) {

                    Toolbar()
                        .isVisible(
                            containerState.isPresentingOverlay &&
                                !containerState.isScrubbing &&
                                !containerState.isPresentingSupplement
                        )
                        .disabled(containerState.isPresentingSupplement)

                    PlaybackProgress()
                        .focused($isPlaybackProgressFocused)
                        .fixedSize(horizontal: false, vertical: true)
                        .isVisible(
                            (containerState.isPresentingOverlay || containerState.isScrubbing) &&
                                !containerState.isPresentingSupplement
                        )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .edgePadding(.horizontal)
                .focusSection()

                segmentSkipLayer
            }
            .animation(.easeInOut(duration: 0.25), value: containerState.isPresentingSupplement)
            .animation(.easeInOut(duration: 0.25), value: containerState.isPresentingOverlay)
            .animation(.linear(duration: 0.1), value: containerState.isScrubbing)
            .animation(.easeInOut(duration: 0.25), value: activeOutro)
            .alert(L10n.closePlayer, isPresented: $containerState.isPresentingCloseConfirmation) {
                Button(L10n.cancel, role: .cancel) {}

                Button(L10n.ok, role: .destructive) {
                    manager.stop()
                }
            } message: {
                Text(L10n.closePlayerWarning)
            }
            .onChange(of: containerState.isPresentingOverlay) {
                isPlaybackProgressFocused = true
            }
            .onChange(of: manager.playbackRequestStatus) {
                if manager.playbackRequestStatus == .paused, !containerState.isPresentingOverlay {
                    containerState.isPresentingOverlay = true
                }
            }
            .onReceive(containerState.containerView?.onPressEvent ?? .init()) { press in
                handlePressEvent(press)
            }
            .onChange(of: containerState.isProgressBarFocused) {
                if !containerState.isProgressBarFocused {
                    containerState.cancelScrub()

                    if isSpeedBoosting {
                        stopSpeedBoost()
                    }
                }
            }
            .onReceive(manager.secondsBox.$value.receive(on: DispatchQueue.main)) { seconds in
                currentSeconds = seconds
            }
            .onChange(of: isSkipButtonFocused) {
                containerState.isSkipButtonFocused = isSkipButtonFocused
            }
            .onChange(of: activeOutro) { _, newValue in
                // Move focus onto the skip button when it appears over hidden controls.
                if newValue != nil, !containerState.isPresentingOverlay {
                    isSkipButtonFocused = true
                }
            }
            .onChange(of: containerState.isPresentingOverlay) { _, presenting in
                // Restore focus to the skip button when controls hide during the outro.
                if !presenting, activeOutro != nil {
                    isSkipButtonFocused = true
                }
            }
        }
    }
}
