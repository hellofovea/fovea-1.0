import AppKit
import SwiftUI
import CapturesCore
import FoveaKit

// Oct 21, Ryan: "make sure all the buttons here actually do their functions ... Make sure copy,
// download and delete all work as expected." `Fovea --design-shots window <dir> --data-dir=<dir>
// --smoke-detail` opens a capture's expanded card and does each thing its bar does, then reads
// the result back:
// - Copy: the pasteboard holds the words (with the passage quoted), the picture and the file;
//   the button turns into a checkmark and back; ⌘C (Edit › Copy) copies it too.
// - Save: a folder with Words.txt, the picture and the file; words alone as a .txt; a save that
//   can't be written is an alert that says why; the toast offers Show in Finder; ⌘S saves.
// - Delete: the card leaves the window, the store and the calendar; Undo puts it back where it
//   was; Undo before the card has left keeps it; ⌘⌫ deletes.
// It prints PASS or FAIL per check. It writes only under <dir> and to a pasteboard of its own,
// and it refuses to run without a data folder of its own.

extension HomeWindowController {
    func detailSmoke(_ dir: URL) async {
        var failures = 0
        func check(_ ok: Bool, _ what: String) {
            print(ok ? "PASS" : "FAIL", what)
            if !ok { failures += 1 }
        }
        func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
        guard CommandLine.arguments.contains(where: { $0.hasPrefix("--data-dir") }) else {
            print("FAIL --smoke-detail needs a --data-dir of its own")
            return
        }
        // The window's own menu, as the App installs it in use (pictures run without it).
        NSApp.mainMenu = mainMenu(quit: #selector(NSApplication.terminate(_:)), quitTarget: NSApp)
        let m = model
        let board = NSPasteboard(name: .init("app.fovea.smoke-detail"))
        m.pasteboard = board
        let out = dir.appendingPathComponent("smoke-detail")
        let files = FileManager.default
        try? files.removeItem(at: out)
        try? files.createDirectory(at: out, withIntermediateDirectories: true)

        // A capture with a picture and a passage, and a file written here so a copy can be made.
        let typical = Fixtures.library(.typical).captures
        guard var c = typical.first(where: { c in !c.failed && c.attachments.contains { $0.kind == .region } }),
              var plain = typical.first(where: { !$0.failed && $0.attachments.isEmpty }) else {
            print("FAIL no fixture capture with a picture")
            return
        }
        var next = (c.attachments.map(\.index).max() ?? 0) + 1
        if !c.attachments.contains(where: { $0.kind == .passage }) {
            c.attachments.append(Attachment(next, .passage, anchor: 0, text: "Ship the notch first.", source: "Notes"))
            next += 1
        }
        let noteName = "Smoke notes.txt"
        try? "Notes for the smoke.".write(to: out.appendingPathComponent(noteName), atomically: true, encoding: .utf8)
        c.id = "smoke-rich"
        plain.id = "smoke-plain"
        c.time = Date()
        plain.time = Date().addingTimeInterval(-60)
        c.attachments.append(Attachment(next, .file, anchor: 0, text: noteName, fileType: "txt", source: out.path))
        m.show(.captures)
        m.library.captures.removeAll { $0.id.hasPrefix("smoke-") }
        m.library.captures.insert(contentsOf: [c, plain], at: 0)
        await wait(0.6)
        check(stores.captures.captures.contains { $0.id == c.id }, "the smoke's captures are in the store")

        // MARK: Copy
        m.open(c.id)
        await wait(0.8)
        check(m.detailID == c.id && m.detailProgress == 1, "the expanded card is open")
        shoot("smoke-detail-bar", out)
        m.copy(c)
        let items = board.pasteboardItems ?? []
        let passage = c.attachments.first { $0.kind == .passage }!
        let words = items.first?.string(forType: .string) ?? ""
        check(words.hasPrefix(c.text), "Copy: the first item is the words")
        check(words.contains("“\(passage.text)”"), "Copy: the passage is quoted under them")
        check(items.contains { $0.types.contains(.png) && $0.types.contains(.tiff) }, "Copy: the picture as PNG and TIFF")
        let urls = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        check(urls.contains { $0.lastPathComponent == noteName }, "Copy: the file as itself")
        check(m.copiedID == c.id, "Copy: the button shows the checkmark")
        await wait(0.3)
        shoot("smoke-detail-copied", out)
        await wait(T.Motion.copiedHold + 0.3)
        check(m.copiedID == nil, "Copy: and turns back into Copy")
        board.clearContents()
        // ⌘C reaches the card only while its window holds the keyboard, as it does in use.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        await wait(0.3)
        print("key window:", window.isKeyWindow, "· first responder:", window.firstResponder.map { String(describing: type(of: $0)) } ?? "none")
        let commandC = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
                                        windowNumber: window.windowNumber, context: nil, characters: "c",
                                        charactersIgnoringModifiers: "c", isARepeat: false, keyCode: 8)!
        let copyItem = NSApp.mainMenu?.items.compactMap(\.submenu).flatMap(\.items).first { $0.keyEquivalent == "c" && $0.keyEquivalentModifierMask == .command }
        print("Edit › Copy:", copyItem.map { "\($0.title) → \(NSStringFromSelector($0.action!)) on \(String(describing: $0.target.map { type(of: $0) }))" } ?? "none")
        let handled = NSApp.mainMenu?.performKeyEquivalent(with: commandC) ?? false
        print("⌘C handled by the menu:", handled)
        check((board.pasteboardItems?.first?.string(forType: .string) ?? "").hasPrefix(c.text), "⌘C copies the open card")
        let copyTarget = NSApp.target(forAction: #selector(NSText.copy(_:)), to: nil, from: copyItem) as AnyObject?
        let validates = (copyTarget as? NSUserInterfaceValidations).map { v in copyItem.map { v.validateUserInterfaceItem($0) } ?? false }
        print("copy: goes to", copyTarget.map { String(describing: type(of: $0)) } ?? "nobody", "· validates:", validates.map(String.init) ?? "no validation")
        // Words selected in the card: ⌘C copies just those, as anywhere on the Mac.
        func textViews(_ v: NSView) -> [NSTextView] { (v as? NSTextView).map { [$0] } ?? v.subviews.flatMap(textViews) }
        let texts = window.contentView.map(textViews) ?? []
        print("text views in the window:", texts.map { String(describing: type(of: $0)) })
        if let body = texts.first(where: { $0.string.hasPrefix(String(c.text.prefix(12))) }) {
            window.makeFirstResponder(body)
            body.setSelectedRange(NSRange(location: 0, length: 4))
            board.clearContents()
            _ = NSApp.mainMenu?.performKeyEquivalent(with: commandC)
            let got = board.string(forType: .string) ?? ""
            check(got == (body.string as NSString).substring(with: NSRange(location: 0, length: 4)), "⌘C with words selected copies those (\(got))")
            body.setSelectedRange(NSRange(location: 0, length: 0))
            window.makeFirstResponder(nil)
        } else {
            print("SKIP no text view holds the card's words (SwiftUI draws them itself)")
        }

        // MARK: Save
        var asked: String?
        let folder = out.appendingPathComponent("Saved")
        try? files.createDirectory(at: folder, withIntermediateDirectories: true)
        m.savePanelOverride = { name in asked = name; return folder.appendingPathComponent(name) }
        m.saveToDisk(c, .capture)
        let saved = folder.appendingPathComponent(asked ?? "")
        let wordsFile = saved.appendingPathComponent(CapturesModel.wordsFile)
        check(asked == CapturesModel.fileName(CapturesModel.firstWords(c)), "Save: named from the first words (\(asked ?? "nothing"))")
        let written = (try? String(contentsOf: wordsFile, encoding: .utf8)) ?? ""
        check(written.contains(c.text) && written.contains("“\(passage.text)”"), "Save: Words.txt has the words and the passage")
        let pictures = c.attachments.filter { $0.kind == .region }
        check(pictures.allSatisfy { files.fileExists(atPath: saved.appendingPathComponent(CapturesModel.pictureName($0.index) + ".png").path) },
              "Save: each picture as a PNG")
        check(files.fileExists(atPath: saved.appendingPathComponent(noteName).path), "Save: the file copied")
        check(m.toast == L("Saved to \(files.displayName(atPath: folder.path))") && m.toastAction?.title == L("Show in Finder"),
              "Save: the toast says where, with Show in Finder")
        await wait(0.4)
        shoot("smoke-detail-saved", out)
        asked = nil
        m.saveToDisk(plain, .capture)
        let text = folder.appendingPathComponent(asked ?? "")
        check(text.pathExtension == "txt" && ((try? String(contentsOf: text, encoding: .utf8)) ?? "").contains(plain.text),
              "Save: words alone as a .txt (\(asked ?? "nothing"))")
        m.savePanelOverride = { name in URL(fileURLWithPath: "/System/\(name)") }
        m.saveFailure = nil
        m.saveToDisk(plain, .capture)
        check(m.saveFailure != nil && !(m.saveFailure?.message.isEmpty ?? true), "Save: a failure is an alert that says why")
        m.saveFailure = nil
        m.savePanelOverride = { name in asked = name; return folder.appendingPathComponent("Shortcut " + name) }
        asked = nil
        let commandS = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
                                        windowNumber: window.windowNumber, context: nil, characters: "s",
                                        charactersIgnoringModifiers: "s", isARepeat: false, keyCode: 1)!
        _ = window.performKeyEquivalent(with: commandS)
        await wait(0.3)
        check(asked != nil && files.fileExists(atPath: folder.appendingPathComponent("Shortcut " + (asked ?? "")).path), "⌘S saves the open card")
        m.savePanelOverride = nil

        // MARK: Delete
        let day = Lines.calendar.startOfDay(for: c.time)
        let before = m.dayCounts[day] ?? 0
        let at = m.library.captures.firstIndex { $0.id == c.id }
        m.delete(c.id)
        check(m.toast != nil && m.lastDeleted?.capture.id == c.id, "Delete: the toast offers Undo")
        await wait(0.8)
        shoot("smoke-detail-deleted", out)
        check(m.detailID == nil, "Delete: the expanded card has gone home")
        check(!m.library.captures.contains { $0.id == c.id }, "Delete: the card has left the window")
        check(!stores.captures.captures.contains { $0.id == c.id }, "Delete: and the store")
        check((m.dayCounts[day] ?? 0) == before - 1, "Delete: the calendar counts one fewer")
        // ⌘Z, the toast's Undo.
        let commandZ = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
                                        windowNumber: window.windowNumber, context: nil, characters: "z",
                                        charactersIgnoringModifiers: "z", isARepeat: false, keyCode: 6)!
        _ = window.performKeyEquivalent(with: commandZ)
        await wait(0.6)
        check(m.library.captures.firstIndex { $0.id == c.id } == at, "Undo (⌘Z): back where it was")
        check(stores.captures.captures.contains { $0.id == c.id }, "Undo: and in the store")
        check((m.dayCounts[day] ?? 0) == before, "Undo: the calendar counts it again")
        // Undone before its card has left: it stays, once.
        m.open(c.id)
        await wait(0.8)
        m.delete(c.id)
        await wait(0.05)
        m.undoDelete()
        await wait(0.8)
        check(m.library.captures.filter { $0.id == c.id }.count == 1, "Undo mid-way: still there, once")
        // ⌘⌫ with the card open.
        m.open(c.id)
        await wait(0.8)
        let commandDelete = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
                                             windowNumber: window.windowNumber, context: nil, characters: "\u{8}",
                                             charactersIgnoringModifiers: "\u{8}", isARepeat: false, keyCode: 51)!
        _ = window.performKeyEquivalent(with: commandDelete)
        await wait(0.8)
        check(!m.library.captures.contains { $0.id == c.id }, "⌘⌫ deletes the open card")

        // Gone again, both of them.
        m.library.captures.removeAll { $0.id.hasPrefix("smoke-") }
        m.lastDeleted = nil
        m.pasteboard = .general
        board.releaseGlobally()
        await wait(0.4)
        print(failures == 0 ? "detail smoke: all passed" : "detail smoke: \(failures) failed")
    }
}
