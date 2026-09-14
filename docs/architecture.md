# Architecture

DMGStudio contains one Xcode project with four targets: the SwiftUI application, `DMGStudioCore` static library, the `dmgstudio` command-line executable, and XCTest. The UI and CLI share only `DMGStudioCore`; the project has no external source dependency.

`DmgBuildPlan` is the boundary between interface code and the build pipeline. It records the selected app, optional artwork, output, volume name, visible screen size, appearance, and normalized icon positions. `BackgroundCanvasPlanner` resolves dimensions once. The SwiftUI preview scales that resolved canvas for display; the builder uses it directly in the generated background and Finder metadata.

`DmgBuilder` validates all input before creating a unique hidden staging directory beside output. It copies the app, creates `Applications -> /Applications`, renders `.background/background.png`, runs `hdiutil` to make and mount a UDRW image, asks Finder through `osascript` to persist icon-view settings, sets the volume icon, detaches, converts to UDZO, verifies, and atomically moves the compressed image to the final path. Any error tries to detach and removes staging.

Disk-image commands, Finder configuration, and volume-icon application sit behind small protocols. Tests inject fakes; production uses `/usr/bin/hdiutil`, `/usr/bin/osascript`, and AppKit. Finder identifies a custom-mounted disk by the final mount-point component, not necessarily its requested volume label, so the layout script uses the mount-point name while preserving the user's label in the image. Post-processing is intentionally a seam, currently a no-op, for a later Developer ID signing/notarization workflow.

Finder settings are presentation metadata, not a portable GUI contract. The preview is accurate about the saved source canvas and coordinates; a recipient’s Finder, display scale, and settings still control final appearance.
