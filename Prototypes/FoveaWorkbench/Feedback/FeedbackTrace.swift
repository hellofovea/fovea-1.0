import SwiftUI
import AppKit

/// `FoveaWorkbench --trace=<tab>[:<stage>] [--seconds=15]`: stages a Feedback tab as the panel does and
/// prints the island's state twice a second, then quits. For chasing what a tab does over time.
@MainActor
enum FeedbackTrace {
    /// Until the window is up and its pages have laid out (up to 6 s).
    static func waitForWindow() async {
        if CommandLine.arguments.contains("--menus") {
            try? await Task.sleep(for: .seconds(2))
            for item in NSApp.mainMenu?.items ?? [] {
                print("MENU", item.title, (item.submenu?.items ?? []).map { "\($0.title)[\($0.action.map { NSStringFromSelector($0) } ?? "-")]" })
            }
            print("WINDOWS", NSApp.windows.map { "\($0.title)|\($0.isVisible)|\(type(of: $0))" })
        }
        for _ in 0..<60 {
            if NSApp.windows.contains(where: { $0.styleMask.contains(.titled) && $0.isVisible }) { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        try? await Task.sleep(for: .milliseconds(600))
    }

    /// `--render-board=<dir>`: the control board in every design, rendered off screen (for when the
    /// screen is locked and the window can't be captured), then quits. The island over a gray
    /// display, at the display's size.
    static func renderBoards(model: WorkbenchModel, to dir: URL) async {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        model.offscreenRender = true
        for density in PanelDensity.allCases {
            model.density = density
            for style in BoardStyle.allCases {
                model.boardStyle = style
                model.stageFeedback(.progress)
                try? await Task.sleep(for: .milliseconds(300))
                let size = model.display.frame.size
                let view = ZStack(alignment: .top) {
                    Color(white: 0.55)
                    MockIsland(model: model)
                    V2CapsuleBoard(model: model)
                }
                .frame(width: size.width, height: min(size.height, 640))
                .environment(\.colorScheme, .dark)
                // Off screen, glass has nothing behind it: the material it falls back to.
                .environment(\.liquidGlass, false)
                .environment(\.displayScheme, model.appearance.colorScheme ?? .dark)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff), let data = rep.representation(using: .png, properties: [:]) {
                    let name = "board-\(style.rawValue)\(density == .compact ? "-compact" : "").png"
                    try? data.write(to: dir.appendingPathComponent(name))
                    print("wrote \(name)")
                }
            }
        }
    }

    static func runIfRequested(model: WorkbenchModel) {
        let args = CommandLine.arguments
        if let flag = args.first(where: { $0.hasPrefix("--render-creatures=") }) {
            let dir = URL(fileURLWithPath: String(flag.dropFirst("--render-creatures=".count)), isDirectory: true)
            Task { @MainActor in
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let renderer = ImageRenderer(content: CreatureSheet())
                renderer.scale = 2
                if let image = renderer.nsImage, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                   let data = rep.representation(using: .png, properties: [:]) {
                    try? data.write(to: dir.appendingPathComponent("creatures.png"))
                    print("wrote creatures.png")
                }
                NSApp.terminate(nil)
            }
            return
        }
        if let flag = args.first(where: { $0.hasPrefix("--render-native=") }) {
            let dir = URL(fileURLWithPath: String(flag.dropFirst("--render-native=".count)), isDirectory: true)
            Task { @MainActor in
                await waitForWindow()
                await renderNative(model: model, to: dir)
                NSApp.terminate(nil)
            }
            return
        }
        if let flag = args.first(where: { $0.hasPrefix("--render-pets=") }) {
            let dir = URL(fileURLWithPath: String(flag.dropFirst("--render-pets=".count)), isDirectory: true)
            Task { @MainActor in
                await waitForWindow()
                await renderPets(model: model, to: dir)
                NSApp.terminate(nil)
            }
            return
        }
        if let flag = args.first(where: { $0.hasPrefix("--render-board=") }) {
            let dir = URL(fileURLWithPath: String(flag.dropFirst("--render-board=".count)), isDirectory: true)
            Task { @MainActor in
                await waitForWindow()
                await renderBoards(model: model, to: dir)
                NSApp.terminate(nil)
            }
            return
        }
        // `--v2=<state>`: opens on one of Dispatch Version 2's states (the panel's list: chat, whole,
        // wholeLong, pulled…) and stays.
        if let flag = args.first(where: { $0.hasPrefix("--v2=") }) {
            let name = String(flag.dropFirst("--v2=".count))
            Task { @MainActor in
                await waitForWindow()
                if let mode = V2Mode(rawValue: name) { model.v2Selection = mode } else { print("no such state: \(name)") }
            }
            return
        }
        // `--stage=<tab>[:<stage>]`: opens on that tab and stays (for watching it from outside). The
        // value rides inside the flag: a bare word would be taken for a file to open, and the window
        // would not open at launch.
        if let flag = args.first(where: { $0.hasPrefix("--stage=") }) {
            let parts = flag.dropFirst("--stage=".count).split(separator: ":").map(String.init)
            Task { @MainActor in
                await waitForWindow()
                if parts.count > 1 {
                    if let s = CountdownStage(rawValue: parts[1]) { model.feedbackCountdownStage = s }
                    if let s = SelectStage(rawValue: parts[1]) { model.feedbackSelectStage = s }
                    if let s = WorkStage(rawValue: parts[1]) { model.feedbackWorkStage = s }
                    if let s = BoardStyle(rawValue: parts[1]) { model.boardStyle = s }
                }
                if let item = FeedbackItem(rawValue: parts[0]) { model.stageFeedback(item) }
            }
            return
        }
        guard let flag = args.first(where: { $0.hasPrefix("--trace=") }) else { return }
        let parts = flag.dropFirst("--trace=".count).split(separator: ":").map(String.init)
        guard let item = FeedbackItem(rawValue: parts[0]) else { print("no such tab: \(parts[0])"); NSApp.terminate(nil); return }
        let seconds = args.first(where: { $0.hasPrefix("--seconds=") }).flatMap { Double($0.dropFirst("--seconds=".count)) } ?? 15
        Task { @MainActor in
            await waitForWindow()
            if parts.count > 1 {
                if let s = CountdownStage(rawValue: parts[1]) { model.feedbackCountdownStage = s }
                if let s = SelectStage(rawValue: parts[1]) { model.feedbackSelectStage = s }
            }
            model.stageFeedback(item)
            let start = Date()
            let shots = args.first(where: { $0.hasPrefix("--trace-shots=") }).map { URL(fileURLWithPath: String($0.dropFirst("--trace-shots=".count))) }
            if let shots { try? FileManager.default.createDirectory(at: shots, withIntermediateDirectories: true) }
            var tick = 0
            while Date().timeIntervalSince(start) < seconds {
                if let shots, tick % 4 == 0, let window = NSApp.windows.first(where: { $0.styleMask.contains(.titled) }),
                   let rep = WorkbenchSnapshots.composited(window), let data = rep.representation(using: .png, properties: [:]) {
                    try? data.write(to: shots.appendingPathComponent(String(format: "t%02d.png", tick / 2)))
                }
                tick += 1
                let t = Date().timeIntervalSince(start)
                let layout = model.stackLayout
                let left = model.recordingRemaining(at: Date()).map { String(format: "%.1f", $0) } ?? "-"
                print(String(format: "%5.1f s", t), model.notchState.rawValue, "lastMinute:\(model.inLastMinute)", "left:\(left)",
                      "wave:\(Int(layout.waveform.x))", "outline:\(Int(layout.outline.size.width))x\(Int(layout.outline.size.height))",
                      "refs:\(model.referents.count)", "marks:\(model.highlights.count)", "hl:\(model.highlighting)", "anchors:\(model.agentAnchors.keys.filter { $0.hasPrefix("article.") }.count)", "flow:\(String(describing: model.restingFlow))", "windows:\(NSApp.windows.filter { $0.isVisible }.count)", "keys:\(model.agentAnchors.keys.sorted().prefix(4))", "screen:\(model.screenContent.rawValue)", "tab:\(model.selectedTab)")
                try? await Task.sleep(for: .milliseconds(500))
            }
            NSApp.terminate(nil)
        }
    }
}
