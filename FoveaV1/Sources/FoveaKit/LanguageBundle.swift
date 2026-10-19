import Foundation
import ObjectiveC

// Oct 18, Ryan: "If they choose Chinese as primary, the entire interface will be in Chinese."
// SwiftUI looks a literal up (`Text("Settings")`, `Button("Done")`, `.help("…")`) in Bundle.main's
// own preferred localization (the Mac's languages), not in the environment's locale, so literal
// text stayed in the Mac's language whatever the primary was. Bundle.main is given this class,
// which answers every lookup from the primary language's .lproj, read at the moment of the lookup;
// FoveaLook's `.foveaLanguage()` redraws each surface when the language changes. Installed once,
// for the whole app, first thing at launch (AppDelegate), so the window, the notch and the first
// run all answer in the primary language.

public final class FoveaLanguageBundle: Bundle, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var tables: [String: Bundle] = [:]

    /// The primary language's table (en.lproj or zh-Hans.lproj in Fovea.app).
    private static func table(_ id: String) -> Bundle? {
        lock.lock(); defer { lock.unlock() }
        if let hit = tables[id] { return hit }
        guard let path = Bundle.main.path(forResource: id, ofType: "lproj"), let bundle = Bundle(path: path) else { return nil }
        tables[id] = bundle
        return bundle
    }

    public override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let t = Self.table(FoveaLocale.shared.language.localeIdentifier) {
            return t.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }

    /// Bundle.main answers in the primary language from now on.
    public static func install() {
        if !(Bundle.main is FoveaLanguageBundle) { object_setClass(Bundle.main, FoveaLanguageBundle.self) }
    }
}
