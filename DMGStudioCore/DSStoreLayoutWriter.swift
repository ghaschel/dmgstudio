import Darwin
import DSStore
import Foundation

protocol DmgLayoutWriting {
    func write(
        mountedVolume: URL,
        volumeName: String,
        applicationName: String,
        layout: DmgFinderLayout
    ) throws
}

/// Writes Finder presentation records directly to the mounted image. This avoids
/// opening Finder or depending on its asynchronous .DS_Store persistence.
struct DSStoreLayoutWriter: DmgLayoutWriting {
    private static let backgroundRelativePath = ".background/background.png"

    func write(
        mountedVolume: URL,
        volumeName: String,
        applicationName: String,
        layout: DmgFinderLayout
    ) throws {
        let backgroundURL = mountedVolume.appendingPathComponent(Self.backgroundRelativePath)
        guard FileManager.default.fileExists(atPath: backgroundURL.path) else {
            throw DmgBuildError.filesystem("DMGStudio could not find the prepared DMG background image.")
        }

        let aliasInfo = try FinderAliasFileInfo.collect(
            mountedVolume: mountedVolume,
            backgroundURL: backgroundURL
        )
        let aliasData = try FinderAliasRecordBuilder.make(
            volumeName: volumeName,
            relativePath: Self.backgroundRelativePath,
            info: aliasInfo
        )

        do {
            let width = Int(layout.canvasSize.width)
            let height = Int(layout.canvasSize.height)
            var store = DSStore()
            try store.setIconPosition(
                for: applicationName,
                x: Int(layout.appPosition.x),
                y: Int(layout.appPosition.y)
            )
            try store.setIconPosition(
                for: "Applications",
                x: Int(layout.applicationsPosition.x),
                y: Int(layout.applicationsPosition.y)
            )
            try store.setWindowBounds(
                top: 100,
                left: 100,
                bottom: height + 100,
                right: width + 100
            )
            store.setWindowSettings(
                DSStore.WindowSettings(
                    windowBounds: DSStore.WindowSettings.WindowFrame(
                        originX: 100,
                        originY: 100,
                        width: Double(width),
                        height: Double(height)
                    ).stringValue,
                    showSidebar: false,
                    showToolbar: false,
                    showStatusBar: false,
                    showPathBar: false,
                    viewStyle: "icnv"
                )
            )
            store.add(
                DSStore.Record(
                    filename: ".",
                    type: .iconViewProperties,
                    value: .propertyList(
                        .dictionary([
                            "arrangeBy": .string("none"),
                            "backgroundColorBlue": .double(1),
                            "backgroundColorGreen": .double(1),
                            "backgroundColorRed": .double(1),
                            "backgroundImageAlias": .data(aliasData),
                            "backgroundType": .int(2),
                            "gridOffsetX": .double(0),
                            "gridOffsetY": .double(0),
                            "gridSpacing": .double(100),
                            "iconSize": .int(96),
                            "labelOnBottom": .bool(true),
                            "scrollPositionX": .double(0),
                            "scrollPositionY": .double(0),
                            "showIconPreview": .bool(false),
                            "showItemInfo": .bool(false),
                            "textSize": .int(12),
                            "viewOptionsVersion": .int(1)
                        ])
                    )
                )
            )
            store.add(
                DSStore.Record(
                    filename: ".",
                    type: .custom(.literal("icvl")),
                    value: .fourCC(.iconView)
                )
            )
            store.add(
                DSStore.Record(
                    filename: ".",
                    type: .viewSortVersion,
                    value: .uint32(1)
                )
            )
            store.setViewStyle(.icon)
            try store.write(to: mountedVolume.appendingPathComponent(".DS_Store"))
        } catch {
            throw DmgBuildError.filesystem("DMGStudio could not write the deterministic Finder layout: \(error.localizedDescription)")
        }
    }
}

private struct FinderAliasFileInfo {
    let volumeCreationDate: UInt32
    let fileCreationDate: UInt32
    let parentCNID: UInt32
    let fileCNID: UInt32

    static func collect(mountedVolume: URL, backgroundURL: URL) throws -> Self {
        let volume = try status(of: mountedVolume)
        let background = try status(of: backgroundURL)
        let parent = try status(of: backgroundURL.deletingLastPathComponent())
        return Self(
            volumeCreationDate: try hfsTimestamp(from: Int64(volume.st_birthtimespec.tv_sec)),
            fileCreationDate: try hfsTimestamp(from: Int64(background.st_birthtimespec.tv_sec)),
            parentCNID: UInt32(truncatingIfNeeded: parent.st_ino),
            fileCNID: UInt32(truncatingIfNeeded: background.st_ino)
        )
    }

    private static func status(of url: URL) throws -> stat {
        var value = stat()
        guard stat(url.path, &value) == 0 else {
            throw DmgBuildError.filesystem("DMGStudio could not read metadata for \(url.lastPathComponent).")
        }
        return value
    }

    private static func hfsTimestamp(from unixTimestamp: Int64) throws -> UInt32 {
        let hfsEpochOffset: Int64 = 2_082_844_800
        let hfsTimestamp = unixTimestamp + hfsEpochOffset
        guard let value = UInt32(exactly: hfsTimestamp) else {
            throw DmgBuildError.filesystem("DMGStudio could not encode the DMG background metadata timestamp.")
        }
        return value
    }
}

private enum FinderAliasRecordBuilder {
    static func make(volumeName: String, relativePath: String, info: FinderAliasFileInfo) throws -> Data {
        let fileName = URL(fileURLWithPath: relativePath).lastPathComponent
        let parentPath = URL(fileURLWithPath: relativePath).deletingLastPathComponent().path
        var data = Data()

        data.appendBigEndian(UInt32(0))
        let sizeOffset = data.count
        data.appendBigEndian(UInt16(0))
        data.appendBigEndian(UInt16(2))
        data.appendBigEndian(UInt16(0))
        data.appendPascalString(volumeName, totalLength: 28)
        data.appendBigEndian(info.volumeCreationDate)
        data.appendBigEndian(UInt16(0x482B))
        data.appendBigEndian(UInt16(0))
        data.appendBigEndian(info.parentCNID)
        data.appendPascalString(fileName, totalLength: 64)
        data.appendBigEndian(info.fileCNID)
        data.appendBigEndian(info.fileCreationDate)
        data.appendBigEndian(UInt32(0))
        data.appendBigEndian(UInt32(0))
        data.appendBigEndian(UInt16.max)
        data.appendBigEndian(UInt16.max)
        data.appendBigEndian(UInt32(0))
        data.appendBigEndian(UInt16(0))
        data.append(contentsOf: repeatElement(0, count: 10))

        try data.appendAliasTag(type: 0, value: Data((parentPath == "." ? volumeName : parentPath).utf8))
        try data.appendAliasTag(type: 0x0010, value: Data.bigEndian(info.volumeCreationDate, shiftedLeftBy: 16))
        try data.appendAliasTag(type: 0x0011, value: Data.bigEndian(info.fileCreationDate, shiftedLeftBy: 16))
        try data.appendAliasTag(
            type: 0x0002,
            value: Data("\(volumeName):\(relativePath.replacingOccurrences(of: "/", with: ":"))".utf8)
        )
        try data.appendUTF16AliasTag(type: 0x000E, value: fileName)
        try data.appendUTF16AliasTag(type: 0x000F, value: volumeName)
        try data.appendAliasTag(type: 0x0012, value: Data("/\(relativePath)".utf8))
        try data.appendAliasTag(type: 0x0013, value: Data("/Volumes/\(volumeName)".utf8))
        data.appendBigEndian(UInt16.max)
        data.appendBigEndian(UInt16(0))

        guard let aliasSize = UInt16(exactly: data.count) else {
            throw DmgBuildError.filesystem("DMGStudio could not encode the DMG background alias.")
        }
        var encodedSize = aliasSize.bigEndian
        let sizeData = Swift.withUnsafeBytes(of: &encodedSize) { Data($0) }
        data.replaceSubrange(sizeOffset..<(sizeOffset + MemoryLayout<UInt16>.size), with: sizeData)
        return data
    }
}

private extension Data {
    static func bigEndian(_ value: UInt32, shiftedLeftBy shift: UInt64) -> Data {
        var shifted = (UInt64(value) << shift).bigEndian
        return Swift.withUnsafeBytes(of: &shifted) { Data($0) }
    }

    mutating func appendBigEndian<T: FixedWidthInteger>(_ value: T) {
        var bigEndian = value.bigEndian
        append(contentsOf: Swift.withUnsafeBytes(of: &bigEndian) { $0 })
    }

    mutating func appendPascalString(_ string: String, totalLength: Int) {
        let maximumLength = totalLength - 1
        let bytes = Array(string.utf8.prefix(maximumLength))
        append(UInt8(bytes.count))
        append(contentsOf: bytes)
        append(contentsOf: repeatElement(0, count: maximumLength - bytes.count))
    }

    mutating func appendAliasTag(type: UInt16, value: Data) throws {
        guard let length = UInt16(exactly: value.count) else {
            throw DmgBuildError.filesystem("DMGStudio could not encode the DMG background alias.")
        }
        appendBigEndian(type)
        appendBigEndian(length)
        append(value)
        if !value.count.isMultiple(of: 2) {
            append(0)
        }
    }

    mutating func appendUTF16AliasTag(type: UInt16, value: String) throws {
        let units = Array(value.utf16)
        guard let count = UInt16(exactly: units.count) else {
            throw DmgBuildError.filesystem("DMGStudio could not encode the DMG background alias.")
        }
        var encoded = Data()
        encoded.appendBigEndian(count)
        for unit in units {
            encoded.appendBigEndian(unit)
        }
        try appendAliasTag(type: type, value: encoded)
    }
}
