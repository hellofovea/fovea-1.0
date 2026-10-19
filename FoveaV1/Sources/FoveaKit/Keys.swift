import Foundation

// Fovea's keys, once, for every surface: Settings › Shortcuts draws them, the island acts on
// them, the onboarding teaches them (OnboardingCore's KeyMap spells the same caps; a test holds
// the two together). Round two of the Oct 6 feedback, as the Workbench and the onboarding have it:
// ⌘ takes a region (twice, the whole screen), left ⌥ is the highlighter, fn is Voiceflow, fn ⌃ is
// Dispatch. Left ⌃ alone works inside Choose chat and a session; the board opens by hover only
// (Oct 9). Oct 17 (Ryan): ⌥ takes a region (twice, the whole screen) instead of ⌘, which Codex
// uses; words and files need no key at all: while Fovea listens, selecting words or clicking a
// file takes them, in Voiceflow as in Dispatch. Later on Oct 17 (Ryan): ⌥ pressed twice is the
// Claude app's own shortcut, so ⌥ is one press only (part of the screen; no whole-screen press),
// and a file is taken by dragging it onto the notch (a click may mean opening it).

/// One shortcut as Settings shows it: what it does, in a line, and its caps.
public struct FoveaShortcut: Identifiable, Equatable, Sendable {
    public let id: String
    /// The English as written; `title` and `detail` are in the primary language (Oct 18).
    public let englishTitle: String
    public let englishDetail: String
    public let keys: [String]
    /// "×2" on the cap: pressed twice.
    public let presses: Int
    public var title: String { L(key: englishTitle) }
    public var detail: String { L(key: englishDetail) }

    public init(id: String, title: String, detail: String, keys: [String], presses: Int = 1) {
        self.id = id; self.englishTitle = title; self.englishDetail = detail; self.keys = keys; self.presses = presses
    }
}

public enum FoveaKeys {
    /// The two keys you use every day. Press once to start, again to stop.
    public static let voiceflow = FoveaShortcut(id: "voiceflow", title: "Voice Flow",
        detail: "Speak, and Fovea types it into the app in front of you.", keys: ["fn"])
    public static let dispatch = FoveaShortcut(id: "dispatch", title: "Dispatch",
        detail: "Send what you say, and what you point at, to Claude Code or Codex.", keys: ["fn", "⌃"])

    /// While you speak.
    public static let region = FoveaShortcut(id: "region", title: "Take part of the screen",
        detail: "Press ⌥, then drag over what to take. Hold ⌥ to take more than one.", keys: ["⌥"])
    /// Oct 18 (Ryan): ⌘ pressed twice takes the whole screen (⌥ twice is the Claude app's). Fixed,
    /// not recorded: a double press, which the recorder doesn't take.
    public static let wholeScreen = FoveaShortcut(id: "wholeScreen", title: "Take the whole screen",
        detail: "Press ⌘ twice.", keys: ["⌘"], presses: 2)
    /// No key (Oct 17): while Fovea listens, words you select are taken, and a file you drag onto
    /// the notch.
    public static let highlighter = FoveaShortcut(id: "highlighter", title: "Take words or a file",
        detail: "While Fovea listens, select words, or drag a file onto the notch. No key needed.", keys: [])

    /// In the notch.
    public static let allChats = FoveaShortcut(id: "allChats", title: "Every chat",
        detail: "In Choose chat, press left ⌃ by itself for every chat by agent.", keys: ["⌃"])
    public static let escape = FoveaShortcut(id: "escape", title: "Step back or cancel",
        detail: "Closes what's open, or cancels while Fovea listens.", keys: ["esc"])
    public static let undo = FoveaShortcut(id: "undo", title: "Undo a cancel",
        detail: "For a moment after you cancel.", keys: ["⌘", "Z"])

    public static let daily = [voiceflow, dispatch]
    public static let whileSpeaking = [region, wholeScreen, highlighter]
    public static let inTheNotch = [allChats, escape, undo]
    public static let all = daily + whileSpeaking + inTheNotch

    /// The shortcuts a person can record (Oct 15, the dev team's review ST-03.1), and what each is
    /// until they do. A cleared shortcut is kept as a chord with no keys: it does nothing.
    /// Oct 17: the highlighter has no key any more (taking words and files is automatic).
    public static let changeable = [voiceflow, dispatch, region]
    public static let defaultChords: [String: KeyChord] = [
        voiceflow.id: KeyChord(modifiers: ["fn"]),
        dispatch.id: KeyChord(modifiers: ["fn", "⌃"]),
        region.id: KeyChord(modifiers: ["⌥"]),
    ]

    /// The chord a shortcut answers to now: the recorded one, or its default.
    public static func chord(_ id: String, _ prefs: FoveaPrefs) -> KeyChord? {
        guard changeable.contains(where: { $0.id == id }) else { return nil }
        return prefs.shortcutChords[id] ?? defaultChords[id]
    }

    /// A press is shorter than this, with nothing pressed or clicked during it.
    public static let tapLength: TimeInterval = 0.3
    /// Two presses within this are a double press.
    public static let doubleTapWindow: TimeInterval = 0.35
}

/// A modifier key's presses, apart from any event source: down, then up as a tap (short, nothing
/// else pressed or clicked) or a hold, and two taps close together as a double press. The island's
/// monitors feed it; the tests feed it times.
public struct ModifierGesture: Sendable {
    public enum Edge: Equatable, Sendable { case down, up(tap: Bool), doublePress }

    public private(set) var isDown = false
    private var downAt: TimeInterval = 0
    private var usedWithKey = false
    private var lastTap: TimeInterval?

    public init() {}

    /// The key went down at `t` (seconds).
    public mutating func down(at t: TimeInterval) -> [Edge] {
        guard !isDown else { return [] }
        isDown = true
        downAt = t
        usedWithKey = false
        return [.down]
    }

    /// Another key or a click while it's down: a hold, not a tap.
    public mutating func used() {
        if isDown { usedWithKey = true }
    }

    /// The key came up at `t`.
    public mutating func up(at t: TimeInterval) -> [Edge] {
        guard isDown else { return [] }
        isDown = false
        let tap = !usedWithKey && t - downAt < FoveaKeys.tapLength
        var edges: [Edge] = [.up(tap: tap)]
        guard tap else { lastTap = nil; return edges }
        if let last = lastTap, t - last < FoveaKeys.doubleTapWindow {
            lastTap = nil
            edges.append(.doublePress)
        } else {
            lastTap = t
        }
        return edges
    }
}
