# ADR-003: One resolved canvas and static default artwork

Custom background dimensions are preserved unless larger than 80% of the creator’s visible screen, in which case they are proportionally reduced. That single resolved canvas drives preview, baked background, Finder bounds, and icon coordinates. When no background is selected, DMGStudio bakes light or dark artwork based on the creator Mac; it cannot adapt after delivery to a recipient’s theme.
