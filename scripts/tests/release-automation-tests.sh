#!/bin/bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fixture_root="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/dmgstudio-release-tests.XXXXXX")" && pwd)"
trap 'rm -rf "$fixture_root"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    [[ "$haystack" == *"$needle"* ]] || fail "Expected '$needle' in '$haystack'."
}

assert_file() {
    [[ -f "$1" ]] || fail "Expected file '$1'."
}

assert_tar_contains_only() {
    local archive="$1"
    local expected_entry="$2"
    local entries
    entries="$(tar -tzf "$archive")"
    [[ "$entries" == "$expected_entry" ]] || fail "Expected '$archive' to contain only '$expected_entry', found '$entries'."
}

dist_dir="$fixture_root/dist"
tap_dir="$fixture_root/homebrew-tap"
stub_log="$fixture_root/dmgstudio-invocation.log"
mkdir -p "$dist_dir/DMGStudio.app"
printf '%s\n' 'fixture CLI' > "$dist_dir/dmgstudio"
chmod +x "$dist_dir/dmgstudio"

cat > "$dist_dir/dmgstudio" <<'STUB'
#!/bin/bash
set -euo pipefail

printf '%s\n' "$*" > "$DMGSTUDIO_STUB_LOG"
output=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            output="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

[[ -n "$output" ]] || exit 2
printf '%s\n' 'fixture DMG' > "$output"
STUB
chmod +x "$dist_dir/dmgstudio"

metadata="$(DMGSTUDIO_STUB_LOG="$stub_log" bash "$repository_root/scripts/package-release.sh" --tag v1.2.3 --dist-dir "$dist_dir")"
assert_contains "$metadata" "version=1.2.3"
assert_contains "$metadata" "prerelease=false"
assert_file "$dist_dir/DMGStudio-1.2.3.dmg"
assert_tar_contains_only "$dist_dir/dmgstudio-1.2.3-macos-universal.tar.gz" "dmgstudio"
assert_contains "$(<"$stub_log")" "--background $repository_root/artwork/dmgstudio-graphite-silk-background.png"
assert_contains "$(<"$stub_log")" "--volume-icon $repository_root/artwork/dmgstudio-studio-capsule-volume.png"
assert_contains "$(<"$stub_log")" "--output $dist_dir/DMGStudio-1.2.3.dmg"

prerelease_metadata="$(DMGSTUDIO_STUB_LOG="$stub_log" bash "$repository_root/scripts/package-release.sh" --tag v1.2.3-beta.1 --dist-dir "$dist_dir")"
assert_contains "$prerelease_metadata" "prerelease=true"

if DMGSTUDIO_STUB_LOG="$stub_log" bash "$repository_root/scripts/package-release.sh" --tag release-1.2.3 --dist-dir "$dist_dir"; then
    fail "Expected an invalid tag to fail."
fi

dmg_sha256="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
cli_sha256="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
bash "$repository_root/scripts/render-homebrew-tap.sh" \
    --tap-dir "$tap_dir" \
    --version 1.2.3 \
    --dmg-sha256 "$dmg_sha256" \
    --cli-sha256 "$cli_sha256"

formula="$(<"$tap_dir/Formula/dmgstudio.rb")"
cask="$(<"$tap_dir/Casks/dmgstudio.rb")"
assert_contains "$formula" "dmgstudio-1.2.3-macos-universal.tar.gz"
assert_contains "$formula" "$cli_sha256"
assert_contains "$formula" 'bin.install "dmgstudio"'
assert_contains "$cask" "DMGStudio-1.2.3.dmg"
assert_contains "$cask" "$dmg_sha256"
assert_contains "$cask" 'app "DMGStudio.app"'

workflow_path="$repository_root/.github/workflows/release.yml"
assert_file "$workflow_path"
ruby -e 'require "yaml"; YAML.load_file(ARGV.fetch(0))' "$workflow_path"
workflow="$(<"$workflow_path")"
assert_contains "$workflow" 'tags:'
assert_contains "$workflow" '"v*"'
assert_contains "$workflow" 'contents: write'
assert_contains "$workflow" 'bash scripts/build.sh'
assert_contains "$workflow" 'bash scripts/package-release.sh'
assert_contains "$workflow" 'gh release create'
assert_contains "$workflow" '--verify-tag'
assert_contains "$workflow" '--generate-notes'
assert_contains "$workflow" 'PRERELEASE: ${{ steps.package.outputs.prerelease }}'
assert_contains "$workflow" '"$PRERELEASE" == "true"'
assert_contains "$workflow" '--prerelease'
assert_contains "$workflow" '--latest=false'
assert_contains "$workflow" "steps.package.outputs.prerelease == 'false'"
assert_contains "$workflow" 'ghaschel/homebrew-tap'
assert_contains "$workflow" 'secrets.HOMEBREW_TAP_TOKEN'

echo "release automation helper tests passed"
