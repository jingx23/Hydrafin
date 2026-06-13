//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Factory
import Foundation
import JellyfinAPI

/// Fetches server-computed media segments via Jellyfin's Media Segments API
/// (`GET /MediaSegments/{itemID}`).
///
/// Segments are produced server-side, typically by a plugin such as Intro
/// Skipper, which detects intros via audio fingerprinting and credits via
/// black-frame / silence analysis.
struct JellyfinSegmentProvider: MediaSegmentProvider {

    func segments(for item: BaseItemDto) async throws -> [MediaSegment] {
        guard let itemID = item.id,
              let userSession = Container.shared.currentUserSession()
        else { return [] }

        let request = Paths.getItemSegments(itemID: itemID)
        let response = try await userSession.client.send(request)

        return (response.value.items ?? [])
            .compactMap(MediaSegment.init(dto:))
    }
}
