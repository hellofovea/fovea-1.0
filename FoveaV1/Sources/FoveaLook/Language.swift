import SwiftUI
import FoveaKit

// The primary language on a surface's root (Oct 18; FoveaKit/Localization.swift): its literal
// text follows the language the moment it changes, and dates and numbers format in it.

private struct FoveaLanguageModifier: ViewModifier {
    @State private var locale = FoveaLocale.shared
    func body(content: Content) -> some View {
        content
            .environment(\.locale, locale.locale)
            // A redraw of everything below when the language changes: words made as Strings
            // (L()) in models are read again.
            .id(locale.language)
    }
}

extension View {
    /// Put on each surface's root: the window's, the island's layers, the first run's stage and
    /// practice windows.
    public func foveaLanguage() -> some View { modifier(FoveaLanguageModifier()) }
}
