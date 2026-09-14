import AppKit
import Darwin
import Foundation
import DMGStudioCore

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.isEmpty || arguments.contains("--help") || arguments.contains("-h") {
    print(DmgCommandLineParser.usage)
    exit(0)
}

do {
    let options = try DmgCommandLineParser.parse(arguments: arguments)
    let screenSize = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1_440, height: 900)
    let appearance = NSApplication.shared.effectiveAppearance
    let usesDarkAppearance = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    let result = try DmgBuilder().build(plan: options.buildPlan(screenSize: screenSize, usesDarkAppearance: usesDarkAppearance))
    print("Created \(result.dmgURL.path)")
} catch {
    FileHandle.standardError.write(Data("dmgstudio: \(error.localizedDescription)\n".utf8))
    exit(1)
}
