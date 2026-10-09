# Hydrafin — Claude Code Context

## Project overview

Hydrafin is a **personal fork** of [jellyfin/Swiftfin](https://github.com/jellyfin/Swiftfin), the native iOS/tvOS Jellyfin client.

**Fork:** `jingx23/Hydrafin` (origin)
**Upstream:** `jellyfin/Swiftfin` (upstream remote)

Since 2026-10 the fork is **upstream plus a short stack of patches**, rebased onto `upstream/main`. Everything else — players (Native, VLC, MPV via MPVUI), project and target names, CI — is upstream's. Keep the stack small: every patch must earn its place, and player changes apply only when the MPV player is selected.

The pre-reset fork (MPVKit player, Skip Credits / Next Episode, custom track mapping) is preserved in tags `archive/pre-upstream-reset` and `archive/spike-mpvui`.

## Patch stack

Each patch is one commit, in this order on top of `upstream/main`:

| Commit | Files | Notes |
|--------|-------|-------|
| `feat: rebrand app identity as Hydrafin` | `XcodeConfig/Shared.xcconfig` (bundle ID), `Swiftfin.xcodeproj/project.pbxproj` (iOS Release bundle ID override), both `Info.plist`s (`CFBundleDisplayName = Hydrafin`, URL scheme `hydrafin` only), `JellyfinClient.swift` (client name), `ProperNouns.swift`, `AboutAppView.swift`, `SwiftfinSpotlight.swift` | Bundle ID `net.jingx.hydrafin`. Never claim the `swiftfin`/`jellyfin` URL schemes — they collide with the real Swiftfin app. Project/target/scheme names stay upstream's on purpose. |
| `feat: replace Jellyfin glyph with the Hydrafin hydra logo` | `Swiftfin/Resources/AppIcons/*.icon/Assets/Glyph.svg`, `Swiftfin/Resources/Assets.xcassets/AppIcon-*.imageset`, `Resources/AppIcons/Dark/*.svg`, `Resources/primary-wide.svg`, `Shared/Resources/Assets.xcassets/jellyfin-blob-blue.imageset`, tvOS front layers / App Store icon / top shelf PNGs | The hydra is a single SVG path that replaces upstream's Jellyfin glyph path. If upstream adds icon variants, swap the path in them too and re-render the tvOS PNGs (`rsvg-convert` from the variant's `Glyph.svg`, 216/432/512 px). |
| `feat: show "Ends at" time in the video player` | `Shared/Views/VideoPlayer/Components/PlaybackProgress/EndsAtText.swift`, iOS + tvOS `PlaybackProgress.swift`, `endsAt` in `Translations/en.lproj/Localizable.strings` | Same formula and hiding rules as jellyfin-web (`getEndsAtFromPosition`). English only — translations come via Weblate. Planned upstream PR. |
| `feat: direct play lossless audio with the MPV player` | `Shared/Objects/VideoPlayerType/VideoPlayerType+MPV.swift`, one switch arm in `VideoPlayerType.swift` | MPV = VLC profiles + TrueHD / DTS-HD / MLP direct play. Planned upstream PR. |
| `fix: keep mpv audio when Live TV reports an unknown audio index` | `setAudioStream` in `Shared/Objects/MediaPlayerManager/MediaPlayerProxy/MediaPlayerProxy+MPV.swift` | M3U Live TV reports audio index -1; upstream's MPV proxy disabled audio for it. Ignore negative indexes. Planned upstream PR. |
| `docs: …` | `CLAUDE.md` | This file. |

## Syncing with upstream

```bash
git fetch upstream
git rebase upstream/main
```

Conflicts are confined to the files in the table. For `Translations/en.lproj/Localizable.strings` (UTF-16, binary to git): take upstream's file, re-add the `endsAt` entry (`/// Ends at %@` doc line, alphabetical), then regenerate `Shared/Strings/Strings.swift` with `swift Scripts/Translations/GenerateStrings.swift` — never hand-edit `Strings.swift`. (The generator strips the file's final newline; upstream commits it with one, so discard that whitespace-only change.) After a rebase, build both targets, then force-push `main` (`--force-with-lease`).

## Building

- Schemes: `Swiftfin` / `Swiftfin tvOS` (upstream names), project `Swiftfin.xcodeproj`.
- Use `-destination 'generic/platform=iOS Simulator'` (or tvOS) and `CODE_SIGNING_ALLOWED=NO`.
- The build's "Run SwiftFormat" phase may reformat unrelated files — revert those before committing and stage files explicitly.
- Signing: put `DEVELOPMENT_TEAM = …` in `XcodeConfig/DevelopmentTeam.xcconfig` (git-ignored, included by `Shared.xcconfig`).
