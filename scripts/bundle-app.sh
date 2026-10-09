#!/bin/zsh
# Assembles a double-clickable Fovea.app from the SwiftPM build.
# Usage: scripts/bundle-app.sh [debug|release]   → build/Fovea.app
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-release}"
cd "$ROOT"
swift build -c "$CONFIG"
BIN="$ROOT/.build/$CONFIG"
APP="$ROOT/build/Fovea.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Fovea" "$APP/Contents/MacOS/Fovea"
cp -R "$BIN/Fovea_FoveaCore.bundle" "$APP/Contents/Resources/"
# App icon, from the masters `scripts/fovea-icon.swift` writes into Resources/Brand.
# With Xcode's actool: the layered icon (AppIcon.icon) compiles to Assets.car, which macOS 26 and
# later draw with the system's edge and in its dark, clear and tinted styles, plus an .icns for
# earlier systems. (macOS 26 and later put an .icns-only icon in a grey container.) Without
# actool, the full iconset (16 and 32 drawn from the small-size master) becomes the .icns.
BRAND="$ROOT/Sources/FoveaCore/Resources/Brand"
ICON_NAME_KEY=""
if xcrun --find actool >/dev/null 2>&1 && [[ -d "$BRAND/AppIcon.icon" ]]; then
  ICONS="$ROOT/build/AppIconCompiled"
  rm -rf "$ICONS"; mkdir -p "$ICONS"
  xcrun actool "$BRAND/AppIcon.icon" --compile "$ICONS" --platform macosx \
    --minimum-deployment-target 14.0 --app-icon AppIcon \
    --output-partial-info-plist "$ICONS/partial.plist" >/dev/null
  cp "$ICONS/Assets.car" "$ICONS/AppIcon.icns" "$APP/Contents/Resources/"
  rm -rf "$ICONS"
  ICON_NAME_KEY="<key>CFBundleIconName</key><string>AppIcon</string>"
else
  iconutil -c icns "$BRAND/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
fi
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Fovea</string>
  <key>CFBundleDisplayName</key><string>Fovea</string>
  <key>CFBundleIdentifier</key><string>app.fovea.prototype</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleExecutable</key><string>Fovea</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  $ICON_NAME_KEY
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSMicrophoneUsageDescription</key><string>Fovea listens after you press the VoiceFlow shortcut so it can transcribe your intent.</string>
  <key>NSScreenCaptureUsageDescription</key><string>Fovea captures the region you point at so it can be sent along with your words.</string>
  <key>NSAccessibilityUsageDescription</key><string>Fovea needs Accessibility to notice the fn shortcut in any app, read on-screen text and track gaze targets.</string>
  <key>NSSpeechRecognitionUsageDescription</key><string>Fovea transcribes your words on this Mac between two presses of the VoiceFlow shortcut.</string>
</dict>
</plist>
PLIST
# Sign with a stable identity so macOS keeps Accessibility / Microphone trust across
# rebuilds (ad-hoc signatures change their hash every build and lose the grants).
# Override with CODESIGN_IDENTITY=…; falls back to ad-hoc when no identity exists.
IDENTITY="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | grep -o '"Apple Development[^"]*"' | head -1 | tr -d '"')}"
if [[ -n "$IDENTITY" ]]; then
  codesign --force --deep --sign "$IDENTITY" "$APP" 2>&1 | grep -v "replacing existing signature" || true
  echo "signed as $IDENTITY"
else
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
  echo "signed ad hoc (no identity found)"
fi
echo "built $APP"
