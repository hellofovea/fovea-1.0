import SwiftUI
import AppKit
import FoveaCore

// The smoke run's checks for the Native design (docs/island/NATIVE.md): the tab, the surface's shapes
// with the panels attached and floating, the inks, the hover across the gap, the approval's verb,
// the glass's pixels (when the window can be captured), and the same words in both designs.

extension WorkbenchSmoke {
    static func native(model: WorkbenchModel, window: NSWindow, check rawCheck: (String, Bool, String) -> Void,
                       settle: (NSWindow, TimeInterval) async -> Void) async {
        func check(_ name: String, _ condition: Bool, _ detail: String = "") { rawCheck(name, condition, detail) }
        let spec = WorkbenchTokens.Island.spec
        let notch = NotchGeometry.notchRect(metrics: model.metrics, spec: spec)
        let rest = NotchGeometry.frames(density: .resting, metrics: model.metrics, spec: spec)
        let savedDesign = model.design, savedAppearance = model.appearance, savedPanels = model.nativePanels

        // The tab and the menu.
        model.design = .native
        await settle(window, 0.3)
        let viewMenu = NSApp.mainMenu?.items.first { $0.title == "View" }?.submenu
        let menuItems = viewMenu?.items.map(\.title) ?? []
        check("Native: the tab switches the design, and View has Original Design and Native Design",
              DesignStore.shared.value == .native && menuItems.contains("Original Design") && menuItems.contains("Native Design"),
              menuItems.filter { $0.contains("Design") }.joined(separator: ", "))

        // The inks: white at an opacity in dark, black at it in light; Original's white either way.
        func resolved(_ color: Color, _ scheme: ColorScheme) -> Color.Resolved {
            var env = EnvironmentValues()
            env.colorScheme = scheme
            return color.resolve(in: env)
        }
        let light = resolved(WorkbenchTokens.ink(0.6), .light), dark = resolved(WorkbenchTokens.ink(0.6), .dark)
        check("Native: ink is black at its opacity in light, white in dark",
              light.red < 0.01 && abs(light.opacity - 0.6) < 0.01 && dark.red > 0.99 && abs(dark.opacity - 0.6) < 0.01,
              String(format: "light %.2f a%.2f, dark %.2f a%.2f", light.red, light.opacity, dark.red, dark.opacity))

        // Shapes. Attached (the default): one glass shape hanging from the top edge, Original's
        // outline. Floating: a panel under the resting notch, by the gap; island states have none.
        func shapes(_ stage: () -> Void) async -> (NotchSurfaceKind, NativeShapes, CGFloat, CGFloat) {
            model.resetFeedback()
            model.design = .original
            stage()
            await settle(window, 0.5)
            let original = model.stackLayout.outline.size.height
            model.design = .native
            await settle(window, 0.4)
            return (model.notchSurface, model.nativeShapes, original, model.stackLayout.outline.size.height)
        }
        let panelStates: [(String, () -> Void)] = [
            ("Paste not found", { model.voiceflowSelection = .pasteNotFound }),
            ("Choose chat", { model.v2Selection = .send }),
            ("the control board", { model.boardStyle = .sections; model.v2Selection = .board }),
            ("a session", { model.v2Selection = .chat }),
        ]
        model.nativePanels = .attached
        var attached: [String] = []
        for (name, stage) in panelStates {
            let (kind, s, original, native) = await shapes(stage)
            if !(kind == .panel && s.presence == 0 && abs(s.island.width - s.width) < 0.5
                 && abs(s.island.height - s.height) < 0.5 && abs(native - original) < 0.5) {
                attached.append("\(name): \(kind), presence \(s.presence), \(Int(original)) → \(Int(native))")
            }
        }
        check("Native attached: Paste, Choose chat, the board and a session are one glass shape from the top edge, Original's outline",
              attached.isEmpty && WorkbenchTokens.Native.panelGap == 0, attached.joined(separator: "; "))
        model.nativePanels = .floating
        let gap = WorkbenchTokens.Native.panelGap
        for (name, stage) in panelStates {
            let (kind, s, original, native) = await shapes(stage)
            check("Native floating: \(name) is a panel under the resting notch, its content moved down by the gap",
                  kind == .panel && s.presence == 1 && abs(s.island.width - rest.width) < 0.5
                  && abs(s.island.height - rest.minHeight) < 0.5 && abs(native - original - gap) < 0.5,
                  "\(kind), island \(Int(s.island.width))×\(Int(s.island.height)), \(Int(original)) → \(Int(native))")
        }
        let (voiceKind, voiceShapes, _, _) = await shapes { model.voiceflowSelection = .voiceFlow }
        check("Native floating: the listening bar is all island, no panel",
              voiceKind == .island && voiceShapes.presence == 0 && voiceShapes.island.width == voiceShapes.width)
        let (wingsKind, wingsShapes, _, _) = await shapes { model.boardStyle = .wings; model.stageFeedback(.progress) }
        check("Native floating: Wings keeps its band on the island, the stage in the panel",
              wingsKind == .split && abs(wingsShapes.island.height - notch.height - WorkbenchTokens.Native.bandExtra) < 0.5
              && wingsShapes.presence == 1)
        model.boardStyle = .sections

        // The hover holds across the gap (floating): the pointer between the island and the panel
        // keeps the board.
        model.resetFeedback()
        model.notchState = .silent
        await settle(window, 0.3)
        model.showAgentPanel(pinned: false)
        await settle(window, 0.4)
        let mid = model.display.frame.width / 2
        model.panelPointer(CGPoint(x: mid, y: notch.height + gap / 2))
        await settle(window, WorkbenchTokens.Panel.exitGrace + 0.3)
        let held = model.notchState == .v2Board
        model.panelPointer(CGPoint(x: mid + 500, y: 700))
        await settle(window, WorkbenchTokens.Panel.exitGrace + 0.3)
        check("Native floating: the pointer in the gap keeps the board; away, it closes", held && model.notchState == .silent)
        model.nativePanels = .attached

        // The approval's verb.
        let verbs = ["swift test --filter PasteNotFound", "swift build", "git push origin main", "npm install", "rm -rf build", "open ."]
            .map { ApprovalVerb.of($0).title }
        check("Native: an approval says what it does (Run Tests, Build, Push, Install, Delete, Run)",
              verbs == ["Run Tests", "Build", "Push", "Install", "Delete", "Run"] && ApprovalVerb.of("swift test").short == "Run",
              verbs.joined(separator: ", "))

        // The words: every accessibility text in the window in both designs (the sidebar and the
        // desktop are the same in both, so any difference is the notch's), the verb mapped back to
        // Allow and digits masked (the clocks run on).
        func notchTexts() -> [String] {
            var out: [String] = []
            var walked = 0, labelled = 0, sample: [String] = []
            func walk(_ element: Any, depth: Int) {
                guard depth < 60, let e = element as? NSAccessibilityProtocol else { return }
                walked += 1
                let frame = e.accessibilityFrame()
                if let l = e.accessibilityLabel(), !l.isEmpty {
                    labelled += 1
                    if sample.count < 6 { sample.append("\(l.prefix(24))@\(Int(frame.minX)),\(Int(frame.minY))") }
                }
                for text in [e.accessibilityLabel(), e.accessibilityValue() as? String, e.accessibilityTitle()] {
                    if let text, !text.isEmpty { out.append(text) }
                }
                for child in e.accessibilityChildren() ?? [] { walk(child, depth: depth + 1) }
                // AppKit views: their subviews too (the hosting view's elements hang off it).
                if let view = element as? NSView {
                    for sub in view.subviews { walk(sub, depth: depth + 1) }
                }
            }
            if let content = window.contentView { walk(content, depth: 0) }
            if ProcessInfo.processInfo.environment["FOVEA_DEBUG_AX"] != nil {
                print("AX walked \(walked), labelled \(labelled), texts \(out.count); \(sample)")
            }
            // The sidebar's Native panels switch shows in Native only; it's the Workbench's, not the notch's.
            let workbenchOnly: Set = ["Native panels", "Panels", "Attached", "Floating"]
            return out.filter { !workbenchOnly.contains($0) }
                .map { $0.replacingOccurrences(of: "[0-9]+", with: "#", options: .regularExpression) }
                .map { $0 == "Run Tests" || $0 == "Run" ? "Allow" : $0 }
                .sorted()
        }
        var differing: [String] = []
        var compared = 0
        for (name, stage) in [("Paste not found", { model.voiceflowSelection = .pasteNotFound }),
                              ("Choose chat", { model.v2Selection = .send }),
                              ("the board", { model.boardStyle = .sections; model.v2Selection = .board }),
                              ("a session", { model.v2Selection = .chat }),
                              ("an error", { model.stageFeedback(.errors) })] as [(String, () -> Void)] {
            model.resetFeedback()
            model.design = .original
            stage()
            await settle(window, 0.7)
            let original = notchTexts()
            model.design = .native
            await settle(window, 0.7)
            let native = notchTexts()
            if !original.isEmpty { compared += 1 }
            if original != native {
                let missing = Set(original).subtracting(native), extra = Set(native).subtracting(original)
                differing.append("\(name): −\(missing.sorted().prefix(3)) +\(extra.sorted().prefix(3))")
            }
        }
        check("Native: the same words as Original in every state (Allow → its verb aside)",
              compared > 0 && differing.isEmpty, differing.isEmpty ? "\(compared) states" : differing.joined(separator: "; "))

        // Pixels, when the window can be captured (not while the screen is locked): the board with
        // the panels attached and floating, Light and Dark; then the bars.
        for (panels, appearance) in [(NativePanels.attached, MockAppearance.light), (.attached, .dark), (.floating, .light), (.floating, .dark)] {
            model.resetFeedback()
            model.nativePanels = panels
            model.appearance = appearance
            model.design = .native
            model.boardStyle = .sections
            model.v2Selection = .board
            await settle(window, 0.8)
            let gap = WorkbenchTokens.Native.panelGap
            let cx = model.display.frame.width / 2
            let outline = model.stackLayout.outline
            // The panel's top band, a grid of points across it (over the page's own chrome, so not
            // over whatever photo the page shows); its median is the glass, not a word.
            let left: CGFloat = cx - outline.size.width / 2 + outline.topRadius + 24
            let across: CGFloat = (outline.size.width - 2 * outline.topRadius - 48) / 7
            let top: CGFloat = notch.height + gap + 6
            var grid: [CGPoint] = []
            for i in 0..<8 {
                for j in 0..<3 { grid.append(CGPoint(x: left + CGFloat(i) * across, y: top + CGFloat(j) * 12)) }
            }
            guard let rep = WorkbenchSnapshots.composited(window), rep.pixelsWide > 0,
                  let island = model.windowPoint(forDisplay: CGPoint(x: cx, y: notch.height / 2)),
                  let between = model.windowPoint(forDisplay: CGPoint(x: cx + rest.width / 2 + 40, y: notch.height + gap / 2))
            else {
                print("skip Native pixels (\(panels.rawValue), \(appearance.rawValue)): the window can't be captured")
                continue
            }
            let scale = CGFloat(rep.pixelsWide) / window.frame.width
            func luminance(_ p: CGPoint) -> CGFloat {
                let x = Int(p.x * scale), y = Int((window.frame.height - p.y) * scale)
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return -1 }
                return 0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent
            }
            let samples = grid.compactMap { model.windowPoint(forDisplay: $0) }.map(luminance).sorted()
            let p = samples.isEmpty ? -1 : samples[samples.count / 2]
            let (i, b) = (luminance(island), luminance(between))
            if i < 0 || (i == 0 && b == 0 && p == 0) {
                print("skip Native pixels (\(panels.rawValue), \(appearance.rawValue)): the capture is blank (screen locked?)")
                continue
            }
            // Light glass reads light; dark glass reads dark, though over a white page it lightens
            // (Liquid Glass takes the color of what's behind it), so "clearly below light's".
            let panelOK = appearance == .light ? p > 0.6 : (p >= 0 && p < 0.5)
            check("Native pixels (\(panels.rawValue), \(appearance.rawValue)): the notch is black, under it isn't, the panel is \(appearance == .light ? "light" : "dark")",
                  i < 0.03 && b > 0.03 && panelOK, String(format: "notch %.2f, under it %.2f, panel %.2f", i, b, p))
        }

        // The bars are glass too (Oct 9): Voiceflow's listening bar and Dispatch's aura bar, light in
        // Light and dark in Dark, the notch on them black. Sampled left of the middle, under the
        // notch, clear of the waveform, the stack and the aura.
        model.nativePanels = .attached
        for (bar, appearance) in [("Voiceflow", MockAppearance.light), ("Voiceflow", .dark), ("Dispatch", .light), ("Dispatch", .dark)] {
            model.resetFeedback()
            model.appearance = appearance
            if bar == "Voiceflow" { model.voiceflowSelection = .voiceFlow } else { model.v2Selection = .voice }
            await settle(window, 0.8)
            let cx = model.display.frame.width / 2
            let outline = model.stackLayout.outline
            let x = cx - outline.size.width / 2 + outline.topRadius + 10
            guard let rep = WorkbenchSnapshots.composited(window), rep.pixelsWide > 0,
                  let notchPoint = model.windowPoint(forDisplay: CGPoint(x: cx, y: notch.height / 2)),
                  let glassPoint = model.windowPoint(forDisplay: CGPoint(x: x, y: notch.height + 6))
            else {
                print("skip Native bar pixels (\(bar), \(appearance.rawValue)): the window can't be captured")
                continue
            }
            let scale = CGFloat(rep.pixelsWide) / window.frame.width
            func luminance(_ p: CGPoint) -> CGFloat {
                let x = Int(p.x * scale), y = Int((window.frame.height - p.y) * scale)
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return -1 }
                return 0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent
            }
            let (n, g) = (luminance(notchPoint), luminance(glassPoint))
            if n < 0 || (n == 0 && g == 0) {
                print("skip Native bar pixels (\(bar), \(appearance.rawValue)): the capture is blank (screen locked?)")
                continue
            }
            let glassOK = appearance == .light ? g > 0.6 : (g > 0.03 && g < 0.5)
            check("Native pixels: \(bar)'s bar is \(appearance == .light ? "light" : "dark") glass in \(appearance.rawValue.capitalized), the notch black",
                  n < 0.06 && glassOK, String(format: "notch %.2f, bar %.2f", n, g))
        }

        model.resetFeedback()
        model.notchState = .silent
        model.appearance = savedAppearance
        model.nativePanels = savedPanels
        model.design = savedDesign
        await settle(window, 0.3)
    }
}
