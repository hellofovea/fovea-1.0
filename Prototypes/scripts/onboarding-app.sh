#!/bin/zsh
# Wraps Fovea Onboarding as an app, for dictation's real words (Oct 9): macOS lets an app ask for
# the microphone and speech recognition only when its Info.plist says why, which a binary run with
# `swift run` doesn't have. macOS asks for both the first time dictation listens; this prompt is
# the prototype's (the shipping Fovea doesn't ask for Speech Recognition).
# Usage: Prototypes/scripts/onboarding-app.sh [debug|release] [--no-open]   → Prototypes/build/FoveaOnboarding.app
# SCRATCH=<dir> builds there instead of Prototypes/.build.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-debug}"
cd "$ROOT"
SCRATCH_ARGS=()
[[ -n "${SCRATCH:-}" ]] && SCRATCH_ARGS=(--scratch-path "$SCRATCH")
swift build -c "$CONFIG" --product FoveaOnboarding "${SCRATCH_ARGS[@]}"
BIN="$(swift build -c "$CONFIG" --show-bin-path "${SCRATCH_ARGS[@]}")"
APP="$ROOT/build/FoveaOnboarding.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/FoveaOnboarding" "$APP/Contents/MacOS/FoveaOnboarding"
# Fovea's shared resources (the photos, the app icon, the agents' marks).
cp -R "$BIN/Fovea_FoveaCore.bundle" "$APP/Contents/Resources/"
BRAND="$ROOT/../Sources/FoveaCore/Resources/Brand"
if [[ -d "$BRAND/AppIcon.iconset" ]]; then
  iconutil -c icns "$BRAND/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns" 2>/dev/null || true
fi
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Fovea Onboarding</string>
  <key>CFBundleDisplayName</key><string>Fovea Onboarding</string>
  <key>CFBundleIdentifier</key><string>app.fovea.onboarding-prototype</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleExecutable</key><string>FoveaOnboarding</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSMicrophoneUsageDescription</key><string>Fovea Onboarding listens while you say the test line, and while you dictate, between two presses of fn.</string>
  <key>NSSpeechRecognitionUsageDescription</key><string>Fovea Onboarding writes what you dictate on this Mac, so your own words land in the window you point at.</string>
</dict>
</plist>
PLIST
# A stable identity keeps macOS's answers across rebuilds (an ad-hoc signature changes every build,
# so macOS would ask again). Override with CODESIGN_IDENTITY=…; falls back to ad hoc.
IDENTITY="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | grep -o '"Apple Development[^"]*"' | head -1 | tr -d '"')}"
if [[ -n "$IDENTITY" ]]; then
  codesign --force --deep --sign "$IDENTITY" "$APP" 2>&1 | grep -v "replacing existing signature" || true
  echo "signed as $IDENTITY"
else
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
  echo "signed ad hoc (no identity found)"
fi
echo "built $APP"
[[ "${2:-}" == "--no-open" ]] || open "$APP"
