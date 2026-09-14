# ADR-005: Address Finder using the custom mount-point name

DMGStudio mounts writable images in a unique staging directory to avoid visible volumes and collisions. Finder exposes that disk using the final mount-point component rather than the volume label requested from `hdiutil`. The layout script must therefore address the mount-point name and use a disk-relative `.background:background.png` reference. A regression test keeps these two names distinct.
