# Distribution notes

DMGStudio v1 produces unsigned, unnotarized images. Recipients may encounter standard macOS security prompts, depending on the embedded app and their system policy. The utility does not sign, notarize, or alter the app it packages.

Treat the package’s app license, assets, and distribution rights as separate from the DMG container. A future Developer ID post-processing implementation belongs behind the builder’s post-processing seam so signing policy does not leak into layout or validation code.

## Automated releases

Pushing a `vMAJOR.MINOR.PATCH` tag runs the GitHub release workflow. It builds universal GUI and CLI artifacts, creates the branded `DMGStudio-<version>.dmg` using the committed Graphite Silk background and Studio Capsule volume icon, and uploads that DMG together with `dmgstudio-<version>-macos-universal.tar.gz`.

Tags with a hyphenated prerelease suffix, such as `v1.2.0-beta.1`, create a GitHub prerelease with the same two assets. They never update Homebrew. Stable releases update both `Formula/dmgstudio.rb` and `Casks/dmgstudio.rb` in `ghaschel/homebrew-tap`, enabling:

```sh
brew tap ghaschel/tap
brew install ghaschel/tap/dmgstudio
brew install --cask ghaschel/tap/dmgstudio
```

The workflow uses the source repository’s `GITHUB_TOKEN` with `contents: write` to create its own release. Add a repository Actions secret named `HOMEBREW_TAP_TOKEN`: a fine-grained personal access token restricted to `ghaschel/homebrew-tap` with **Contents: Read and write** permission. It is used only for the stable-release checkout and push to that separate repository; do not place it in the source repository or expose it in logs.
