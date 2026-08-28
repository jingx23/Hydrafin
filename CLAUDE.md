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
| `Shared/Views/VideoPlayer/VideoPlayer.swift` | Upstream file with two MPV patches: `init` uses `MPVMediaPlayerProxy()` instead of `VLCMediaPlayerProxy()`, and `onAppear`/`onDisappear` toggle `UIApplication.shared.isIdleTimerDisabled` (MPV's CAMetalLayer doesn't auto-suppress the idle timer). On merge: take upstream, re-apply both patches. (The old `Shared/Components/MPVVideoPlayer.swift` wrapper was retired in the 2026-08 merge.) |
| `Shared/Objects/MediaPlayerManager/MediaPlayerProxy/MediaPlayerProxy+MPV.swift` | Full MPV proxy implementation (`MPVMediaPlayerProxy`) |
| `Shared/Objects/MediaPlayerManager/AudioUnitFix/AudioUnitChannelLayoutFix.h` | C header for the CoreAudio multichannel/Atmos workaround |
| `Shared/Objects/MediaPlayerManager/AudioUnitFix/AudioUnitChannelLayoutFix.c` | mach-o symbol-rebinding implementation; called from `MPVController.setupMpv()` |
| `Shared/Hydrafin-Bridging-Header.h` | Swift ↔ C bridging header (configured via `XcodeConfig/Shared.xcconfig`) |
| `Shared/Objects/VideoPlayerType/VideoPlayerType.swift` | Has `.mpv` + `.native` cases — upstream has `.native` + `.swiftfin` |
| `Shared/Objects/VideoPlayerType/VideoPlayerType+MPV.swift` | MPV direct-play, transcoding, and subtitle profiles |

### Skip Credits / Next Episode (fork-only feature)

Upstream has no media-segment support. These files are fork-only — preserve on every merge:

| File | Role |
|------|------|
| `Shared/Objects/MediaSegments/*` | Segment model + providers (Jellyfin API, heuristic fallback, composite) |
| `Shared/Views/VideoPlayer/Components/SegmentSkipButton.swift` | Floating iOS skip button (`VideoPlayer.PlaybackControls.SegmentSkipButton`) |
| `Swiftfin tvOS/Views/VideoPlayer/PlaybackControls/Components/PlaybackControls+SegmentSkip.swift` | tvOS skip layer + skip logic extension on `VideoPlayer.PlaybackControls` |
| `Swiftfin tvOS/Views/VideoPlayer/PlaybackControls/Components/SkipButtonStyle.swift` | Focus-aware capsule button style for tvOS |

**CRITICAL — seconds sync:** upstream's playback controls (progress bar, timestamps) are driven by `containerState.scrubbedSeconds`, which each proxy's player view must feed. Upstream's VLC view does this in `onSecondsUpdated`; the MPV equivalent is `MPVPlayerBodyView` in `MediaPlayerProxy+MPV.swift` (wraps `MPVPlayerView`, forwards `manager.secondsBox` → `containerState.scrubbedSeconds` when not scrubbing). Without it the player UI freezes at the start position.

Small fork patches inside upstream files (re-apply after taking upstream):
- `Swiftfin tvOS/Views/VideoPlayer/PlaybackControls/Components/PlaybackProgress.swift` — "Ends at HH:MM" wall-clock label above the slider (uses `L10n.endsAt`)
- `Shared/Objects/VideoPlayerContainerState.swift` — `isSkipButtonFocused` published var (tvOS)
- `Shared/Views/VideoPlayer/VideoPlayerContainerView/VideoPlayerContainerView.swift` — iOS: `SegmentSkipButton()` in the playback-controls ZStack; tvOS: `handleSelectEnded` forwards select presses when `isSkipButtonFocused`
- `Swiftfin tvOS/Views/VideoPlayer/PlaybackControls/PlaybackControls.swift` — `showSkipButtons` default, `isSkipButtonFocused` FocusState, `currentSeconds` state, `segmentSkipLayer` in body ZStack, focus-management `onChange` handlers
- `Shared/Views/SettingsView/VideoPlayerSettingsView.swift` — `showSkipButtons` toggle in the buttons section
- `Shared/Objects/MediaPlayerManager/MediaPlayerItem/MediaPlayerItem.swift` + `+Build.swift` — `segments` property, populated via `mediaSegmentProvider`
- Strings: `nextEpisode`, `skipCredits`, `showSkipButton`, `endsAt` in `Strings.swift` + `Translations/*` (plus MPV-specific `playerSwiftfinDescription`/`playerNativeDescription` texts)

### MPV-specific defaults

In `Shared/Services/SwiftfinDefaults.swift`:
- `videoPlayerType` default is `.mpv` (upstream defaults to `.swiftfin`)
- `showSkipButtons` (fork-only key, default `true`)

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

- **CoreStore pinned to a revision** (temporary) — CoreStore 9.3.0 fails to compile under Xcode 27 (`ambiguous use of 'cs_sync'`). The fix (JohnEstropia/CoreStore#519) is merged on `develop` but unreleased, so the project pins `CoreStore` to revision `332883717578c009e1e8917a647a2f6c975e8f0a` (= 9.3.0 + fix). When a release newer than 9.3.0 ships, switch the requirement in `project.pbxproj` back to `upToNextMajorVersion 9.0.0`. Upstream Swiftfin uses the normal version range — on merges, keep the revision pin until then.

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

**RULE — fork-added controls and information are never silently dropped.** Before resolving, inventory the fork's custom player UI/behavior (see "Skip Credits / Next Episode" and "fork patches" sections above, plus `git diff <merge-base>..HEAD` for anything newer). Every item must survive the merge — ported into upstream's new structure if it moved. If upstream adds the same or an equivalent control/information display, check whether upstream's version works with MPV, then **ask the user** whether to adopt upstream's version or keep the fork's — do not decide unilaterally. (Lesson from the 2026-08 merge: the upstream player rewrite silently dropped the "Ends at" label and the MPV progress sync.)

Use this policy for each conflicted file:

| File | Resolution |
|------|-----------|
| `Shared/Views/VideoPlayer/VideoPlayer.swift` | Take upstream, then re-apply the two MPV patches: `MPVMediaPlayerProxy()` in `init`, and the `isIdleTimerDisabled` toggle in `onAppear`/`onDisappear` |
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
grep -r "DeletedSymbolName" Shared/Views/VideoPlayer/VideoPlayer.swift \
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
