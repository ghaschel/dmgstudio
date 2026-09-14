import CoreGraphics
import Foundation

/// Resolves the one canvas size used by both the preview and Finder metadata.
public enum BackgroundCanvasPlanner {
    private static let productMaximumSize = CGSize(width: 900, height: 600)

    public static func resolve(imageSize: CGSize, visibleScreenSize: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }

        let maximumSize = CGSize(
            width: min(visibleScreenSize.width * 0.8, productMaximumSize.width),
            height: min(visibleScreenSize.height * 0.8, productMaximumSize.height)
        )
        guard maximumSize.width > 0, maximumSize.height > 0 else { return imageSize }

        let scale = min(1, maximumSize.width / imageSize.width, maximumSize.height / imageSize.height)
        return CGSize(width: floor(imageSize.width * scale), height: floor(imageSize.height * scale))
    }
}
