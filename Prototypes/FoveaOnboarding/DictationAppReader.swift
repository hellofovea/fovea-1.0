import Foundation
import SQLite3
import OnboardingCore

/// Reads a dictation app's own words from where it keeps them on this Mac (Oct 9: Connect, as
/// VoiceOS imports from Wispr Flow): `DictationApp.localStore` names the file and the query (the
/// word, and what it replaces; deleted entries and snippets left behind). Opened read-only and
/// immutable, so the app's file is never changed or locked; only when Connect is clicked. Nil when
/// the file isn't there or can't be read.
enum DictationAppReader {
    static func read(_ app: DictationApp) -> [(word: String, replacement: String?)]? {
        guard let store = app.localStore else { return nil }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let file = base.appendingPathComponent(store.path)
        guard FileManager.default.fileExists(atPath: file.path),
              var components = URLComponents(url: file, resolvingAgainstBaseURL: false) else { return nil }
        components.scheme = "file"
        components.queryItems = [URLQueryItem(name: "mode", value: "ro"), URLQueryItem(name: "immutable", value: "1")]
        guard let uri = components.url?.absoluteString else { return nil }

        var db: OpaquePointer?
        guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return nil
        }
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, store.query, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        var rows: [(word: String, replacement: String?)] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let word = text(statement, 0) else { continue }
            rows.append((word: word, replacement: text(statement, 1)))
            if rows.count >= DictionaryImport.limit * 2 { break }
        }
        return rows
    }

    private static func text(_ statement: OpaquePointer?, _ column: Int32) -> String? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL, let c = sqlite3_column_text(statement, column) else { return nil }
        return String(cString: c)
    }
}
