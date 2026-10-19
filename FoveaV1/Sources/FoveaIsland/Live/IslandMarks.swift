import AppKit
import SwiftUI
import FoveaPlatform

// Oct 18, Ryan: the marks over words taken from another app (and the one being made, as the cursor
// moves) are drawn over the window they're in, by a window of their own (`MarkWindow`, FoveaPlatform):
// on that window's display and Space only, under whatever covers it, put away while it's minimised,
// hidden or on another Space, moving with it. The island's layer, on every Space, no longer draws them.

extension IslandController {
    /// Starts keeping the mark windows with the model's marks and with their windows.
    func startMarks() {
        live.syncMarks = { [weak self] in self?.syncMarks() }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification,
                     NSWorkspace.didHideApplicationNotification, NSWorkspace.didUnhideApplicationNotification] {
            live.markObservers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.followMarks() }
            })
        }
    }

    /// One mark window for each window with marks (taken words, and the selection being made), the
    /// others put away.
    func syncMarks() {
        guard live.smoke == nil else { return }
        var wanted: [CGWindowID: (bounds: CGRect, rects: [CGRect])] = [:]
        for mark in model.highlights where mark.taken {
            guard let window = mark.window else { continue }
            wanted[window, default: (mark.windowBounds, [])].rects += mark.windowRects
        }
        if let draft = live.draftMark { wanted[draft.window, default: (draft.bounds, [])].rects += draft.rects }
        for (id, panel) in live.markWindows where wanted[id] == nil {
            panel.orderOut(nil)
            live.markWindows[id] = nil
        }
        let F = WorkbenchTokens.Feedback.self
        let color = NSColor(model.accent.color).withAlphaComponent(F.takenMarkOpacity)
        for (id, want) in wanted {
            let panel = live.markWindows[id] ?? MarkWindow(target: id, bounds: want.bounds)
            live.markWindows[id] = panel
            panel.show(want.rects, color: color, radius: F.markRadius, outset: F.takenMarkOutset)
            panel.follow()
        }
        updateMarkFollow()
    }

    /// Each mark window with its window: moved, covered, minimised, on another Space.
    func followMarks() {
        for panel in live.markWindows.values { panel.follow() }
    }

    /// While any marks show, they check on their windows a few times a second.
    private func updateMarkFollow() {
        if live.markWindows.isEmpty {
            live.markFollow?.invalidate()
            live.markFollow = nil
        } else if live.markFollow == nil {
            live.markFollow = Timer.scheduledTimer(withTimeInterval: WorkbenchTokens.Capture.markFollowInterval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.followMarks() }
            }
        }
    }
}
