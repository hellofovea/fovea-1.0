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
    // Oct 21, perf: remembered (`LookupMemo`); the lookup itself is as it was.
    LookupMemo.shared.value(language: FoveaLocale.shared.language, value) {
        String(localized: LocalizedStringResource(value, locale: FoveaLocale.shared.locale, bundle: .main))
    }
}

/// A key known only at run time (a title kept as data): looked up as written.
public func L(key: String) -> String {
    guard !key.isEmpty else { return key }
    return LookupMemo.shared.value(language: FoveaLocale.shared.language, key: key) {
        String(localized: LocalizedStringResource(String.LocalizationValue(key),
                                                  locale: FoveaLocale.shared.locale, bundle: .main))
    }
}

/// Oct 21, perf: every word Fovea has looked up, by language and by what was asked (the key and
/// its values), so each is looked up once. A lookup with a locale (`LocalizedStringResource`)
/// made a bundle and read the strings file from disk every time, ~1 ms; view bodies make dozens
/// (the island's whole body, with every panel's words, ran on each change of the voice's level).
/// The language is part of the key, so a change of language looks everything up again; the words
/// never change otherwise. A value that can't be encoded (an object) is looked up every time.
public final class LookupMemo: @unchecked Sendable {
    public static let shared = LookupMemo()
    private let lock = NSLock()
    private var table: [String: String] = [:]
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()
    /// Words with ever-new values in them (a count, a time) would grow it without end: past this
    /// many it starts again.
    private static let limit = 4096

    /// `value`, as `lookup` gives it, once per language.
    public func value(language: FoveaLanguage, _ value: String.LocalizationValue, lookup: () -> String) -> String {
        lock.lock()
        let encoded = try? encoder.encode(value)
        lock.unlock()
        guard let encoded, let text = String(data: encoded, encoding: .utf8) else { return lookup() }
        return remembered(language.localeIdentifier + "\u{1}v" + text, lookup)
    }

    /// A key looked up as written, once per language.
    public func value(language: FoveaLanguage, key: String, lookup: () -> String) -> String {
        remembered(language.localeIdentifier + "\u{1}k" + key, lookup)
    }

    /// A key of its own with its English (`L(_:english:)`), once per language.
    public func value(language: FoveaLanguage, key: StaticString, english: String.LocalizationValue,
                      lookup: () -> String) -> String {
        lock.lock()
        let encoded = try? encoder.encode(english)
        lock.unlock()
        guard let encoded, let text = String(data: encoded, encoding: .utf8) else { return lookup() }
        return remembered(language.localeIdentifier + "\u{1}s" + key.description + "\u{1}" + text, lookup)
    }

    private func remembered(_ memoKey: String, _ lookup: () -> String) -> String {
        lock.lock()
        if let hit = table[memoKey] { lock.unlock(); return hit }
        lock.unlock()
        let found = lookup()
        lock.lock()
        if table.count >= Self.limit { table.removeAll(keepingCapacity: true) }
        table[memoKey] = found
        lock.unlock()
        return found
    }
}

extension FoveaLanguage {
    /// The localization Fovea.app carries for it.
    public var localeIdentifier: String { self == .chinese ? "zh-Hans" : "en" }
}
