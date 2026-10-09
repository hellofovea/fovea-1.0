import SwiftUI
import AppKit

/// The screenshot walkthrough, played on the live window with a drawn pointer (a recording
/// does not show the real one): the bar opens, capture mode starts, a region is captured,
/// the page scrolls under the crosshair and another is captured, tabs switch and more are
/// captured, the stack fans on hover, opens to show every capture, closes, and capture mode
/// stops. Positions are display points on Safari's pages.
extension WorkbenchModel {
    func playDemo() {
        demoTask?.cancel()
        demoTask = Task { [weak self] in await self?.runDemo() }
    }

    func stopDemo() {
        demoTask?.cancel()
        demoTask = nil
        demoRunning = false
        demoPointer = nil
        selection = nil
    }

    func runDemo() async {
        demoRunning = true
        defer { demoRunning = false; demoPointer = nil }

        // A clean start: the bar closed, Safari on its first tab, every page at its top.
        notchState = .silent
        guard await pause(0.35) else { return }
        screenContent = .fullScreenApp
        selectTab(0)
        scrollReset += 1
        demoPointer = DemoPointer(location: CGPoint(x: 900, y: 700), style: .arrow)
        guard await pause(0.9) else { return }

        // fn: the bar. Left Option held: capture mode, the crosshair.
        notchState = .voiceFlow
        guard await pause(0.9) else { return }
        capturing = true
        demoPointer?.style = .crosshair
        guard await pause(0.6) else { return }

        // The article's photograph.
        guard await drag(from: CGPoint(x: 430, y: 225), to: CGPoint(x: 1040, y: 545)), await pause(1.1) else { return }

        // The page scrolls under the crosshair; a passage further down.
        scroll(tab: 0, to: "pass")
        guard await pause(1.3) else { return }
        guard await drag(from: CGPoint(x: 372, y: 126), to: CGPoint(x: 1098, y: 372)), await pause(1.1) else { return }

        // Another tab, another capture.
        guard await click(at: tabCenter(1), then: { self.selectTab(1) }), await pause(0.8) else { return }
        guard await drag(from: CGPoint(x: 770, y: 300), to: CGPoint(x: 1195, y: 562)), await pause(1.1) else { return }

        // The code tab, scrolled, a few lines.
        guard await click(at: tabCenter(3), then: { self.selectTab(3) }), await pause(0.6) else { return }
        scroll(tab: 3, to: "l15")
        guard await pause(1.2) else { return }
        guard await drag(from: CGPoint(x: 300, y: 142), to: CGPoint(x: 1010, y: 424)), await pause(1.1) else { return }

        // The stack: the pointer fans it, a click opens every capture, the pill closes it.
        demoPointer?.style = .arrow
        let hit = stackLayout.stackHit ?? .zero
        guard await move(to: CGPoint(x: display.frame.width / 2 + hit.midX, y: hit.midY), duration: 0.6) else { return }
        setStackHovered(true)
        guard await pause(1.1) else { return }
        guard await press() else { return }
        setExpanded(true)
        guard await pause(1.6) else { return }

        // A click on one looks closer; a click on it again goes back to all of them.
        if liveReferents.count > 1 {
            let target = liveReferents[1].id
            let card = stackLayout.cards[1]
            guard await move(to: CGPoint(x: display.frame.width / 2 + card.cx, y: card.top + card.height / 2), duration: 0.5) else { return }
            hoveredReferent = target
            guard await pause(0.6), await press() else { return }
            inspect(target)
            guard await pause(2.2) else { return }
            let big = stackLayout.cards[1]
            guard await move(to: CGPoint(x: display.frame.width / 2 + big.cx + 40, y: big.top + big.height / 2), duration: 0.4),
                  await press() else { return }
            inspect(nil)
            guard await pause(1.0) else { return }
        }

        // Hover one: its ✕ appears; a click on it removes that capture and the rest close up.
        if liveReferents.count > 2 {
            let target = liveReferents[2].id
            let card = stackLayout.cards[2]
            guard await move(to: CGPoint(x: display.frame.width / 2 + card.cx, y: card.top + card.height / 2), duration: 0.5) else { return }
            hoveredReferent = target
            guard await pause(0.7) else { return }
            let x = StackLayout.removeCenter(width: card.width, height: card.height, radius: card.radius)
            guard await move(to: CGPoint(x: display.frame.width / 2 + card.cx - card.width / 2 + x.x, y: card.top + x.y), duration: 0.35),
                  await pause(0.25), await press() else { return }
            removeReferent(target)
            guard await pause(1.3) else { return }
        }
        if let close = stackLayout.close {
            guard await move(to: CGPoint(x: display.frame.width / 2 + close.midX, y: close.midY), duration: 0.5),
                  await pause(0.3), await press() else { return }
        }
        setExpanded(false)
        guard await pause(1.0) else { return }

        // Left Option let go: capture mode stops; the bar and its captures stay.
        guard await move(to: CGPoint(x: 900, y: 700), duration: 0.5) else { return }
        capturing = false
        guard await pause(1.2) else { return }
    }

    // MARK: Steps

    private func pause(_ seconds: Double) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds))
        return !Task.isCancelled
    }

    private func move(to point: CGPoint, duration: Double) async -> Bool {
        withAnimation(.easeInOut(duration: duration)) { demoPointer?.location = point }
        return await pause(duration)
    }

    private func press() async -> Bool {
        withAnimation(.easeOut(duration: 0.08)) { demoPointer?.pressed = true }
        guard await pause(0.12) else { return false }
        withAnimation(.easeOut(duration: 0.12)) { demoPointer?.pressed = false }
        return true
    }

    private func click(at point: CGPoint, then action: @escaping () -> Void) async -> Bool {
        guard await move(to: point, duration: 0.5), await press() else { return false }
        action()
        return true
    }

    /// Draws a selection the way a hand would, then lets go: a capture.
    private func drag(from a: CGPoint, to b: CGPoint) async -> Bool {
        guard await move(to: a, duration: 0.45) else { return false }
        withAnimation(.easeOut(duration: 0.08)) { demoPointer?.pressed = true }
        let steps = 36
        for i in 1...steps {
            let t = Double(i) / Double(steps)
            let e = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
            let p = CGPoint(x: a.x + (b.x - a.x) * e, y: a.y + (b.y - a.y) * e)
            selection = CGRect(from: a, to: p)
            demoPointer?.location = p
            guard await pause(0.6 / Double(steps)) else { return false }
        }
        demoPointer?.pressed = false
        let rect = CGRect(from: a, to: b)
        selection = nil
        // The pointer is drawn into the window, so it steps aside while the pixels are read.
        let pointer = demoPointer
        demoPointer = nil
        await capture(rect)
        if demoPointer == nil { demoPointer = pointer }
        return !Task.isCancelled
    }

    private func tabCenter(_ index: Int) -> CGPoint {
        let frame = MockSafari.tabFrame(index, count: tabs.count, displayWidth: display.frame.width, top: metrics.safeAreaTop)
        return CGPoint(x: frame.midX, y: frame.midY)
    }
}
