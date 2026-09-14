# Distribution notes

DMGStudio v1 produces unsigned, unnotarized images. Recipients may encounter standard macOS security prompts, depending on the embedded app and their system policy. The utility does not sign, notarize, or alter the app it packages.

Treat the package’s app license, assets, and distribution rights as separate from the DMG container. A future Developer ID post-processing implementation belongs behind the builder’s post-processing seam so signing policy does not leak into layout or validation code.
