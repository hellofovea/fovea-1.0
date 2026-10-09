import Foundation

// Fovea's keys, once, for every surface: Settings › Shortcuts draws them, the island acts on
// them, the onboarding teaches them (OnboardingCore's KeyMap spells the same caps; a test holds
// the two together). Round two of the Oct 6 feedback, as the Workbench and the onboarding have it:
// ⌘ takes a region (twice, the whole screen), left ⌥ is the highlighter, fn is Voiceflow, fn ⌃ is
// Dispatch. Left ⌃ alone works inside Choose chat and a session; the board opens by hover only
// (Oct 9).

/// One shortcut as Settings shows it: what it does, in a line, and its caps.
public struct FoveaShortcut: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let keys: [String]
    /// "×2" on the cap: pressed twice.
    public let presses: Int

    public init(id: String, title: String, detail: String, keys: [String], presses: Int = 1) {
        self.id = id; self.title = title; self.detail = detail; self.keys = keys; self.presses = presses
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
        detail: "Press ⌘, then drag over what to take. Hold ⌘ to take more than one.", keys: ["⌘"])
    public static let wholeScreen = FoveaShortcut(id: "wholeScreen", title: "Take the whole screen",
        detail: "Press ⌘ twice.", keys: ["⌘"], presses: 2)
    public static let highlighter = FoveaShortcut(id: "highlighter", title: "Highlight words or a file",
        detail: "Press left ⌥, then drag across words, or click a paragraph or a file.", keys: ["⌥"])

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
