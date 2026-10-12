# DMGStudio

DMGStudio is a native macOS 13+ utility for creating an unsigned, drag-to-install DMG from any macOS `.app`. It has a SwiftUI editor and a `dmgstudio` CLI; both use the same project-local disk-image builder.

Choose an app, optionally add PNG/JPEG background artwork and an ICNS or large square PNG volume icon, position the app and Applications icons in the preview, choose an automatic, light, or dark arrow, then create the disk image. When no artwork is supplied, DMGStudio bakes a simple static light or dark background based on the creator Mac’s current appearance. On dark artwork, it adds a subtle backing where Finder's native black icon labels would otherwise be unreadable.

See [local development](docs/local-development.md), [CLI usage](docs/cli.md), and [the feature specification](.spec/features/001-dmgstudio-builder.md). DMGStudio writes the Finder layout directly to `.DS_Store`, so creating an image never opens, focuses, or automates Finder. Recipient Finder preferences can still affect how a mounted image is ultimately presented. Version 1 does not sign or notarize the resulting image.

## Homebrew

After a stable release is published, install the command-line tool or the macOS app independently:

```sh
brew tap ghaschel/tap
brew install ghaschel/tap/dmgstudio
brew install --cask ghaschel/tap/dmgstudio
```

The formula installs the `dmgstudio` CLI. The cask installs `DMGStudio.app`.
