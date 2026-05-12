# Swiftfin — Claude Code Context

## Project overview

This is a **personal fork** of [jellyfin/Swiftfin](https://github.com/jellyfin/Swiftfin) — a native iOS/tvOS Jellyfin client written in SwiftUI.

**Fork:** `jingx23/Swiftfin` (origin)
**Upstream:** `jellyfin/Swiftfin` (upstream remote)

The primary customization of this fork is **replacing the VLC player with MPV**. Everything else tracks upstream as closely as possible.

## MPV player integration

### What was replaced

Upstream uses VLC (via the `VLCUI` SPM package and Carthage `MobileVLCKit.xcframework`). This fork removes both entirely and substitutes MPV via the [MPVKit](https://github.com/mpvkit/MPVKit) SPM package.

### MPV-specific files (never overwrite with upstream)

| File | Role |
|------|------|
| `Shared/Components/MPVVideoPlayer.swift` | Top-level SwiftUI view for the MPV player (equivalent to upstream's `VideoPlayer.swift` body) |
| `Shared/Components/VideoPlayer.swift` | Empty namespace enum — upstream has a VLC-hardcoded body here |
| `Shared/Objects/MediaPlayerManager/MediaPlayerProxy/MediaPlayerProxy+MPV.swift` | Full MPV proxy implementation (`MPVMediaPlayerProxy`) |
| `Shared/Objects/MediaPlayerManager/AudioUnitFix/AudioUnitChannelLayoutFix.h` | C header for the CoreAudio multichannel/Atmos workaround |
| `Shared/Objects/MediaPlayerManager/AudioUnitFix/AudioUnitChannelLayoutFix.c` | mach-o symbol-rebinding implementation; called from `MPVController.setupMpv()` |
| `Shared/Hydrafin-Bridging-Header.h` | Swift ↔ C bridging header (configured via `XcodeConfig/Shared.xcconfig`) |
| `Shared/Objects/VideoPlayerType/VideoPlayerType.swift` | Has `.mpv` + `.native` cases — upstream has `.native` + `.swiftfin` |
| `Shared/Objects/VideoPlayerType/VideoPlayerType+MPV.swift` | MPV direct-play, transcoding, and subtitle profiles |

### MPV-specific defaults

In `Shared/Services/SwiftfinDefaults.swift`:
- `videoPlayerType` default is `.mpv` (upstream defaults to `.swiftfin`)

### SPM dependency

Package: `https://github.com/mpvkit/MPVKit`
Product linked: `MPVKit-GPL`
Version constraint: `upToNextMajorVersion 0.41.0`

**project.pbxproj UUIDs** (these never change — preserve on every merge):

```
43A6D0442F38D4F500A89054  XCRemoteSwiftPackageReference "MPVKit"
43A6D0452F38D4F500A89054  XCSwiftPackageProductDependency MPVKit-GPL (iOS target)
43A6D0462F38D4F500A89054  PBXBuildFile MPVKit-GPL in Frameworks (iOS target)
43A6D0472F38D52100A89054  XCSwiftPackageProductDependency MPVKit-GPL (tvOS target)
43A6D0482F38D52100A89054  PBXBuildFile MPVKit-GPL in Frameworks (tvOS target)
```

Package.resolved entry (version may update, identity and location are fixed):

```json
{
  "identity" : "mpvkit",
  "kind" : "remoteSourceControl",
  "location" : "https://github.com/mpvkit/MPVKit",
  "state" : {
    "revision" : "613c0ccc3acf70e136aaff880a9b5fe8fdfaf5b8",
    "version" : "0.41.0"
  }
}
```

### Known issues / TODOs

- **Audio passthrough** — `audio-spdif=ac3,dts,eac3,truehd` is currently commented out in `setupMpvIOS()` and `setupMpvTVOS()` in `MediaPlayerProxy+MPV.swift`. It only works when connected to a real AV receiver; on device speakers/headphones it causes playback to hang. Needs a user-facing setting ("Send audio directly to receiver") in Video Player settings.

- **Rotation on iOS** — Fixed by explicitly setting `drawableSize` on the `CAMetalLayer` sublayer and cycling the video track (`vid no` → `vid auto`) to force a VO reconfig on bounds change. Root cause: CAMetalLayer sublayers don't auto-update `drawableSize` on frame changes. View-backed layer was not usable because MoltenVK modifies CAMetalLayer properties from `vo_thread` (off-main), which UIKit forbids for view-backed layers.

---

## Merging upstream

### Setup

```bash
git remote add upstream https://github.com/jellyfin/Swiftfin.git
git fetch upstream
```

### Merge workflow

```bash
git fetch upstream
git merge upstream/main
```

### Step 1 — before resolving any conflicts, snapshot custom deps

```bash
grep -E "MPVKit|43A6D04" Hydrafin.xcodeproj/project.pbxproj > /tmp/custom-deps.txt
grep "mpvkit" Hydrafin.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved >> /tmp/custom-deps.txt
```

### Step 2 — resolve conflicts

Use this policy for each conflicted file:

| File | Resolution |
|------|-----------|
| `Shared/Components/MPVVideoPlayer.swift` | Keep HEAD; manually apply upstream improvements (check diff for status bar API changes, error string localization, async wrapper removal) |
| `Shared/Components/VideoPlayer.swift` | Keep HEAD (the empty namespace enum) |
| `Shared/Objects/MediaPlayerManager/MediaPlayerProxy/MediaPlayerProxy+MPV.swift` | Keep HEAD entirely |
| `Shared/Objects/VideoPlayerType/VideoPlayerType.swift` | Keep HEAD; upstream may add cases that don't exist — ignore them |
| `Shared/Services/SwiftfinDefaults.swift` | Take upstream (to get new keys/style), then change `videoPlayerType` default back to `.mpv` |
| `Hydrafin.xcodeproj/project.pbxproj` | Take upstream (`git checkout --theirs`), then re-add all MPVKit entries from Step 1 |
| `Hydrafin.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` | Take upstream (`git checkout --theirs`), then re-add the `mpvkit` block |
| `XcodeConfig/Shared.xcconfig` | Take upstream, then restore `PRODUCT_BUNDLE_IDENTIFIER = net.jingx.hydrafin`, `SWIFT_OBJC_BRIDGING_HEADER`, and `HEADER_SEARCH_PATHS` |
| `Swiftfin tvOS/Resources/Info.plist` | Take upstream, then restore `CFBundledisplayTitle = Hydrafin` |
| All other files | Take upstream (`git checkout --theirs`) unless you have a specific reason to keep HEAD |

### Step 3 — check for deleted files that MPV still references

```bash
git diff upstream/main...HEAD --name-only --diff-filter=D
```

For each deleted file, grep for its exported symbol in the MPV-specific files:

```bash
grep -r "DeletedSymbolName" Shared/Components/MPVVideoPlayer.swift \
  Shared/Objects/MediaPlayerManager/MediaPlayerProxy/MediaPlayerProxy+MPV.swift
```

### Step 4 — verify protocol conformance

Upstream occasionally adds requirements to `VideoMediaPlayerProxy` or `MediaPlayerProxy`. The AVPlayer impl gets them automatically during the merge, but `MPVMediaPlayerProxy` won't. After merging:

```bash
# List all protocol requirements
grep -n "var\|func" Shared/Objects/MediaPlayerManager/MediaPlayerProxy/MediaPlayerProxy.swift

# Check MPV impl covers every one
grep -n "var\|func" Shared/Objects/MediaPlayerManager/MediaPlayerProxy/MediaPlayerProxy+MPV.swift
```

Common pattern to watch: new `PublishedBox<T>` properties added to the protocol (e.g. `droppedFrames`, `corruptedFrames`). Add them to `MPVMediaPlayerProxy` initialized to a sensible zero value.

### Step 5 — build early

Build the iOS target after resolving just the MPV-related files (Steps 2–4) before resolving the rest of the conflicts. This surfaces breaking changes immediately rather than at the very end.

### Step 6 — commit

```bash
git add .
git commit -m "feat: merge upstream jellyfin/Swiftfin main"
```

---

## App identity (Hydrafin rebrand)

This fork is branded as **Hydrafin** (not Swiftfin). Key identity values:

| Setting | Value |
|---------|-------|
| Bundle ID | `net.jingx.hydrafin` |
| iOS display name | `Hydrafin` (set via `INFOPLIST_KEY_CFBundleDisplayName` in `project.pbxproj`) |
| tvOS display title | `Hydrafin` (set via `CFBundledisplayTitle` in `Swiftfin tvOS/Resources/Info.plist`) |
| Primary xcconfig | `XcodeConfig/Shared.xcconfig` — `PRODUCT_BUNDLE_IDENTIFIER = net.jingx.hydrafin` |

After taking upstream changes to `project.pbxproj`, restore:
```bash
sed -i '' 's/org\.jellyfin\.swiftfin/net.jingx.hydrafin/g' Hydrafin.xcodeproj/project.pbxproj
sed -i '' 's/INFOPLIST_KEY_CFBundleDisplayName = Swiftfin/INFOPLIST_KEY_CFBundleDisplayName = Hydrafin/g' Hydrafin.xcodeproj/project.pbxproj
```

---

## Architecture notes

- **`VideoMediaPlayerProxy`** — protocol in `MediaPlayerProxy.swift` that both `MPVMediaPlayerProxy` and `AVMediaPlayerProxy` conform to. Any new requirement added upstream to this protocol must be implemented in `MediaPlayerProxy+MPV.swift` manually.
- **`VideoPlayerType`** — enum that controls which player is used. This fork adds `.mpv`; upstream adds `.swiftfin` (their native wrapper). The two diverge — keep HEAD.
- **`MediaPlayerManager`** — shared; takes upstream changes freely.
- **Supplements** (`EpisodeMediaPlayerQueue`, `PlaybackInformationSupplement`, etc.) — shared; take upstream changes freely.
