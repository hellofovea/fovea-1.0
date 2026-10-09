import Foundation

/// The project list's groups, in the brief's order: stuck → to look at → running → earlier.
/// `failed` exists only for the notch's order, where Failed comes after Working (PRD §4).
public enum ProjectGroup: String, CaseIterable, Codable, Hashable, Sendable {
    case stuck, toLook, running, failed, earlier

    public var title: String {
        switch self {
        case .stuck: return "Stuck"
        case .toLook: return "To look at"
        case .running: return "Running"
        case .failed: return "Failed"
        case .earlier: return "Earlier"
        }
    }
}

/// Where a failed project sits: with the stuck ones (the brief) or last, after running (the notch).
public enum FailedPlacement: String, Codable, Hashable, Sendable {
    case withStuck, last
}

public struct ProjectSummary: Identifiable, Hashable, Sendable {
    public var project: Project
    /// The most urgent state among the project's runs; nil when it has none.
    public var state: RunState?
    public var meta: String
    public var lastActivity: Date
    public var group: ProjectGroup
    /// Quiet for long enough to fold into "N older projects". Still searchable.
    public var sunk: Bool

    public var id: String { project.id }
}

/// One item of the project list. Headers are items too, so a row moving between groups keeps
/// its identity and animates instead of being removed and inserted.
public enum ProjectListItem: Identifiable, Hashable, Sendable {
    case header(ProjectGroup)
    case project(ProjectSummary)
    case olderFold(count: Int)

    public var id: String {
        switch self {
        case .header(let group): return "header/\(group.rawValue)"
        case .project(let summary): return "project/\(summary.id)"
        case .olderFold: return "older-fold"
        }
    }
}

public enum ProjectIndex {
    /// Projects quiet for this long sink into the older fold.
    public static let sinkAfter: TimeInterval = 7 * 86_400

    public static func mostUrgent(_ runs: [Run]) -> RunState? {
        runs.min { $0.state.urgency < $1.state.urgency }?.state
    }

    public static func group(for state: RunState?, failed: FailedPlacement) -> ProjectGroup {
        switch state {
        case .waiting?: return .stuck
        case .failed?: return failed == .withStuck ? .stuck : .failed
        case .finished?: return .toLook
        case .running?: return .running
        case .unobserved?, .seen?, nil: return .earlier
        }
    }

    public static func summaries(_ index: LibraryIndex, failed: FailedPlacement) -> [ProjectSummary] {
        index.library.projects.map { project in
            let runs = index.runs(inProject: project.id)
            let state = mostUrgent(runs)
            let last = runs.map(\.lastActivity).max() ?? project.scan?.lastActive ?? .distantPast
            let group = group(for: state, failed: failed)
            let sunk = group == .earlier && index.now.timeIntervalSince(last) > sinkAfter
            return ProjectSummary(project: project, state: state, meta: Lines.projectMeta(project, index: index),
                                  lastActivity: last, group: group, sunk: sunk)
        }
    }

    /// The list as drawn: each non-empty group's header and its projects, newest activity first;
    /// sunk projects behind one fold row, listed after it when it is open. Every project appears
    /// in exactly one group; there is never a catch-all bucket.
    public static func list(_ index: LibraryIndex, failed: FailedPlacement, olderOpen: Bool) -> [ProjectListItem] {
        let all = summaries(index, failed: failed)
        var items: [ProjectListItem] = []
        let order: [ProjectGroup] = failed == .withStuck ? [.stuck, .toLook, .running, .earlier]
                                                         : [.stuck, .toLook, .running, .failed, .earlier]
        for group in order {
            let members = all.filter { $0.group == group && !$0.sunk }.sorted { $0.lastActivity > $1.lastActivity }
            guard !members.isEmpty else { continue }
            items.append(.header(group))
            items += members.map(ProjectListItem.project)
        }
        let sunk = all.filter(\.sunk).sorted { $0.lastActivity > $1.lastActivity }
        if !sunk.isEmpty {
            items.append(.olderFold(count: sunk.count))
            if olderOpen { items += sunk.map(ProjectListItem.project) }
        }
        return items
    }

    /// `12 older projects`
    public static func olderTitle(_ count: Int) -> String {
        count == 1 ? "1 older project" : "\(count) older projects"
    }
}

/// A thread's runs as the project page shows them: the ones still asking for attention, and
/// the ones you've seen behind an "N earlier runs" fold.
public struct ThreadRuns: Hashable, Sendable {
    public var visible: [Run]
    public var earlier: [Run]

    public static func split(_ runs: [Run]) -> ThreadRuns {
        let sorted = runs.sorted { $0.started > $1.started }
        var visible = sorted.filter { $0.state != .seen }
        var earlier = sorted.filter { $0.state == .seen }
        // A thread you've seen all of still shows its latest run.
        if visible.isEmpty, !earlier.isEmpty { visible = [earlier.removeFirst()] }
        return ThreadRuns(visible: visible, earlier: earlier)
    }

    /// `12 earlier runs`
    public static func earlierTitle(_ count: Int) -> String {
        count == 1 ? "1 earlier run" : "\(count) earlier runs"
    }
}

extension LibraryIndex {
    /// The most urgent state of a thread's runs.
    public func state(ofThread id: String) -> RunState? { ProjectIndex.mostUrgent(runs(in: id)) }
}
