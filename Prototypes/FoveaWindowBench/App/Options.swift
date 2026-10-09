import Foundation
import WindowBenchCore

/// What the bench was launched to do.
struct BenchOptions {
    var snapshotDirectory: URL?
    var snapshotFilter: String?
    var smoke = false
    var dumpMenus = false
    var recordURL: URL?
    var play: String?
    var route: String?
    var fixture: FixtureSet?
    var source: DataSource?
    /// Start from the defaults instead of the saved state (the saved state is left alone).
    var fresh = false
    var noActivate = ProcessInfo.processInfo.environment["FOVEA_NO_ACTIVATE"] != nil
    /// `--set drill=notchExpand --set reveal=fromSummary`: variants for this launch.
    var variants: [String: String] = [:]
    /// `--speed 0.5`
    var speed: Double?
    /// `--appearance light|dark|system`
    var appearance: BenchAppearance?

    /// Snapshots, the smoke run and recordings never read or write Ryan's saved choices.
    var isAutomated: Bool { snapshotDirectory != nil || smoke || recordURL != nil || dumpMenus }

    static func parse(_ args: [String] = CommandLine.arguments) -> BenchOptions {
        var o = BenchOptions()
        func value(after flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), args.count > i + 1 else { return nil }
            return args[i + 1]
        }
        if let dir = value(after: "--snapshot") { o.snapshotDirectory = URL(fileURLWithPath: dir, isDirectory: true) }
        o.snapshotFilter = value(after: "--only")
        o.smoke = args.contains("--smoke")
        o.dumpMenus = args.contains("--dump-menus")
        if let file = value(after: "--record") { o.recordURL = URL(fileURLWithPath: file) }
        o.play = value(after: "--play")
        o.route = value(after: "--route")
        o.fixture = value(after: "--fixture").flatMap(FixtureSet.init(rawValue:))
        if value(after: "--source") == "mac" { o.source = .thisMac }
        o.fresh = args.contains("--fresh")
        for (i, arg) in args.enumerated() where arg == "--set" && args.count > i + 1 {
            let pair = args[i + 1].split(separator: "=", maxSplits: 1).map(String.init)
            if pair.count == 2 { o.variants[pair[0]] = pair[1] }
        }
        o.speed = value(after: "--speed").flatMap(Double.init)
        o.appearance = value(after: "--appearance").flatMap(BenchAppearance.init(rawValue:))
        return o
    }
}
