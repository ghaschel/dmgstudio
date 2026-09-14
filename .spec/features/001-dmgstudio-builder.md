# DMGStudio v1 — DMG builder

## Goal

Create a native macOS 13+ app and companion CLI that turn one valid macOS `.app` into one unsigned, compressed `<App Name>.dmg`. The project is self-contained so it can be maintained and moved without bringing source code from another product.

## User workflow

1. Choose a macOS application bundle. The default output is `<App Name>.dmg` beside it; choose another output folder when needed.
2. Optionally choose a PNG or JPEG Finder background and an ICNS or square PNG (at least 512 × 512) volume icon. Without a volume icon, derive one from the app. Without a background, bake simple static artwork using the creator’s current light or dark appearance.
3. Review the live canvas. Its source background dimensions are capped to 80% of the creator’s visible screen, while preserving aspect ratio. The background fills the resulting Finder content area.
4. Horizontally reposition the app and Applications icons on a grid. The baked arrow stays horizontally centred and all three elements share the vertical centreline.
5. Create the DMG. DMGStudio stages the app, Applications symlink, artwork, Finder settings, and icon; creates a writable disk image; then compresses, verifies, and atomically moves it into place. Existing output is never overwritten.

## CLI

`dmgstudio create --app /path/App.app` exposes the same build path for scripted work. It accepts `--background`, `--volume-icon`, `--volume-name`, `--output`, `--app-x`, and `--applications-x`. The CLI uses the creator Mac’s main visible screen and current appearance for its default canvas. It is a DMGStudio target, not a root-level shared tool.

## Acceptance criteria

- A valid `.app` produces an unsigned UDZO DMG containing the app and an `Applications` symlink.
- The saved Finder icon view uses the same resolved canvas and positions displayed in the preview.
- Custom input types and dimensions are checked before staging. Invalid input, output parent, layout, command failures, and existing outputs result in actionable errors and leave no staging directory.
- The CLI parses the documented options and produces the same `DmgBuildPlan` as the visual editor.
- Tests cover validation, sizing, icon conversion/validation, output refusal, staging cleanup, generated layout commands, icon placement, and injected disk-image command failures.
- A release candidate is manually checked by mounting a generated DMG, inspecting its layout and icon, drag-installing the app, and launching the installed copy.

## Boundaries

Finder metadata is best-effort: macOS may render saved window bounds and background treatment differently on a recipient Mac. v1 has no signing, notarization, update feed, distribution service, template marketplace, or non-macOS support. A no-op post-processing seam preserves a clear later path to Developer ID signing and notarization.

When the image is mounted within hidden staging, Finder addresses it by the mount-point directory name rather than the requested volume label. The build pipeline deliberately uses the former for layout persistence and retains the latter for the disk image's user-visible label.

## Domain model

- `DmgBuildPlan`: immutable app, artwork, output, volume, screen, appearance, and layout input.
- `DmgLayout` / `DmgFinderLayout`: normalized positions and resolved Finder coordinates.
- `DmgBuilder`: validates, stages, invokes disk-image services, and atomically publishes output.
- `DmgCommandLineOptions` / `DmgCommandLineParser`: CLI input mapped to the same build plan.
- `DmgBuildError`: user-actionable validation, filesystem, and tool failures.
