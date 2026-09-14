# ADR-004: Keep signing and notarization out of v1

DMGStudio v1 produces unsigned images. Layout generation, validation, and disk-image creation must not contain Developer ID policy. The builder reserves a small post-processing seam, initially no-op, so a later signing/notarization workflow can be added without changing the UI/CLI plan or Finder-layout code.
