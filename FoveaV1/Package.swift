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
        .target(name: "FoveaKit", path: "Sources/FoveaKit"),
        // Pure: captures, attachments, the dictionary, search and every computed line.
        .target(name: "CapturesCore", dependencies: ["FoveaKit"], path: "Sources/CapturesCore"),
        // Pure: the onboarding's steps, beats, copy and the dictionary import.
        .target(name: "OnboardingCore", dependencies: ["FoveaKit"], path: "Sources/OnboardingCore"),
        // What's kept on this Mac: prefs, captures, their pictures, the dictionary, the first run.
        .target(name: "FoveaStore", dependencies: ["FoveaKit", "CapturesCore"], path: "Sources/FoveaStore"),
        // The system: the notch panel, keys, the microphone and speech, screen capture,
        // Accessibility, pasting, permissions, hiding apps.
        .target(name: "FoveaPlatform", dependencies: ["FoveaKit", .product(name: "FoveaCore", package: "Fovea")],
                path: "Sources/FoveaPlatform"),
        // The look both surfaces share: the glass, the island's outline, the glow.
        .target(name: "FoveaLook", dependencies: ["FoveaKit"], path: "Sources/FoveaLook"),
        // The notch (UI/Overlay).
        .target(name: "FoveaIsland",
                dependencies: ["FoveaKit", "FoveaStore", "FoveaPlatform", "FoveaLook", "CapturesCore",
                               .product(name: "FoveaCore", package: "Fovea")],
                path: "Sources/FoveaIsland",
                resources: [.copy("Resources/Agents")]),
        // The window: Home and Settings (UI/Window).
        .target(name: "FoveaWindow",
                dependencies: ["FoveaKit", "FoveaStore", "FoveaPlatform", "FoveaLook", "CapturesCore",
                               .product(name: "FoveaCore", package: "Fovea")],
                path: "Sources/FoveaWindow",
                exclude: ["README.md", "DESIGN.md"]),
        // The first run, on the real desktop. It drives the real island; it never sees the window.
        .target(name: "FoveaOnboarding",
                dependencies: ["FoveaKit", "OnboardingCore", "FoveaStore", "FoveaPlatform", "FoveaLook",
                               "FoveaIsland", "CapturesCore", .product(name: "FoveaCore", package: "Fovea")],
                path: "Sources/FoveaOnboarding"),
        // The composition root.
        .executableTarget(name: "FoveaApp",
                          dependencies: ["FoveaKit", "FoveaStore", "FoveaPlatform", "FoveaIsland",
                                         "FoveaWindow", "FoveaOnboarding", "CapturesCore",
                                         .product(name: "FoveaCore", package: "Fovea")],
                          path: "Sources/FoveaApp"),
        .testTarget(name: "FoveaKitTests", dependencies: ["FoveaKit", "FoveaStore", "CapturesCore",
                                                          .product(name: "FoveaCore", package: "Fovea")],
                    path: "Tests/FoveaKitTests"),
        .testTarget(name: "CapturesCoreTests", dependencies: ["CapturesCore"], path: "Tests/CapturesCoreTests"),
        .testTarget(name: "OnboardingCoreTests", dependencies: ["OnboardingCore"], path: "Tests/OnboardingCoreTests"),
    ]
)
