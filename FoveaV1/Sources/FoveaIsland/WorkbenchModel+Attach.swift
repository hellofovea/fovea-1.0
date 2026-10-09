import SwiftUI
import AppKit
import UniformTypeIdentifiers

// Capture mode takes three things (left Option on either voice bar: a click turns it on, or hold
// it): a region of the screen
// (a drag, as before), the text of a passage (a click on it), or a file (a click on it on the
// desktop). The text and the file are drawn as cards, so all three ride the same referent stack,
// flights, fans and looks closer.

/// A file on the mock desktop.
struct DesktopFile: Identifiable, Equatable {
    let name: String
    let size: String
    var id: String { name }

    var icon: NSImage {
        let ext = (name as NSString).pathExtension
        return NSWorkspace.shared.icon(for: UTType(filenameExtension: ext) ?? .data)
    }

    static let all = [
        DesktopFile(name: "Launch plan.pdf", size: "2.1 MB"),
        DesktopFile(name: "ears-spec.md", size: "4 KB"),
        DesktopFile(name: "Q3 numbers.xlsx", size: "88 KB"),
    ]
}

extension WorkbenchModel {
    /// ⌘ pressed twice on a voice bar: the whole screen, attached. (The two presses turned capture
    /// mode on and off again, so it is as it was.)
    /// Nothing of Fovea is in it: the island, its pulled-out chats and capture mode's marks are
    /// hidden while the screen is taken, as a real capture leaves out its own app's windows.
    func captureWholeScreen() {
        guard notchState.collects else { return }
        Task { await takeWholeScreen() }
    }

    func takeWholeScreen() async {
        if let live {
            await liveWholeScreen(live)
            return
        }
        hidingOwnSurfaces = true
        try? await Task.sleep(for: WorkbenchTokens.Capture.clearDelay)
        let image = windowImage(displayRect: display.frame)
        hidingOwnSurfaces = false
        guard let image, notchState.collects else { return }
        add(image: image, from: display.frame.insetBy(dx: 40, dy: 40), animated: !snapshotMode, kind: .screenshot)
    }

    /// A click while picking (⌘): on a passage of the page, its text; on a desktop file, the file.
    /// Returns whether it took something.
    func captureClick(at point: CGPoint) -> Bool {
        guard capturing || highlighting, live == nil else { return false }
        for file in DesktopFile.all {
            if let rect = agentAnchors["desktop.\(file.name)"], rect.contains(point) {
                attachFile(file, from: rect)
                return true
            }
        }
        guard screenContent == .fullScreenApp else { return false }
        let passages = ArticlePage.passages
        for (name, text) in passages {
            if let rect = agentAnchors["article.\(name)"], rect.contains(point) {
                attachText(text, from: rect)
                return true
            }
        }
        return false
    }

    /// The passage's text, as a card; the passage flashes as it is taken.
    func attachText(_ text: String, from rect: CGRect, animated: Bool = true) {
        guard let image = AttachmentCards.text(text) else { return }
        capturedFlash = rect.insetBy(dx: -4, dy: -3)
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(380))
            self?.capturedFlash = nil
        }
        add(image: image, from: rect, animated: animated, kind: .text(text))
    }

    /// The file, as a card.
    func attachFile(_ file: DesktopFile, from rect: CGRect, animated: Bool = true) {
        guard let image = AttachmentCards.file(file) else { return }
        add(image: image, from: rect, animated: animated, kind: .file(name: file.name, size: file.size))
    }
}

/// The cards text and files are drawn as.
@MainActor
enum AttachmentCards {
    private static var cache: [String: NSImage] = [:]

    static func text(_ text: String) -> NSImage? {
        if let hit = cache["t:" + text] { return hit }
        let image = render(TextCardView(text: text), size: CGSize(width: 260, height: 150))
        cache["t:" + text] = image
        return image
    }

    static func file(_ file: DesktopFile) -> NSImage? {
        if let hit = cache["f:" + file.name] { return hit }
        let image = render(FileCardView(file: file), size: CGSize(width: 220, height: 150))
        cache["f:" + file.name] = image
        return image
    }

    private static func render<V: View>(_ view: V, size: CGSize) -> NSImage? {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 2
        return renderer.nsImage
    }
}

/// A passage of text, taken: a quote mark and the words on paper.
struct TextCardView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "text.quote")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 0.25, green: 0.45, blue: 0.85))
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(Color(white: 0.15))
                .lineSpacing(2)
                .lineLimit(5)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.99, green: 0.985, blue: 0.97))
        .environment(\.colorScheme, .light)
    }
}

/// A file, taken: its icon, its name, its size.
struct FileCardView: View {
    let file: DesktopFile

    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: file.icon)
                .resizable()
                .frame(width: 64, height: 64)
            VStack(spacing: 2) {
                Text(file.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(white: 0.12))
                Text(file.size).font(.system(size: 11)).foregroundStyle(Color(white: 0.45))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.97))
        .environment(\.colorScheme, .light)
    }
}

/// The desktop's files, in a column at its right, as macOS lays them out. They report where they
/// are, so capture mode can take one.
struct DesktopFiles: View {
    let model: WorkbenchModel

    var body: some View {
        VStack(spacing: 18) {
            ForEach(DesktopFile.all) { file in
                VStack(spacing: 4) {
                    Image(nsImage: file.icon)
                        .resizable()
                        .frame(width: 48, height: 48)
                    Text(file.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                        .lineLimit(1)
                }
                .frame(width: 92)
                .agentAnchor(file.name)
                .help(model.capturing ? "Click to attach \(file.name)" : file.name)
            }
        }
        .environment(\.agentAnchorReporter, AgentAnchorReporter { name, rect in model.agentAnchors["desktop.\(name)"] = rect })
    }
}
