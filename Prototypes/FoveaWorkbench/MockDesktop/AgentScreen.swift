import SwiftUI

// What the agent at work shows on the mock screen besides its own pointer: the key it pressed,
// the text it selected, a context menu it opened, a screenshot's flash, the region it zoomed
// into, the thing it drags, and a toast (a download). Drawn over the page in display points,
// never hit-testable: the person's own pointer and keys still reach the page.
// docs/island/AGENT_VOICE_AND_THINKING.md has the actions and their references.

/// A context menu the agent opened, and the item it is about to choose.
struct AgentMenu: Equatable {
    var items: [String]
    var at: CGPoint
    var highlighted: Int?
}

/// A short notice by Safari's toolbar: a download and its size.
struct AgentToast: Equatable {
    var symbol: String
    var text: String
}

/// Everything the agent draws over the page.
struct AgentScreenOverlay: View {
    let model: WorkbenchModel

    var body: some View {
        let T = WorkbenchTokens.AgentScreen.self
        ZStack(alignment: .topLeading) {
            Color.clear
            // Text the agent selected, in the system's selection color.
            ForEach(Array(model.agentHighlights.enumerated()), id: \.offset) { _, rect in
                Rectangle()
                    .fill(T.selection)
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
            }
            // Matches of a find, in the find highlight yellow.
            ForEach(Array(model.agentFinds.enumerated()), id: \.offset) { _, rect in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(T.find)
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
            }
            // The element it is about to act on, bracketed at its corners.
            if let target = model.agentTarget {
                AgentBrackets()
                    .frame(width: target.width + 2 * T.bracketOut, height: target.height + 2 * T.bracketOut)
                    .offset(x: target.minX - T.bracketOut, y: target.minY - T.bracketOut)
                    .transition(.opacity.combined(with: .scale(scale: 1.08)))
            }
            // A region it zoomed into: a bright frame, the rest dimmed a little.
            if let zoom = model.agentZoom {
                Rectangle().fill(T.zoomDim)
                    .reverseMask { Rectangle().frame(width: zoom.width, height: zoom.height).offset(x: zoom.minX, y: zoom.minY) }
                RoundedRectangle(cornerRadius: T.zoomRadius, style: .continuous)
                    .strokeBorder(Color.white, lineWidth: T.zoomStroke)
                    .shadow(color: .black.opacity(0.4), radius: 2)
                    .frame(width: zoom.width, height: zoom.height)
                    .offset(x: zoom.minX, y: zoom.minY)
                    .transition(.opacity)
            }
            // What it drags, a ghost under the pointer.
            if let drag = model.agentDrag {
                RoundedRectangle(cornerRadius: T.dragRadius, style: .continuous)
                    .fill(T.dragFill)
                    .overlay(RoundedRectangle(cornerRadius: T.dragRadius, style: .continuous).strokeBorder(T.dragStroke))
                    .frame(width: drag.width, height: drag.height)
                    .offset(x: drag.minX, y: drag.minY)
            }
            // A context menu.
            if let menu = model.agentMenu {
                AgentMenuView(menu: menu)
                    .offset(x: menu.at.x, y: menu.at.y)
                    .transition(.opacity)
            }
            // A toast by the toolbar.
            if let toast = model.agentToast {
                HStack(spacing: T.toastSpacing) {
                    Image(systemName: toast.symbol)
                    Text(toast.text)
                }
                .font(T.toastFont)
                .padding(.horizontal, T.toastPaddingH)
                .frame(height: T.toastHeight)
                .background(Capsule().fill(.regularMaterial))
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1)))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                .environment(\.colorScheme, .light)
                .frame(width: model.display.frame.width - T.toastInset, alignment: .trailing)
                .offset(y: model.metrics.safeAreaTop + T.toastTop)
                .transition(.opacity)
            }
            // The key it pressed, as a keystroke display shows one: low in the middle.
            if let key = model.agentKeycap {
                Text(key)
                    .font(T.keycapFont)
                    .foregroundStyle(.white)
                    .padding(.horizontal, T.keycapPaddingH)
                    .frame(height: T.keycapHeight)
                    .background(RoundedRectangle(cornerRadius: T.keycapRadius, style: .continuous).fill(T.keycapFill))
                    .frame(width: model.display.frame.width)
                    .offset(y: model.display.frame.height - T.keycapBottom)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            // A screenshot's flash.
            Rectangle()
                .fill(Color.white)
                .opacity(model.agentFlash ? T.flashOpacity : 0)
                .animation(model.agentFlash ? .easeOut(duration: 0.05) : .easeOut(duration: T.flashFade), value: model.agentFlash)
        }
        .animation(T.change, value: model.agentKeycap)
        .animation(T.change, value: model.agentMenu)
        .animation(T.change, value: model.agentZoom)
        .animation(T.change, value: model.agentToast)
        .animation(T.change, value: model.agentFinds)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A native-looking context menu: material, rows, the chosen one in the accent color.
struct AgentMenuView: View {
    let menu: AgentMenu

    var body: some View {
        let T = WorkbenchTokens.AgentScreen.self
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(menu.items.enumerated()), id: \.offset) { i, item in
                Text(item)
                    .font(T.menuFont)
                    .foregroundStyle(menu.highlighted == i ? Color.white : Color.primary)
                    .padding(.horizontal, T.menuPaddingH)
                    .frame(width: T.menuWidth, height: T.menuRow, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: T.menuHighlightRadius, style: .continuous)
                        .fill(menu.highlighted == i ? Color.accentColor : .clear))
            }
        }
        .padding(T.menuPadding)
        .background(RoundedRectangle(cornerRadius: T.menuRadius, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: T.menuRadius, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        .environment(\.colorScheme, .light)
    }
}

extension View {
    /// Everything but the mask's shape.
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask {
            Rectangle()
                .overlay(alignment: .topLeading) { mask().blendMode(.destinationOut) }
                .compositingGroup()
        }
    }
}

/// Four corner brackets around an element, in the accent color.
struct AgentBrackets: View {
    var body: some View {
        let T = WorkbenchTokens.AgentScreen.self
        Canvas { ctx, size in
            let l = min(T.bracketLength, size.width / 2, size.height / 2)
            let w = size.width, h = size.height
            var p = Path()
            p.move(to: CGPoint(x: 0, y: l)); p.addLine(to: .zero); p.addLine(to: CGPoint(x: l, y: 0))
            p.move(to: CGPoint(x: w - l, y: 0)); p.addLine(to: CGPoint(x: w, y: 0)); p.addLine(to: CGPoint(x: w, y: l))
            p.move(to: CGPoint(x: w, y: h - l)); p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: w - l, y: h))
            p.move(to: CGPoint(x: l, y: h)); p.addLine(to: CGPoint(x: 0, y: h)); p.addLine(to: CGPoint(x: 0, y: h - l))
            ctx.stroke(p, with: .color(.accentColor), style: StrokeStyle(lineWidth: T.bracketWeight, lineCap: .round, lineJoin: .round))
        }
    }
}
