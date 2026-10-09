import SwiftUI
import AppKit

// `--render-native=<dir>`: the Native design's island and panels in Light and Dark, drawn off
// screen, then quits (docs/island/NATIVE.md). For when the screen is locked and the window can't be
// captured: off screen there is nothing behind the glass to take its color from, so the panels are
// drawn in their fallback (a solid of the glass's tone). The window's snapshots (`--snapshot`, the
// `native-` shots) are the real thing.

extension FeedbackTrace {
    static func renderNative(model: WorkbenchModel, to dir: URL) async {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        model.offscreenRender = true
        model.design = .native
        let states: [(String, (WorkbenchModel) -> Void)] = [
            ("voice", { $0.voiceflowSelection = .voiceFlow }),
            ("transcribing", { $0.voiceflowSelection = .transcribing }),
            ("paste", { $0.voiceflowSelection = .pasteNotFound }),
            ("error", { $0.stageFeedback(.errors) }),
            ("v2-voice", { $0.v2Selection = .voice }),
            ("v2-send", { $0.v2Selection = .send }),
            ("v2-board", { $0.boardStyle = .sections; $0.v2Selection = .board }),
            ("v2-board-badges", { $0.boardStyle = .badges; $0.stageFeedback(.progress) }),
            ("v2-board-wings", { $0.boardStyle = .wings; $0.stageFeedback(.progress) }),
            ("v2-board-desk", { $0.boardStyle = .petDesk; $0.stageFeedback(.progress) }),
            ("v2-board-capsules", { $0.boardStyle = .capsules; $0.stageFeedback(.progress) }),
            ("v2-chat", { $0.v2Selection = .chat }),
            ("v2-whole", { $0.v2Selection = .whole }),
        ]
        for appearance in [MockAppearance.light, .dark] {
            model.appearance = appearance
            for (name, stage) in states {
                model.resetFeedback()
                model.boardStyle = .sections
                stage(model)
                try? await Task.sleep(for: .milliseconds(450))
                let size = model.display.frame.size
                let scheme = appearance.colorScheme ?? .light
                let height = min(size.height, 760)
                let view = ZStack(alignment: .top) {
                    WallpaperView(fill: model.wallpaperFill)
                        .frame(width: size.width, height: height)
                        .clipped()
                    V2DetachedLayer(model: model)
                    MockIsland(model: model)
                    PetAtRest(model: model)
                    V2CapsuleBoard(model: model)
                }
                .frame(width: size.width, height: height, alignment: .top)
                .clipped()
                .environment(\.colorScheme, scheme)
                .environment(\.displayScheme, scheme)
                .environment(\.liquidGlass, false)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff), let data = rep.representation(using: .png, properties: [:]) {
                    let file = "native-\(appearance.rawValue)-\(name).png"
                    try? data.write(to: dir.appendingPathComponent(file))
                    print("wrote \(file)")
                }
            }
        }
    }
}
