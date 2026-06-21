#!/usr/bin/env bash
set -e

APP_NAME="Klok"
BUNDLE="${APP_NAME}.app"
BUILD_DIR=".build/release"
OUT_DIR="dist"

echo "▸ Building release binary…"
swift build -c release 2>&1 | grep -v "^Build complete" || true
swift build -c release

BINARY="${BUILD_DIR}/${APP_NAME}"

echo "▸ Creating .app bundle…"
rm -rf "${OUT_DIR}/${BUNDLE}"
mkdir -p "${OUT_DIR}/${BUNDLE}/Contents/MacOS"
mkdir -p "${OUT_DIR}/${BUNDLE}/Contents/Resources"

cp "${BINARY}" "${OUT_DIR}/${BUNDLE}/Contents/MacOS/${APP_NAME}"

# Bundle the ClocX skins
if [ -d "Skins" ]; then
    echo "▸ Bundling $(ls Skins | wc -l | tr -d ' ') skin files…"
    cp -r "Skins" "${OUT_DIR}/${BUNDLE}/Contents/Resources/Skins"
fi

cat > "${OUT_DIR}/${BUNDLE}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>       <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>       <string>com.klok.app</string>
  <key>CFBundleName</key>             <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>      <string>Klok</string>
  <key>CFBundleVersion</key>          <string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundlePackageType</key>      <string>APPL</string>
  <key>LSMinimumSystemVersion</key>   <string>13.0</string>
  <key>LSUIElement</key>              <true/>
  <key>NSPrincipalClass</key>         <string>NSApplication</string>
  <key>NSHighResolutionCapable</key>  <true/>
  <key>NSUserNotificationAlertStyle</key><string>alert</string>
  <key>NSCalendarsUsageDescription</key><string>Klok 需要访问日历来在日历视图中显示您的日程。</string>
  <key>CFBundleIconFile</key>          <string>AppIcon</string>
</dict>
</plist>
PLIST

# App icon — use the metal clock skin as source
ICON_SRC="app.png"
if command -v sips &>/dev/null && command -v iconutil &>/dev/null && [ -f "${ICON_SRC}" ]; then
  ICONSET="${OUT_DIR}/Klok.iconset"
  mkdir -p "${ICONSET}"
  for SIZE in 16 32 64 128 256 512; do
    sips -z ${SIZE} ${SIZE} "${ICON_SRC}" --out "${ICONSET}/icon_${SIZE}x${SIZE}.png" &>/dev/null
    sips -z $((SIZE*2)) $((SIZE*2)) "${ICON_SRC}" --out "${ICONSET}/icon_${SIZE}x${SIZE}@2x.png" &>/dev/null
  done
  iconutil -c icns "${ICONSET}" -o "${OUT_DIR}/${BUNDLE}/Contents/Resources/AppIcon.icns" 2>/dev/null || true
  rm -rf "${ICONSET}"
fi

echo "✓ Built: ${OUT_DIR}/${BUNDLE}"
echo ""
echo "To run:"
echo "  open ${OUT_DIR}/${BUNDLE}"
echo ""
echo "To install:"
echo "  cp -r ${OUT_DIR}/${BUNDLE} /Applications/"
