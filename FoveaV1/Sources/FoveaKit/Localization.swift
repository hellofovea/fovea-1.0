import Foundation
import Observation

// Fovea's own words in the person's primary language (Oct 18, Ryan: "the primary language will
// be the language that appears in the interface; choose Chinese and the entire interface is in
// Chinese"). English is the source; the Chinese is in Localization/zh-Hans/*.strings, which
// scripts/bundle.sh gathers into Fovea.app's zh-Hans.lproj. It switches live:
//
// - SwiftUI text written as a literal (`Text("Settings")`, `Button("Try Again")`) follows the
//   environment's locale, which every surface's root sets from `FoveaLocale.shared`
//   (FoveaLook's `.foveaLanguage()`).
// - Words made as Strings (copy in models, enum titles, menus, alerts) go through `L("…")`,
//   which reads `FoveaLocale.shared` (so a SwiftUI body that calls it redraws when it changes).
//
// The compiler lists every key: `scripts/l10n.py` builds with `-emit-localized-strings` and
// reports the ones without Chinese. A key is the English as written, with %@ / %lld where it
// interpolates (as Xcode's string catalogs make them).

/// The language Fovea's words are in now: the primary of the languages the person chose.
@Observable
public final class FoveaLocale: @unchecked Sendable {
    public static let shared = FoveaLocale()
    public var language: FoveaLanguage = .english
    public var locale: Locale { Locale(identifier: language.localeIdentifier) }
    private init() {}
}

/// Fovea's words, in the primary language: `L("Allow")`, `L("Hello, \(name).")`.
public func L(_ value: String.LocalizationValue) -> String {
    String(localized: LocalizedStringResource(value, locale: FoveaLocale.shared.locale, bundle: .main))
}

/// A key known only at run time (a title kept as data): looked up as written.
public func L(key: String) -> String {
    guard !key.isEmpty else { return key }
    return String(localized: LocalizedStringResource(String.LocalizationValue(key),
                                                     locale: FoveaLocale.shared.locale, bundle: .main))
}

extension FoveaLanguage {
    /// The localization Fovea.app carries for it.
    public var localeIdentifier: String { self == .chinese ? "zh-Hans" : "en" }
}
