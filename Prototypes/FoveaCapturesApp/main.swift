// Fovea Captures: the app. Everything else lives in the CapturesUI library (FoveaCaptures/),
// so other prototypes can open the real Home (FoveaCaptures/Embedding.swift).
import CapturesUI

MainActor.assumeIsolated { runFoveaCapturesApp() }
