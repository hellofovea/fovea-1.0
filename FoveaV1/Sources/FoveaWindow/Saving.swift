import AppKit
import SwiftUI
import UniformTypeIdentifiers
import CapturesCore
import FoveaKit

// Oct 15 review, IS04: Save writes real files. Oct 21, Ryan: the expanded card's Save is one
// click: the words as a .txt, or a folder named for them (the words, the pictures, the passages,
// copies of the files that are still there); Save Picture… and Save a Copy… one file each. A
// save that fails says so in an alert, the Mac's own, with what went wrong. No recording is ever
// saved: 1.0 keeps none you can see (VF11, QA19).

/// Why a save didn't happen, in the words of the alert.
private struct SaveError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// The panel was closed without saving: nothing to say.
private struct SaveCancelled: Error {}

extension CapturesModel {
    enum SaveKind {
        /// Oct 21, Ryan: the expanded card's Save (one click, ⌘S): the words as a .txt named from
        /// their first words; with what you took, a folder named the same with the words
        /// (Words.txt, the passages quoted in it), each picture as a PNG and each file still on this
        /// Mac copied. Suggested in Downloads.
        case capture
        /// One picture, by its attachment's index.
        case picture(Int)
        /// A copy of a file that was taken, by its attachment's index.
        case file(Int)
    }

    /// Oct 15 review, IS04: asks where, with the Mac's own panel, then writes.
    func saveToDisk(_ capture: Capture, _ kind: SaveKind) {
        do {
            switch kind {
            case .capture:
                try saveCapture(capture)
                flashConfirmed(\.savedID, capture.id)
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

    // MARK: The saves

    /// Oct 21, Ryan: "make sure copy, download and delete all work as expected, and design the
    /// according experiences." Save asks where with the Mac's panel (in Downloads to start), writes,
    /// then says where in a toast with Show in Finder. Cancel does nothing; a failure is an alert
    /// that says why (`saveToDisk`).
    private func saveCapture(_ capture: Capture) throws {
        let taken = !capture.attachments.isEmpty
        let name = Self.fileName(Self.firstWords(capture))
        let panel = NSSavePanel()
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        panel.canCreateDirectories = true
        panel.prompt = L("Save")
        if taken {
            panel.title = L("Save Capture")
            panel.message = L("A folder with the words and what you took with them.")
            panel.nameFieldStringValue = name
        } else {
            panel.title = L("Save Words")
            panel.allowedContentTypes = [.plainText]
            panel.nameFieldStringValue = name + ".txt"
        }
        guard let url = savePanelOverride.map({ $0(panel.nameFieldStringValue) })
                ?? (panel.runModal() == .OK ? panel.url : nil) else { throw SaveCancelled() }
        let files = FileManager.default
        if taken {
            if files.fileExists(atPath: url.path) { try files.removeItem(at: url) }
            try files.createDirectory(at: url, withIntermediateDirectories: true)
            try writeEverything(capture, into: url)
        } else {
            try Self.words(capture).write(to: url, atomically: true, encoding: .utf8)
        }
        let place = files.displayName(atPath: url.deletingLastPathComponent().path)
        say(L("Saved to \(place)"), action: ToastAction(title: L("Show in Finder")) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        })
    }

    /// The words (Words.txt, the passages quoted in it), each picture as a PNG and a copy of each
    /// file still on this Mac, into a folder that's there.
    private func writeEverything(_ capture: Capture, into folder: URL) throws {
        let files = FileManager.default
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

    // MARK: Copy

    /// Oct 21, Ryan: what Copy puts on the pasteboard, in one write, as Notes, Mail, Messages and
    /// Slack paste it: first the words as text, with the passages you took quoted under them and
    /// the names of files that aren't on this Mac any more; then each picture as an image (PNG and
    /// TIFF) and each file still here as itself (its URL), in the order you took them. An app
    /// that takes only text pastes the words.
    func pasteboardItems(_ capture: Capture) -> [NSPasteboardWriting] {
        var text = capture.text
        var after: [NSPasteboardWriting] = []
        var notes: [String] = []
        for a in capture.attachments.sorted(by: { $0.index < $1.index }) {
            switch a.kind {
            case .passage:
                notes.append(Self.quoted(a))
            case .region:
                guard let png = png(a) else { continue }
                let item = NSPasteboardItem()
                item.setData(png, forType: .png)
                if let tiff = NSImage(data: png)?.tiffRepresentation { item.setData(tiff, forType: .tiff) }
                after.append(item)
            case .file:
                if let url = Self.original(a) { after.append(url as NSURL) } else { notes.append(L("\(a.text), in \(a.source)")) }
            }
        }
        if !notes.isEmpty { text += "\n\n" + notes.joined(separator: "\n\n") }
        let words = NSPasteboardItem()
        words.setString(text, forType: .string)
        return [words] + after
    }

    /// A passage you took, quoted, and where from: “…” — Safari.
    static func quoted(_ a: Attachment) -> String { L("“\(a.text)” — \(a.source)") }

    /// A name from the words' first few: the first sentence, up to its first comma in a language
    /// written without spaces (at least six characters), or its first six words; never more than
    /// 48 characters. The capture's title when there are no words yet.
    static func firstWords(_ c: Capture) -> String {
        let line = c.text.split(whereSeparator: \.isNewline).first.map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        guard !line.isEmpty, !c.failed else { return c.theme }
        let sentence = line.split(whereSeparator: { ".:;!?。：；！？".contains($0) }).first.map(String.init) ?? line
        let spaceless = sentence.unicodeScalars.contains { (0x3040...0x9FFF).contains($0.value) }
        var name: String
        if spaceless {
            let clause = sentence.split(whereSeparator: { "，、,".contains($0) }).first.map(String.init) ?? sentence
            name = clause.count >= 6 ? clause : sentence
            if name.count > 24 { name = String(name.prefix(24)) }
        } else {
            name = sentence.split(separator: " ").prefix(6).joined(separator: " ")
        }
        if name.count > 48 { name = String(name.prefix(48)) }
        let trimmed = name.trimmingCharacters(in: CharacterSet(charactersIn: " ,-—–，、").union(.whitespaces))
        return trimmed.isEmpty ? c.theme : trimmed
    }

    // MARK: What's written

    /// A picture's PNG: the file Fovea kept (`media:`), or the region cut from its screen.
    func png(_ a: Attachment) -> Data? {
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
