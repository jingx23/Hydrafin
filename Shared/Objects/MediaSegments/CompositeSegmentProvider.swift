//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import JellyfinAPI

/// Combines an authoritative provider (e.g. Jellyfin) with a fallback (e.g.
/// heuristic) used only when the primary yields no outro segment.
///
/// This is what lets Jellyfin items with no server-side segments — and
/// segment-less sources like Xtream — still surface a "Skip Credits" /
/// "Next Episode" button. Primary segments are always preserved; the fallback
/// only contributes its outro(s) when the primary has none.
struct CompositeSegmentProvider: MediaSegmentProvider {

    let primary: any MediaSegmentProvider
    let fallback: any MediaSegmentProvider

    func segments(for item: BaseItemDto) async throws -> [MediaSegment] {
        let primarySegments = await (try? primary.segments(for: item)) ?? []

        if primarySegments.contains(where: { $0.kind == .outro }) {
            return primarySegments
        }

        let fallbackOutros = await ((try? fallback.segments(for: item)) ?? [])
            .filter { $0.kind == .outro }

        return primarySegments + fallbackOutros
    }
}
