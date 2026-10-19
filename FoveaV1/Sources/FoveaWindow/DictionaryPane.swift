import AppKit
import SwiftUI
import UniformTypeIdentifiers
import CapturesCore
import FoveaKit
import FoveaLook

// Settings › Dictionary (Oct 15 review, DI-01.1–DI-01.3, FR-30): its own section now. The words
// Fovea writes your way, at their real number: searched, All · Learned · Added, each with an On/Off;
// a word opened in a sheet to change its spelling, the ways it's heard ("Also heard as", added and
// removed) and whether it's on; signed out, the list stays to read, with a line to sign in; and
// words brought in from other dictation apps, from a file or pasted. The words are the dictionary
// store's (`dictionary.json`); their other spellings and On/Off are kept beside it until
// `DictionaryWord` holds them (`WordExtrasFile`).

/// A word's other spellings, past the one `DictionaryWord.heardAs` holds, and whether it's on.
struct WordExtras: Codable, Equatable {
    var variants: [String] = []
    var on = true
}

/// Where `WordExtras` are kept: `dictionary-extras.json`, beside `dictionary.json` in Fovea's folder.
/// Off words and the extra spellings reach speech recognition once the dictionary store reads them
/// (Wiring needed in the Oct 15 report).
enum WordExtrasFile {
    static func url(_ folder: URL?) -> URL? { folder?.appendingPathComponent("dictionary-extras.json") }
}

extension PanesState {
    func loadWordExtras(_ folder: URL?) {
        guard extrasFile == nil, let url = WordExtrasFile.url(folder) else { return }
        extrasFile = url
        if let data = try? Data(contentsOf: url), let extras = try? JSONDecoder().decode([String: WordExtras].self, from: data) {
            wordExtras = extras
        }
    }

    func saveWordExtras() {
        guard let url = extrasFile else { return }
        let kept = wordExtras.filter { $0.value != WordExtras() }
        if let data = try? JSONEncoder().encode(kept) { try? data.write(to: url, options: .atomic) }
    }

    func extras(_ id: String) -> WordExtras { wordExtras[id] ?? WordExtras() }
}

/// A word being added or changed in the sheet.
struct WordDraft: Identifiable, Equatable {
    var id: String
    var isNew: Bool
    var word: String
    var variants: [String]
    var on: Bool
    var learned: String?

    init(_ w: DictionaryWord, extras: WordExtras?) {
        id = w.id
        isNew = false
        word = w.word
        variants = (w.heardAs.map { [$0] } ?? []) + (extras?.variants ?? [])
        on = extras?.on ?? true
        if w.source == .learned {
            let day = Lines.day(w.date)
            learned = w.learnedIn.map { L("Learned \(day) in \($0), when you corrected what it typed.") }
                ?? L("Learned \(day), when you corrected what it typed.")
        }
    }

    private init() { id = "new"; isNew = true; word = ""; variants = []; on = true }
    static func new() -> WordDraft { WordDraft() }
}

// MARK: - Actions

extension CapturesModel {
    /// Saves the sheet's word: its spelling, the first way it's heard where the store keeps it (the
    /// island replaces it), the rest and its On/Off beside it.
    func saveWord(_ draft: WordDraft) {
        let word = draft.word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        var seen = Set<String>()
        let variants = draft.variants.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.lowercased() != word.lowercased() && seen.insert($0.lowercased()).inserted }
        let id: String
        if !draft.isNew, let i = library.dictionary.firstIndex(where: { $0.id == draft.id }) {
            id = draft.id
            animate(.swap) {
                library.dictionary[i].word = word
                library.dictionary[i].heardAs = variants.first
            }
            say(L("Saved “\(word)”"))
        } else {
            id = "w-\(UUID().uuidString.prefix(8))"
            animate(.swap) {
                library.dictionary.insert(DictionaryWord(id: id, word: word, heardAs: variants.first, source: .added, date: Date()), at: 0)
            }
            say(L("Added “\(word)”"))
        }
        panes.wordExtras[id] = WordExtras(variants: Array(variants.dropFirst()), on: draft.on)
        panes.saveWordExtras()
    }

    func setWord(_ id: String, on: Bool) {
        var e = panes.extras(id)
        e.on = on
        panes.wordExtras[id] = e
        panes.saveWordExtras()
    }

    func deleteWord(_ id: String) {
        let word = library.dictionary.first { $0.id == id }?.word ?? ""
        removeWord(id)
        panes.wordExtras[id] = nil
        panes.saveWordExtras()
        say(L("Deleted “\(word)”"))
    }

    /// Words brought in from another app: added, as words you added, with what they're heard as.
    func importWords(_ words: [ImportedEntry]) {
        let now = Date()
        let new = words.map { DictionaryWord(id: "w-\(UUID().uuidString.prefix(8))", word: $0.word, heardAs: $0.heardAs, source: .added, date: now) }
        guard !new.isEmpty else { return }
        animate(.swap) { library.dictionary.insert(contentsOf: new, at: 0) }
        say(new.count == 1 ? L("Brought in 1 word") : L("Brought in \(new.count) words"))
    }
}

// MARK: - The pane

/// The dictionary as its own section of Settings (DI-01). The other window builder routes
/// `SettingsCategory.dictionary` here; it needs nothing passed in.
struct DictionaryPane: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.settingsNative) private var native

    var body: some View {
        @Bindable var panes = model.panes
        let all = model.library.dictionary
        let tab = model.dictionaryTab
        let readOnly = model.signedOut
        let tokens = panes.dictionarySearch.lowercased().split(separator: " ").map(String.init)
        let words = all.filter { w in
            let heard = ([w.heardAs].compactMap { $0 } + panes.extras(w.id).variants).joined(separator: " ").lowercased()
            return (tab == .all || (tab == .learned ? w.source == .learned : w.source == .added))
                && tokens.allSatisfy { t in w.word.lowercased().contains(t) || heard.contains(t) }
        }
        .sorted { $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending }
        let groups = Dictionary(grouping: words) { Self.letter($0.word) }
        let letters = groups.keys.sorted { a, b in a == "#" ? false : (b == "#" ? true : a < b) }

        // Oct 18: "Words" (Voice & Capture's "Your words" is about how they're written).
        SettingsSection("Words") {
            if !all.isEmpty {
                SettingsSegments(segments: DictionaryTab.allCases.map { t in
                    let n = t == .all ? all.count : all.filter { $0.source == (t == .learned ? .learned : .added) }.count
                    return (t, t == .added ? L("Added \(n)") : (t == .learned ? L("Learned \(n)") : L("All \(n)")))
                }, selection: tab, inset: 3, padding: 8) { t in
                    model.animate(.swap) { model.dictionaryTab = t }
                }
            }
        } content: {
            SettingsCard {
                if readOnly {
                    SignedOutLine()
                    RowDivider()
                }
                if !all.isEmpty {
                    HStack(spacing: 8) {
                        SearchField(prompt: L("Search \(all.count.formatted()) words"), text: $panes.dictionarySearch)
                        if !readOnly {
                            TextButton("Add Word…") { panes.editingWord = .new() }
                        }
                    }
                    .cardPadding()
                    RowDivider()
                }
                if all.isEmpty {
                    VStack(spacing: 6) {
                        Text("No words yet").font(.system(size: 13, weight: .medium)).foregroundStyle(palette.secondary)
                        Text(readOnly ? L("Sign in to add the names, terms and acronyms you use.")
                                      : L("Add the names, terms and acronyms you use, or bring them in from another app."))
                            .font(.system(size: 12)).foregroundStyle(palette.tertiary)
                            .multilineTextAlignment(.center)
                        if !readOnly {
                            HStack(spacing: 8) {
                                TextButton("Add Word…") { panes.editingWord = .new() }
                                TextButton("Import…") { panes.importing = true }
                            }
                            .padding(.top, 6)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 150)
                } else if words.isEmpty {
                    Text("No matching words.").font(.system(size: 12.5)).foregroundStyle(palette.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                            ForEach(letters, id: \.self) { letter in
                                Section {
                                    ForEach(groups[letter] ?? []) { w in
                                        DictionaryRow(word: w, extras: panes.extras(w.id), readOnly: readOnly)
                                    }
                                } header: {
                                    Text(letter)
                                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(palette.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 3)
                                        .background(native ? palette.nativeGroup : palette.card)
                                }
                            }
                        }
                    }
                    .frame(height: 320)
                }
            } footer: {
                Text("✦ Learned: Fovea adds a word when you correct what it typed. A word that's off stays here, unused.")
            }
        }
        .sheet(item: $panes.editingWord) { draft in
            WordEditSheet(draft: draft)
                .environment(model)
                .environment(\.palette, palette)
                .foveaLanguage()
        }
        .onAppear { model.panes.loadWordExtras(model.foveaFolder) }

        // Oct 15 review, FR-30: words from other dictation apps, as the first run brings them in.
        SettingsSection("From other apps") {
            SettingsCard {
                SettingsRow("Bring in your words",
                            detail: "From Wispr Flow, Superwhisper, Typeless or your Mac's Text Replacements: a file, or a list pasted in.") {
                    TextButton("Import…") { panes.importing = true }
                        .disabled(readOnly)
                }
            }
        }
        .sheet(isPresented: $panes.importing) {
            ImportWordsSheet()
                .environment(model)
                .environment(\.palette, palette)
                .foveaLanguage()
        }
    }

    /// The section a word sorts under: its first letter, or # for the rest (numbers, 中文).
    static func letter(_ word: String) -> String {
        guard let c = word.first, c.isLetter, c.isASCII else { return "#" }
        return String(c).uppercased()
    }
}

/// The dictionary in other layouts (Account on the tabs, and Memory until Dictionary has its own
/// section in the sidebar): the pane itself.
struct DictionarySection: View {
    var body: some View { DictionaryPane() }
}

/// Signed out: why the list can't change, and the way to sign in.
private struct SignedOutLine: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock").foregroundStyle(palette.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("You're signed out").font(.system(size: 12.5, weight: .medium)).foregroundStyle(palette.text)
                Text("Your words stay on this Mac, to read. Sign in to change them.")
                    .font(.system(size: 11.5)).foregroundStyle(palette.secondary)
            }
            Spacer(minLength: 8)
            TextButton("Sign In…") { model.openSettings(.account) }
        }
        .cardPadding()
    }
}

/// A search field in a settings card.
struct SearchField: View {
    @Environment(\.palette) private var palette
    let prompt: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(palette.tertiary)
            TextField(L(key: prompt), text: $text).textFieldStyle(.plain)  // Oct 18, Ryan: in the primary language.
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(palette.tertiary) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
            }
        }
        .font(.system(size: 12.5))
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(palette.ink(T.Shade.fill)))
    }
}

/// One word: ✦ when learned, as Fovea writes it, the ways it's heard, when, and its On/Off. A
/// click opens it in the sheet (signed out, it doesn't).
private struct DictionaryRow: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let word: DictionaryWord
    let extras: WordExtras
    let readOnly: Bool
    @State private var hover = false

    var body: some View {
        let heard = (word.heardAs.map { [$0] } ?? []) + extras.variants
        HStack(spacing: 8) {
            Button {
                guard !readOnly else { return }
                model.panes.editingWord = WordDraft(word, extras: model.panes.wordExtras[word.id])
            } label: {
                HStack(spacing: 8) {
                    Text(word.source == .learned ? "✦" : " ")
                        .font(.system(size: 10)).foregroundStyle(palette.accent).frame(width: 12)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(word.word).font(.system(size: 13)).foregroundStyle(extras.on ? palette.text : palette.tertiary)
                        if !heard.isEmpty {
                            Text(L("heard as \(heard.map { "“\($0)”" }.joined(separator: L(", ")))"))
                                .font(.system(size: 11)).foregroundStyle(palette.tertiary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    Text(Lines.day(word.date)).font(.system(size: 11)).foregroundStyle(palette.tertiary).monospacedDigit()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(readOnly ? L("Sign in to change it") : L("Edit “\(word.word)”"))
            Toggle("Use “\(word.word)”", isOn: Binding(get: { extras.on }, set: { model.setWord(word.id, on: $0) }))
                .toggleStyle(.switch).controlSize(.mini).labelsHidden()
                .disabled(readOnly)
                .help(extras.on ? L("On: Fovea writes it your way") : L("Off: kept, not used"))
        }
        .padding(.horizontal, 12)
        .frame(height: heard.isEmpty ? 30 : 38)
        .background(hover && !readOnly ? palette.ink(0.04) : .clear)
        .onHover { hover = $0 }
    }
}

// MARK: - Edit a word (DI-01.2)

/// The word as Fovea writes it, the ways it's heard (each removable, one added at a time), and On
/// or Off; Delete for a word that's there.
struct WordEditSheet: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var draft: WordDraft
    @State private var newVariant = ""
    @State private var confirmDelete = false
    @FocusState private var wordFocused: Bool

    init(draft: WordDraft) { _draft = State(initialValue: draft) }

    var body: some View {
        let word = draft.word.trimmingCharacters(in: .whitespacesAndNewlines)
        let duplicate = model.library.dictionary.contains { $0.id != draft.id && $0.word.lowercased() == word.lowercased() }
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.isNew ? L("Add a Word") : L("Edit Word")).font(.system(size: 15, weight: .semibold))
            VStack(alignment: .leading, spacing: 5) {
                Text("Word").font(.system(size: 12, weight: .medium))
                TextField("As Fovea should write it", text: $draft.word)
                    .textFieldStyle(.roundedBorder)
                    .focused($wordFocused)
                if duplicate {
                    Text("“\(word)” is already in your dictionary.").font(.system(size: 11)).foregroundStyle(palette.danger)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Also heard as").font(.system(size: 12, weight: .medium))
                Text("What Fovea might hear instead. It writes the word for each.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(Array(draft.variants.enumerated()), id: \.offset) { i, v in
                        HStack {
                            Text(v).font(.system(size: 12.5))
                            Spacer()
                            Button { draft.variants.remove(at: i) } label: {
                                Image(systemName: "minus.circle").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Remove")
                            .accessibilityLabel("Remove \(v)")
                        }
                        .padding(.vertical, 5)
                        Divider()
                    }
                }
                HStack(spacing: 8) {
                    TextField("Add a way it's heard", text: $newVariant)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addVariant)
                    Button("Add", action: addVariant)
                        .disabled(newVariant.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("On").font(.system(size: 12.5))
                    Text(draft.on ? L("Fovea writes it your way.") : L("Kept here, not used.")).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("On", isOn: $draft.on).toggleStyle(.switch).labelsHidden()
            }
            if let learned = draft.learned {
                Text(learned).font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            HStack {
                if !draft.isNew {
                    Button("Delete Word…", role: .destructive) { confirmDelete = true }
                }
                Spacer()
                Button("Cancel") { model.panes.editingWord = nil }
                    .keyboardShortcut(.cancelAction)
                Button(draft.isNew ? L("Add") : L("Save")) {
                    if !newVariant.trimmingCharacters(in: .whitespaces).isEmpty { addVariant() }
                    model.saveWord(draft)
                    model.panes.editingWord = nil
                }
                .keyboardShortcut(.defaultAction)
                .disabled(word.isEmpty || duplicate)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear { if draft.isNew { wordFocused = true } }
        .alert("Delete “\(word)”?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                model.deleteWord(draft.id)
                model.panes.editingWord = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Fovea stops writing it your way.")
        }
    }

    private func addVariant() {
        let v = newVariant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !v.isEmpty, !draft.variants.contains(where: { $0.lowercased() == v.lowercased() }) else { newVariant = ""; return }
        draft.variants.append(v)
        newVariant = ""
    }
}

// MARK: - Import (FR-30)

/// A word brought in, and what it was heard as where the other app kept that.
struct ImportedEntry: Hashable {
    var word: String
    var heardAs: String?
}

/// What other dictation apps let people take out of them, read the way the first run's importer
/// reads it (OnboardingCore's `DictionaryImport`, which the window can't reach: Wiring needed):
/// a CSV (one column of words, or heard then written, as Wispr Flow imports), a text file or a
/// paste (one a line, "heard → word" keeps both), JSON (a list of words, or of objects), and the
/// property list the Mac's Text Replacements drag out. Cleaned: trimmed, no duplicates or words
/// already there, at most 1,000.
enum WordImport {
    static let limit = 1000

    static func parse(_ data: Data, filename: String) -> [ImportedEntry]? {
        switch (filename as NSString).pathExtension.lowercased() {
        case "csv", "tsv": return csv(String(decoding: data, as: UTF8.self))
        case "txt", "text", "md": return text(String(decoding: data, as: UTF8.self))
        case "json":
            guard let object = try? JSONSerialization.jsonObject(with: data) else { return [] }
            return entries(object)
        case "plist":
            guard let object = try? PropertyListSerialization.propertyList(from: data, format: nil) else { return [] }
            if let list = object as? [[String: Any]] { return list.compactMap { ($0["phrase"] as? String).map { ImportedEntry(word: $0) } } }
            return entries(object)
        default: return nil
        }
    }

    static func text(_ text: String) -> [ImportedEntry] {
        var lines = text.components(separatedBy: .newlines)
        if lines.filter({ !$0.trimmingCharacters(in: .whitespaces).isEmpty }).count == 1, let line = lines.first(where: { $0.contains(",") }) {
            lines = line.components(separatedBy: ",")
        }
        return lines.map { line in
            for arrow in ["→", "->", "=>", "\t"] where line.contains(arrow) {
                let parts = line.components(separatedBy: arrow)
                if parts.count >= 2 { return ImportedEntry(word: parts[1], heardAs: parts[0]) }
            }
            return ImportedEntry(word: line)
        }
    }

    static func csv(_ text: String) -> [ImportedEntry] {
        let headers: Set<String> = ["word", "words", "phrase", "term", "misspelling", "correction", "heard", "replacement", "from", "to"]
        var rows = text.components(separatedBy: .newlines).map { line in
            line.components(separatedBy: line.contains(",") ? "," : "\t").map {
                $0.trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "\"")))
            }.filter { !$0.isEmpty }
        }.filter { !$0.isEmpty }
        if let first = rows.first, first.contains(where: { headers.contains($0.lowercased()) }) { rows.removeFirst() }
        return rows.map { $0.count >= 2 ? ImportedEntry(word: $0[1], heardAs: $0[0]) : ImportedEntry(word: $0[0]) }
    }

    private static func entries(_ object: Any) -> [ImportedEntry] {
        if let strings = object as? [String] { return strings.map { ImportedEntry(word: $0) } }
        if let list = object as? [[String: Any]] {
            return list.compactMap { item in
                guard let word = ["word", "phrase", "text", "replacement", "to", "correction", "value", "term"]
                    .lazy.compactMap({ item[$0] as? String }).first else { return nil }
                return ImportedEntry(word: word, heardAs: ["find", "original", "from", "heard", "heardAs", "misspelling"]
                    .lazy.compactMap { item[$0] as? String }.first)
            }
        }
        if let dict = object as? [String: Any] {
            for key in ["words", "dictionary", "vocabulary", "replacements", "items", "entries", "terms"] {
                if let inner = dict[key] { return entries(inner) }
            }
        }
        return []
    }

    static func clean(_ words: [ImportedEntry], existing: Set<String>) -> (new: [ImportedEntry], known: Int) {
        var seen = Set(existing.map { $0.lowercased() })
        var out: [ImportedEntry] = []
        var known = 0
        for item in words {
            let word = tidy(item.word)
            guard !word.isEmpty, word.count <= 64 else { continue }
            guard !seen.contains(word.lowercased()) else { known += existing.contains { $0.lowercased() == word.lowercased() } ? 1 : 0; continue }
            seen.insert(word.lowercased())
            let heard = item.heardAs.map(tidy).flatMap { $0.isEmpty || $0.lowercased() == word.lowercased() ? nil : $0 }
            out.append(ImportedEntry(word: word, heardAs: heard))
            if out.count == limit { break }
        }
        return (out, known)
    }

    private static func tidy(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"“”'")))
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}

/// Bring words in: choose a file, or paste a list; see what's new before it's added.
struct ImportWordsSheet: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var pasted = ""
    @State private var fromFile: [ImportedEntry]?
    @State private var fileName: String?
    @State private var unreadable = false

    var body: some View {
        let existing = Set(model.library.dictionary.map(\.word))
        let raw = fromFile ?? WordImport.text(pasted)
        let (new, known) = WordImport.clean(raw, existing: existing)
        VStack(alignment: .leading, spacing: 14) {
            Text("Import Words").font(.system(size: 15, weight: .semibold))
            Text("Bring in the words you taught another dictation app, or a list of your own.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button("Choose File…", action: choose)
                if let fileName {
                    Label(fileName, systemImage: "doc").font(.system(size: 12)).lineLimit(1)
                    Button { self.fileName = nil; fromFile = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove the file")
                }
            }
            Text("Wispr Flow's CSV, a text file, JSON, or your Mac's Text Replacements (drag them from System Settings › Keyboard to a file).")
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if unreadable {
                Text("Fovea can't read that file. Choose a .csv, .txt, .json or .plist.")
                    .font(.system(size: 11)).foregroundStyle(palette.danger)
            }
            if fromFile == nil {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Or paste them, one a line (“heard → word” keeps both):").font(.system(size: 12))
                    TextEditor(text: $pasted)
                        .font(.system(size: 12.5))
                        .frame(height: 96)
                        .padding(4)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.35), lineWidth: 0.5))
                }
            }
            if !new.isEmpty || known > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Text((new.count == 1 ? L("1 new word") : L("\(new.count) new words"))
                         + (known > 0 ? " · " + L("\(known) already in your dictionary") : ""))
                        .font(.system(size: 12, weight: .medium))
                    Text(new.prefix(8).map { e in e.heardAs.map { h in L("\(e.word) (heard as “\(h)”)") } ?? e.word }.joined(separator: L(", "))
                         + (new.count > 8 ? L(", and \(new.count - 8) more") : ""))
                        .font(.system(size: 11.5)).foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { model.panes.importing = false }.keyboardShortcut(.cancelAction)
                Button(new.isEmpty ? L("Import") : (new.count == 1 ? L("Import 1 Word") : L("Import \(new.count) Words"))) {
                    model.importWords(new)
                    model.panes.importing = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(new.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.title = L("Choose Your Words")
        panel.allowedContentTypes = [.commaSeparatedText, .tabSeparatedText, .plainText, .json, .propertyList]
            + [UTType(filenameExtension: "md")].compactMap { $0 }
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else { return }
        if let words = WordImport.parse(data, filename: url.lastPathComponent) {
            fromFile = words
            fileName = url.lastPathComponent
            unreadable = false
        } else {
            unreadable = true
        }
    }
}
