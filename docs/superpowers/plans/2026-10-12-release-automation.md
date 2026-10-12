# Release Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish tagged DMGStudio releases and keep a formula and cask in `ghaschel/homebrew-tap` up to date on stable versions.

**Architecture:** A portable release-packaging script turns an existing `dist/` build into the branded DMG and CLI archive, emitting validated release metadata. A separate renderer creates Formula and Cask Ruby files from the resulting version and SHA-256 values. The GitHub workflow orchestrates those scripts, uploads the assets with GitHub CLI, and checks out the tap only when the tag is stable.

**Tech Stack:** Bash, macOS `hdiutil` through the built `dmgstudio` CLI, GitHub Actions, GitHub CLI, Homebrew Formula/Cask Ruby DSL.

**Spec:** `docs/release-automation.md`

## Global Constraints

- Accept only `vMAJOR.MINOR.PATCH` tags with an optional hyphenated prerelease suffix.
- Stable tags create a GitHub release and update Homebrew; prerelease tags create a GitHub prerelease only.
- Package `DMGStudio.app` with `artwork/dmgstudio-graphite-silk-background.png` and `artwork/dmgstudio-studio-capsule-volume.png`.
- Publish `DMGStudio-<version>.dmg` and `dmgstudio-<version>-macos-universal.tar.gz`.
- Keep version 1 artifacts unsigned and unnotarized.
- Use `GITHUB_TOKEN` only for the source release and `HOMEBREW_TAP_TOKEN` only for access to `ghaschel/homebrew-tap`.

## Review Focus

- Invalid tags must fail before any release or tap side effect; covered by the packaging-script test.
- A prerelease must emit `prerelease=true` and never satisfy the workflow’s tap-update condition; covered by the packaging and workflow tests.
- The generated cask and formula must embed the exact SHA-256 values emitted for their respective assets; covered by the tap-rendering test.
- The formula archive must contain only the `dmgstudio` executable; covered by the packaging-script test.
- The workflow must grant source-release permission explicitly while keeping the tap credential scoped to its checkout/push steps; covered by the workflow structure test.

### Task 1: Reproducible release and Homebrew helpers

**Files:**
- Create: `scripts/package-release.sh`
- Create: `scripts/render-homebrew-tap.sh`
- Create: `scripts/templates/dmgstudio.rb.template`
- Create: `scripts/templates/dmgstudio-cask.rb.template`
- Create: `scripts/tests/release-automation-tests.sh`

**Interfaces:**
- Consumes: an existing `dist/DMGStudio.app`, `dist/dmgstudio`, and the two committed artwork files.
- Produces: newline-delimited `key=value` metadata for GitHub Actions and rendered `Formula/dmgstudio.rb` / `Casks/dmgstudio.rb` files in a supplied tap directory.

- [ ] **Step 1: Write the failing helper test**

Create `scripts/tests/release-automation-tests.sh` with a temporary fake app, a stub CLI that records `--background`, `--volume-icon`, and `--output`, and assertions for:

```bash
assert_contains "$metadata" "version=1.2.3"
assert_contains "$metadata" "prerelease=false"
assert_file "$dist_dir/DMGStudio-1.2.3.dmg"
assert_tar_contains_only "$dist_dir/dmgstudio-1.2.3-macos-universal.tar.gz" "dmgstudio"
```

Also assert `v1.2.3-beta.1` emits `prerelease=true`, invalid tags fail, and rendered Formula/Cask files contain the matching URLs and SHA-256s.

- [ ] **Step 2: Run the helper test to verify it fails**

Run: `bash scripts/tests/release-automation-tests.sh`

Expected: FAIL because the packaging and renderer helpers do not exist.

- [ ] **Step 3: Implement `scripts/package-release.sh`**

Accept `--tag` and `--dist-dir`; reject any tag outside the stated format. Require the built app, CLI, and artwork files; invoke the CLI with the committed artwork; create the named tarball containing only `dmgstudio`; emit version, prerelease state, paths, and SHA-256 values to standard output. Send progress output to standard error so metadata can be appended directly to `$GITHUB_OUTPUT`.

- [ ] **Step 4: Implement `scripts/render-homebrew-tap.sh` and templates**

Accept the tap path, version, and both SHA-256 values. Validate each input; create `Formula/` and `Casks/`; render a CLI formula and GUI cask that point at `ghaschel/dmgstudio` release assets and declare the MIT license.

- [ ] **Step 5: Run the helper test to verify it passes**

Run: `bash scripts/tests/release-automation-tests.sh`

Expected: PASS.

- [ ] **Step 6: Commit the helper scripts and tests**

```bash
git add scripts
git commit -m "feat: add release packaging helpers"
```

### Task 2: Tag-triggered GitHub release workflow

**Files:**
- Create: `.github/workflows/release.yml`
- Modify: `scripts/tests/release-automation-tests.sh`

**Interfaces:**
- Consumes: `scripts/build.sh`, `scripts/package-release.sh`, and `scripts/render-homebrew-tap.sh` from Task 1.
- Produces: GitHub release assets for every valid `v*` tag, plus stable-only Homebrew updates.

- [ ] **Step 1: Extend the helper test with workflow expectations**

Assert the workflow parses as YAML and includes a `push` `v*` tag trigger, `contents: write` permission, the build/package scripts, `gh release create --verify-tag`, a prerelease flag derived from packaging metadata, and a stable-only tap-update condition using `secrets.HOMEBREW_TAP_TOKEN`.

- [ ] **Step 2: Run the workflow structure test to verify it fails**

Run: `bash scripts/tests/release-automation-tests.sh`

Expected: FAIL because `.github/workflows/release.yml` does not exist.

- [ ] **Step 3: Implement `.github/workflows/release.yml`**

Run on macOS for every pushed `v*` tag. Build with `scripts/build.sh`, append package metadata to `$GITHUB_OUTPUT`, create a verified GitHub release with both assets and `--generate-notes`, set `--prerelease --latest=false` only when metadata says prerelease, and conditionally check out/render/commit/push `ghaschel/homebrew-tap` for stable tags.

- [ ] **Step 4: Run the workflow structure test to verify it passes**

Run: `bash scripts/tests/release-automation-tests.sh`

Expected: PASS.

- [ ] **Step 5: Commit the workflow**

```bash
git add .github/workflows/release.yml scripts/tests/release-automation-tests.sh
git commit -m "ci: publish tagged releases and Homebrew packages"
```

### Task 3: Document release operation

**Files:**
- Modify: `README.md`
- Modify: `docs/local-development.md`
- Modify: `docs/distribution.md`

**Interfaces:**
- Consumes: the actual asset names, tag validation, and token behavior from Tasks 1–2.
- Produces: contributor-facing instructions to make stable and prerelease releases safely.

- [ ] **Step 1: Document the release contract**

Add the required tag forms, output assets, stable/prerelease behavior, Homebrew commands, and exact `HOMEBREW_TAP_TOKEN` setup requirement. Preserve the existing unsigned/notarized status.

- [ ] **Step 2: Run the complete release-automation test and existing project verification**

Run:

```bash
bash scripts/tests/release-automation-tests.sh
scripts/build.sh
xcodebuild test -project DMGStudio.xcodeproj -scheme DMGStudio -configuration Debug -destination 'platform=macOS,arch=arm64' ARCHS=arm64
```

Expected: all commands exit 0; the XCTest linker may retain the existing macOS 13/XCTest 14 compatibility warning.

- [ ] **Step 3: Commit the documentation**

```bash
git add README.md docs/local-development.md docs/distribution.md
git commit -m "docs: explain automated releases"
```
