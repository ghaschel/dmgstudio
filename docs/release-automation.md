# Release automation

DMGStudio releases are driven by Git tags in the `vMAJOR.MINOR.PATCH` form. A tag with a hyphenated prerelease suffix, such as `v1.2.0-beta.1`, produces a GitHub prerelease with the same files but never changes Homebrew.

Every tagged build creates two universal macOS assets:

- `DMGStudio-<version>.dmg`, containing `DMGStudio.app`, built with the committed Graphite Silk background and Studio Capsule volume icon.
- `dmgstudio-<version>-macos-universal.tar.gz`, containing the command-line executable.

Stable tags create a GitHub release and update both packages in `ghaschel/homebrew-tap`:

- `Formula/dmgstudio.rb` installs the CLI archive as `dmgstudio`.
- `Casks/dmgstudio.rb` installs `DMGStudio.app` from the release DMG.

The source repository's `GITHUB_TOKEN` is limited to creating its own release. The workflow uses a separate `HOMEBREW_TAP_TOKEN` secret only when it checks out and pushes `ghaschel/homebrew-tap`; that token needs write access to the tap repository. Release artifacts remain unsigned and unnotarized, consistent with [distribution notes](distribution.md).
