//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI

/// mpv uses VLC's profiles, except that direct play also allows the lossless
/// audio codecs mpv decodes itself. Without them the server transcodes
/// TrueHD / DTS-HD audio tracks.
extension VideoPlayerType {

    // MARK: - Direct Play

    static var _mpvDirectPlayProfiles: [DirectPlayProfile] {
        _vlcDirectPlayProfiles.map { profile in
            guard profile.type == .video, let audioCodec = profile.audioCodec else { return profile }

            let audioCodecs = audioCodec.split(separator: ",").map(String.init)
            let additionalCodecs = mpvAdditionalAudioCodecs
                .map(\.rawValue)
                .filter { !audioCodecs.contains($0) }

            return DirectPlayProfile(
                audioCodec: (audioCodecs + additionalCodecs).joined(separator: ","),
                container: profile.container,
                type: profile.type,
                videoCodec: profile.videoCodec
            )
        }
    }

    private static let mpvAdditionalAudioCodecs: [AudioCodec] = [
        .dts_hd,
        .mlp,
        .truehd,
    ]
}
