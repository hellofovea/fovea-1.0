import Foundation

/// What one press of the hotkey made. Two kinds (the App UI review, Oct 6, row 30): what you said
/// went into the app in front of you, or to an agent. Taking things off the screen while you speak
/// doesn't make a third kind; a dictation keeps what you took too.
public enum CaptureKind: String, Codable, CaseIterable, Hashable, Sendable {
    /// You spoke, and maybe took things off the screen (a region, a passage, a file); Fovea put
    /// your words, with what you took, into the app in front of you.
    case dictation
    /// You spoke (and maybe took things); Fovea sent it to an agent to do or to answer. A quick
    /// question is a dispatch too.
    case dispatch

    public var title: String {
        switch self {
        case .dictation: return "Dictation"
        case .dispatch: return "Dispatch"
        }
    }

    public var plural: String {
        switch self {
        case .dictation: return "Dictations"
        case .dispatch: return "Dispatches"
        }
    }
}

/// An app on this Mac, by bundle identifier (its icon comes from the system).
public struct AppRef: Codable, Hashable, Sendable {
    public var name: String
    public var bundleID: String
    public init(_ name: String, _ bundleID: String) { self.name = name; self.bundleID = bundleID }
}

/// Where a dispatch went: an agent, the chat inside it, and the turn this request started, so
/// opening it lands on that place in the chat (row 27).
public struct Destination: Codable, Hashable, Sendable {
    public var agent: String
    public var chat: String
    public var turn: Int
    public init(_ agent: String, chat: String, turn: Int = 1) { self.agent = agent; self.chat = chat; self.turn = turn }
}

/// A part of a rect, in unit coordinates (0…1, top-left origin).
public struct UnitRect: Codable, Hashable, Sendable {
    public var x: Double, y: Double, w: Double, h: Double
    public init(_ x: Double, _ y: Double, _ w: Double, _ h: Double) { self.x = x; self.y = y; self.w = w; self.h = h }
    public static let full = UnitRect(0, 0, 1, 1)
}

/// One thing you took while speaking, numbered by the order you took it, and remembered at
/// the place in your words where you took it ("…this one [2] …").
public struct Attachment: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Hashable, Sendable {
        /// A region of the screen you dragged over.
        case region
        /// A passage of text you clicked.
        case passage
        /// A file you clicked.
        case file
    }

    public var index: Int
    public var kind: Kind
    /// UTF-16 offset into the capture's `text`: where you were in your sentence when you took it.
    public var anchor: Int
    /// How many UTF-16 units before the anchor are the words you pointed with ("this one",
    /// "这一屏"): the Binding, drawn so you can see which words meant which thing. 0 when an
    /// earlier attachment's words already cover it ("these three files ⟨1⟩⟨2⟩⟨3⟩").
    public var bound: Int = 0
    /// Region: the drawn screen it was taken from, and the part of it, in unit coordinates.
    public var art: String?
    public var crop: UnitRect
    /// Region: the text read off it. Passage: the passage. File: its name.
    public var text: String
    /// File: its filename extension ("pdf", "csv").
    public var fileType: String?
    /// Where it was taken: a window's title, or the folder of a file.
    public var source: String

    public init(_ index: Int, _ kind: Kind, anchor: Int, art: String? = nil, crop: UnitRect = .full,
                text: String, fileType: String? = nil, source: String) {
        self.index = index; self.kind = kind; self.anchor = anchor; self.art = art; self.crop = crop
        self.text = text; self.fileType = fileType; self.source = source
    }
}

public struct Capture: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var kind: CaptureKind
    public var time: Date
    /// The app in front when you pressed the hotkey.
    public var app: AppRef
    /// The words as Fovea put them: the typed text, the inserted note, the request it sent. Empty
    /// while it failed (`failure`).
    public var text: String
    /// What you took, in order, each anchored in `text`.
    public var attachments: [Attachment]
    /// Dispatch: where it went. Kept, searchable, not shown on the card.
    public var destination: Destination?
    /// Three or four words naming what it's about, for the header option that shows one.
    public var theme: String
    /// Seconds of speech: the recording's length. Every capture keeps its recording (row 28), until
    /// the history setting lets it go, so it can be played, saved, and transcribed again.
    public var seconds: Double
    /// In a browser: the website you were on, by its domain ("chatgpt.com"), so words said into
    /// ChatGPT in Chrome are told from Chrome (row 38).
    public var site: String?
    /// What it's about, a word or two each, given by Fovea and yours to change. The filter picks
    /// by them, and Memory's areas read from them (row 25).
    public var tags: [String]
    /// Set when your words never came back (the network dropped, the service didn't answer). The
    /// recording is kept, so it can be transcribed again; `text` is empty until it is.
    public var failure: String?

    public init(id: String, kind: CaptureKind, time: Date, app: AppRef, text: String,
                attachments: [Attachment] = [], destination: Destination? = nil, theme: String, seconds: Double,
                site: String? = nil, tags: [String] = [], failure: String? = nil) {
        self.id = id; self.kind = kind; self.time = time; self.app = app; self.text = text
        self.attachments = attachments; self.destination = destination; self.theme = theme; self.seconds = seconds
        self.site = site; self.tags = tags; self.failure = failure
    }

    /// The words never came back; the recording waits to be transcribed again.
    public var failed: Bool { failure != nil }

    /// The text cut at its attachments: text runs, each followed by the attachments taken at its
    /// end. The card and the expanded view both draw from this, so a chip always sits where it
    /// was taken.
    public var segments: [Segment] {
        let ns = text as NSString
        var out: [Segment] = []
        var cursor = 0
        for a in attachments.sorted(by: { ($0.anchor, $0.index) < ($1.anchor, $1.index) }) {
            let at = min(max(a.anchor, cursor), ns.length)
            if at > cursor {
                out.append(.run(location: cursor, text: ns.substring(with: NSRange(location: cursor, length: at - cursor))))
            }
            out.append(.attachment(a))
            cursor = at
        }
        if cursor < ns.length || out.isEmpty {
            out.append(.run(location: cursor, text: ns.substring(from: cursor)))
        }
        return out
    }

    public enum Segment: Hashable, Sendable {
        /// A run of text, and where it starts in `text` (UTF-16), for search's ranges.
        case run(location: Int, text: String)
        case attachment(Attachment)

        public var isRun: Bool { if case .run = self { return true } else { return false } }
    }

    public var wordCount: Int { text.split(whereSeparator: { $0.isWhitespace }).count }

    /// Where the words went, by name: the agent a dispatch went to, otherwise the app in front, and
    /// in a browser the website too ("Chrome · chatgpt.com"). What the card's icon shows, and what
    /// the app filter picks from.
    public var target: String {
        if kind == .dispatch, let d = destination { return d.agent }
        if let site { return "\(app.name) · \(site)" }
        return app.name
    }
}

/// A word Fovea writes your way: added by you, or learned from a correction you made.
public struct DictionaryWord: Identifiable, Codable, Hashable, Sendable {
    public enum Source: String, Codable, Hashable, Sendable { case learned, added }
    public var id: String
    public var word: String
    /// What Fovea used to hear instead, when it learned from a correction.
    public var heardAs: String?
    public var source: Source
    public var date: Date
    /// Learned: where the correction happened.
    public var learnedIn: String?

    public init(id: String, word: String, heardAs: String? = nil, source: Source, date: Date, learnedIn: String? = nil) {
        self.id = id; self.word = word; self.heardAs = heardAs; self.source = source; self.date = date; self.learnedIn = learnedIn
    }
}

/// One thing Fovea keeps, raw: something you told it to remember, or something it read from what
/// you sent your agents, with the words it came from and the capture they were in. Memory's areas
/// are summaries of these; this is the record under them (row 24).
public struct Memory: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var text: String
    public var quote: String
    public var date: Date
    /// An app or a project it applies to; nil everywhere.
    public var scope: String?
    /// The capture it came from, if it's still in your history.
    public var captureID: String?
    /// The area of your life it belongs to (`MemoryArea.id`), and the tags it carries.
    public var area: String?
    public var tags: [String]
    /// You said "remember…" (true), or Fovea read it from what you sent (false).
    public var stated: Bool
    /// Kept from agents: Fovea still uses it, but an agent reading Fovea's memory doesn't see it.
    public var hidden: Bool
    /// Deleted, and when: restorable for 30 days.
    public var deleted: Date?

    public init(id: String, text: String, quote: String, date: Date, scope: String? = nil,
                captureID: String? = nil, area: String? = nil, tags: [String] = [], stated: Bool = true,
                hidden: Bool = false, deleted: Date? = nil) {
        self.id = id; self.text = text; self.quote = quote; self.date = date; self.scope = scope
        self.captureID = captureID; self.area = area; self.tags = tags; self.stated = stated
        self.hidden = hidden; self.deleted = deleted
    }
}

/// One part of your life Fovea has come to know from what you send your agents (work, interests,
/// money…): a short summary in its words, which you can correct or forget, the tags it was read
/// from, and when it last changed (row 24, after Claude's memory topics).
public struct MemoryArea: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    /// An SF Symbol, for the area's tile.
    public var symbol: String
    public var summary: String
    /// The tags it reads from: a tag that keeps coming up becomes part of the summary.
    public var tags: [String]
    public var updated: Date

    public init(id: String, title: String, symbol: String, summary: String, tags: [String], updated: Date) {
        self.id = id; self.title = title; self.symbol = symbol; self.summary = summary; self.tags = tags; self.updated = updated
    }
}

/// The plan's credits.
public struct Usage: Codable, Hashable, Sendable {
    public var plan: String
    public var used: Int
    public var total: Int
    public var resets: Date

    public init(plan: String, used: Int, total: Int, resets: Date) {
        self.plan = plan; self.used = used; self.total = total; self.resets = resets
    }

    public var left: Int { max(0, total - used) }
    public var fraction: Double { total == 0 ? 0 : min(1, Double(used) / Double(total)) }
}

public struct Library: Hashable, Sendable {
    public var now: Date
    public var captures: [Capture]
    public var dictionary: [DictionaryWord]
    public var memories: [Memory]
    public var usage: Usage
    public var areas: [MemoryArea]

    public init(now: Date, captures: [Capture], dictionary: [DictionaryWord], memories: [Memory], usage: Usage,
                areas: [MemoryArea] = []) {
        self.now = now; self.captures = captures; self.dictionary = dictionary; self.memories = memories; self.usage = usage
        self.areas = areas
    }
}
