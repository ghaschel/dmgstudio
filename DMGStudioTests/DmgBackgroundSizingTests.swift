import CoreGraphics
import XCTest
@testable import DMGStudioCore
import DSStore

final class DmgBackgroundSizingTests: XCTestCase {
    func testPlannerScalesAnOversizedBackgroundToProductMaximum() {
        let canvas = BackgroundCanvasPlanner.resolve(
            imageSize: CGSize(width: 2_000, height: 1_000),
            visibleScreenSize: CGSize(width: 1_600, height: 1_000)
        )

        XCTAssertEqual(canvas, CGSize(width: 900, height: 450))
    }

    func testPlannerCapsWideBackgroundAtProductMaximum() {
        let canvas = BackgroundCanvasPlanner.resolve(
            imageSize: CGSize(width: 1_536, height: 1_024),
            visibleScreenSize: CGSize(width: 1_728, height: 1_084)
        )

        XCTAssertEqual(canvas, CGSize(width: 900, height: 600))
    }

    func testPlannerCapsTallBackgroundAtProductMaximum() {
        let canvas = BackgroundCanvasPlanner.resolve(
            imageSize: CGSize(width: 1_000, height: 2_000),
            visibleScreenSize: CGSize(width: 1_728, height: 1_084)
        )

        XCTAssertEqual(canvas, CGSize(width: 300, height: 600))
    }

    func testFinderLayoutPlacesTheIconRowAtTheVisualCenterline() throws {
        let layout = try DmgLayout(
            appHorizontalPosition: 0.25,
            applicationsHorizontalPosition: 0.75
        ).finderLayout(canvasSize: CGSize(width: 800, height: 500))

        XCTAssertEqual(layout.appPosition, CGPoint(x: 200, y: 225))
        XCTAssertEqual(layout.applicationsPosition, CGPoint(x: 600, y: 225))
    }

    func testFinderLayoutKeepsTheArrowAtTheCanvasCenterWhenIconsAreRaisedForLabels() throws {
        let layout = try DmgLayout(
            appHorizontalPosition: 0.25,
            applicationsHorizontalPosition: 0.75
        ).finderLayout(canvasSize: CGSize(width: 800, height: 500))

        XCTAssertEqual(layout.arrowPosition, CGPoint(x: 400, y: 250))
    }

    func testValidatorAcceptsSquareLargePNGForVolumeIcon() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let icon = fixture.root.appendingPathComponent("volume-icon.png")
        try makePNG(at: icon, size: 512)

        XCTAssertNoThrow(try DmgImageValidator.validateVolumeIcon(at: icon))
    }

    func testValidatorRejectsSmallOrNonSquarePNGForVolumeIcon() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let icon = fixture.root.appendingPathComponent("small-icon.png")
        try makePNG(at: icon, size: 256)

        XCTAssertThrowsError(try DmgImageValidator.validateVolumeIcon(at: icon)) { error in
            XCTAssertEqual(error as? DmgBuildError, .invalidVolumeIcon)
        }
    }

    func testDSStoreLayoutWriterPersistsPictureBackgroundAndIconCoordinates() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let artworkFolder = fixture.root.appendingPathComponent(".background", isDirectory: true)
        try FileManager.default.createDirectory(at: artworkFolder, withIntermediateDirectories: true)
        let artwork = artworkFolder.appendingPathComponent("background.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: artwork)
        let layout = try DmgLayout(appHorizontalPosition: 0.25, applicationsHorizontalPosition: 0.75)
            .finderLayout(canvasSize: CGSize(width: 800, height: 500))

        try DSStoreLayoutWriter().write(
            mountedVolume: fixture.root,
            volumeName: "Example",
            applicationName: "Example.app",
            layout: layout
        )

        let store = try DSStore.read(from: fixture.root.appendingPathComponent(".DS_Store"))
        let iconViewRecord = try XCTUnwrap(store.record(for: ".", type: .iconViewProperties))
        guard case .propertyList(.dictionary(let iconViewProperties)) = iconViewRecord.value,
              case .data(let aliasData)? = iconViewProperties["backgroundImageAlias"] else {
            return XCTFail("The modern icon view record must contain the background alias.")
        }
        XCTAssertTrue(aliasData.contains(Data("Example:.background:background.png".utf8)))
        XCTAssertEqual(store.iconPosition(for: "Example.app")?.x, 200)
        XCTAssertEqual(store.iconPosition(for: "Example.app")?.y, 225)
        XCTAssertEqual(store.iconPosition(for: "Applications")?.x, 600)
        XCTAssertEqual(store.iconPosition(for: "Applications")?.y, 225)
        XCTAssertEqual(store.viewStyleValue(), .icon)
        XCTAssertEqual(store.windowBounds()?.top, 100)
        XCTAssertEqual(store.windowBounds()?.left, 100)
        XCTAssertEqual(store.windowBounds()?.bottom, 600)
        XCTAssertEqual(store.windowBounds()?.right, 900)
        XCTAssertEqual(store.iconViewSettings()?.arrangeBy, "none")
        XCTAssertEqual(store.iconViewSettings()?.iconSize, 96)
        XCTAssertEqual(iconViewProperties["backgroundImageAlias"], .data(aliasData))
        XCTAssertEqual(iconViewProperties["gridOffsetX"], .double(0))
        XCTAssertEqual(iconViewProperties["gridOffsetY"], .double(0))
        XCTAssertEqual(
            store.record(for: ".", type: .custom(.literal("icvl")))?.value,
            .fourCC(.iconView)
        )
        XCTAssertEqual(store.record(for: ".", type: .viewSortVersion)?.value, .uint32(1))
        XCTAssertNil(store.record(for: ".", type: .background))
        XCTAssertNil(store.record(for: ".", type: .backgroundPicture))
    }

    func testBuilderCopiesAppAddsApplicationsShortcutAndMovesVerifiedOutput() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let output = fixture.root.appendingPathComponent("Example.dmg")
        let diskTool = RecordingDiskImageTool()
        let layoutWriter = RecordingDSStoreLayoutWriter()
        let iconSetter = RecordingVolumeIconSetter()
        let plan = DmgBuildPlan(appURL: fixture.app, outputURL: output, volumeName: "Example", screenSize: CGSize(width: 1_600, height: 1_000))

        let result = try DmgBuilder(diskImageTool: diskTool, layoutWriter: layoutWriter, volumeIconSetter: iconSetter).build(plan: plan)

        XCTAssertEqual(result.dmgURL, output)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        XCTAssertTrue(diskTool.stagedApplicationIsPresent)
        XCTAssertEqual(diskTool.applicationsDestination, "/Applications")
        XCTAssertEqual(try XCTUnwrap(layoutWriter.layout).appPosition.y, layoutWriter.layout?.applicationsPosition.y)
        XCTAssertEqual(layoutWriter.applicationName, "Example.app")
        XCTAssertEqual(layoutWriter.volumeName, "Example")
        XCTAssertEqual(iconSetter.appURL, fixture.app)
        XCTAssertTrue(diskTool.didVerify)
    }

    func testBuilderStagesOutsideTheSelectedOutputDirectory() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let outputDirectory = fixture.root.appendingPathComponent("dist", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let output = outputDirectory.appendingPathComponent("Example.dmg")
        let diskTool = RecordingDiskImageTool()

        _ = try DmgBuilder(
            diskImageTool: diskTool,
            layoutWriter: RecordingDSStoreLayoutWriter(),
            volumeIconSetter: RecordingVolumeIconSetter()
        ).build(
            plan: DmgBuildPlan(
                appURL: fixture.app,
                outputURL: output,
                volumeName: "Example",
                screenSize: CGSize(width: 1_600, height: 1_000)
            )
        )

        let sourceFolder = try XCTUnwrap(diskTool.sourceFolder)
        let mountPoint = try XCTUnwrap(diskTool.mountPoint)
        XCTAssertFalse(sourceFolder.path.hasPrefix(outputDirectory.path + "/"))
        XCTAssertFalse(mountPoint.path.hasPrefix(outputDirectory.path + "/"))
        XCTAssertTrue(sourceFolder.path.hasPrefix("/private/tmp/"))
        XCTAssertTrue(mountPoint.path.hasPrefix("/private/tmp/"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
    }

    func testBuilderSetsVolumeIconAfterWritingLayoutMetadata() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let output = fixture.root.appendingPathComponent("Example.dmg")
        let events = MutableEventLog()
        let builder = DmgBuilder(
            diskImageTool: RecordingDiskImageTool(),
            layoutWriter: LayoutWriterRecordingOrder(events: events),
            volumeIconSetter: VolumeIconSetterRecordingOrder(events: events)
        )

        let result = try builder.build(
            plan: DmgBuildPlan(
                appURL: fixture.app,
                outputURL: output,
                volumeName: "Example",
                screenSize: CGSize(width: 1_600, height: 1_000)
            )
        )

        XCTAssertEqual(result.dmgURL, output)
        XCTAssertEqual(events.values, ["write", "setIcon"])
    }

    func testBuilderWritesLayoutMetadataBeforeDetaching() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let diskTool = PersistenceCheckingDiskImageTool()
        let builder = DmgBuilder(
            diskImageTool: diskTool,
            layoutWriter: MetadataWritingLayoutWriter(),
            volumeIconSetter: RecordingVolumeIconSetter()
        )
        let output = fixture.root.appendingPathComponent("Example.dmg")

        _ = try builder.build(
            plan: DmgBuildPlan(
                appURL: fixture.app,
                outputURL: output,
                volumeName: "Example",
                screenSize: CGSize(width: 1_600, height: 1_000)
            )
        )

        XCTAssertTrue(diskTool.didFindBackgroundMetadataBeforeDetach)
    }

    func testBuilderReplacesExistingOutputAfterVerifyingNewDMG() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let output = fixture.root.appendingPathComponent("Existing.dmg")
        try Data("previous".utf8).write(to: output)
        let diskTool = RecordingDiskImageTool()

        _ = try DmgBuilder(
            diskImageTool: diskTool,
            layoutWriter: RecordingDSStoreLayoutWriter(),
            volumeIconSetter: RecordingVolumeIconSetter()
        ).build(
            plan: DmgBuildPlan(appURL: fixture.app, outputURL: output, volumeName: "Example", screenSize: CGSize(width: 1_600, height: 1_000))
        )

        XCTAssertTrue(diskTool.didVerify)
        XCTAssertEqual(try Data(contentsOf: output), Data("compressed".utf8))
    }

    func testBuilderPreservesExistingOutputWhenNewBuildFails() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let output = fixture.root.appendingPathComponent("Existing.dmg")
        try Data("previous".utf8).write(to: output)
        let diskTool = RecordingDiskImageTool(createError: .commandFailed("create failed"))

        XCTAssertThrowsError(
            try DmgBuilder(diskImageTool: diskTool).build(
                plan: DmgBuildPlan(appURL: fixture.app, outputURL: output, volumeName: "Example", screenSize: CGSize(width: 1_600, height: 1_000))
            )
        ) { error in
            XCTAssertEqual(error as? DmgBuildError, .commandFailed("create failed"))
        }

        XCTAssertEqual(try Data(contentsOf: output), Data("previous".utf8))
    }

    func testBuilderCleansStagingWhenCreatingWritableImageFails() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let diskTool = RecordingDiskImageTool(createError: .commandFailed("create failed"))
        let output = fixture.root.appendingPathComponent("Broken.dmg")

        XCTAssertThrowsError(try DmgBuilder(diskImageTool: diskTool).build(plan: DmgBuildPlan(appURL: fixture.app, outputURL: output, volumeName: "Example", screenSize: CGSize(width: 1_600, height: 1_000))))

        let contents = try FileManager.default.contentsOfDirectory(atPath: fixture.root.path)
        XCTAssertFalse(contents.contains { $0.hasPrefix(".DMGStudio-") })
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
    }

    func testBuilderRunsPostProcessingBeforeItPublishesTheDMG() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let output = fixture.root.appendingPathComponent("Example.dmg")
        let postProcessor = RecordingPostProcessor()
        let builder = DmgBuilder(
            diskImageTool: RecordingDiskImageTool(),
            layoutWriter: RecordingDSStoreLayoutWriter(),
            volumeIconSetter: RecordingVolumeIconSetter(),
            postProcessor: postProcessor
        )

        _ = try builder.build(plan: DmgBuildPlan(appURL: fixture.app, outputURL: output, volumeName: "Example", screenSize: CGSize(width: 1_600, height: 1_000)))

        XCTAssertEqual(postProcessor.processedImageName, "Result.dmg")
    }

    func testCommandLineParserBuildsPlanWithCustomArtworkAndLayout() throws {
        let arguments = [
            "create", "--app", "/Games/Example.app", "--background", "/Art/background.jpg",
            "--volume-icon", "/Art/icon.png", "--volume-name", "Example Disk", "--output", "/Output/Example.dmg",
            "--app-x", "0.25", "--applications-x", "0.75"
        ]

        let options = try DmgCommandLineParser.parse(arguments: arguments)

        XCTAssertEqual(options.appURL.path, "/Games/Example.app")
        XCTAssertEqual(options.backgroundURL?.path, "/Art/background.jpg")
        XCTAssertEqual(options.volumeIconURL?.path, "/Art/icon.png")
        XCTAssertEqual(options.volumeName, "Example Disk")
        XCTAssertEqual(options.outputURL?.path, "/Output/Example.dmg")
        XCTAssertEqual(options.layout.appHorizontalPosition, 0.25)
        XCTAssertEqual(options.layout.applicationsHorizontalPosition, 0.75)
    }

    func testCommandLineOptionsDefaultOutputIsOutputDMGInCurrentDirectory() throws {
        let options = try DmgCommandLineParser.parse(arguments: ["create", "--app", "/Games/Example.app"])

        let plan = options.buildPlan(screenSize: CGSize(width: 1_600, height: 1_000), usesDarkAppearance: false)

        let expectedOutput = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent("output.dmg")
        XCTAssertEqual(plan.outputURL, expectedOutput)
    }

    func testHdiutilToolGeneratesWritableThenCompressedCommandArguments() throws {
        let runner = RecordingCommandRunner()
        let tool = HdiutilDiskImageTool(commandRunner: runner)
        let source = URL(fileURLWithPath: "/tmp/Source")
        let working = URL(fileURLWithPath: "/tmp/Working.dmg")
        let result = URL(fileURLWithPath: "/tmp/Result.dmg")

        try tool.createWritableImage(from: source, volumeName: "Example", at: working)
        try tool.compress(imageURL: working, to: result)

        XCTAssertEqual(runner.commands[0].arguments, ["create", "-ov", "-format", "UDRW", "-volname", "Example", "-srcfolder", source.path, working.path])
        XCTAssertEqual(runner.commands[1].arguments, ["convert", working.path, "-format", "UDZO", "-o", result.path])
    }

    private func makePNG(at url: URL, size: Int) throws {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try XCTUnwrap(CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }

    private func makeFixture() throws -> DmgFixture {
        try DmgFixture()
    }
}

private final class DmgFixture {
    let root: URL
    let app: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        app = root.appendingPathComponent("Example.app", isDirectory: true)
        try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents", isDirectory: true), withIntermediateDirectories: true)
        try Data("plist".utf8).write(to: app.appendingPathComponent("Contents/Info.plist"))
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}

private final class RecordingDiskImageTool: DiskImageTooling {
    let createError: DmgBuildError?
    var stagedApplicationIsPresent = false
    var applicationsDestination: String?
    var didVerify = false
    var sourceFolder: URL?
    var mountPoint: URL?

    init(createError: DmgBuildError? = nil) {
        self.createError = createError
    }

    func createWritableImage(from sourceFolder: URL, volumeName: String, at imageURL: URL) throws {
        if let createError { throw createError }
        self.sourceFolder = sourceFolder
        stagedApplicationIsPresent = FileManager.default.fileExists(
            atPath: sourceFolder.appendingPathComponent("Example.app/Contents/Info.plist").path
        )
        applicationsDestination = try? FileManager.default.destinationOfSymbolicLink(
            atPath: sourceFolder.appendingPathComponent("Applications").path
        )
        try Data("writable".utf8).write(to: imageURL)
    }

    func attach(imageURL: URL, mountPoint: URL) throws {
        self.mountPoint = mountPoint
        try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)
    }

    func detach(mountPoint: URL) throws {}

    func compress(imageURL: URL, to outputURL: URL) throws {
        try Data("compressed".utf8).write(to: outputURL)
    }

    func verify(imageURL: URL) throws {
        didVerify = true
    }
}

private final class PersistenceCheckingDiskImageTool: DiskImageTooling {
    var didFindBackgroundMetadataBeforeDetach = false

    func createWritableImage(from sourceFolder: URL, volumeName: String, at imageURL: URL) throws {
        try Data("writable".utf8).write(to: imageURL)
    }

    func attach(imageURL: URL, mountPoint: URL) throws {
        try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)
    }

    func detach(mountPoint: URL) throws {
        let metadataURL = mountPoint.appendingPathComponent(".DS_Store")
        let data = try? Data(contentsOf: metadataURL)
        didFindBackgroundMetadataBeforeDetach = data?.range(of: Data("layout-ready".utf8)) != nil
    }

    func compress(imageURL: URL, to outputURL: URL) throws {
        try Data("compressed".utf8).write(to: outputURL)
    }

    func verify(imageURL: URL) throws {}
}

private final class RecordingDSStoreLayoutWriter: DmgLayoutWriting {
    var layout: DmgFinderLayout?
    var applicationName: String?
    var volumeName: String?

    func write(mountedVolume: URL, volumeName: String, applicationName: String, layout: DmgFinderLayout) throws {
        self.layout = layout
        self.applicationName = applicationName
        self.volumeName = volumeName
    }
}

private final class MetadataWritingLayoutWriter: DmgLayoutWriting {
    func write(mountedVolume: URL, volumeName: String, applicationName: String, layout: DmgFinderLayout) throws {
        try Data("layout-ready".utf8).write(to: mountedVolume.appendingPathComponent(".DS_Store"))
    }
}

private final class RecordingVolumeIconSetter: VolumeIconSetting {
    var appURL: URL?

    func setIcon(for mountedVolume: URL, customIconURL: URL?, fallbackAppURL: URL) throws {
        appURL = fallbackAppURL
    }
}

private final class MutableEventLog {
    var values: [String] = []
}

private final class LayoutWriterRecordingOrder: DmgLayoutWriting {
    private let events: MutableEventLog

    init(events: MutableEventLog) {
        self.events = events
    }

    func write(mountedVolume: URL, volumeName: String, applicationName: String, layout: DmgFinderLayout) throws {
        events.values.append("write")
    }
}

private final class VolumeIconSetterRecordingOrder: VolumeIconSetting {
    private let events: MutableEventLog

    init(events: MutableEventLog) {
        self.events = events
    }

    func setIcon(for mountedVolume: URL, customIconURL: URL?, fallbackAppURL: URL) throws {
        events.values.append("setIcon")
    }
}

private final class RecordingPostProcessor: DmgPostProcessing {
    var processedImageName: String?

    func process(imageURL: URL) throws {
        processedImageName = imageURL.lastPathComponent
    }
}

private final class RecordingCommandRunner: CommandRunning {
    struct Command {
        let executableURL: URL
        let arguments: [String]
    }

    var commands: [Command] = []

    func run(executableURL: URL, arguments: [String]) throws {
        commands.append(Command(executableURL: executableURL, arguments: arguments))
    }
}
