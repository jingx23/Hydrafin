//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI

enum VideoPlayerType: String, CaseIterable, Displayable, Storable {

    case mpv
    case native

    var displayTitle: String {
        switch self {
        case .mpv:
            "MPV"
        case .native:
            L10n.native
        }
    }

    var directPlayProfiles: [DirectPlayProfile] {
        switch self {
        case .mpv:
            Self._mpvDirectPlayProfiles
        case .native:
            Self._nativeDirectPlayProfiles
        }
    }

    var transcodingProfiles: [TranscodingProfile] {
        switch self {
        case .mpv:
            Self._mpvTranscodingProfiles
        case .native:
            Self._nativeTranscodingProfiles
        }
    }

    var subtitleProfiles: [SubtitleProfile] {
        switch self {
        case .mpv:
            Self._mpvSubtitleProfiles
        case .native:
            Self._nativeSubtitleProfiles
        }
    }
}
