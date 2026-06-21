#!/usr/bin/env bash
set -e

APP_NAME="Klok"
VERSION="1.0.0"
BUNDLE="${APP_NAME}.app"
OUT_DIR="dist"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${OUT_DIR}/${DMG_NAME}"
STAGING_DIR="${OUT_DIR}/dmg_staging"

# Build the .app first
echo "▸ Building .app bundle…"
bash build_app.sh

# Prepare staging directory
echo "▸ Preparing DMG staging…"
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

cp -r "${OUT_DIR}/${BUNDLE}" "${STAGING_DIR}/${BUNDLE}"

# Symlink to /Applications for drag-install UX
ln -s /Applications "${STAGING_DIR}/Applications"

# Create DMG
echo "▸ Creating DMG…"
rm -f "${DMG_PATH}"
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "${DMG_PATH}"

rm -rf "${STAGING_DIR}"

echo "✓ DMG ready: ${DMG_PATH}"
echo ""
echo "To install: open ${DMG_PATH} then drag ${BUNDLE} to Applications"
