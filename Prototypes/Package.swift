// swift-tools-version:5.9
import PackageDescription

// Fovea Lab (front-page prototypes) and the Notch Workbench (a mock desktop for notch designs),
// kept apart from the shipping app in Sources/. Both depend on the shipping package only for
// FoveaCore (models, fixtures, geometry).
let package = Package(
    name: "FoveaLab",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(name: "Fovea", path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "FoveaLab",
            dependencies: [.product(name: "FoveaCore", package: "Fovea")],
            path: "FoveaLab"
        ),
        .executableTarget(
            name: "FoveaWorkbench",
            dependencies: [.product(name: "FoveaCore", package: "Fovea")],
            path: "FoveaWorkbench",
            resources: [.copy("Resources/Agents")]
        ),
        // The Window Bench: the app window for the notch, every open design choice on a panel
        // (FoveaWindowBench/README.md). Its model is pure and tested on its own.
        .target(
            name: "WindowBenchCore",
            path: "WindowBenchCore"
        ),
        .executableTarget(
            name: "FoveaWindowBench",
            dependencies: ["WindowBenchCore", .product(name: "FoveaCore", package: "Fovea")],
            path: "FoveaWindowBench",
            exclude: ["README.md"]
        ),
        .testTarget(
            name: "WindowBenchCoreTests",
            dependencies: ["WindowBenchCore"],
            path: "Tests/WindowBenchCoreTests"
        ),
        // Fovea Captures: the app as an input tool, its captures as Paste-style cards, search on
        // top, You (dictionary, memories, credits) and Settings; no sidebar (FoveaCaptures/README.md).
        .target(
            name: "CapturesCore",
            path: "CapturesCore"
        ),
        // Every Fovea Captures view and the app delegate, as a library, so other prototypes can open
        // the real Home (FoveaCaptures/Embedding.swift). The app itself is one main.swift.
        .target(
            name: "CapturesUI",
            dependencies: ["CapturesCore", .product(name: "FoveaCore", package: "Fovea")],
            path: "FoveaCaptures",
            exclude: ["README.md", "DESIGN.md"]
        ),
        .executableTarget(
            name: "FoveaCaptures",
            dependencies: ["CapturesUI"],
            path: "FoveaCapturesApp"
        ),
        .testTarget(
            name: "CapturesCoreTests",
            dependencies: ["CapturesCore"],
            path: "Tests/CapturesCoreTests"
        ),
        // Fovea Onboarding: the first run as an interactive prototype on a mock desktop: the
        // Island at the notch, real key presses, ending in the real Home (docs/onboarding/ONBOARDING.md).
        .target(
            name: "OnboardingCore",
            path: "OnboardingCore"
        ),
        .executableTarget(
            name: "FoveaOnboarding",
            dependencies: ["OnboardingCore", "CapturesUI", "CapturesCore", .product(name: "FoveaCore", package: "Fovea")],
            path: "FoveaOnboarding"
        ),
        .testTarget(
            name: "OnboardingCoreTests",
            dependencies: ["OnboardingCore"],
            path: "Tests/OnboardingCoreTests"
        ),
    ]
)
