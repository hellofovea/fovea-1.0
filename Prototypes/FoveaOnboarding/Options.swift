import Foundation
import OnboardingCore

/// The command line:
/// - `--step=<id>` starts at a step (`hello`, `makeItYours`, `permissions`, … `home`);
/// - `--snapshot <dir> [--only <prefix>]` renders every step's moments to PNGs and quits;
/// - `--smoke` walks the whole first run with simulated presses and prints `SMOKE PASS`;
/// - `--play` plays the whole first run by itself, the pointer and the keys shown;
///   `--play-from=arrive|turnOn|agents|pointAndSay|dictation|home` from a stage;
/// - `--pace=<x>` scales every wait (0.5 is twice as fast);
/// - `--practice-agent` never calls the real Claude Code;
/// - `--no-typing` shows lines whole instead of typing them out;
/// - `--mute` starts without sound. `FOVEA_NO_ACTIVATE=1` keeps the window in the background.
struct Options {
    var step: Step?
    var snapshotDir: URL?
    var only: String?
    var smoke = false
    var play = false
    var playFrom: String?
    var pace: Double?
    /// Never call the real agent (tests): the practice agent answers.
    var practiceAgent = false
    var noTyping = false
    var mute = false
    var noActivate = ProcessInfo.processInfo.environment["FOVEA_NO_ACTIVATE"] == "1"

    /// Snapshot or smoke: no sound, no real key monitors, no waiting.
    var harness: Bool { snapshotDir != nil || smoke }

    /// The stages by the names `--play-from` takes.
    static let stages: [String: Stage] = ["arrive": .arrive, "turnOn": .turnOn, "agents": .agents,
                                          "pointAndSay": .pointAndSay, "dictation": .dictation, "home": .home]

    static func parse(_ args: [String] = CommandLine.arguments) -> Options {
        var o = Options()
        func value(after flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        for arg in args where arg.hasPrefix("--step=") {
            o.step = Step(rawValue: String(arg.dropFirst("--step=".count)))
        }
        if let dir = value(after: "--snapshot") { o.snapshotDir = URL(fileURLWithPath: dir, isDirectory: true) }
        o.only = value(after: "--only")
        o.smoke = args.contains("--smoke")
        o.play = args.contains("--play")
        for arg in args where arg.hasPrefix("--play-from=") { o.playFrom = String(arg.dropFirst("--play-from=".count)); o.play = true }
        for arg in args where arg.hasPrefix("--pace=") { o.pace = Double(arg.dropFirst("--pace=".count)) }
        o.practiceAgent = args.contains("--practice-agent")
        o.noTyping = args.contains("--no-typing")
        o.mute = args.contains("--mute")
        return o
    }
}
