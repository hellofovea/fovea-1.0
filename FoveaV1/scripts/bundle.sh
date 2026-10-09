#!/bin/zsh
# Assembles Fovea.app (1.0) from the SwiftPM build.
# Usage: FoveaV1/scripts/bundle.sh [debug|release]   → FoveaV1/build/Fovea.app
set -euo pipefail
V1="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$V1/.." && pwd)"
CONFIG="${1:-release}"
cd "$V1"
swift build -c "$CONFIG" --product FoveaApp
BIN="$V1/.build/$CONFIG"
APP="$V1/build/Fovea.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/FoveaApp" "$APP/Contents/MacOS/Fovea"
# Every target's resources (the brand assets, the agents' marks).
for bundle in "$BIN"/*.bundle; do
  cp -R "$bundle" "$APP/Contents/Resources/"
done
# The icon: the layered icon (AppIcon.icon, solid white field) compiled by actool into Assets.car,
# which macOS 26 and later draw with the system's edge and in its dark, clear and tinted styles,
# plus an .icns for earlier systems. Without actool, the iconset becomes the .icns.
BRAND="$ROOT/Sources/FoveaCore/Resources/Brand"
ICON_NAME_KEY=""
if xcrun --find actool >/dev/null 2>&1 && [[ -d "$BRAND/AppIcon.icon" ]]; then
  ICONS="$V1/build/AppIconCompiled"
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
BUILD_NUMBER="$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Fovea</string>
  <key>CFBundleDisplayName</key><string>Fovea</string>
  <key>CFBundleIdentifier</key><string>app.fovea</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleExecutable</key><string>Fovea</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  $ICON_NAME_KEY
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>Fovea 1.0</string>
  <key>NSMicrophoneUsageDescription</key><string>Fovea listens between two presses of fn (or fn ⌃) so it can turn what you say into words.</string>
  <key>NSSpeechRecognitionUsageDescription</key><string>Fovea turns what you say into words on this Mac.</string>
  <key>NSScreenCaptureUsageDescription</key><string>Fovea takes only what you point at: a part of the screen you drag over, or the whole screen when you press ⌘ twice.</string>
  <key>NSAccessibilityUsageDescription</key><string>Fovea needs this for its keys in any app, to type your words where you are, and to read the words you highlight.</string>
</dict>
</plist>
PLIST
# Sign with a stable identity so macOS keeps Accessibility, Screen Recording and Microphone trust
# across rebuilds (ad-hoc signatures change every build and lose the grants).
# Override with CODESIGN_IDENTITY=…; falls back to ad hoc when no identity exists.
IDENTITY="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | grep -o '"Apple Development[^"]*"' | head -1 | tr -d '"')}"
if [[ -n "$IDENTITY" ]]; then
  codesign --force --deep --sign "$IDENTITY" "$APP" 2>&1 | grep -v "replacing existing signature" || true
  echo "signed as $IDENTITY"
else
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
  echo "signed ad hoc (no identity found)"
fi
echo "built $APP"
