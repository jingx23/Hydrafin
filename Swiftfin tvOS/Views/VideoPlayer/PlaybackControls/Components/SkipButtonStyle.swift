//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

// Focusable text capsule for the floating "Skip Credits" / "Next Episode" button.
// Like PlayerOverlayButtonStyle, uses a nested View to read @Environment(\.isFocused),
// which ButtonStyle.makeBody can't hold directly.
struct SkipButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        InnerView(configuration: configuration)
    }

    private struct InnerView: View {

        @Environment(\.isFocused)
        private var isFocused

        let configuration: ButtonStyle.Configuration

        var body: some View {
            configuration.label
                .font(.callout.weight(.semibold))
                .foregroundStyle(isFocused ? Color.black : .white)
                .padding(.vertical, 14)
                .padding(.horizontal, 28)
                .background(
                    Capsule()
                        .fill(isFocused ? Color.white : Color(white: 0.2, opacity: 0.7))
                )
                .scaleEffect(configuration.isPressed ? 0.95 : (isFocused ? 1.05 : 1.0))
                .animation(.easeInOut(duration: 0.15), value: isFocused)
                .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        }
    }
}
