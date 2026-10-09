import Foundation

/// Bundled files (the brand assets, the photos, the agents' marks), found where they are: inside
/// Fovea.app's Contents/Resources, or beside the binary in a `swift run`. Never SwiftPM's own
/// `Bundle.module`, whose fallback is the build folder's absolute path: inside the app that's a
/// folder on the Desktop, and reading it makes macOS ask for Desktop access (and wait).
public enum FoveaFiles {
    /// Root FoveaCore's resources: `Brand/…`, `Photos/…`, `AppIcon.png`.
    public static func url(_ relativePath: String) -> URL? {
        find(relativePath, bundle: "Fovea_FoveaCore", inner: "Resources")
    }

    /// The island's own resources (`Agents/claude-code.png`).
    public static func island(_ relativePath: String) -> URL? {
        find(relativePath, bundle: "FoveaV1_FoveaIsland", inner: nil)
    }

    static func find(_ path: String, bundle name: String, inner: String?) -> URL? {
        let fm = FileManager.default
        for base in [Bundle.main.resourceURL, Bundle.main.bundleURL].compactMap({ $0 }) {
            let bundle = base.appendingPathComponent("\(name).bundle")
            var candidates = [bundle.appendingPathComponent(path),
                              bundle.appendingPathComponent("Contents/Resources").appendingPathComponent(path)]
            if let inner {
                candidates.insert(bundle.appendingPathComponent(inner).appendingPathComponent(path), at: 0)
                candidates.append(bundle.appendingPathComponent("Contents/Resources").appendingPathComponent(inner).appendingPathComponent(path))
            }
            if let hit = candidates.first(where: { fm.fileExists(atPath: $0.path) }) { return hit }
        }
        return nil
    }
}
