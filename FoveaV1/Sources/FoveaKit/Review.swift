import Foundation

// The dev team's review of Oct 15 (their workbook "Fovea 全应用 UI 新旧图文对照与替换评审", and
// docs/v1/REVIEW_2026-10-15.md): every case it found missing, built in Fovea's own design. With
// `--review`, a Review menu stages each state the review added that using the app wouldn't show
// on demand (a failure, a trial that ended, a session that can't be restored). Each surface
// registers its own when it starts. (The orange tags on each change were removed on Oct 17.)

public enum Review {
    /// The Review menu's sections, in the order of a walk through the app.
    public enum Area: String, CaseIterable, Sendable {
        case firstRun = "First Run"
        case home = "Home"
        case settings = "Settings"
        case notch = "Notch"
        case menuBar = "Menu Bar & System"
    }

    /// One state the Review menu can stage.
    public struct Stage: Identifiable {
        /// The workbook's ID (MW-02a, QA24…), shown in the menu beside the title.
        public let id: String
        public let title: String
        public let area: Area
        public let run: @MainActor () -> Void
    }

    @MainActor public private(set) static var stages: [Stage] = []

    /// Registers a state to stage. A second registration under the same ID and title replaces the
    /// first (a surface that starts again).
    @MainActor public static func stage(_ id: String, _ title: String, area: Area, run: @escaping @MainActor () -> Void) {
        stages.removeAll { $0.id == id && $0.title == title }
        stages.append(Stage(id: id, title: title, area: area, run: run))
    }
}
