# DMGStudio handoff

## Current state

DMGStudio is a macOS 13+ Xcode project with a SwiftUI editor and a `dmgstudio` command-line target. It creates an unsigned, compressed UDZO DMG from a valid `.app`, with optional PNG/JPEG Finder background and ICNS or large square-PNG volume icon. Finder presentation is written deterministically to `.DS_Store`; the build never automates Finder.

The project has one exact-pinned Swift Package dependency: `DSStore` at `e0a551419527f7f5af6e8b545d597aa7ee52b2e6`. Keep the UI and CLI using `DMGStudioCore`; do not duplicate disk-image behavior between them.

## Repository layout

- `DMGStudio/` — SwiftUI application target.
- `DMGStudioCLI/` — `dmgstudio` executable entry point.
- `DMGStudioCore/` — validation, canvas/layout resolution, artwork, disk-image pipeline, and CLI parsing.
- `DMGStudioTests/` — XCTest coverage for core behavior and injected system boundaries.
- `.spec/features/` — product requirements and acceptance criteria.
- `docs/` and `docs/adr/` — architecture, development notes, CLI instructions, distribution notes, and decisions.

## Build and test

Run from the repository root:

```sh
xcodebuild build -project DMGStudio.xcodeproj -scheme DMGStudio -configuration Debug -destination 'platform=macOS'
xcodebuild test -project DMGStudio.xcodeproj -scheme DMGStudio -configuration Debug -destination 'platform=macOS'
```

The `DMGStudio` scheme builds the GUI and CLI. Xcode places Debug products under its DerivedData directory. Use `dmgstudio --help` to see the command interface:

```text
dmgstudio create --app /path/App.app [--background path] [--volume-icon path]
          [--volume-name name] [--output path] [--app-x 0...1]
          [--applications-x 0...1]
```

## Verified behavior

- The complete XCTest suite was green: 17 DMGStudio tests.
- The direct `.DS_Store` test reads back the picture alias, icon coordinates, icon-view settings, and window bounds emitted by the deterministic writer.
- The mounted image contained the app, `Applications -> /Applications`, `.DS_Store`, `.VolumeIcon.icns`, and `.background/background.png`. The static dark background and centred arrow were visually inspected.

## Important implementation details

- `DmgBuildPlan` is the single UI/CLI handoff to `DmgBuilder`.
- `BackgroundCanvasPlanner` limits backgrounds to 80% of the creator Mac's visible screen. Preview and Finder layout must use this same resolved canvas.
- App and Applications icons share the vertical centreline; the arrow remains horizontally centred. The editor snaps horizontal drag positions to a 12-column grid.
- Output staging happens in `/private/tmp/DMGStudio-<UUID>`. The image is attached with `-noautoopen`, its `.DS_Store` records are written synchronously, and an existing output is replaced only after the new image has been verified.
- `DSStoreLayoutWriter` builds a Finder Alias v2 record from metadata on the mounted image and writes the picture background, icon positions, icon-view settings, window bounds, and icon view style. Do not reintroduce AppleScript or a Finder persistence poll.
- `DmgPostProcessing` is deliberately a no-op seam for future Developer ID signing and notarization. Do not mix that policy into layout or validation.

## Work still worth doing

Before calling a release candidate ready, manually open a generated DMG in Finder, inspect the visual layout at normal user scale, drag-install the app, and launch the copied app. Finder may still adapt the presentation to recipient display preferences, but image creation must not open or focus Finder.

Potential follow-ups are GUI-level tests for view-model selection state and a Developer ID post-processing implementation. Keep version 1's boundary: no signing/notarization, update feeds, template marketplace, or non-macOS support unless the product scope changes.
