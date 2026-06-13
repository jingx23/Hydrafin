//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import Defaults
import SwiftUI

extension VideoPlayer.PlaybackControls {

    /// A floating button that appears while playback is inside the outro
    /// (closing credits) segment. Tapping it starts the next episode when one
    /// is queued, otherwise seeks just past the credits.
    ///
    /// Shown independently of the playback controls' visibility so the user can
    /// skip without first revealing the controls.
    struct SegmentSkipButton: View {

        @Default(.VideoPlayer.showSkipButtons)
        private var showSkipButtons

        @EnvironmentObject
        private var manager: MediaPlayerManager

        @State
        private var currentSeconds: Duration = .zero

        /// The outro segment containing the current position, if the feature is
        /// enabled and we're inside one.
        private var activeOutro: MediaSegment? {
            guard showSkipButtons, !manager.item.isLiveStream else { return nil }
            return manager.playbackItem?.segments.segment(ofKind: .outro, at: currentSeconds)
        }

        private var hasNextItem: Bool {
            manager.queue?.nextItem != nil
        }

        private func skip(past outro: MediaSegment) {
            if let nextItem = manager.queue?.nextItem {
                manager.playNewItem(provider: nextItem)
            } else {
                manager.proxy?.setSeconds(outro.end)
            }
        }

        @ViewBuilder
        private func button(for outro: MediaSegment) -> some View {
            Button {
                skip(past: outro)
            } label: {
                Label(
                    hasNextItem ? L10n.nextEpisode : L10n.skipCredits,
                    systemImage: hasNextItem ? "forward.end.fill" : "forward.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 18)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }

        var body: some View {
            ZStack(alignment: .bottomTrailing) {
                if let outro = activeOutro {
                    button(for: outro)
                        .padding(.trailing, 32)
                        .padding(.bottom, 80)
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomTrailing)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .animation(.snappy, value: activeOutro)
            .onReceive(manager.secondsBox.$value.receive(on: DispatchQueue.main)) { currentSeconds = $0 }
        }
    }
}
