import SwiftUI

/// The menu bar as it reads on a notched Mac: the wallpaper through the bar material, the
/// frontmost app's menus on the left, status items and the clock on the right. The bar spans
/// the full width; `MockNotch` draws the cutout on top of it.
struct MockMenuBar: View {
    let height: CGFloat
    let clock: Date

    private let menus = ["File", "Edit", "View", "Go", "Window", "Help"]
    private let status = ["wifi", "battery.100percent", "magnifyingglass", "switch.2"]

    /// The menu bar's own clock format: "Thu Sep 24  9:41 AM", no comma, no "at". Pinned to
    /// one locale so the mock reads the same on every Mac.
    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE MMM d  h:mm a"
        return formatter
    }()

    var body: some View {
        HStack(spacing: WorkbenchTokens.Layout.menuBarItemSpacing) {
            Image(systemName: "apple.logo")
            Text("Finder").font(WorkbenchTokens.Type_.menuBarApp)
            ForEach(menus, id: \.self) { Text($0) }
            Spacer(minLength: 0)
            HStack(spacing: WorkbenchTokens.Layout.menuBarStatusSpacing) {
                ForEach(status, id: \.self) { name in
                    Image(systemName: name)
                        .font(.system(size: WorkbenchTokens.Layout.menuBarStatusIconSize))
                }
                Text(Self.clockFormatter.string(from: clock))
            }
        }
        .font(WorkbenchTokens.Type_.menuBar)
        .foregroundStyle(.primary)
        .padding(.horizontal, WorkbenchTokens.Layout.menuBarSidePadding)
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(WorkbenchTokens.Materials.menuBar)
    }
}
