import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum DmgBuildError: Error, Equatable, LocalizedError, Sendable {
    case invalidApplication(URL)
    case invalidOutput(URL)
    case invalidVolumeName
    case invalidBackground
    case invalidVolumeIcon
    case invalidLayout
    case commandFailed(String)
    case filesystem(String)

    public var errorDescription: String? {
        switch self {
        case .invalidApplication:
            return "Choose a valid macOS .app bundle."
        case .invalidOutput:
            return "Choose a .dmg output path inside an existing folder."
        case .invalidVolumeName:
            return "Use a visible volume name without path separators or colons."
        case .invalidBackground:
            return "Choose a readable PNG or JPEG background image."
        case .invalidVolumeIcon:
            return "Choose an ICNS file or a square PNG that is at least 512 × 512 pixels."
        case .invalidLayout:
            return "App and Applications positions must be inside the DMG canvas."
        case .commandFailed(let message), .filesystem(let message):
            return message
        }
    }
}

public struct DmgLayout: Equatable, Sendable {
    public var appHorizontalPosition: CGFloat
    public var applicationsHorizontalPosition: CGFloat

    public init(appHorizontalPosition: CGFloat = 0.28, applicationsHorizontalPosition: CGFloat = 0.72) {
        self.appHorizontalPosition = appHorizontalPosition
        self.applicationsHorizontalPosition = applicationsHorizontalPosition
    }

    public func finderLayout(canvasSize: CGSize) throws -> DmgFinderLayout {
        guard (0...1).contains(appHorizontalPosition), (0...1).contains(applicationsHorizontalPosition) else {
            throw DmgBuildError.invalidLayout
        }
        let centerY = Self.visualCenterlineY(in: canvasSize)
        return DmgFinderLayout(
            canvasSize: canvasSize,
            appPosition: CGPoint(x: floor(canvasSize.width * appHorizontalPosition), y: centerY),
            applicationsPosition: CGPoint(x: floor(canvasSize.width * applicationsHorizontalPosition), y: centerY),
            arrowPosition: CGPoint(
                x: floor(canvasSize.width / 2),
                y: Self.canvasCenterY(in: canvasSize)
            )
        )
    }

    public static func visualCenterlineY(in canvasSize: CGSize) -> CGFloat {
        floor(canvasSize.height * 0.45)
    }

    public static func canvasCenterY(in canvasSize: CGSize) -> CGFloat {
        floor(canvasSize.height / 2)
    }
}

public struct DmgFinderLayout: Equatable, Sendable {
    public let canvasSize: CGSize
    public let appPosition: CGPoint
    public let applicationsPosition: CGPoint
    public let arrowPosition: CGPoint
}

public struct DmgBuildPlan: Equatable, Sendable {
    public let appURL: URL
    public let backgroundURL: URL?
    public let volumeIconURL: URL?
    public let outputURL: URL
    public let volumeName: String
    public let screenSize: CGSize
    public let layout: DmgLayout
    public let usesDarkAppearance: Bool

    public init(
        appURL: URL,
        backgroundURL: URL? = nil,
        volumeIconURL: URL? = nil,
        outputURL: URL,
        volumeName: String,
        screenSize: CGSize,
        layout: DmgLayout = DmgLayout(),
        usesDarkAppearance: Bool = false
    ) {
        self.appURL = appURL
        self.backgroundURL = backgroundURL
        self.volumeIconURL = volumeIconURL
        self.outputURL = outputURL
        self.volumeName = volumeName
        self.screenSize = screenSize
        self.layout = layout
        self.usesDarkAppearance = usesDarkAppearance
    }

    public static func defaultOutputURL(for appURL: URL) -> URL {
        appURL.deletingLastPathComponent().appendingPathComponent(appURL.deletingPathExtension().lastPathComponent).appendingPathExtension("dmg")
    }
}

public struct DmgBuildResult: Equatable, Sendable {
    public let dmgURL: URL
    public let layout: DmgFinderLayout
}

enum DmgImageValidator {
    static func backgroundSize(at url: URL) throws -> CGSize {
        let source = try imageSource(at: url, acceptedTypes: [.png, .jpeg], error: .invalidBackground)
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              width > 0,
              height > 0 else {
            throw DmgBuildError.invalidBackground
        }
        return CGSize(width: width, height: height)
    }

    static func validateVolumeIcon(at url: URL) throws {
        let type = UTType(filenameExtension: url.pathExtension.lowercased())
        if type?.conforms(to: .icns) == true {
            guard let image = NSImage(contentsOf: url),
                  image.representations.contains(where: { $0.pixelsWide > 0 && $0.pixelsHigh > 0 }) else {
                throw DmgBuildError.invalidVolumeIcon
            }
            return
        }

        let source = try imageSource(at: url, acceptedTypes: [.png], error: .invalidVolumeIcon)
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              width == height,
              width >= 512 else {
            throw DmgBuildError.invalidVolumeIcon
        }
    }

    static func image(at url: URL) throws -> CGImage {
        let source = try imageSource(at: url, acceptedTypes: [.png, .jpeg], error: .invalidBackground)
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw DmgBuildError.invalidBackground
        }
        return image
    }

    private static func imageSource(at url: URL, acceptedTypes: [UTType], error: DmgBuildError) throws -> CGImageSource {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let identifier = CGImageSourceGetType(source) as String?,
              let type = UTType(identifier),
              acceptedTypes.contains(where: { type.conforms(to: $0) }) else {
            throw error
        }
        return source
    }
}

enum DmgArtworkBuilder {
    static func render(backgroundURL: URL?, canvasSize: CGSize, usesDarkAppearance: Bool, to outputURL: URL) throws {
        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        guard width > 0, height > 0,
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw DmgBuildError.filesystem("DMGStudio could not create the background image canvas.")
        }

        let canvas = CGRect(origin: .zero, size: canvasSize)
        if let backgroundURL {
            _ = try DmgImageValidator.backgroundSize(at: backgroundURL)
            context.draw(try DmgImageValidator.image(at: backgroundURL), in: canvas)
        } else {
            context.setFillColor((usesDarkAppearance ? NSColor(calibratedWhite: 0.16, alpha: 1) : NSColor(calibratedWhite: 0.96, alpha: 1)).cgColor)
            context.fill(canvas)
        }

        drawArrow(in: context, canvasSize: canvasSize, isDark: usesDarkAppearance)
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw DmgBuildError.filesystem("DMGStudio could not write the prepared background image.")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw DmgBuildError.filesystem("DMGStudio could not finish the prepared background image.")
        }
    }

    private static func drawArrow(in context: CGContext, canvasSize: CGSize, isDark: Bool) {
        let center = CGPoint(
            x: canvasSize.width / 2,
            y: DmgLayout.canvasCenterY(in: canvasSize)
        )
        let arrowWidth = min(110, canvasSize.width * 0.16)
        let arrowHeight = arrowWidth * 0.35
        let startX = center.x - arrowWidth / 2
        let endX = center.x + arrowWidth / 2
        let color = (isDark ? NSColor.white : NSColor.black).withAlphaComponent(0.58).cgColor

        context.setStrokeColor(color)
        context.setLineWidth(max(4, arrowWidth * 0.06))
        context.setLineCap(.round)
        context.move(to: CGPoint(x: startX, y: center.y))
        context.addLine(to: CGPoint(x: endX, y: center.y))
        context.move(to: CGPoint(x: endX - arrowHeight, y: center.y + arrowHeight))
        context.addLine(to: CGPoint(x: endX, y: center.y))
        context.addLine(to: CGPoint(x: endX - arrowHeight, y: center.y - arrowHeight))
        context.strokePath()
    }
}

protocol DiskImageTooling {
    func createWritableImage(from sourceFolder: URL, volumeName: String, at imageURL: URL) throws
    func attach(imageURL: URL, mountPoint: URL) throws
    func detach(mountPoint: URL) throws
    func compress(imageURL: URL, to outputURL: URL) throws
    func verify(imageURL: URL) throws
}

protocol VolumeIconSetting {
    func setIcon(for mountedVolume: URL, customIconURL: URL?, fallbackAppURL: URL) throws
}

/// Deliberately narrow seam for a later Developer ID signing/notarization workflow.
protocol DmgPostProcessing {
    func process(imageURL: URL) throws
}

struct NoDmgPostProcessing: DmgPostProcessing {
    func process(imageURL: URL) throws {}
}

protocol CommandRunning {
    func run(executableURL: URL, arguments: [String]) throws
}

struct ProcessCommandRunner: CommandRunning {
    func run(executableURL: URL, arguments: [String]) throws {
        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardError = errorPipe
        do {
            try process.run()
        } catch {
            throw DmgBuildError.commandFailed("DMGStudio could not run \(executableURL.lastPathComponent): \(error.localizedDescription)")
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let output = String(decoding: errorPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw DmgBuildError.commandFailed(output.isEmpty ? "\(executableURL.lastPathComponent) failed." : output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}

struct HdiutilDiskImageTool: DiskImageTooling {
    private let commandRunner: any CommandRunning

    init(commandRunner: any CommandRunning = ProcessCommandRunner()) {
        self.commandRunner = commandRunner
    }

    func createWritableImage(from sourceFolder: URL, volumeName: String, at imageURL: URL) throws {
        try commandRunner.run(executableURL: URL(fileURLWithPath: "/usr/bin/hdiutil"), arguments: [
            "create", "-ov", "-format", "UDRW", "-volname", volumeName, "-srcfolder", sourceFolder.path, imageURL.path
        ])
    }

    func attach(imageURL: URL, mountPoint: URL) throws {
        try commandRunner.run(executableURL: URL(fileURLWithPath: "/usr/bin/hdiutil"), arguments: [
            "attach", imageURL.path, "-readwrite", "-noverify", "-noautoopen", "-mountpoint", mountPoint.path
        ])
    }

    func detach(mountPoint: URL) throws {
        try commandRunner.run(executableURL: URL(fileURLWithPath: "/usr/bin/hdiutil"), arguments: ["detach", mountPoint.path])
    }

    func compress(imageURL: URL, to outputURL: URL) throws {
        try commandRunner.run(executableURL: URL(fileURLWithPath: "/usr/bin/hdiutil"), arguments: [
            "convert", imageURL.path, "-format", "UDZO", "-o", outputURL.path
        ])
    }

    func verify(imageURL: URL) throws {
        try commandRunner.run(executableURL: URL(fileURLWithPath: "/usr/bin/hdiutil"), arguments: ["verify", imageURL.path])
    }
}

struct VolumeIconSetter: VolumeIconSetting {
    func setIcon(for mountedVolume: URL, customIconURL: URL?, fallbackAppURL: URL) throws {
        let icon: NSImage?
        if let customIconURL {
            try DmgImageValidator.validateVolumeIcon(at: customIconURL)
            icon = NSImage(contentsOf: customIconURL)
        } else {
            icon = NSWorkspace.shared.icon(forFile: fallbackAppURL.path)
        }
        guard let icon, NSWorkspace.shared.setIcon(icon, forFile: mountedVolume.path, options: []) else {
            throw DmgBuildError.filesystem("DMGStudio could not set the mounted volume icon.")
        }
    }
}

public final class DmgBuilder {
    private let diskImageTool: any DiskImageTooling
    private let layoutWriter: any DmgLayoutWriting
    private let volumeIconSetter: any VolumeIconSetting
    private let postProcessor: any DmgPostProcessing
    private let fileManager: FileManager

    public init() {
        diskImageTool = HdiutilDiskImageTool()
        layoutWriter = DSStoreLayoutWriter()
        volumeIconSetter = VolumeIconSetter()
        postProcessor = NoDmgPostProcessing()
        fileManager = .default
    }

    init(
        diskImageTool: any DiskImageTooling,
        layoutWriter: any DmgLayoutWriting = DSStoreLayoutWriter(),
        volumeIconSetter: any VolumeIconSetting = VolumeIconSetter(),
        postProcessor: any DmgPostProcessing = NoDmgPostProcessing(),
        fileManager: FileManager = .default
    ) {
        self.diskImageTool = diskImageTool
        self.layoutWriter = layoutWriter
        self.volumeIconSetter = volumeIconSetter
        self.postProcessor = postProcessor
        self.fileManager = fileManager
    }

    public func build(plan: DmgBuildPlan) throws -> DmgBuildResult {
        try validate(plan: plan)
        let canvasSize = try resolvedCanvasSize(for: plan)
        let layout = try plan.layout.finderLayout(canvasSize: canvasSize)
        let stagingDirectory = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("DMGStudio-\(UUID().uuidString)", isDirectory: true)
        let sourceFolder = stagingDirectory.appendingPathComponent("Source", isDirectory: true)
        let writableImage = stagingDirectory.appendingPathComponent("Working.dmg")
        let compressedImage = stagingDirectory.appendingPathComponent("Result.dmg")
        let mountPoint = stagingDirectory.appendingPathComponent("Mount", isDirectory: true)
        var attached = false

        do {
            try fileManager.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
            try stageContents(for: plan, canvasSize: canvasSize, in: sourceFolder)
            try diskImageTool.createWritableImage(from: sourceFolder, volumeName: plan.volumeName, at: writableImage)
            try fileManager.createDirectory(at: mountPoint, withIntermediateDirectories: true)
            try diskImageTool.attach(imageURL: writableImage, mountPoint: mountPoint)
            attached = true
            try layoutWriter.write(
                mountedVolume: mountPoint,
                volumeName: plan.volumeName,
                applicationName: plan.appURL.lastPathComponent,
                layout: layout
            )
            try volumeIconSetter.setIcon(for: mountPoint, customIconURL: plan.volumeIconURL, fallbackAppURL: plan.appURL)
            try diskImageTool.detach(mountPoint: mountPoint)
            attached = false
            try diskImageTool.compress(imageURL: writableImage, to: compressedImage)
            try postProcessor.process(imageURL: compressedImage)
            try diskImageTool.verify(imageURL: compressedImage)
            if fileManager.fileExists(atPath: plan.outputURL.path) {
                _ = try fileManager.replaceItemAt(plan.outputURL, withItemAt: compressedImage)
            } else {
                try fileManager.moveItem(at: compressedImage, to: plan.outputURL)
            }
            try? fileManager.removeItem(at: stagingDirectory)
            return DmgBuildResult(dmgURL: plan.outputURL, layout: layout)
        } catch let error as DmgBuildError {
            if attached { try? diskImageTool.detach(mountPoint: mountPoint) }
            try? fileManager.removeItem(at: stagingDirectory)
            throw error
        } catch {
            if attached { try? diskImageTool.detach(mountPoint: mountPoint) }
            try? fileManager.removeItem(at: stagingDirectory)
            throw DmgBuildError.filesystem(error.localizedDescription)
        }
    }

    private func validate(plan: DmgBuildPlan) throws {
        var appIsDirectory: ObjCBool = false
        guard plan.appURL.pathExtension.lowercased() == "app",
              fileManager.fileExists(atPath: plan.appURL.path, isDirectory: &appIsDirectory),
              appIsDirectory.boolValue,
              fileManager.fileExists(atPath: plan.appURL.appendingPathComponent("Contents/Info.plist").path) else {
            throw DmgBuildError.invalidApplication(plan.appURL)
        }
        var outputDirectoryIsDirectory: ObjCBool = false
        guard plan.outputURL.pathExtension.lowercased() == "dmg",
              fileManager.fileExists(
                atPath: plan.outputURL.deletingLastPathComponent().path,
                isDirectory: &outputDirectoryIsDirectory
              ),
              outputDirectoryIsDirectory.boolValue else {
            throw DmgBuildError.invalidOutput(plan.outputURL)
        }
        let trimmedName = plan.volumeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedName.contains("/"), !trimmedName.contains(":") else {
            throw DmgBuildError.invalidVolumeName
        }
        if let backgroundURL = plan.backgroundURL { _ = try DmgImageValidator.backgroundSize(at: backgroundURL) }
        if let volumeIconURL = plan.volumeIconURL { try DmgImageValidator.validateVolumeIcon(at: volumeIconURL) }
        _ = try plan.layout.finderLayout(canvasSize: try resolvedCanvasSize(for: plan))
    }

    private func resolvedCanvasSize(for plan: DmgBuildPlan) throws -> CGSize {
        if let backgroundURL = plan.backgroundURL {
            return BackgroundCanvasPlanner.resolve(
                imageSize: try DmgImageValidator.backgroundSize(at: backgroundURL),
                visibleScreenSize: plan.screenSize
            )
        }
        return BackgroundCanvasPlanner.resolve(imageSize: CGSize(width: 800, height: 500), visibleScreenSize: plan.screenSize)
    }

    private func stageContents(for plan: DmgBuildPlan, canvasSize: CGSize, in sourceFolder: URL) throws {
        let appDestination = sourceFolder.appendingPathComponent(plan.appURL.lastPathComponent, isDirectory: true)
        try fileManager.copyItem(at: plan.appURL, to: appDestination)
        let applicationsURL = sourceFolder.appendingPathComponent("Applications")
        try fileManager.createSymbolicLink(at: applicationsURL, withDestinationURL: URL(fileURLWithPath: "/Applications"))
        let backgroundDirectory = sourceFolder.appendingPathComponent(".background", isDirectory: true)
        try fileManager.createDirectory(at: backgroundDirectory, withIntermediateDirectories: true)
        try DmgArtworkBuilder.render(
            backgroundURL: plan.backgroundURL,
            canvasSize: canvasSize,
            usesDarkAppearance: plan.usesDarkAppearance,
            to: backgroundDirectory.appendingPathComponent("background.png")
        )
    }
}

public struct DmgCommandLineOptions: Equatable, Sendable {
    public let appURL: URL
    public let backgroundURL: URL?
    public let volumeIconURL: URL?
    public let volumeName: String?
    public let outputURL: URL?
    public let layout: DmgLayout

    public func buildPlan(screenSize: CGSize, usesDarkAppearance: Bool) -> DmgBuildPlan {
        DmgBuildPlan(
            appURL: appURL,
            backgroundURL: backgroundURL,
            volumeIconURL: volumeIconURL,
            outputURL: outputURL ?? URL(
                fileURLWithPath: FileManager.default.currentDirectoryPath,
                isDirectory: true
            ).appendingPathComponent("output.dmg"),
            volumeName: volumeName ?? appURL.deletingPathExtension().lastPathComponent,
            screenSize: screenSize,
            layout: layout,
            usesDarkAppearance: usesDarkAppearance
        )
    }
}

public enum DmgCommandLineParser {
    public static func parse(arguments: [String]) throws -> DmgCommandLineOptions {
        var values = arguments
        if values.first == "create" { values.removeFirst() }
        var appURL: URL?
        var backgroundURL: URL?
        var volumeIconURL: URL?
        var volumeName: String?
        var outputURL: URL?
        var appX: CGFloat = 0.28
        var applicationsX: CGFloat = 0.72
        var index = 0

        while index < values.count {
            let flag = values[index]
            guard index + 1 < values.count else { throw DmgBuildError.commandFailed("Missing value for \(flag).") }
            let value = values[index + 1]
            switch flag {
            case "--app": appURL = URL(fileURLWithPath: value)
            case "--background": backgroundURL = URL(fileURLWithPath: value)
            case "--volume-icon": volumeIconURL = URL(fileURLWithPath: value)
            case "--volume-name": volumeName = value
            case "--output": outputURL = URL(fileURLWithPath: value)
            case "--app-x":
                guard let parsed = Double(value) else { throw DmgBuildError.commandFailed("--app-x must be a number between 0 and 1.") }
                appX = CGFloat(parsed)
            case "--applications-x":
                guard let parsed = Double(value) else { throw DmgBuildError.commandFailed("--applications-x must be a number between 0 and 1.") }
                applicationsX = CGFloat(parsed)
            default:
                throw DmgBuildError.commandFailed("Unknown option: \(flag). Run dmgstudio --help for usage.")
            }
            index += 2
        }

        guard let appURL else { throw DmgBuildError.commandFailed("--app is required. Run dmgstudio --help for usage.") }
        return DmgCommandLineOptions(
            appURL: appURL,
            backgroundURL: backgroundURL,
            volumeIconURL: volumeIconURL,
            volumeName: volumeName,
            outputURL: outputURL,
            layout: DmgLayout(appHorizontalPosition: appX, applicationsHorizontalPosition: applicationsX)
        )
    }

    public static let usage = """
    Usage: dmgstudio create --app /path/App.app [options]

      --background /path/background.png|jpg
      --volume-icon /path/icon.icns|png
      --volume-name "Mounted name"
      --output /path/App.dmg
      --app-x 0...1
      --applications-x 0...1
    """
}
