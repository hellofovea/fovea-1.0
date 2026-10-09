import SwiftUI
import AppKit
import OnboardingCore
import FoveaCore

/// System Settings as macOS 27 shows Privacy & Security's lists: Fovea isn't in a list until it's
/// dragged in from the notch, and joins it switched on (REAL_MAC.md). The drop zone breathes in the
/// accent until then (Oct 9: make the drag obvious). Simulated: nothing here touches the real
/// System Settings.
struct SystemSettingsWindow: View {
    let model: OnboardingModel
    let pane: Permission

    private let others = [("Raycast", "com.raycast.macos"), ("Zoom", "us.zoom.xos")]

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left").foregroundStyle(.secondary)
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    Text(pane.paneName).font(OT.Type_.systemTitle)
                }
                Text(pane == .screenRecording
                     ? "Allow the applications below to record the contents of your screen and audio."
                     : "Allow the applications below to control your computer and read what's on screen.")
                    .font(OT.Type_.systemSmall)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 0) {
                    ForEach(others, id: \.0) { name, id in
                        row(name: name, icon: appIcon(id), on: name == "Raycast")
                        Divider()
                    }
                    if model.inList.contains(pane) {
                        row(name: "Fovea", icon: foveaIcon, on: model.switchedOn.contains(pane), fovea: true)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        DropZone(model: model)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(OT.Colors.systemControl))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(model.tileDrag != nil ? model.accentColor : OT.Colors.systemSeparator,
                                  lineWidth: model.tileDrag != nil ? 2 : 0.5))
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(ScreenSpace.name)) } action: { model.settingsListFrame = $0 }
                .id(pane)
                Spacer(minLength: 0)
            }
            .padding(18)
        }
        .background(OT.Colors.systemWindow)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(OT.Colors.systemEdge))
        .shadow(color: OT.Colors.systemShadow, radius: 30, y: 16)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                ForEach([Color(nsColor: .systemRed), Color(nsColor: .systemYellow), Color(nsColor: .systemGreen)], id: \.self) {
                    Circle().fill($0).frame(width: 12, height: 12)
                }
            }
            .padding(.bottom, 14)
            ForEach(["Wi-Fi", "Bluetooth", "Notifications", "Sound", "Focus", "Privacy & Security", "Keyboard", "Displays"], id: \.self) { item in
                Text(item)
                    .font(OT.Type_.systemBody)
                    .foregroundStyle(item == "Privacy & Security" ? OT.Colors.systemChosenText : OT.Colors.systemText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(item == "Privacy & Security" ? OT.Colors.systemBlue : .clear))
            }
            Spacer()
        }
        .padding(12)
        .frame(width: OT.Layout.settingsSidebar)
        .background(OT.Colors.systemSidebar)
    }

    private func row(name: String, icon: NSImage?, on: Bool, fovea: Bool = false) -> some View {
        HStack(spacing: 10) {
            if let icon { Image(nsImage: icon).resizable().frame(width: 22, height: 22) }
            Text(name).font(OT.Type_.systemBody)
            Spacer()
            Toggle("", isOn: Binding(get: { on }, set: { _ in if fovea { model.toggleSwitch(pane) } }))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .disabled(!fovea)
                // The switch is AppKit's and reports its place only once flipped; a plain layer over
                // it reports as soon as the row appears.
                .overlay(Color.clear.playTarget(fovea ? .toggle : nil, model).allowsHitTesting(false))
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
    }

    private func appIcon(_ id: String) -> NSImage? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: id).map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSWorkspace.shared.icon(for: .application)
    }

    private var foveaIcon: NSImage? { FoveaIcon.image }
}

/// Fovea's app icon, from FoveaCore's resources.
enum FoveaIcon {
    static let image: NSImage? = FoveaResources.url("AppIcon.png").flatMap { NSImage(contentsOf: $0) }
}

/// Where Fovea goes: a dashed place at the foot of the list, breathing in the accent until it's
/// dropped on.
struct DropZone: View {
    let model: OnboardingModel
    @State private var breathe = false

    var body: some View {
        let accent = model.accentColor
        let over = model.tileDrag.map { model.settingsListFrame.insetBy(dx: -20, dy: -20).contains($0) } ?? false
        HStack(spacing: 8) {
            Image(systemName: "plus.square.dashed")
            Text(model.tileDrag != nil ? "Drop Fovea here" : "Drag Fovea from the notch into this list")
        }
        .font(OT.Type_.systemSmall.weight(.medium))
        .foregroundStyle(accent)
        .frame(maxWidth: .infinity)
        .frame(height: OT.Layout.dropZoneHeight)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(accent.opacity(over ? 0.18 : (breathe ? 0.1 : 0.03))))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
            .strokeBorder(accent.opacity(over ? 1 : (breathe ? 0.8 : 0.35)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
        .padding(6)
        .onAppear { if !model.options.harness { withAnimation(OT.Motion.dropZone) { breathe = true } } }
    }
}

/// Fovea, as it's dragged: the icon and the name, lifted.
struct TileView: View {
    var dragging = false

    var body: some View {
        HStack(spacing: 8) {
            if let icon = FoveaIcon.image { Image(nsImage: icon).resizable().frame(width: 22, height: 22) }
            Text("Fovea").font(.system(size: 12.5, weight: .semibold))
        }
        .foregroundStyle(dragging ? OT.Colors.tileLiftedText : OT.Colors.islandText)
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(dragging ? OT.Colors.tileLifted : OT.Colors.islandFill))
        .shadow(color: OT.Colors.tileShadow.opacity(dragging ? 1 : 0), radius: 10, y: 4)
    }
}

/// macOS's own prompts, drawn as the system draws them: the microphone, and the reopen Screen
/// Recording asks for.
struct MockAlertView: View {
    let model: OnboardingModel
    let alert: MockAlert

    var body: some View {
        VStack(spacing: 10) {
            if let icon = FoveaIcon.image { Image(nsImage: icon).resizable().frame(width: 56, height: 56) }
            Text(title).font(.system(size: 13, weight: .semibold)).multilineTextAlignment(.center)
            Text(message).font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 6) {
                Button(action: { model.alertAnswered(true) }) {
                    Text(primary).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .playTarget(.alertPrimary, model)
                Button(action: { model.alertAnswered(false) }) {
                    Text(secondary).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.top, 4)
        }
        .padding(18)
        .frame(width: OT.Layout.alertWidth)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(OT.Materials.alert))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(OT.Colors.alertEdge))
        .shadow(color: OT.Colors.systemShadow, radius: 30, y: 12)
    }

    private var title: String {
        switch alert {
        case .microphone: "“Fovea” would like to access the microphone."
        case .reopen: "“Fovea” may not be able to record the contents of your screen until it is quit."
        }
    }

    private var message: String {
        switch alert {
        case .microphone: "Fovea listens only between your presses of fn or fn ⌃."
        case .reopen: "You can quit Fovea now, or later. It opens again right where you were."
        }
    }

    private var primary: String {
        switch alert {
        case .microphone: "Allow"
        case .reopen: "Quit & Reopen"
        }
    }

    private var secondary: String {
        switch alert {
        case .microphone: "Don't Allow"
        case .reopen: "Later"
        }
    }
}
