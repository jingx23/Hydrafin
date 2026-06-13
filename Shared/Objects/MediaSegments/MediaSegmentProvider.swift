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

/// Produces the media segments (intro, outro/credits, …) for a playable item.
///
/// The player consumes segments through this protocol and does not care where
/// the boundaries originate — a server's Media Segments API, on-device
/// heuristics, or a future signal-processing detector. This lets segment-less
/// sources (e.g. Xtream) participate by synthesizing segments.
protocol MediaSegmentProvider: Sendable {

    func segments(for item: BaseItemDto) async throws -> [MediaSegment]
}

extension Container {

    /// The default provider used by the playback build pipeline: server
    /// segments when available, heuristic fallback otherwise.
    var mediaSegmentProvider: Factory<any MediaSegmentProvider> {
        self {
            CompositeSegmentProvider(
                primary: JellyfinSegmentProvider(),
                fallback: HeuristicSegmentProvider()
            )
        }
    }
}
