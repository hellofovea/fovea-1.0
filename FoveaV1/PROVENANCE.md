# Where FoveaV1's code came from

Forked at commit `ab6ab64` ("Baseline: the prototypes, their docs and the working tree before
Fovea v1", Oct 9). The prototypes stay where they are, for design work; FoveaV1 diverges from them
(the real screen, not a mock), so a change in one is not a change in the other.

| FoveaV1 | Forked from |
|---|---|
| `Sources/CapturesCore/` | `Prototypes/CapturesCore/` |
| `Sources/OnboardingCore/` | `Prototypes/OnboardingCore/` |
| `Sources/FoveaWindow/` | `Prototypes/FoveaCaptures/` (the `CapturesUI` library) |
| `Sources/FoveaIsland/` | `Prototypes/FoveaWorkbench/` (minus `WorkbenchApp.swift`) |
| `Sources/FoveaOnboarding/` | `Prototypes/FoveaOnboarding/` (minus `OnboardingApp.swift`; `HomeEnding.swift` became `PracticeCaptures.swift`) |
| `Tests/CapturesCoreTests/`, `Tests/OnboardingCoreTests/` | `Prototypes/Tests/` |
| `Sources/FoveaPlatform/` | new; pieces from `Sources/Fovea/Platform/` (NotchPanel, AudioServices, FunctionKeyTap, ScreenObserver) as they arrive |
| `Sources/FoveaKit/`, `Sources/FoveaStore/`, `Sources/FoveaLook/`, `Sources/FoveaApp/` | new |

Root `FoveaCore` (`../Sources/FoveaCore`) is a dependency, not a fork: the notch geometry and the
brand resources (the app icon, the agents' marks).
