import AppKit
import SwiftUI
import UniformTypeIdentifiers
import DMGStudioCore

@MainActor
final class DmgStudioViewModel: ObservableObject {
    @Published private(set) var appURL: URL?
    @Published private(set) var backgroundURL: URL?
    @Published private(set) var volumeIconURL: URL?
    @Published private(set) var outputDirectoryURL: URL?
    @Published var volumeName = ""
    @Published var appHorizontalPosition: CGFloat = 0.28
    @Published var applicationsHorizontalPosition: CGFloat = 0.72
    @Published private(set) var isBuilding = false
    @Published private(set) var statusMessage: String?
    @Published var errorMessage: String?

    var outputURL: URL? {
        guard let appURL else { return nil }
        let directory = outputDirectoryURL ?? appURL.deletingLastPathComponent()
        return directory
            .appendingPathComponent(appURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension("dmg")
    }

    var layout: DmgLayout {
        DmgLayout(
            appHorizontalPosition: appHorizontalPosition,
            applicationsHorizontalPosition: applicationsHorizontalPosition
        )
    }

    func chooseApplication() {
        let panel = NSOpenPanel()
        panel.message = "Choose the macOS app to package"
        panel.prompt = "Choose App"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        appURL = url
        outputDirectoryURL = url.deletingLastPathComponent()
        volumeName = url.deletingPathExtension().lastPathComponent
        statusMessage = nil
        errorMessage = nil
    }

    func chooseBackground() {
        backgroundURL = chooseFile(
            message: "Choose a PNG or JPEG background",
            prompt: "Choose Background",
            contentTypes: [.png, .jpeg]
        )
    }

    func chooseVolumeIcon() {
        volumeIconURL = chooseFile(
            message: "Choose an ICNS or square PNG volume icon",
            prompt: "Choose Icon",
            contentTypes: [.icns, .png]
        )
    }

    func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.message = "Choose the folder that will receive the DMG"
        panel.prompt = "Choose Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        outputDirectoryURL = url
    }

    func clearBackground() {
        backgroundURL = nil
    }

    func clearVolumeIcon() {
        volumeIconURL = nil
    }

    func moveApp(to horizontalPosition: CGFloat) {
        appHorizontalPosition = snappedPosition(horizontalPosition)
    }

    func moveApplications(to horizontalPosition: CGFloat) {
        applicationsHorizontalPosition = snappedPosition(horizontalPosition)
    }

    func createDmg(usesDarkAppearance: Bool) {
        guard let plan = makePlan(usesDarkAppearance: usesDarkAppearance) else {
            errorMessage = "Choose an app and an output folder first."
            return
        }

        isBuilding = true
        errorMessage = nil
        statusMessage = "Creating \(plan.outputURL.lastPathComponent)…"

        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> Result<DmgBuildResult, DmgBuildError> in
                do {
                    return .success(try DmgBuilder().build(plan: plan))
                } catch let error as DmgBuildError {
                    return .failure(error)
                } catch {
                    return .failure(.filesystem(error.localizedDescription))
                }
            }.value

            isBuilding = false
            switch result {
            case .success(let buildResult):
                statusMessage = "Created \(buildResult.dmgURL.lastPathComponent)."
                NSWorkspace.shared.activateFileViewerSelecting([buildResult.dmgURL])
            case .failure(let error):
                errorMessage = error.localizedDescription
                statusMessage = nil
            }
        }
    }

    private func chooseFile(message: String, prompt: String, contentTypes: [UTType]) -> URL? {
        let panel = NSOpenPanel()
        panel.message = message
        panel.prompt = prompt
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = contentTypes
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func makePlan(usesDarkAppearance: Bool) -> DmgBuildPlan? {
        guard let appURL, let outputURL else { return nil }
        return DmgBuildPlan(
            appURL: appURL,
            backgroundURL: backgroundURL,
            volumeIconURL: volumeIconURL,
            outputURL: outputURL,
            volumeName: volumeName,
            screenSize: NSScreen.main?.visibleFrame.size ?? CGSize(width: 1_440, height: 900),
            layout: layout,
            usesDarkAppearance: usesDarkAppearance
        )
    }

    private func snappedPosition(_ position: CGFloat) -> CGFloat {
        min(0.88, max(0.12, (position * 12).rounded() / 12))
    }
}

struct DmgStudioView: View {
    @StateObject private var viewModel = DmgStudioViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HSplitView {
            controls
                .frame(minWidth: 300, idealWidth: 340, maxWidth: 380)
            preview
                .padding(.leading, 18)
                .frame(minWidth: 500, minHeight: 560)
        }
        .padding(20)
        .frame(minWidth: 900, minHeight: 640)
        .alert("DMGStudio could not create the disk image", isPresented: hasError) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("DMGStudio")
                        .font(.largeTitle.weight(.bold))
                    Text("Create a clean, unsigned drag-to-install disk image.")
                        .foregroundStyle(.secondary)
                }

                GroupBox("App") {
                    FileSelectionRow(url: viewModel.appURL, buttonTitle: "Choose App", action: viewModel.chooseApplication)
                }

                GroupBox("Artwork") {
                    VStack(alignment: .leading, spacing: 12) {
                        FileSelectionRow(url: viewModel.backgroundURL, buttonTitle: "Choose Background", action: viewModel.chooseBackground)
                        if viewModel.backgroundURL != nil {
                            Button("Use Default Artwork", action: viewModel.clearBackground)
                        }
                        FileSelectionRow(url: viewModel.volumeIconURL, buttonTitle: "Choose Volume Icon", action: viewModel.chooseVolumeIcon)
                        if viewModel.volumeIconURL != nil {
                            Button("Use App Icon", action: viewModel.clearVolumeIcon)
                        }
                        Text("Backgrounds accept PNG or JPEG. A custom volume icon accepts ICNS or a square PNG of at least 512 × 512 pixels.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                GroupBox("Output") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Mounted volume name", text: $viewModel.volumeName)
                        FileSelectionRow(url: viewModel.outputDirectoryURL, buttonTitle: "Choose Output Folder", action: viewModel.chooseOutputDirectory)
                        if let outputURL = viewModel.outputURL {
                            Text("Creates \(outputURL.lastPathComponent), replacing an existing DMG only after the new one is verified.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button {
                    viewModel.createDmg(usesDarkAppearance: colorScheme == .dark)
                } label: {
                    HStack {
                        if viewModel.isBuilding { ProgressView().controlSize(.small) }
                        Text(viewModel.isBuilding ? "Creating DMG…" : "Create DMG")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.appURL == nil || viewModel.isBuilding)

                if let statusMessage = viewModel.statusMessage {
                    Label(statusMessage, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .padding(.trailing, 18)
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Finder layout")
                    .font(.title2.weight(.semibold))
                Spacer()
                Text("Drag either icon horizontally")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            DmgPreviewCanvas(
                appURL: viewModel.appURL,
                backgroundURL: viewModel.backgroundURL,
                appHorizontalPosition: viewModel.appHorizontalPosition,
                applicationsHorizontalPosition: viewModel.applicationsHorizontalPosition,
                usesDarkAppearance: colorScheme == .dark,
                creatorScreenSize: NSScreen.main?.visibleFrame.size ?? CGSize(width: 1_440, height: 900),
                moveApp: viewModel.moveApp,
                moveApplications: viewModel.moveApplications
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text("Finder stores this presentation as a best effort. Recipient display settings can change the final window size or background treatment.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var hasError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

private struct FileSelectionRow: View {
    let url: URL?
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(url?.lastPathComponent ?? "Not selected")
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(url == nil ? .secondary : .primary)
            Spacer(minLength: 0)
            Button(buttonTitle, action: action)
        }
    }
}

private struct DmgPreviewCanvas: View {
    let appURL: URL?
    let backgroundURL: URL?
    let appHorizontalPosition: CGFloat
    let applicationsHorizontalPosition: CGFloat
    let usesDarkAppearance: Bool
    let creatorScreenSize: CGSize
    let moveApp: (CGFloat) -> Void
    let moveApplications: (CGFloat) -> Void

    var body: some View {
        GeometryReader { geometry in
            let canvasSize = resolvedCanvasSize(in: geometry.size)
            let visualCenterlineY = DmgLayout.visualCenterlineY(in: canvasSize)
            let arrowCenterY = DmgLayout.canvasCenterY(in: canvasSize)
            ZStack {
                canvasBackground
                Image(systemName: "arrow.right")
                    .font(.system(size: max(26, canvasSize.width * 0.08), weight: .medium))
                    .foregroundStyle((usesDarkAppearance ? Color.white : Color.black).opacity(0.58))
                    .position(x: canvasSize.width / 2, y: arrowCenterY)

                PreviewIcon(
                    image: appURL.map { NSWorkspace.shared.icon(forFile: $0.path) },
                    title: appURL?.deletingPathExtension().lastPathComponent ?? "Your App"
                )
                .position(
                    x: canvasSize.width * appHorizontalPosition,
                    y: visualCenterlineY + PreviewIcon.iconCenterOffset
                )
                .gesture(horizontalDrag(in: canvasSize, move: moveApp))

                PreviewIcon(
                    image: NSWorkspace.shared.icon(forFile: "/Applications"),
                    title: "Applications"
                )
                .position(
                    x: canvasSize.width * applicationsHorizontalPosition,
                    y: visualCenterlineY + PreviewIcon.iconCenterOffset
                )
                .gesture(horizontalDrag(in: canvasSize, move: moveApplications))
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    @ViewBuilder
    private var canvasBackground: some View {
        if let backgroundURL, let image = NSImage(contentsOf: backgroundURL) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(usesDarkAppearance ? Color(white: 0.16) : Color(white: 0.96))
        }
    }

    private func resolvedCanvasSize(in availableSize: CGSize) -> CGSize {
        let baseSize = backgroundPixelSize ?? CGSize(width: 800, height: 500)
        let canvas = BackgroundCanvasPlanner.resolve(imageSize: baseSize, visibleScreenSize: creatorScreenSize)
        let scale = min(1, availableSize.width / canvas.width, availableSize.height / canvas.height)
        return CGSize(width: floor(canvas.width * scale), height: floor(canvas.height * scale))
    }

    private var backgroundPixelSize: CGSize? {
        guard let backgroundURL, let image = NSImage(contentsOf: backgroundURL), let representation = image.representations.first else {
            return nil
        }
        return CGSize(width: representation.pixelsWide, height: representation.pixelsHigh)
    }

    private func horizontalDrag(in size: CGSize, move: @escaping (CGFloat) -> Void) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                move(value.location.x / size.width)
            }
    }
}

private struct PreviewIcon: View {
    static let iconCenterOffset: CGFloat = 12

    let image: NSImage?
    let title: String

    var body: some View {
        VStack(spacing: 5) {
            Image(nsImage: image ?? NSImage())
                .resizable()
                .interpolation(.high)
                .frame(width: 78, height: 78)
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.regularMaterial, in: Capsule())
        }
        .frame(width: 128)
        .contentShape(Rectangle())
    }
}
