//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

extension VideoPlayer.PlaybackControls {

    /// The outro (closing credits) segment containing the current position,
    /// when the skip feature is enabled and we're inside one.
    var activeOutro: MediaSegment? {
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
            manager.seconds = outro.end
        }
        containerState.timer.poke()
    }

    /// Floating, focusable "Next Episode" / "Skip Credits" button shown over
    /// hidden controls while playback is inside the outro segment.
    @ViewBuilder
    var segmentSkipLayer: some View {
        if let outro = activeOutro,
           !containerState.isPresentingOverlay,
           !containerState.isPresentingSupplement
        {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        skip(past: outro)
                    } label: {
                        Label(
                            hasNextItem ? L10n.nextEpisode : L10n.skipCredits,
                            systemImage: hasNextItem ? "forward.end.fill" : "forward.fill"
                        )
                    }
                    .buttonStyle(SkipButtonStyle())
                    .focused($isSkipButtonFocused)
                }
            }
            .padding(80)
            .transition(.opacity)
        }
    }
}
