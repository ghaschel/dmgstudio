#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: render-homebrew-tap.sh --tap-dir PATH --version VERSION --dmg-sha256 SHA256 --cli-sha256 SHA256" >&2
}

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tap_dir=""
version=""
dmg_sha256=""
cli_sha256=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tap-dir)
            tap_dir="${2:-}"
            shift 2
            ;;
        --version)
            version="${2:-}"
            shift 2
            ;;
        --dmg-sha256)
            dmg_sha256="${2:-}"
            shift 2
            ;;
        --cli-sha256)
            cli_sha256="${2:-}"
            shift 2
            ;;
        *)
            usage
            exit 2
            ;;
    esac
done

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Homebrew packages require a stable MAJOR.MINOR.PATCH version." >&2
    exit 2
fi

for checksum in "$dmg_sha256" "$cli_sha256"; do
    if [[ ! "$checksum" =~ ^[a-f0-9]{64}$ ]]; then
        echo "Homebrew checksums must be lowercase SHA-256 values." >&2
        exit 2
    fi
done

[[ -n "$tap_dir" ]] || { usage; exit 2; }
mkdir -p "$tap_dir/Formula" "$tap_dir/Casks"

render_template() {
    local template_path="$1"
    local destination_path="$2"

    sed \
        -e "s/{{VERSION}}/$version/g" \
        -e "s/{{DMG_SHA256}}/$dmg_sha256/g" \
        -e "s/{{CLI_SHA256}}/$cli_sha256/g" \
        "$template_path" > "$destination_path"
}

render_template \
    "$repository_root/scripts/templates/dmgstudio.rb.template" \
    "$tap_dir/Formula/dmgstudio.rb"
render_template \
    "$repository_root/scripts/templates/dmgstudio-cask.rb.template" \
    "$tap_dir/Casks/dmgstudio.rb"
