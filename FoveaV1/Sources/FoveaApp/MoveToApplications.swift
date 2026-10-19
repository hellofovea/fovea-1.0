import AppKit
import FoveaKit

// Where Fovea runs from (Oct 15 review, NH-06): opened from Downloads or straight from its disk
// image, it offers to move itself to Applications, where it can update itself and open at login,
// as Mac apps downloaded from the web do. Asked once per place; "Don't ask again" means never.
// A copy built in a project folder is left alone (that's development, not someone's download).

@MainActor
enum MoveToApplications {
    private static let declinedKey = "fovea.moveToApplications.declined"

    /// Where the running app is, if it's somewhere it should offer to leave.
    static var strayLocation: URL? {
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        let url = Bundle.main.bundleURL.resolvingSymlinksInPath()
        let path = url.path
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? "~/Downloads"
        let stray = path.hasPrefix("/Volumes/") || path.hasPrefix(downloads) || path.contains("/AppTranslocation/")
        return stray ? url : nil
    }

    static func offerIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: declinedKey), let from = strayLocation else { return }
        ask(from: from, simulated: false)
    }

    /// The question, as it appears. `simulated` (the Review menu): nothing is moved.
    static func ask(from: URL?, simulated: Bool) {
        let alert = NSAlert()
        alert.messageText = L("Move Fovea to your Applications folder?")
        let place = from.map { ($0.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath } ?? L("Downloads")
        alert.informativeText = L("From Applications, Fovea can update itself and open when you log in. It's running from \(place) now.")
        alert.addButton(withTitle: L("Move to Applications"))
        alert.addButton(withTitle: L("Not Now"))
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = L("Don't ask again")
        NSApp.activate(ignoringOtherApps: true)
        let answer = alert.runModal()
        if alert.suppressionButton?.state == .on, !simulated { UserDefaults.standard.set(true, forKey: declinedKey) }
        guard answer == .alertFirstButtonReturn, !simulated, let from else { return }
        move(from)
    }

    /// Copies the app into /Applications (replacing an older copy, which goes to the Trash), opens
    /// the copy and quits this one. The copy that was run is left where it is.
    private static func move(_ from: URL) {
        let to = URL(fileURLWithPath: "/Applications").appendingPathComponent(from.lastPathComponent)
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: to.path) { try fm.trashItem(at: to, resultingItemURL: nil) }
            try fm.copyItem(at: from, to: to)
        } catch {
            let failed = NSAlert()
            failed.messageText = L("Fovea couldn't move itself")
            failed.informativeText = L("Drag Fovea into your Applications folder in Finder, then open it from there.") + "\n\n" + error.localizedDescription
            failed.addButton(withTitle: L("OK"))
            failed.runModal()
            return
        }
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = ["-n", to.path]
        try? open.run()
        NSApp.terminate(nil)
    }
}
