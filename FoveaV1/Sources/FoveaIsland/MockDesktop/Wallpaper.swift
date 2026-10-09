import SwiftUI
import AppKit
import UniformTypeIdentifiers
import FoveaCore
import FoveaKit

/// What the mock display shows behind the menu bar and the Dock.
enum WallpaperChoice: Hashable {
    /// The user's own desktop picture.
    case system
    /// A bundled photo, by name (`Wallpaper.photos`).
    case photo(String)
    case color(WallpaperColor)
    /// A picture chosen on disk.
    case file(URL)

    var title: String {
        switch self {
        case .system: return "Desktop Picture"
        case .photo(let name): return name.capitalized
        case .color(let color): return color.title
        case .file(let url): return url.lastPathComponent
        }
    }

    /// The remembered form: "system", "photo:mountain", "color:slate", "file:/path".
    var key: String {
        switch self {
        case .system: return "system"
        case .photo(let name): return "photo:\(name)"
        case .color(let color): return "color:\(color.rawValue)"
        case .file(let url): return "file:\(url.path)"
        }
    }

    init?(key: String) {
        if key == "system" { self = .system; return }
        if key.hasPrefix("photo:") { self = .photo(String(key.dropFirst("photo:".count))); return }
        if key.hasPrefix("color:"), let color = WallpaperColor(rawValue: String(key.dropFirst("color:".count))) {
            self = .color(color); return
        }
        if key.hasPrefix("file:") { self = .file(URL(fileURLWithPath: String(key.dropFirst("file:".count)))); return }
        return nil
    }
}

/// Flat backgrounds: the contrast cases a notch design is checked against.
enum WallpaperColor: String, CaseIterable, Identifiable {
    case slate, black, white
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .slate: return WorkbenchTokens.Colors.desktopFallback
        case .black: return WorkbenchTokens.Colors.desktopBlack
        case .white: return WorkbenchTokens.Colors.desktopWhite
        }
    }
}

/// What the display paints: a picture or a flat color.
enum WallpaperFill {
    case image(NSImage)
    case color(Color)
}

enum Wallpaper {
    /// The bundled photos, in the order the panel lists them.
    static let photos = ["mountain", "coast", "forest", "desk", "building", "lion"]
    static let defaultPhoto = "mountain"

    /// The fill for a choice. A picture that cannot be read falls back to the bundled photo
    /// for the desktop picture, else to the slate color.
    static func fill(for choice: WallpaperChoice) -> WallpaperFill {
        let slate = WallpaperFill.color(WallpaperColor.slate.color)
        switch choice {
        case .system: return (system() ?? bundled(defaultPhoto)).map(WallpaperFill.image) ?? slate
        case .photo(let name): return bundled(name).map(WallpaperFill.image) ?? slate
        case .color(let color): return .color(color.color)
        case .file(let url): return NSImage(contentsOf: url).map(WallpaperFill.image) ?? slate
        }
    }

    static func bundled(_ name: String) -> NSImage? {
        FoveaFiles.url("Photos/\(name).jpg").flatMap { NSImage(contentsOf: $0) }
    }

    /// The user's desktop picture, when it is something `NSImage` can read: a still image
    /// directly, an aerial (Sonoma and later, a <UUID>.mov) through the still the system keeps.
    static func system() -> NSImage? {
        guard let screen = NSScreen.main,
              let url = NSWorkspace.shared.desktopImageURL(for: screen) else { return nil }
        let files = FileManager.default
        if isImage(url), files.isReadableFile(atPath: url.path) {
            return NSImage(contentsOf: url)
        }
        let still = URL(fileURLWithPath: "/Library/Application Support/com.apple.idleassetsd/snapshots")
            .appendingPathComponent("asset-preview-\(url.deletingPathExtension().lastPathComponent).jpg")
        if files.isReadableFile(atPath: still.path) { return NSImage(contentsOf: still) }
        return nil
    }

    private static func isImage(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) ?? false
    }
}
