//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import JellyfinAPI

/// Synthesizes an `.outro` segment for sources that don't provide media
/// segments (e.g. Xtream), so the "Next Episode" / "Skip Credits" button can
/// still appear.
///
/// Boundary strategy, in order:
/// 1. A chapter whose title looks like credits → outro from that chapter's
///    start to the end of the item.
/// 2. Otherwise, the trailing `tailFraction` of the runtime, capped so the
///    synthesized outro is never longer than `maxTail`.
struct HeuristicSegmentProvider: MediaSegmentProvider {

    /// Fraction of total runtime, measured from the end, treated as credits
    /// when no labeled chapter is found.
    let tailFraction: Double

    /// Maximum length of a synthesized trailing outro.
    let maxTail: Duration

    /// Minimum runtime for which an outro is synthesized at all. Avoids firing
    /// on clips and very short items.
    let minRuntime: Duration

    init(
        tailFraction: Double = 0.04,
        maxTail: Duration = .seconds(90),
        minRuntime: Duration = .minutes(5)
    ) {
        self.tailFraction = tailFraction
        self.maxTail = maxTail
        self.minRuntime = minRuntime
    }

    func segments(for item: BaseItemDto) async throws -> [MediaSegment] {
        guard let runtime = item.runtime, runtime >= minRuntime else { return [] }

        let start = Self.outroStart(
            chapters: item.chapters ?? [],
            runtime: runtime,
            tailFraction: tailFraction,
            maxTail: maxTail
        )

        guard start < runtime else { return [] }

        return [
            MediaSegment(
                id: "heuristic-outro",
                kind: .outro,
                start: start,
                end: runtime
            ),
        ]
    }

    /// Pure outro-start computation, separated from item plumbing for testing.
    static func outroStart(
        chapters: [ChapterInfo],
        runtime: Duration,
        tailFraction: Double,
        maxTail: Duration
    ) -> Duration {

        // Prefer a chapter whose title looks like credits.
        if let creditsChapter = chapters.first(where: { $0.isLikelyCredits }),
           let startSeconds = creditsChapter.startSeconds,
           startSeconds < runtime
        {
            return startSeconds
        }

        // Fall back to the trailing fraction of runtime, capped to `maxTail`.
        let fractionStart = runtime - (runtime * tailFraction)
        let cappedStart = runtime - maxTail
        return max(fractionStart, cappedStart)
    }
}

private extension ChapterInfo {

    /// Whether this chapter's title suggests it is the credits/outro.
    var isLikelyCredits: Bool {
        guard let name else { return false }
        let lowercased = name.lowercased()
        return ["credit", "outro", "closing"].contains { lowercased.contains($0) }
    }
}
