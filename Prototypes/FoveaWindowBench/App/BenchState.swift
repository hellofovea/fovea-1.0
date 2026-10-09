import Foundation
import WindowBenchCore

enum WindowSection: String, Codable, CaseIterable, Hashable {
    case project, capture

    var title: String { self == .project ? "Project" : "Capture" }
}

/// One level of the window, drilled into in place.
enum Level: Codable, Hashable {
    case projects
    case project(String)
    case run(String)
    case captures
    case capture(String)

    var key: String {
        switch self {
        case .projects: return "projects"
        case .project(let id): return "project/\(id)"
        case .run(let id): return "run/\(id)"
        case .captures: return "captures"
        case .capture(let id): return "capture/\(id)"
        }
    }
}

/// A level and the row it was opened from, so going back can land on that row.
struct PathEntry: Codable, Hashable, Identifiable {
    var level: Level
    var sourceKey: String?
    var id: String { level.key }
}

enum OnboardingStep: String, Codable, CaseIterable, Hashable {
    case consent, scanning, reveal, merge, nothingFound, handoff

    var title: String {
        switch self {
        case .consent: return "Consent"
        case .scanning: return "Scanning"
        case .reveal: return "Reveal"
        case .merge: return "Merge suggestion"
        case .nothingFound: return "Skipped / nothing found"
        case .handoff: return "Hand-off to the notch"
        }
    }
}

enum DataSource: String, Codable, CaseIterable, Hashable {
    case fixtures, thisMac

    var title: String { self == .fixtures ? "Fixtures" : "This Mac" }
}

enum BenchAppearance: String, Codable, CaseIterable, Hashable {
    case system, light, dark

    var title: String { rawValue.capitalized }
}

enum WindowSizePreset: String, Codable, CaseIterable, Hashable {
    case fit, large, compact

    var title: String {
        switch self {
        case .fit: return "Fit beside panel"
        case .large: return "1240 × 820"
        case .compact: return "1000 × 660"
        }
    }
}

enum SettingsTab: String, Codable, CaseIterable, Hashable {
    case general, notch, connections, memory

    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .notch: return "rectangle.topthird.inset.filled"
        case .connections: return "point.3.connected.trianglepath.dotted"
        case .memory: return "text.book.closed"
        }
    }
}

/// Everything the bench remembers between launches. Snapshots and the smoke run use their own
/// stores, so they never touch Ryan's choices.
struct BenchState: Codable, Hashable {
    var variants = VariantValues()
    var revealStaggerMS = BenchTokens.MotionValues.revealDefault
    var highlightSeconds = BenchTokens.MotionValues.highlightDefault
    var speed = 1.0
    var reduceMotion = false
    var appearance = BenchAppearance.system
    var windowSize = WindowSizePreset.fit
    var source = DataSource.fixtures
    var fixture = FixtureSet.typical
    var section = WindowSection.project
    var projectPath: [PathEntry] = [PathEntry(level: .projects)]
    var capturePath: [PathEntry] = [PathEntry(level: .captures)]
    /// Set while onboarding shows; nil once it's done.
    var onboarding: OnboardingStep? = .consent
    var labNotch = true
    var compare = false
    var otherNotchApp = false
    var calendarGranted = false
    /// Calendar access was asked for and refused (simulated).
    var calendarDenied = false
    var panelCollapsed = false
    /// The top visible row of each level, by level key.
    var scrollAnchors: [String: String] = [:]
    var settings = BenchSettings()

    init() {}

    /// Every field falls back to its default when it's missing, so a new field never throws away
    /// the choices saved before it existed.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = BenchState()
        variants = (try? c.decodeIfPresent(VariantValues.self, forKey: .variants)) ?? d.variants
        revealStaggerMS = (try? c.decodeIfPresent(Double.self, forKey: .revealStaggerMS)) ?? d.revealStaggerMS
        highlightSeconds = (try? c.decodeIfPresent(Double.self, forKey: .highlightSeconds)) ?? d.highlightSeconds
        speed = (try? c.decodeIfPresent(Double.self, forKey: .speed)) ?? d.speed
        reduceMotion = (try? c.decodeIfPresent(Bool.self, forKey: .reduceMotion)) ?? d.reduceMotion
        appearance = (try? c.decodeIfPresent(BenchAppearance.self, forKey: .appearance)) ?? d.appearance
        windowSize = (try? c.decodeIfPresent(WindowSizePreset.self, forKey: .windowSize)) ?? d.windowSize
        source = (try? c.decodeIfPresent(DataSource.self, forKey: .source)) ?? d.source
        fixture = (try? c.decodeIfPresent(FixtureSet.self, forKey: .fixture)) ?? d.fixture
        section = (try? c.decodeIfPresent(WindowSection.self, forKey: .section)) ?? d.section
        projectPath = (try? c.decodeIfPresent([PathEntry].self, forKey: .projectPath)) ?? d.projectPath
        capturePath = (try? c.decodeIfPresent([PathEntry].self, forKey: .capturePath)) ?? d.capturePath
        // Saved without the key once onboarding is done (a nil optional isn't written): missing is nil.
        onboarding = (try? c.decodeIfPresent(OnboardingStep.self, forKey: .onboarding)) ?? nil
        labNotch = (try? c.decodeIfPresent(Bool.self, forKey: .labNotch)) ?? d.labNotch
        compare = (try? c.decodeIfPresent(Bool.self, forKey: .compare)) ?? d.compare
        otherNotchApp = (try? c.decodeIfPresent(Bool.self, forKey: .otherNotchApp)) ?? d.otherNotchApp
        calendarGranted = (try? c.decodeIfPresent(Bool.self, forKey: .calendarGranted)) ?? d.calendarGranted
        calendarDenied = (try? c.decodeIfPresent(Bool.self, forKey: .calendarDenied)) ?? d.calendarDenied
        panelCollapsed = (try? c.decodeIfPresent(Bool.self, forKey: .panelCollapsed)) ?? d.panelCollapsed
        scrollAnchors = (try? c.decodeIfPresent([String: String].self, forKey: .scrollAnchors)) ?? d.scrollAnchors
        settings = (try? c.decodeIfPresent(BenchSettings.self, forKey: .settings)) ?? d.settings
    }
}
