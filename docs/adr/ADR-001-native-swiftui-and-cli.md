# ADR-001: Native SwiftUI app with a project-local CLI

DMGStudio uses SwiftUI and AppKit-backed file panels for the macOS editor. The `dmgstudio` CLI is a second Xcode target linked to the project-local core library. This gives automation parity without introducing a package manager or cross-application source dependency.
