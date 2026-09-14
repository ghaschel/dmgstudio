# DMGStudio

DMGStudio is a native macOS 13+ utility for creating an unsigned, drag-to-install DMG from any macOS `.app`. It has a SwiftUI editor and a `dmgstudio` CLI; both use the same project-local disk-image builder.

Choose an app, optionally add PNG/JPEG background artwork and an ICNS or large square PNG volume icon, position the app and Applications icons in the preview, then create the disk image. When no artwork is supplied, DMGStudio bakes a simple static light or dark background based on the creator Mac’s current appearance.

See [local development](docs/local-development.md), [CLI usage](docs/cli.md), and [the feature specification](.spec/features/001-dmgstudio-builder.md). DMGStudio writes the Finder layout directly to `.DS_Store`, so creating an image never opens, focuses, or automates Finder. Recipient Finder preferences can still affect how a mounted image is ultimately presented. Version 1 does not sign or notarize the resulting image.
