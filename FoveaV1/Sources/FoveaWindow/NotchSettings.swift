import AppKit
import SwiftUI
import CapturesCore
import FoveaKit

/// Settings › Notch: the Island made yours, without a way to break it. The real notch shows each
/// change as it's made. A control shows only where it can change something (the wait only while
/// the pointer opens the board): one that can't move looks broken (Ryan, Oct 6). The board can
/// always be reached, and Restore Defaults puts it all back. (Oct 27: the glow's palettes are gone
/// with the aura.)



struct NotchPane: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.motion) private var motion
    @State private var confirmRestore = false

    var body: some View {
        @Bindable var model = model
        let prefs = model.prefs

        // The notch's look (Oct 9): Liquid Glass, light or dark (Oct 27: out, then back); what opens
        // below attached to the top edge or floating under it (one size since Oct 27). No picture of it here (Oct 10): the
        // real notch shows each choice as it's made.
        SettingsSection("Look", note: "The notch at the top of your screen shows each change as you make it.") {
            SettingsCard {
                SettingsRow("Glass", detail: prefs.notchAppearance == .light ? "Light glass, dark words." : "Dark glass, white words.") {
                    SettingsSegments(segments: NotchAppearance.allCases.map { ($0, $0.title) }, selection: prefs.notchAppearance) { a in
                        model.animate(.fadeIn) { model.prefs.notchAppearance = a }
                    }
                }
                RowDivider()
                SettingsRow("Panels", detail: prefs.panels == .attached
                            ? "What opens below hangs from the top of the screen, one shape with the notch."
                            : "What opens below floats just under the notch.") {
                    SettingsSegments(segments: NativePanels.allCases.map { ($0, $0.title) }, selection: prefs.panels) { p in
                        model.animate(.fadeIn) { model.prefs.panels = p }
                    }
                }
            }
        }
        .id("notch-look")

        // Oct 27, Ryan: the Glow section is gone with the aura ("abandon the orbs and aurora
        // completely, i think these are too flashy").

        SettingsSection("Opening the board") {
            SettingsCard {
                SettingsRow("Open when the pointer reaches the notch",
                            detail: "The board shows what your agents are doing; with nothing running, it says hello.") {
                    InkToggle(title: "Open when the pointer reaches the notch", isOn: $model.prefs.hoverOpens.animation(motion.animation(.layout)))
                }
                if prefs.hoverOpens {
                    // Only while the pointer opens it: a wait for nothing would look broken.
                    VStack(spacing: 0) {
                        RowDivider()
                        SettingsRow("Wait before opening", detail: "Relaxed keeps it shut when you only pass by.") {
                            SettingsSegments(segments: HoverWait.allCases.map { ($0, $0.title) }, selection: prefs.hoverWait) { wait in
                                model.prefs.hoverWait = wait
                            }
                        }
                    }
                    .transition(.arrive)
                } else {
                    // Never no way in: with the hover off, the key still opens it.
                    VStack(spacing: 0) {
                        RowDivider()
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle").foregroundStyle(palette.secondary)
                            Text("The board still shows each time you send.")
                                .font(.system(size: 12)).foregroundStyle(palette.text)
                            Spacer()
                        }
                        .cardPadding()
                    }
                    .transition(.arrive)
                }
                RowDivider()
                SettingsRow("Show an answer as soon as it's back",
                            detail: "When an agent answers within a few seconds, the notch opens it for you.") {
                    InkToggle(title: "Show an answer as soon as it's back", isOn: $model.prefs.showAnswers)
                }
            }
        }
        .id("notch-board")

        SettingsSection("Sending to an agent") {
            SettingsCard {
                SettingsRow("Review your words before sending",
                            detail: prefs.reviewFirst
                                ? "Choose chat shows your words and where they'll go. Return sends."
                                : "Fovea sends to the chat it picks. The voice bar says where, and the board shows it on its way.") {
                    InkToggle(title: "Review your words before sending", isOn: $model.prefs.reviewFirst)
                }
            }
        }

        HStack {
            Spacer()
            if WindowLook.isAligned {
                PillButton(AlignedCopy.sentence("Restore Defaults")) { confirmRestore = true }
                    .disabled(prefs.notchIsDefault)
            } else {
                Button("Restore Defaults") { confirmRestore = true }
                    .disabled(prefs.notchIsDefault)
            }
        }
        .alert("Restore the notch's defaults?", isPresented: $confirmRestore) {
            Button("Restore Defaults") { model.animate(.layout) { model.prefs.restoreNotch() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The notch's look, opening at the notch, and reviewing your words before sending.")
        }
    }

}






/// A row of pictures to choose between, each with its name and a line under it; the chosen one
/// ringed in the accent, as System Settings' Appearance tiles are.
struct PictureChoices<Value: Hashable, Picture: View>: View {
    @Environment(\.palette) private var palette
    @Environment(\.motion) private var motion
    let options: [Value]
    @Binding var selection: Value
    let title: KeyPath<Value, String>
    var detail: KeyPath<Value, String>?
    var pictureHeight: CGFloat = 56
    @ViewBuilder let picture: (Value, Bool) -> Picture

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(options, id: \.self) { option in
                let on = option == selection
                Button { selection = option } label: {
                    VStack(spacing: 6) {
                        picture(option, on)
                            .frame(maxWidth: .infinity)
                            .frame(height: pictureHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(WindowLook.isAligned ? palette.hairline : .black.opacity(0.12), lineWidth: 0.5))
                            .padding(3)
                            // Aligned: the chosen one ringed as the first run rings its tiles.
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(on ? (WindowLook.isAligned ? palette.secondary : palette.accent) : .clear,
                                              lineWidth: WindowLook.isAligned ? T.Aligned.chosenRing : 2.5))
                        Text(L(key: option[keyPath: title]))
                            .font(.system(size: 11.5, weight: on ? .semibold : .regular))
                            .foregroundStyle(palette.text)
                        if let detail {
                            Text(L(key: option[keyPath: detail]))
                                .font(.system(size: 10.5))
                                .foregroundStyle(palette.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L(key: option[keyPath: title]))
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
    }
}

// MARK: - Aligned (Oct 24): the first run's Make it yours, in Settings


/// A press in Aligned: 0.97 on the press itself, quick (the first run's `PressStyle`).
struct AlignedPress: ButtonStyle {
    @Environment(\.motion) private var motion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !motion.reduce ? T.Aligned.pressScale : 1)
            .animation(motion.animation(.press), value: configuration.isPressed)
    }
}


