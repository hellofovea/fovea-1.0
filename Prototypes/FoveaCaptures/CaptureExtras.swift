import AppKit
import SwiftUI
import CapturesCore

// What the App UI review (Oct 6) added to a capture, each built on the card as it was:
// - a recording that failed says so, keeps nothing from you, and can be transcribed again
//   (row 28; after Messages' "Not Delivered" and Superwhisper's Reprocess);
// - its tags, yours to change, each showing every capture that has it (row 25);
// - Save, the recording among what it saves, and a picture opened large (row 28).
// Gone (Yulun, Oct 7): the recording to play on the card, and Open in Claude Code (row 27).

/// A recording whose words never came back: what happened, that nothing is lost, and how to try
/// again. On the card, two lines; in the expanded card, Transcribe Again.
struct FailedNotice: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let capture: Capture
    var compact = false

    var body: some View {
        let busy = model.transcribing.contains(capture.id)
        if compact {
            VStack(alignment: .leading, spacing: 4) {
                Text(capture.failure ?? "")
                    .font(.system(size: T.Text.cardBody)).foregroundStyle(palette.text)
                Text(busy ? "Transcribing…" : "The recording is kept. Open it to transcribe it again.")
                    .font(.system(size: 11.5)).foregroundStyle(palette.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 17)).foregroundStyle(palette.danger)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fovea couldn't transcribe this").font(.system(size: 13, weight: .semibold)).foregroundStyle(palette.text)
                    Text("\(capture.failure ?? "") Your recording is kept, so nothing you said is lost.")
                        .font(.system(size: 13)).foregroundStyle(palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        if busy {
                            ProgressView().controlSize(.small)
                            Text("Transcribing…").font(.system(size: 12)).foregroundStyle(palette.secondary)
                        } else {
                            Button("Transcribe Again") { model.transcribeAgain(capture.id) }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(minHeight: 28)
                    .padding(.top, 6)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(palette.dangerWash))
            .accessibilityElement(children: .contain)
        }
    }
}

/// The foot of an expanded capture: its tags. Nothing else (Yulun, Oct 7: no recording to play
/// and no Open in Claude Code on any card).
struct CaptureFooter: View {
    let capture: Capture

    var body: some View {
        TagRow(capture: capture)
            .frame(maxWidth: .infinity, alignment: .leading)
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

/// Save, in the expanded card's bar: everything (the words, the recording and what you took), or
/// one part.
struct SaveMenu: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let capture: Capture

    var body: some View {
        Menu {
            Button("Save Everything…") { model.save(capture, .everything) }
            Divider()
            Button("Save Recording…") { model.save(capture, .recording) }
            if capture.attachments.contains(where: { $0.kind == .region }) {
                Button("Save Pictures…") { model.save(capture, .pictures) }
            }
        } label: {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Save")
        .accessibilityLabel("Save")
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
                                model.say("Copied the picture")
                            }
                        }
                        IconButton(symbol: "square.and.arrow.down", help: "Save Picture…") { model.save(capture, .picture) }
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
