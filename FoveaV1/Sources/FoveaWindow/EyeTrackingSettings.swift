import AppKit
import SwiftUI
import CapturesCore
import FoveaKit
import FoveaLook

// Settings › Eye Tracking. In beta, and honest about it (row 34): there's a model at work already;
// the way to try it is to help collect the data that fits it to you. Oct 15 review, ST-08.1 and
// ST-08.2 (Ryan: "design the controls, but they only show up after the user collected the gaze
// tracking data"): the Collector's steps stay; once the person's session is in, the controls
// appear: whether the camera is connected, Calibrate…, Paste where you look, Show what you're
// looking at, the display (this Mac's own), and Test…. Eye tracking is simulated in 1.0: the
// Collector, the session, calibration and the test; the camera and the displays are this Mac's.

extension CapturesModel {
    /// The Gaze Collector opened: about ten minutes of following dots, played quickly (simulated).
    func openCollector() {
        play?.cancel()
        withAnimation(motion.animation(.swap)) { prefs.gaze = .collecting(0) }
        play = Task { @MainActor in
            for step in 1...40 {
                try? await Task.sleep(for: .seconds(motion.seconds(0.1)))
                guard !Task.isCancelled, case .collecting = prefs.gaze else { return }
                prefs.gaze = .collecting(Double(step) / 40)
            }
            withAnimation(motion.animation(.swap)) { prefs.gaze = .reviewing }
        }
    }

    /// Stops following the dots: nothing is kept.
    func stopCollecting() {
        play?.cancel()
        withAnimation(motion.animation(.swap)) { prefs.gaze = .downloaded }
    }

    /// The session sent; the model is fitted, and the controls appear (simulated).
    func sendSession() {
        play?.cancel()
        withAnimation(motion.animation(.swap)) { prefs.gaze = .sending(0) }
        play = Task { @MainActor in
            for step in 1...20 {
                try? await Task.sleep(for: .seconds(motion.seconds(0.06)))
                guard !Task.isCancelled, case .sending = prefs.gaze else { return }
                prefs.gaze = .sending(Double(step) / 20)
            }
            withAnimation(motion.animation(.swap)) {
                prefs.gaze = .collected
                panes.eyeTrackingOn = true
                panes.calibratedAt = Date()
            }
            say(L("Sent. Eye tracking is on, fitted to your eyes."))
        }
    }

    /// The session deleted before it was sent.
    func discardSession() {
        play?.cancel()
        withAnimation(motion.animation(.swap)) { prefs.gaze = .downloaded }
        say(L("Deleted the session"))
    }
}

/// In beta: before the person's session, what it is and how to help; after, its controls first.
struct EyeTrackingPane: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let collected = model.prefs.gaze == .collected
        if collected {
            EyeTrackingControls()
        } else {
            SettingsSection(nil) {
                // Concentric: the picture inset 8 pt in a card rounded 20, so rounded 12.
                SettingsCard(radius: 20) {
                    VStack(spacing: 14) {
                        GazeHero().frame(height: 196)
                            .padding(.horizontal, -8)
                            .padding(.top, -8)
                        VStack(spacing: 6) {
                            Text("Eye tracking is in beta")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(palette.text)
                            // Row 34: say there's a model at work already, and how to get to try it.
                            Text("Fovea already has a gaze model at work: look at something, say “this,” and it knows what you mean. To try it, spend ten minutes with the Gaze Collector; then it's yours, fitted to your eyes.")
                                .font(.system(size: 13))
                                .foregroundStyle(palette.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: 400)
                        }
                    }
                    .cardPadding()
                    .padding(.bottom, 8)
                }
            }
        }

        let gaze = model.prefs.gaze
        SettingsSection(collected ? "Your session" : "Try the beta",
                        note: collected ? nil : "The beta is open to people who help collect data. One session with the Gaze Collector fits the model to your eyes, and makes eye tracking better for everyone.") {
            SettingsCard {
                VStack(alignment: .leading, spacing: 14) {
                    Step(number: 1, title: "Download the Gaze Collector", detail: "A small app, separate from Fovea.", done: gaze.reached(.downloaded))
                    Step(number: 2, title: "Follow the dots", detail: "About ten minutes, at your desk, with the camera on.", done: gaze.reached(.reviewing))
                    Step(number: 3, title: "Review, then send", detail: "Watch the recording first. Send it only if you want to.", done: collected)
                    Step(number: 4, title: "Turn on eye tracking", detail: "Once your session is in, its settings show here, with a model fitted to you.", done: collected)
                }
                .cardPadding()
                .frame(maxWidth: .infinity, alignment: .leading)
                RowDivider()
                CollectorDownload()
                    .cardPadding()
                    .frame(maxWidth: .infinity)
            }
        }
        .id("eye-beta")

        SettingsSection("What the Collector records") {
            SettingsCard {
                SettingsRow("Video of your eyes", detail: "Only while you follow the dots. The camera light stays on the whole time.")
                RowDivider()
                SettingsRow("Where each dot was", detail: "Its place on the screen and when it moved.")
                RowDivider()
                SettingsRow("Nothing leaves without you", detail: "Recordings stay on your Mac until you review them and choose to send.")
                RowDivider()
                SettingsRow("Yours to delete", detail: "Remove any recording from the Collector, anytime.")
            } footer: {
                Text("Thank you. Every session helps Fovea see a little better.")
            }
        }
    }
}

extension Prefs.Gaze {
    private var rank: Int {
        switch self {
        case .idle: return 0
        case .downloading: return 1
        case .downloaded: return 2
        case .collecting: return 3
        case .reviewing: return 4
        case .sending: return 5
        case .collected: return 6
        }
    }
    /// At or past a step of the Collector's.
    func reached(_ step: Prefs.Gaze) -> Bool { rank >= step.rank }
}

/// After the session (ST-08.1, ST-08.2): eye tracking on or off; the camera, connected or not;
/// calibration; what it does while you speak; the display it follows, and a test.
private struct EyeTrackingControls: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        @Bindable var panes = model.panes
        let on = panes.eyeTrackingOn
        let camera = panes.stagedNoCamera ? nil : panes.cameraName
        SettingsSection(nil) {
            SettingsCard {
                SettingsRow("Eye tracking", detail: "Look at something and say “this”: Fovea knows what you mean.") {
                    InkToggle(title: "Eye tracking", isOn: $panes.eyeTrackingOn.animation(model.motion.animation(.swap)))
                }
                RowDivider()
                SettingsRow("Status", detail: camera.map { L("Following your eyes with \($0).") }
                                        ?? "No camera found. Connect one, or open your MacBook's lid.") {
                    if camera != nil {
                        StatusLabel(word: "Connected")
                    } else {
                        StatusLabel(word: "Not connected", ok: false, fix: ("Check Again", {
                            panes.stagedNoCamera = false
                            panes.readCamera()
                        }))
                    }
                }
                RowDivider()
                SettingsRow("Calibration", detail: panes.calibratedAt.map { L("Calibrated \(Lines.relative($0, now: Date())).") }
                                             ?? "Not calibrated yet.") {
                    TextButton("Calibrate…") { panes.calibrating = true }
                        .disabled(camera == nil)
                }
            }
        }
        .id("eye-controls")
        .sheet(isPresented: $panes.calibrating) {
            CalibrateSheet().environment(model).environment(\.palette, palette).environment(\.motion, model.motion).foveaLanguage()
        }
        .onAppear { panes.readCamera() }

        SettingsSection("While you speak") {
            SettingsCard {
                SettingsRow("Paste where you look", detail: "Voice Flow types into the field you're looking at, not only where the cursor is.") {
                    InkToggle(title: "Paste where you look", isOn: $panes.pasteWhereYouLook)
                }
                RowDivider()
                SettingsRow("Show what you're looking at", detail: "A soft ring follows your eyes while Fovea listens.") {
                    InkToggle(title: "Show what you're looking at", isOn: $panes.showGaze)
                }
            }
            .disabled(!on)
            .opacity(on ? 1 : 0.5)
        }

        SettingsSection("Display") {
            SettingsCard {
                let screens = NSScreen.screens.map(\.localizedName)
                SettingsRow("Display", detail: "The one the camera sits on. Fovea follows your eyes there.") {
                    InlinePicker(options: screens.isEmpty ? [panes.gazeDisplay] : screens,
                                 selection: $panes.gazeDisplay, label: { $0.isEmpty ? "This Mac's display" : $0 })
                }
                RowDivider()
                SettingsRow("Test", detail: "Look around the screen: a dot follows your eyes.") {
                    TextButton("Test…") { panes.testing = true }
                        .disabled(camera == nil)
                }
            }
            .disabled(!on)
            .opacity(on ? 1 : 0.5)
        }
        .sheet(isPresented: $panes.testing) {
            GazeTestSheet().environment(model).environment(\.palette, palette).environment(\.motion, model.motion).foveaLanguage()
        }
    }
}

/// Five dots, one at a time, each filling while it's looked at; then how closely the eyes and the
/// screen line up (simulated).
private struct CalibrateSheet: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.motion) private var motion
    @State private var dot = 0
    @State private var fill: CGFloat = 0
    @State private var done = false
    private let points: [CGPoint] = [CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.1, y: 0.12), CGPoint(x: 0.9, y: 0.12),
                                     CGPoint(x: 0.9, y: 0.88), CGPoint(x: 0.1, y: 0.88)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Calibrate").font(.system(size: 15, weight: .semibold))
            Text(done ? L("Calibrated. Where you look and where Fovea thinks you look are about a fingertip apart.")
                      : L("Look at each dot until it fills. Keep your head where it usually is."))
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(palette.ink(0.05))
                    ForEach(Array(points.enumerated()), id: \.offset) { i, pt in
                        ZStack {
                            Circle().strokeBorder(palette.ink(0.35), lineWidth: 1.5)
                            Circle().trim(from: 0, to: i < dot || done ? 1 : (i == dot ? fill : 0))
                                .stroke(palette.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            if i < dot || done { Circle().fill(palette.accent).frame(width: 6, height: 6) }
                        }
                        .frame(width: 22, height: 22)
                        .position(x: geo.size.width * pt.x, y: geo.size.height * pt.y)
                    }
                }
            }
            .frame(width: 380, height: 220)
            HStack {
                Spacer()
                Button(done ? L("Done") : L("Cancel")) { model.panes.calibrating = false }
                    .keyboardShortcut(done ? .defaultAction : .cancelAction)
            }
        }
        .padding(20)
        .frame(width: 420, height: 372, alignment: .top)
        .task {
            for i in points.indices {
                dot = i
                fill = 0
                withAnimation(.linear(duration: motion.seconds(0.9))) { fill = 1 }
                try? await Task.sleep(for: .seconds(motion.seconds(1.0)))
                if Task.isCancelled { return }
            }
            withAnimation(motion.animation(.swap)) { done = true }
            model.panes.calibratedAt = Date()
        }
    }
}

/// A dot that follows the eyes round a picture of the screen (simulated: it drifts the way eyes
/// read a page).
private struct GazeTestSheet: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.motion) private var motion

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Test Eye Tracking").font(.system(size: 15, weight: .semibold))
            Text("Look at the corners of your screen, then at something you'd point at. The dot should follow your eyes.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: motion.reduce)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                GeometryReader { geo in
                    let x = motion.reduce ? 0.5 : 0.5 + 0.36 * sin(t * 0.7) * cos(t * 0.23)
                    let y = motion.reduce ? 0.5 : 0.5 + 0.32 * sin(t * 0.53 + 1)
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous).fill(palette.ink(0.05))
                        Circle().fill(palette.accent.opacity(0.22)).frame(width: 34, height: 34)
                            .position(x: geo.size.width * x, y: geo.size.height * y)
                        Circle().fill(palette.accent).frame(width: 9, height: 9)
                            .position(x: geo.size.width * x, y: geo.size.height * y)
                    }
                }
            }
            .frame(width: 380, height: 220)
            HStack {
                Text(model.panes.gazeDisplay.isEmpty ? L("On this Mac's display") : L("On \(model.panes.gazeDisplay)"))
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
                Spacer()
                Button("Done") { model.panes.testing = false }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420, height: 372, alignment: .top)
    }
}

private struct Step: View {
    @Environment(\.palette) private var palette
    let number: Int
    let title: String
    let detail: String
    var done = false
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Group {
                if done {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(palette.card)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(palette.text))
                } else {
                    Text(verbatim: "\(number)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.text)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().strokeBorder(palette.tertiary, lineWidth: 0.75))
                }
            }
            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 5 }
            VStack(alignment: .leading, spacing: 2) {
                Text(L(key: title)).font(.system(size: 13, weight: .medium)).foregroundStyle(palette.text)
                Text(L(key: detail)).font(.system(size: 11.5)).foregroundStyle(palette.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(done ? "Done" : "")
    }
}

/// Download, then its progress, then Open; then following the dots, reviewing and sending, in
/// place (all simulated: nothing is fetched, recorded or sent).
private struct CollectorDownload: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    var body: some View {
        ZStack {
            switch model.prefs.gaze {
            case .idle:
                VStack(spacing: 6) {
                    PillButton("Download Gaze Collector", symbol: "arrow.down", kind: .prominent, large: true) {
                        model.downloadCollector()
                    }
                    Text("38 MB · macOS 14 or later").font(.system(size: 11.5)).foregroundStyle(palette.secondary)
                }
                .transition(.blockSwap)
            case .downloading(let p):
                progress(p, L("Downloading… \(Int((p * 38).rounded())) of 38 MB")) { model.cancelCollector() }
                    .transition(.blockSwap)
            case .downloaded:
                VStack(spacing: 6) {
                    HStack(spacing: 12) {
                        PillButton("Open Gaze Collector", symbol: "eye", kind: .prominent, large: true) {
                            model.openCollector()
                        }
                        TextButton("Show in Finder") { model.say(L("Would show it in Downloads (simulated)")) }
                    }
                    StatusLabel(word: "In your Downloads folder")
                }
                .transition(.blockSwap)
            case .collecting(let p):
                progress(p, L("Following the dots… about \(max(1, Int(((1 - p) * 10).rounded(.up)))) min left"), stop: "Stop") {
                    model.stopCollecting()
                }
                .transition(.blockSwap)
            case .reviewing:
                VStack(spacing: 8) {
                    Text("Your session: 9 min 40 s, 312 dots.").font(.system(size: 12.5, weight: .medium)).foregroundStyle(palette.text)
                    HStack(spacing: 10) {
                        TextButton("Watch Recording") { model.say(L("Would play the recording in the Collector (simulated)")) }
                        PillButton("Send Session", symbol: "paperplane", kind: .prominent) { model.sendSession() }
                        TextButton("Delete It", role: .destructive) { model.discardSession() }
                    }
                    Text("It's sent only if you choose to.").font(.system(size: 11.5)).foregroundStyle(palette.secondary)
                }
                .transition(.blockSwap)
            case .sending(let p):
                progress(p, L("Sending… \(Int((p * 120).rounded())) of 120 MB"), action: nil)
                    .transition(.blockSwap)
            case .collected:
                HStack(spacing: 12) {
                    StatusLabel(word: "Session sent. The model is fitted to your eyes.")
                    TextButton("Collect Again") { model.openCollector() }
                }
                .transition(.blockSwap)
            }
        }
        .frame(minHeight: 56)
    }

    private func progress(_ p: Double, _ line: String, stop: String = "Cancel", action: (() -> Void)?) -> some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.text.opacity(0.08))
                    Capsule().fill(palette.text.opacity(0.85)).frame(width: max(4, geo.size.width * p))
                }
            }
            .frame(width: 240, height: 4)
            HStack(spacing: 10) {
                Text(line).monospacedDigit()
                if let action { TextButton(stop, action: action) }
            }
            .font(.system(size: 11.5))
            .foregroundStyle(palette.secondary)
        }
    }
}

private struct GazeHero: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.motion) private var motion
    @State private var focus = 1
    @State private var trail: [Int] = []
    @State private var resting = true

    private let screen = CGSize(width: 340, height: 178)
    /// The three windows on the screen, and where on each the eyes land.
    private let windows: [CGRect] = [
        CGRect(x: 14, y: 22, width: 150, height: 82),
        CGRect(x: 176, y: 22, width: 150, height: 82),
        CGRect(x: 14, y: 114, width: 312, height: 50),
    ]
    private let gazes: [CGPoint] = [CGPoint(x: 96, y: 58), CGPoint(x: 236, y: 66), CGPoint(x: 150, y: 140)]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.mark.opacity(palette.isDark ? 0.10 : 0.16))
            screenView
        }
        .task(id: motion.reduce) { await run() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Coming soon: look at something on screen and say “this.”")
    }

    private var screenView: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(palette.card)
            // The menu bar, with the notch where Fovea lives.
            Rectangle().fill(palette.text.opacity(0.04)).frame(height: 12)
            IslandShape(topRadius: 3, bottomRadius: 5)
                .fill(Color.black)
                .frame(width: 52, height: 12)
                .offset(x: (screen.width - 52) / 2)
            chart.frame(width: windows[0].width, height: windows[0].height).offset(x: windows[0].minX, y: windows[0].minY)
            paragraph.frame(width: windows[1].width, height: windows[1].height).offset(x: windows[1].minX, y: windows[1].minY)
            code.frame(width: windows[2].width, height: windows[2].height).offset(x: windows[2].minX, y: windows[2].minY)
            ForEach(Array(windows.enumerated()), id: \.offset) { i, w in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(palette.text, lineWidth: 1.5)
                    .frame(width: w.width + 4, height: w.height + 4)
                    .offset(x: w.minX - 2, y: w.minY - 2)
                    .opacity(focus == i && resting ? 1 : 0)
                    .animation(motion.animation(.hover), value: focus == i && resting)
            }
            ForEach(Array(trail.enumerated()), id: \.offset) { n, i in
                Circle().fill(palette.text)
                    .frame(width: 5, height: 5)
                    .opacity([0.35, 0.18, 0.08][min(n, 2)])
                    .offset(x: gazes[i].x - 2.5, y: gazes[i].y - 2.5)
            }
            gaze.offset(x: gazes[focus].x - 18, y: gazes[focus].y - 18)
            Text("this")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(palette.onMark)
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(Capsule().fill(palette.mark))
                .scaleEffect(resting ? 1 : 0.9, anchor: .bottomLeading)
                .opacity(resting ? 1 : 0)
                .offset(x: gazes[focus].x + 12, y: gazes[focus].y - 26)
        }
        .frame(width: screen.width, height: screen.height)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(palette.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(palette.isDark ? 0.4 : 0.1), radius: 8, y: 3)
    }

    private var gaze: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [palette.mark.opacity(0.7), palette.mark.opacity(0)],
                                         center: .center, startRadius: 2, endRadius: 18))
            Circle().fill(palette.text).frame(width: 8, height: 8)
            Circle().strokeBorder(Color.white, lineWidth: 1.5).frame(width: 8, height: 8)
        }
        .frame(width: 36, height: 36)
    }

    private var windowFill: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous).fill(palette.text.opacity(0.035))
    }

    private var chart: some View {
        HStack(alignment: .bottom, spacing: 7) {
            ForEach([0.45, 0.7, 0.55, 0.9, 0.62, 0.8], id: \.self) { h in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(palette.text.opacity(0.28))
                    .frame(width: 14, height: 56 * h)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(12)
        .background(windowFill)
    }

    private var paragraph: some View {
        VStack(alignment: .leading, spacing: 7) {
            Capsule().fill(palette.text.opacity(0.5)).frame(width: 70, height: 6)
            ForEach([118.0, 104, 122, 84], id: \.self) { w in
                Capsule().fill(palette.text.opacity(0.16)).frame(width: w, height: 5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(windowFill)
    }

    private var code: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array([[(0.0, 34.0, Color.purple), (40, 56, Color.blue)],
                           [(14, 48, Color.pink), (68, 90, Color.gray)],
                           [(14, 30, Color.orange), (50, 120, Color.gray)]].enumerated()), id: \.offset) { _, line in
                ZStack(alignment: .leading) {
                    ForEach(Array(line.enumerated()), id: \.offset) { _, token in
                        Capsule().fill(token.2.opacity(0.4)).frame(width: token.1, height: 5).offset(x: token.0)
                    }
                }
                .frame(height: 5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(windowFill)
    }

    /// A rest of about a second and a half, the "this" fading, a quick jump to the next window,
    /// "this" again: the rhythm of reading a screen.
    private func run() async {
        if motion.reduce {
            focus = 1; resting = true; trail = []
            return
        }
        while !Task.isCancelled {
            withAnimation(motion.animation(.content)) { resting = true }
            try? await Task.sleep(for: .seconds(motion.seconds(1.5)))
            guard !Task.isCancelled else { return }
            withAnimation(motion.animation(.press)) { resting = false }
            try? await Task.sleep(for: .seconds(motion.seconds(0.1)))
            trail = Array(([focus] + trail).prefix(3))
            withAnimation(.spring(duration: motion.seconds(0.32), bounce: 0.06)) { focus = (focus + 1) % gazes.count }
            try? await Task.sleep(for: .seconds(motion.seconds(0.28)))
        }
    }
}
