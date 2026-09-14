#!/bin/bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
configuration="${CONFIGURATION:-Release}"
derived_data_path="${DERIVED_DATA_PATH:-$repository_root/.build/DerivedData}"
dist_dir="${DIST_DIR:-$repository_root/dist}"
products_dir="$derived_data_path/Build/Products/$configuration"

if [[ "$dist_dir" == "/" ]]; then
    echo "DIST_DIR must not be the filesystem root." >&2
    exit 1
fi

xcodebuild build \
    -project "$repository_root/DMGStudio.xcodeproj" \
    -scheme DMGStudio \
    -configuration "$configuration" \
    -destination 'platform=macOS' \
    -derivedDataPath "$derived_data_path"

test -d "$products_dir/DMGStudio.app"
test -f "$products_dir/dmgstudio"

mkdir -p "$dist_dir"
rm -rf "$dist_dir/DMGStudio.app"
rm -f "$dist_dir/dmgstudio"
/usr/bin/ditto "$products_dir/DMGStudio.app" "$dist_dir/DMGStudio.app"
/usr/bin/ditto "$products_dir/dmgstudio" "$dist_dir/dmgstudio"

echo "Built $dist_dir/DMGStudio.app and $dist_dir/dmgstudio"
