// swift-tools-version:5.9
import PackageDescription

// Fovea 1.0: the one app. The first run (the onboarding), the window (Home and Settings) and the
// notch (Voiceflow and Dispatch Version 2), on the real desktop and the real notch. Forked from the
// prototypes in ../Prototypes at the baseline commit named in PROVENANCE.md; the prototypes stay as
// they are, for design work. Root FoveaCore supplies the notch geometry and the brand resources.
//
// Layers, top depends on bottom, never the other way:
//   FoveaApp → FoveaOnboarding → FoveaIsland ┐
//            → FoveaWindow ──────────────────┼→ FoveaLook, FoveaPlatform → FoveaStore → FoveaKit, cores
// The island and the window never import each other: they meet in FoveaStore and FoveaKit.
// `scripts/l10n.py` (Oct 18, Localization/README.md) sets FOVEA_L10N to have the compiler list every
// interface string, each target into its own folder (two targets can share a file name).
import Foundation
func l10n(_ target: String) -> [SwiftSetting] {
    guard let dir = ProcessInfo.processInfo.environment["FOVEA_L10N"] else { return [] }
    return [.unsafeFlags(["-emit-localized-strings", "-emit-localized-strings-path", "\(dir)/\(target)"])]
}

let package = Package(
    name: "FoveaV1",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "FoveaApp", targets: ["FoveaApp"]),
    ],
    dependencies: [
        .package(name: "Fovea", path: ".."),
    ],
    targets: [
        // Pure: the prefs, the keys, matching words to a request. No UI, no platform APIs.
        .target(name: "FoveaKit", path: "Sources/FoveaKit", swiftSettings: l10n("FoveaKit")),
        // Pure: captures, attachments, the dictionary, search and every computed line.
        .target(name: "CapturesCore", dependencies: ["FoveaKit"], path: "Sources/CapturesCore", swiftSettings: l10n("CapturesCore")),
        // Pure: the onboarding's steps, beats, copy and the dictionary import.
        .target(name: "OnboardingCore", dependencies: ["FoveaKit"], path: "Sources/OnboardingCore", swiftSettings: l10n("OnboardingCore")),
        // What's kept on this Mac: prefs, captures, their pictures, the dictionary, the first run.
        .target(name: "FoveaStore", dependencies: ["FoveaKit", "CapturesCore"], path: "Sources/FoveaStore", swiftSettings: l10n("FoveaStore")),
        // The system: the notch panel, keys, the microphone and speech, screen capture,
        // Accessibility, pasting, permissions, hiding apps.
        .target(name: "FoveaPlatform", dependencies: ["FoveaKit", .product(name: "FoveaCore", package: "Fovea")],
                path: "Sources/FoveaPlatform", swiftSettings: l10n("FoveaPlatform")),
        // The look both surfaces share: the glass, the island's outline, the glow.
        .target(name: "FoveaLook", dependencies: ["FoveaKit"], path: "Sources/FoveaLook", swiftSettings: l10n("FoveaLook")),
        // The notch (UI/Overlay).
        .target(name: "FoveaIsland",
                dependencies: ["FoveaKit", "FoveaStore", "FoveaPlatform", "FoveaLook", "CapturesCore",
                               .product(name: "FoveaCore", package: "Fovea")],
                path: "Sources/FoveaIsland",
                resources: [.copy("Resources/Agents"), .copy("Resources/Fonts")], swiftSettings: l10n("FoveaIsland")),
        // The window: Home and Settings (UI/Window).
        .target(name: "FoveaWindow",
                dependencies: ["FoveaKit", "FoveaStore", "FoveaPlatform", "FoveaLook", "CapturesCore",
                               .product(name: "FoveaCore", package: "Fovea")],
                path: "Sources/FoveaWindow",
                exclude: ["README.md", "DESIGN.md"], swiftSettings: l10n("FoveaWindow")),
        // The first run, on the real desktop. It drives the real island; it never sees the window.
        .target(name: "FoveaOnboarding",
                dependencies: ["FoveaKit", "OnboardingCore", "FoveaStore", "FoveaPlatform", "FoveaLook",
                               "FoveaIsland", "CapturesCore", .product(name: "FoveaCore", package: "Fovea")],
                path: "Sources/FoveaOnboarding", swiftSettings: l10n("FoveaOnboarding")),
        // The composition root.
        .executableTarget(name: "FoveaApp",
                          dependencies: ["FoveaKit", "FoveaStore", "FoveaPlatform", "FoveaIsland",
                                         "FoveaWindow", "FoveaOnboarding", "OnboardingCore", "CapturesCore",
                                         .product(name: "FoveaCore", package: "Fovea")],
                          path: "Sources/FoveaApp", swiftSettings: l10n("FoveaApp")),
        .testTarget(name: "FoveaKitTests", dependencies: ["FoveaKit", "FoveaStore", "CapturesCore",
                                                          .product(name: "FoveaCore", package: "Fovea")],
                    path: "Tests/FoveaKitTests"),
        .testTarget(name: "CapturesCoreTests", dependencies: ["CapturesCore"], path: "Tests/CapturesCoreTests"),
        .testTarget(name: "OnboardingCoreTests", dependencies: ["OnboardingCore"], path: "Tests/OnboardingCoreTests"),
    ]
)
