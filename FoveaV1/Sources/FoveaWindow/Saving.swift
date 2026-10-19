import AppKit
import SwiftUI
import UniformTypeIdentifiers
import CapturesCore
import FoveaKit

// Oct 15 review, IS04: Save writes real files. Save Everything… makes a folder named for the
// capture (its words, the pictures, the passages, copies of the files that are still there);
// Save Pictures… puts the pictures in a folder you pick; Save Picture… and Save a Copy… one file
// each. A save that fails says so in an alert, the Mac's own, with what went wrong. No recording
// is ever saved: 1.0 keeps none you can see (VF11, QA19).

/// Why a save didn't happen, in the words of the alert.
private struct SaveError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// The panel was closed without saving: nothing to say.
private struct SaveCancelled: Error {}

extension CapturesModel {
    enum SaveKind {
        /// The words and everything taken, in a folder of their own.
        case everything
        /// Every picture taken, into a folder.
        case pictures
        /// One picture, by its attachment's index.
        case picture(Int)
        /// A copy of a file that was taken, by its attachment's index.
        case file(Int)
    }

    /// Oct 15 review, IS04: asks where, with the Mac's own panel, then writes.
    func saveToDisk(_ capture: Capture, _ kind: SaveKind) {
        do {
            switch kind {
            case .everything: try saveEverything(capture)
            case .pictures: try savePictures(capture)
            case .picture(let index): try savePicture(capture, index)
            case .file(let index): try saveCopy(capture, index)
            }
        } catch is SaveCancelled {
            return
        } catch {
            // Oct 18, Ryan: the panels, the alert and the toasts in the primary language. The files
            // written (Words.txt and what's in it) stay as they are.
            saveFailure = SaveFailure(title: L("Couldn't Save “\(Self.fileName(capture.theme))”"),
                                      message: error.localizedDescription)
        }
    }

    // MARK: The four saves

    private func saveEverything(_ capture: Capture) throws {
        let panel = NSSavePanel()
        panel.title = L("Save Everything")
        panel.message = L("A folder with the words and everything taken with them.")
        panel.prompt = L("Save")
        panel.nameFieldStringValue = Self.fileName(capture.theme)
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let folder = panel.url else { throw SaveCancelled() }
        let files = FileManager.default
        if files.fileExists(atPath: folder.path) { try files.removeItem(at: folder) }
        try files.createDirectory(at: folder, withIntermediateDirectories: true)
        try Self.words(capture).write(to: folder.appendingPathComponent(Self.wordsFile), atomically: true, encoding: .utf8)
        for a in capture.attachments {
            switch a.kind {
            case .region:
                if let png = png(a) { try png.write(to: folder.appendingPathComponent(Self.pictureName(a.index) + ".png"), options: .atomic) }
            case .passage:
                break   // in Words.txt
            case .file:
                // A copy where the file still is; the name alone (in Words.txt) where it isn't.
                if let source = Self.original(a) {
                    try files.copyItem(at: source, to: folder.appendingPathComponent(a.text))
                }
            }
        }
        say(L("Saved “\(folder.lastPathComponent)” to \(folder.deletingLastPathComponent().lastPathComponent)"))
    }

    private func savePictures(_ capture: Capture) throws {
        let regions = capture.attachments.filter { $0.kind == .region }
        let panel = NSOpenPanel()
        panel.title = L("Save Pictures")
        panel.message = regions.count == 1 ? L("Choose a folder for the picture.") : L("Choose a folder for the \(regions.count) pictures.")
        panel.prompt = L("Save Here")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let folder = panel.url else { throw SaveCancelled() }
        var saved = 0
        for a in regions {
            guard let png = png(a) else { continue }
            let url = Self.unique(folder.appendingPathComponent("\(Self.fileName(capture.theme)) \(a.index).png"))
            try png.write(to: url, options: .atomic)
            saved += 1
        }
        guard saved > 0 else { throw SaveError(message: L("Fovea couldn't find the pictures taken with this capture.")) }
        say(saved == 1 ? L("Saved 1 picture to \(folder.lastPathComponent)") : L("Saved \(saved) pictures to \(folder.lastPathComponent)"))
    }

    private func savePicture(_ capture: Capture, _ index: Int) throws {
        guard let a = capture.attachments.first(where: { $0.index == index }), let png = png(a) else {
            throw SaveError(message: L("Fovea couldn't find this picture."))
        }
        let panel = NSSavePanel()
        panel.title = L("Save Picture")
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(Self.fileName(capture.theme)) \(index).png"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { throw SaveCancelled() }
        try png.write(to: url, options: .atomic)
        say(L("Saved the picture to \(url.deletingLastPathComponent().lastPathComponent)"))
    }

    private func saveCopy(_ capture: Capture, _ index: Int) throws {
        guard let a = capture.attachments.first(where: { $0.index == index }) else { throw SaveCancelled() }
        // Fovea keeps a file's name and folder, not the file: a copy comes from where it still is.
        guard let source = Self.original(a) else {
            throw SaveError(message: L("“\(a.text)” isn't in \(a.source) any more. Fovea keeps a file's name, not the file itself."))
        }
        let panel = NSSavePanel()
        panel.title = L("Save a Copy")
        panel.nameFieldStringValue = a.text
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { throw SaveCancelled() }
        let files = FileManager.default
        if files.fileExists(atPath: url.path) { try files.removeItem(at: url) }
        try files.copyItem(at: source, to: url)
        say(L("Saved a copy of \(a.text) to \(url.deletingLastPathComponent().lastPathComponent)"))
    }

    // MARK: What's written

    /// A picture's PNG: the file Fovea kept (`media:`), or the region cut from its screen.
    private func png(_ a: Attachment) -> Data? {
        if let url = media?.url(for: a.art), a.crop == .full, let data = try? Data(contentsOf: url) { return data }
        guard let image = Art.region(a), let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    /// The words, as a person would read them: what it is, when, where it went, then the words
    /// and the passages quoted.
    static func words(_ c: Capture) -> String {
        var lines = [c.theme, ""]
        var meta = "\(c.kind.title) · \(Lines.day(c.time)), \(Lines.time(c.time))"
        if c.kind == .dispatch, let d = c.destination { meta += " · \(d.agent), “\(d.chat)”" } else { meta += " · \(c.target)" }
        lines.append(meta)
        lines.append("")
        lines.append(c.text)
        let passages = c.attachments.filter { $0.kind == .passage }
        let files = c.attachments.filter { $0.kind == .file }
        let pictures = c.attachments.filter { $0.kind == .region }
        if !passages.isEmpty || !files.isEmpty || !pictures.isEmpty {
            lines += ["", L("Taken with it:")]
            for a in c.attachments.sorted(by: { $0.index < $1.index }) {
                switch a.kind {
                case .region: lines.append("\(a.index). " + L("\(pictureName(a.index)).png, from \(a.source)"))
                case .passage: lines.append("\(a.index). " + L("From \(a.source):") + "\n   “\(a.text)”")
                case .file: lines.append("\(a.index). " + L("\(a.text), in \(a.source)"))
                }
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Oct 18, Ryan: the folder's files are named in the primary language too ("Words.txt",
    /// "Picture 1.png"; "文字.txt", "图片 1.png"), and Words.txt names each picture as it's saved.
    static var wordsFile: String { L("Words (a file's name)", english: "Words") + ".txt" }
    static func pictureName(_ index: Int) -> String { L("Picture \(index)") }

    /// Where a taken file still is: its folder as an absolute path, or a folder in your home
    /// (Desktop, Downloads, Documents).
    static func original(_ a: Attachment) -> URL? {
        guard a.kind == .file else { return nil }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let folders = [URL(fileURLWithPath: (a.source as NSString).expandingTildeInPath),
                       home.appendingPathComponent(a.source),
                       home.appendingPathComponent("Desktop"), home.appendingPathComponent("Downloads"),
                       home.appendingPathComponent("Documents")]
        return folders.map { $0.appendingPathComponent(a.text) }.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// A name a file can have: no slashes or colons.
    static func fileName(_ s: String) -> String {
        let cleaned = s.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // A card is a 记录 in Chinese; "Capture" alone is Settings' verb (截取), so a key of its own.
        return cleaned.isEmpty ? L("Capture (a file's name)", english: "Capture") : cleaned
    }

    /// The URL, or the same with " 2", " 3"… before its extension if one is there.
    static func unique(_ url: URL) -> URL {
        let files = FileManager.default
        guard files.fileExists(atPath: url.path) else { return url }
        let base = url.deletingPathExtension().lastPathComponent, ext = url.pathExtension
        let folder = url.deletingLastPathComponent()
        for n in 2... {
            let next = folder.appendingPathComponent("\(base) \(n)").appendingPathExtension(ext)
            if !files.fileExists(atPath: next.path) { return next }
        }
        return url
    }
}
