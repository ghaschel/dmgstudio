# Local development

Requirements: macOS 13+, Xcode with Swift 6, and Xcode command-line tools. Xcode resolves the project’s pinned `DSStore` package dependency automatically; no generator is required.

Open `DMGStudio.xcodeproj` and run the `DMGStudio` scheme. It builds the GUI and `dmgstudio` CLI. From this directory:

```sh
xcodebuild build -project DMGStudio.xcodeproj -scheme DMGStudio -configuration Debug -destination 'platform=macOS'
xcodebuild test -project DMGStudio.xcodeproj -scheme DMGStudio -configuration Debug -destination 'platform=macOS'
```

Run the commands from this repository's root. Keep the app, CLI, core, tests, specs, and docs in this repository. The only external source dependency is the exact-pinned `DSStore` package used to write Finder metadata deterministically.

To produce release artifacts for local distribution or CI, run:

```sh
scripts/build.sh
```

This writes `DMGStudio.app` and `dmgstudio` to `dist/`; intermediate Xcode output stays in `.build/`.

For a manual acceptance check, build a DMG from a disposable app copy, mount it, check the background, app/Applications positions, and volume icon, drag-install it, and launch the installed app. Creating the DMG does not require Finder Automation permission or alter existing Finder windows.

## Release rehearsal

After building, package the two release assets locally with a stable or prerelease tag:

```sh
bash scripts/package-release.sh --tag v1.2.3 --dist-dir dist
bash scripts/package-release.sh --tag v1.2.4-beta.1 --dist-dir dist
```

The script produces the branded `DMGStudio-<version>.dmg` and the `dmgstudio-<version>-macos-universal.tar.gz` CLI archive. It accepts only `vMAJOR.MINOR.PATCH` tags with an optional hyphenated prerelease suffix. It uses the built CLI and does not automate Finder.

Run the release helper checks with:

```sh
bash scripts/tests/release-automation-tests.sh
```
