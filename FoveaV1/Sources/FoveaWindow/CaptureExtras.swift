import AppKit
import SwiftUI
import CapturesCore
import FoveaKit
import FoveaLook

// What the App UI review (Oct 6) added to a capture, each built on the card as it was:
// - a recording whose words didn't come back says so, and Fovea tries it again on its own
//   (row 28; Oct 15 review, VF11, VF13 and QA19: no recording to see, play or save, no button);
// - its tags, yours to change, each showing every capture that has it (row 25);
// - Save, and a picture opened large (row 28; Oct 15 review, IS04: real files).
// Gone (Yulun, Oct 7): the recording to play on the card, and Open in Claude Code (row 27).
// Oct 15 review, HI-01.3 and QA25: a Dispatch's expanded card says where it went, opens it in the
// notch, and sends a failed one again.

/// A recording whose words haven't come back yet: what happened, and that Fovea is trying again
/// on its own (Oct 15 review, VF13). On the card, two lines; in the expanded card, a quiet notice
/// and "Trying again…" while it does. Nothing to press, no recording to see.
struct FailedNotice: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let capture: Capture
    var compact = false

    var body: some View {
        let busy = model.transcribing.contains(capture.id)
        if compact {
            VStack(alignment: .leading, spacing: 4) {
                // The title above says "Not transcribed yet": here, why, and that Fovea is on it.
                // Oct 18, Ryan: why, in the primary language (looked up as written).
                Text(L(key: capture.failure ?? ""))
                    .font(.system(size: T.Text.cardBody)).foregroundStyle(palette.text)
                Text(busy ? "Trying again…" : "Fovea is trying again.")
                    .font(.system(size: 11.5)).foregroundStyle(palette.secondary)
                    .contentTransition(.opacity)
            }
            .fixedSize(horizontal: false, vertical: true)
            // Oct 15 review, VF13: no "the recording is kept, open it"; Fovea retries by itself.
        } else {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(palette.secondary)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Not transcribed yet").font(.system(size: 13, weight: .semibold)).foregroundStyle(palette.text)
                    Text("\(L(key: capture.failure ?? "")) Fovea is trying again, and your words show up here when they're back.")
                        .font(.system(size: 13)).foregroundStyle(palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if busy {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Trying again…").font(.system(size: 12)).foregroundStyle(palette.secondary)
                        }
                        .frame(minHeight: 24)
                        .padding(.top, 4)
                        .transition(.arrive)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(palette.fill))
            .accessibilityElement(children: .contain)
        }
    }
}

/// Oct 15 review, QA25: a Dispatch that didn't reach its agent: why, and Send Again (the notch
/// sends it, `onSendAgain`).
struct NotSentNotice: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let capture: Capture

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 17)).foregroundStyle(palette.danger)
            VStack(alignment: .leading, spacing: 4) {
                // Oct 18, Ryan: in the primary language.
                Text("Not sent to \(capture.destination?.agent ?? L("your agent"))")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(palette.text)
                Text(L(key: capture.sendFailure ?? ""))
                    .font(.system(size: 13)).foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            PillButton("Send Again", symbol: "arrow.up", kind: .prominent) { model.sendAgain(capture.id) }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(palette.dangerWash))
        .accessibilityElement(children: .contain)
    }
}

/// The foot of an expanded capture: its tags; for a Dispatch, where it went and Open in Notch
/// (Oct 15 review, HI-01.3). No recording to play, no Open in Claude Code (Yulun, Oct 7).
struct CaptureFooter: View {
    let capture: Capture

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if capture.kind == .dispatch, capture.destination != nil {
                DispatchRoute(capture: capture)
            }
            TagRow(capture: capture)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Where a Dispatch went (the agent, its chat, how many requests it has had) and the way back to
/// it in the notch, where its answers are: Fovea is a remote control, not a display, so the
/// session opens there, never here (AGENTS.md).
struct DispatchRoute: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let capture: Capture

    var body: some View {
        let d = capture.destination!
        let n = model.requests(capture)
        HStack(spacing: 10) {
            Image(nsImage: Art.agentIcon(d.agent)).resizable().interpolation(.high).frame(width: 20, height: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(d.chat).font(.system(size: 13, weight: .medium)).foregroundStyle(palette.text).lineLimit(1)
                Text(n > 1 ? L("\(d.agent) · \(n) requests") : d.agent)
                    .font(.system(size: 11.5)).foregroundStyle(palette.secondary)
            }
            Spacer(minLength: 12)
            if !capture.notSent {
                PillButton("Open in Notch", symbol: "macbook") { model.openInNotch(capture.id) }
                    .help("Open this session at the notch, where its answers are")
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// Its tags: Fovea's, and yours to change. A tag shows every capture that has it; Memory reads its
/// interests from the ones that keep coming up.
struct TagRow: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let capture: Capture
    @State private var adding = false
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(capture.tags, id: \.self) { tag in
                TagChip(tag: tag, open: { model.show(tag: tag) }, remove: { model.removeTag(tag, from: capture.id) })
            }
            if adding {
                TextField("Tag", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(width: 110)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(Capsule().strokeBorder(palette.accent, lineWidth: 1))
                    .focused($focused)
                    .onSubmit { commit() }
                    .onExitCommand { adding = false; text = "" }
                    .onAppear { focused = true }
            } else {
                Button { adding = true } label: {
                    Label(capture.tags.isEmpty ? "Add Tag" : "Tag", systemImage: "plus")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.secondary)
                        .padding(.horizontal, 9)
                        .frame(height: 24)
                        .background(Capsule().strokeBorder(palette.hairline, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Add a tag")
            }
        }
        .onChange(of: focused) { if !focused { commit() } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tags")
    }

    private func commit() {
        if !text.trimmingCharacters(in: .whitespaces).isEmpty { model.addTag(text, to: capture.id) }
        text = ""
        adding = false
    }
}

/// One tag: click it to see every capture that has it; hover for its ✕.
struct TagChip: View {
    @Environment(\.palette) private var palette
    let tag: String
    var open: () -> Void
    var remove: (() -> Void)?
    @State private var hover = false

    var body: some View {
        HStack(spacing: 4) {
            Button(action: open) {
                Text(tag).font(.system(size: 12)).foregroundStyle(palette.text)
            }
            .buttonStyle(.plain)
            .help("Show everything tagged “\(tag)”")
            if let remove, hover {
                Button(action: remove) {
                    Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundStyle(palette.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove this tag")
                .accessibilityLabel("Remove \(tag)")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(Capsule().fill(palette.fill))
        .onHover { hover = $0 }
    }
}

/// Save, in the expanded card's bar: the words as a .txt, or with what you took a folder of the
/// words, the pictures and the files. Oct 15 review: no Save Recording (VF11, QA19); real files (IS04).
struct SaveButton: View {
    @Environment(CapturesModel.self) private var model
    let capture: Capture

    var body: some View {
        // Oct 21, Ryan: one click saves (no menu): the words, or a folder with what you took.
        // Save Everything… and Save Pictures… were the menu; the folder is everything, and the
        // pictures are in it, so the menu offered no real choice. One picture or one file is still
        // saved from where it shows (the picture viewer, the file's row).
        // Oct 21, Ryan: saved, the tray turns into a checkmark a moment, beside the toast.
        let saved = model.savedID == capture.id
        IconButton(symbol: saved ? "checkmark" : "square.and.arrow.down", help: saved ? "Saved" : "Save… (⌘S)",
                   confirmed: saved, label: saved ? "Saved" : "Save…") {
            model.saveToDisk(capture, .capture)
        }
        // Nothing to save until the words are back.
        .disabled(capture.failed)
    }
}

/// A picture you took, large: fitted to the window or at its own size, with Copy and Save. Over
/// everything, as Quick Look opens; Esc, or a click around it, closes it.
struct ImageViewer: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let capture: Capture
    let attachment: Attachment
    @State private var actualSize = false

    var body: some View {
        ZStack {
            // Nearly opaque, as Quick Look's: the picture is the only thing to look at, and the
            // card's own buttons don't show through beside the viewer's.
            Color.black.opacity(0.9)
                .contentShape(Rectangle())
                .onTapGesture { model.closeViewer() }
                .accessibilityHidden(true)
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    GlassBar {
                        IconButton(symbol: "xmark", help: "Close (Esc)") { model.closeViewer() }
                            .keyboardShortcut(.cancelAction)
                    }
                    Spacer()
                    Picker("Size", selection: $actualSize) {
                        Text("Fit").tag(false)
                        Text("Actual Size").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    GlassBar {
                        IconButton(symbol: "doc.on.doc", help: "Copy Picture") {
                            if let image = Art.region(attachment) {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.writeObjects([image])
                                model.say(L("Copied the picture"))
                            }
                        }
                        IconButton(symbol: "square.and.arrow.down", help: "Save Picture…") { model.saveToDisk(capture, .picture(attachment.index)) }
                    }
                }
                if let image = Art.region(attachment) {
                    if actualSize {
                        ScrollView([.horizontal, .vertical]) {
                            Image(nsImage: image).interpolation(.high)
                        }
                    } else {
                        Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                Text(attachment.source).font(.subheadline).foregroundStyle(.white.opacity(0.7))
            }
            .padding(20)
        }
        .environment(\.colorScheme, .dark)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel("\(Lines.name(attachment)), from \(attachment.source)")
    }
}
