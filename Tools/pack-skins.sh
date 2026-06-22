#!/usr/bin/env bash
# Pack the Skins/ directory into a distributable zip.
# Usage: ./Tools/pack-skins.sh [output-path]
# Default output: ClockX-Skins.zip in the project root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SKINS_DIR="$PROJECT_ROOT/Skins"
OUTPUT="${1:-$PROJECT_ROOT/ClockX-Skins.zip}"

if [ ! -d "$SKINS_DIR" ]; then
    echo "Error: Skins directory not found at $SKINS_DIR" >&2
    exit 1
fi

# Remove previous zip if present
[ -f "$OUTPUT" ] && rm "$OUTPUT"

# Create zip with Skins/ as the top-level directory inside the archive.
# Users unzip this and point the app at the resulting Skins/ folder.
(cd "$PROJECT_ROOT" && zip -r "$OUTPUT" Skins/ --exclude "*.DS_Store")

echo "Packed $(ls "$SKINS_DIR" | wc -l | tr -d ' ') files → $OUTPUT"
