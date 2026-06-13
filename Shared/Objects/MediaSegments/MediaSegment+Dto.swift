//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import JellyfinAPI

extension MediaSegment {

    /// Maps a Jellyfin `MediaSegmentDto`. Returns `nil` for segments that are
    /// of an unsupported type or that have incomplete / invalid bounds.
    init?(dto: MediaSegmentDto) {
        guard let kind = dto.type?.asMediaSegmentKind,
              let startTicks = dto.startTicks,
              let endTicks = dto.endTicks,
              endTicks > startTicks
        else { return nil }

        self.init(
            id: dto.id ?? "\(kind)-\(startTicks)-\(endTicks)",
            kind: kind,
            start: .ticks(startTicks),
            end: .ticks(endTicks)
        )
    }
}

private extension MediaSegmentType {

    /// The supported `MediaSegment.Kind`, or `nil` for `.unknown`.
    var asMediaSegmentKind: MediaSegment.Kind? {
        switch self {
        case .intro: .intro
        case .outro: .outro
        case .recap: .recap
        case .preview: .preview
        case .commercial: .commercial
        case .unknown: nil
        }
    }
}
