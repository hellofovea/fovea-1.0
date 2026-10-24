import AppKit
import SwiftUI
import CapturesCore
import FoveaKit
import FoveaLook

// Oct 15 review, RC-01, RC-02.1, RC-02.2 and MW-05.4: captures kept by an earlier version of
// Fovea, or by another account on this Mac. Home says so quietly, once there are some; Account ›
// Earlier Data lists them, each to bring in or delete, with the wait, the failure, and a
// confirmation before anything is deleted for good (data not brought in, or the originals after).
// Shown only when there is earlier data. Simulated: 1.0 has no earlier versions and no account
// server, so a review stage puts them there and nothing on this Mac is read or deleted.

extension CapturesModel {
    /// Home's Review…: Account, at Earlier Data.
    func reviewEarlierData() {
        scrollTarget = nil
        openSettings(.account)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.45))
            self.scrollTarget = "earlier-data"
        }
    }

    /// Brings them into Home, a little at a time. Simulated: the row says it's done; no captures
    /// are made up.
    func bringIn(_ id: String) {
        guard let i = earlierData.firstIndex(where: { $0.id == id }) else { return }
        animate(.layout) { earlierData[i].state = .bringingIn(0) }
        Task { @MainActor in
            let steps = 30
            for step in 1...steps {
                try? await Task.sleep(for: .seconds(self.motion.seconds(T.Simulated.bringIn / Double(steps))))
                guard let j = self.earlierData.firstIndex(where: { $0.id == id }), case .bringingIn = self.earlierData[j].state else { return }
                self.earlierData[j].state = .bringingIn(Double(step) / Double(steps))
            }
            guard let j = self.earlierData.firstIndex(where: { $0.id == id }) else { return }
            self.animate(.layout) { self.earlierData[j].state = .broughtIn }
            // Oct 18, Ryan: the toasts in the primary language.
            self.say(L("Brought in \(self.earlierData[j].captures.formatted()) captures"))
        }
    }

    /// Deletes them (not brought in: gone for good), or the originals of ones brought in.
    func deleteEarlier(_ id: String) {
        guard let i = earlierData.firstIndex(where: { $0.id == id }) else { return }
        let broughtIn = earlierData[i].state == .broughtIn
        animate(.layout) { earlierData[i].state = .deleting }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(self.motion.seconds(T.Simulated.delete)))
            self.animate(.layout) { self.earlierData.removeAll { $0.id == id } }
            self.say(broughtIn ? L("Deleted the originals") : L("Deleted"))
        }
    }

    /// The review stage's earlier data: Fovea 0.9's history on this Mac, and another account's.
    static func sampleEarlierData(now: Date) -> [EarlierData] {
        let day: TimeInterval = 86_400
        return [
            EarlierData(id: "earlier-0.9", origin: .earlierVersion("Fovea 0.9"), captures: 128, bytes: 46_200_000,
                        date: now.addingTimeInterval(-16 * day), account: "This Mac's account"),
            EarlierData(id: "earlier-account", origin: .otherAccount("sam@northwind.studio"), captures: 37,
                        bytes: 12_800_000, date: now.addingTimeInterval(-41 * day), account: "sam@northwind.studio"),
        ]
    }
}

/// Oct 15 review, RC-01: one quiet line at the top of Home while earlier data waits.
struct EarlierDataBanner: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let fromAccount = model.earlierData.contains { if case .otherAccount = $0.origin, $0.state == .pending { return true }; return false }
        let fromVersion = model.earlierData.contains { if case .earlierVersion = $0.origin, $0.state == .pending { return true }; return false }
        let line = fromVersion ? L("Captures from an earlier version are ready to bring in")
            : (fromAccount ? L("Captures from another account are ready to bring in") : L("Earlier captures are ready to bring in"))
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath").font(.system(size: 11, weight: .medium)).foregroundStyle(palette.secondary)
            Text(line).foregroundStyle(palette.secondary)
            Text("·").foregroundStyle(palette.tertiary)
            Button("Review…") { model.reviewEarlierData() }
                .buttonStyle(.plain)
                .foregroundStyle(palette.accent)
                .help("See them in Account › Earlier Data")
        }
        .font(.system(size: 12, weight: .medium))
    }
}

/// Oct 15 review, RC-02 and MW-05.4: Account › Earlier Data, only while there is some.
struct EarlierDataSection: View {
    @Environment(CapturesModel.self) private var model

    var body: some View {
        if !model.earlierData.isEmpty {
            SettingsSection("Earlier data",
                            note: "Captures kept by an earlier version of Fovea, or by another account on this Mac. Bring them in to see them in Home.") {
                SettingsCard {
                    ForEach(Array(model.earlierData.enumerated()), id: \.element.id) { i, data in
                        if i > 0 { RowDivider(inset: 56) }
                        EarlierDataRow(data: data)
                    }
                }
            }
            .id("earlier-data")
        }
    }
}

private struct EarlierDataRow: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let data: EarlierData
    @State private var confirmDelete = false

    var body: some View {
        let size = ByteCountFormatter.string(fromByteCount: data.bytes, countStyle: .file)
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15)).foregroundStyle(palette.secondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(palette.fill))
            VStack(alignment: .leading, spacing: 2) {
                Text(data.title).font(.system(size: 13, weight: .medium)).foregroundStyle(palette.text)
                Text("\(data.captures.formatted()) captures · \(size) · last used \(Lines.day(data.date))")
                    .font(.system(size: 11.5)).foregroundStyle(palette.secondary).monospacedDigit()
                status
            }
            Spacer(minLength: 12)
            actions
        }
        .cardPadding()
        .confirmationDialog(confirmTitle, isPresented: $confirmDelete) {
            Button(data.state == .broughtIn ? "Delete Originals" : "Delete \(data.captures.formatted()) Captures", role: .destructive) {
                model.deleteEarlier(data.id)
            }
            Button(data.state == .broughtIn ? "Keep Them" : "Cancel", role: .cancel) {}
        } message: {
            Text(confirmMessage(size))
        }
    }

    private var icon: String {
        if case .otherAccount = data.origin { return "person.crop.circle" }
        return "clock.arrow.circlepath"
    }

    /// What's happening, or what happened, under the numbers.
    @ViewBuilder private var status: some View {
        switch data.state {
        case .pending:
            if case .otherAccount(let email) = data.origin {
                Text("Kept by \(email), not the account you're signed in with.")
                    .font(.system(size: 11.5)).foregroundStyle(palette.tertiary)
            }
        case .bringingIn(let p):
            Text("Bringing in… \(Int((p * Double(data.captures)).rounded())) of \(data.captures.formatted())")
                .font(.system(size: 11.5)).foregroundStyle(palette.secondary).monospacedDigit()
        case .broughtIn:
            Text("In Home now. The originals are still kept.")
                .font(.system(size: 11.5)).foregroundStyle(palette.secondary)
        case .deleting:
            Text("Deleting…").font(.system(size: 11.5)).foregroundStyle(palette.secondary)
        case .failed(let reason):
            Text(L(key: reason)).font(.system(size: 11.5)).foregroundStyle(palette.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var actions: some View {
        switch data.state {
        case .pending:
            HStack(spacing: 8) {
                TextButton("Delete…", role: .destructive) { confirmDelete = true }
                PaneButton("Bring In", prominent: true) { model.bringIn(data.id) }
            }
        case .bringingIn(let p):
            ProgressView(value: p).frame(width: 120)
        case .broughtIn:
            TextButton("Delete Originals…", role: .destructive) { confirmDelete = true }
        case .deleting:
            ProgressView().controlSize(.small)
        case .failed:
            HStack(spacing: 8) {
                TextButton("Delete…", role: .destructive) { confirmDelete = true }
                PaneButton("Try Again") { model.bringIn(data.id) }
            }
        }
    }

    /// Oct 18, Ryan: in the primary language.
    private var confirmTitle: String {
        data.state == .broughtIn ? L("Delete the originals?") : L("Delete \(data.captures.formatted()) captures from \(data.source)?")
    }

    private func confirmMessage(_ size: String) -> String {
        if data.state == .broughtIn {
            return L("Your \(data.captures.formatted()) captures are in Home now. This deletes the copies kept before, \(size). This can't be undone.")
        }
        return L("They haven't been brought in, so they'll be gone for good. This can't be undone.")
    }
}
