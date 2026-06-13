//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation

/// A source-agnostic media segment (intro, outro/credits, recap, …).
///
/// Decoupled from Jellyfin's `MediaSegmentDto` so that sources without a
/// Media Segments API (e.g. Xtream) can synthesize segments too. A
/// `MediaSegmentProvider` is responsible for producing these regardless of
/// where the boundaries come from.
struct MediaSegment: Identifiable, Hashable {

    enum Kind: Hashable {
        case intro
        case outro
        case recap
        case preview
        case commercial
    }

    let id: String
    let kind: Kind
    let start: Duration
    let end: Duration

    /// Whether the given playback position falls within this segment.
    func contains(_ seconds: Duration) -> Bool {
        seconds >= start && seconds < end
    }
}

extension Collection<MediaSegment> {

    /// The first segment of the given kind containing `seconds`, if any.
    func segment(ofKind kind: MediaSegment.Kind, at seconds: Duration) -> MediaSegment? {
        first { $0.kind == kind && $0.contains(seconds) }
    }
}
