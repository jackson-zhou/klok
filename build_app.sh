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
</dict>
</plist>
PLIST

# App icon (use system clock symbol if available, skip if not)
if command -v sips &>/dev/null && command -v iconutil &>/dev/null; then
  ICONSET="${OUT_DIR}/Klok.iconset"
  mkdir -p "${ICONSET}"
  python3 - <<'PY'
import subprocess, os
sizes = [16,32,64,128,256,512]
src = "dist/Klok.iconset"
for s in sizes:
    for scale in [1, 2]:
        px = s * scale
        suffix = "" if scale == 1 else "@2x"
        name = f"icon_{s}x{s}{suffix}.png"
        # Create a simple placeholder PNG using built-in tools
        subprocess.run([
            "python3", "-c",
            f"""
import struct, zlib
def png(w, h, color=(30,30,30,255)):
    def row(c):
        return b'\\x00' + bytes([c[0],c[1],c[2],c[3]]*(w))
    raw = b''.join(row(color) for _ in range(h))
    def chunk(t, d): c=zlib.crc32(t+d)&0xFFFFFFFF; return struct.pack('>I',len(d))+t+d+struct.pack('>I',c)
    data = chunk(b'IHDR', struct.pack('>IIBBBBB',w,h,8,6,0,0,0))
    data += chunk(b'IDAT', zlib.compress(raw))
    data += chunk(b'IEND', b'')
    return b'\\x89PNG\\r\\n\\x1a\\n' + data
open('{src}/{name}','wb').write(png({px},{px},(30,30,30,255)))
"""
        ])
PY
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
