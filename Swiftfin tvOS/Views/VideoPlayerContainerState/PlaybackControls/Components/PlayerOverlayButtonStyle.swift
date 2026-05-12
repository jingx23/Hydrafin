//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

// Moonfin-style player overlay button: white circle background when focused, transparent when not.
// Uses a nested View to access @Environment(\.isFocused), which ButtonStyle.makeBody can't hold directly.
// Label should set .frame(width: 46, height: 46).contentShape(Circle()) — style adds .padding(10) → 66×66 circle.
struct PlayerOverlayButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        InnerView(configuration: configuration)
    }

    private struct InnerView: View {

        @Environment(\.isFocused)
        private var isFocused

        let configuration: ButtonStyle.Configuration

        var body: some View {
            configuration.label
                .foregroundStyle(isFocused ? Color(white: 0.27) : .white)
                .padding(10)
                .background(Circle().fill(isFocused ? Color(white: 0.8, opacity: 0.9) : .clear))
                .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isFocused)
                .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        }
    }
}

extension View {

    func playerOverlayButtonStyle() -> some View {
        buttonStyle(PlayerOverlayButtonStyle())
            .menuStyle(.button)
            .labelStyle(.iconOnly)
    }
}
