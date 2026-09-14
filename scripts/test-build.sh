#!/bin/bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/dmgstudio-build-test.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

DIST_DIR="$test_root/dist" DERIVED_DATA_PATH="$test_root/DerivedData" "$repository_root/scripts/build.sh"

test -d "$test_root/dist/DMGStudio.app"
test -x "$test_root/dist/dmgstudio"
