#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: package-release.sh --tag vMAJOR.MINOR.PATCH[-PRERELEASE] [--dist-dir PATH]" >&2
}

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tag=""
dist_dir="$repository_root/dist"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tag)
            tag="${2:-}"
            shift 2
            ;;
        --dist-dir)
            dist_dir="${2:-}"
            shift 2
            ;;
        *)
            usage
            exit 2
            ;;
    esac
done

if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$ ]]; then
    echo "Release tags must be vMAJOR.MINOR.PATCH with an optional prerelease suffix." >&2
    exit 2
fi

if [[ ! -d "$dist_dir" ]]; then
    echo "Distribution directory does not exist: $dist_dir" >&2
    exit 2
fi

dist_dir="$(cd "$dist_dir" && pwd)"
version="${tag#v}"
prerelease=false
if [[ "$version" == *-* ]]; then
    prerelease=true
fi

app_path="$dist_dir/DMGStudio.app"
cli_path="$dist_dir/dmgstudio"
background_path="$repository_root/artwork/dmgstudio-graphite-silk-background.png"
volume_icon_path="$repository_root/artwork/dmgstudio-studio-capsule-volume.png"
dmg_path="$dist_dir/DMGStudio-$version.dmg"
archive_path="$dist_dir/dmgstudio-$version-macos-universal.tar.gz"

[[ -d "$app_path" ]] || { echo "Built app not found: $app_path" >&2; exit 2; }
[[ -x "$cli_path" ]] || { echo "Built CLI is not executable: $cli_path" >&2; exit 2; }
[[ -f "$background_path" ]] || { echo "Release background not found: $background_path" >&2; exit 2; }
[[ -f "$volume_icon_path" ]] || { echo "Release volume icon not found: $volume_icon_path" >&2; exit 2; }

echo "Creating $dmg_path" >&2
"$cli_path" create \
    --app "$app_path" \
    --background "$background_path" \
    --volume-icon "$volume_icon_path" \
    --volume-name DMGStudio \
    --output "$dmg_path" >&2

archive_temporary_path="$(mktemp "$dist_dir/.dmgstudio-$version.XXXXXX.tar.gz")"
cleanup() {
    rm -f "$archive_temporary_path"
}
trap cleanup EXIT

tar -C "$dist_dir" -czf "$archive_temporary_path" dmgstudio
mv -f "$archive_temporary_path" "$archive_path"
trap - EXIT

dmg_sha256="$(shasum -a 256 "$dmg_path" | awk '{print $1}')"
cli_sha256="$(shasum -a 256 "$archive_path" | awk '{print $1}')"

printf 'version=%s\n' "$version"
printf 'prerelease=%s\n' "$prerelease"
printf 'dmg_path=%s\n' "$dmg_path"
printf 'cli_archive_path=%s\n' "$archive_path"
printf 'dmg_sha256=%s\n' "$dmg_sha256"
printf 'cli_sha256=%s\n' "$cli_sha256"
