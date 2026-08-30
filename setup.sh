#!/usr/bin/env bash
# One command: fetch xcodegen, generate FLASH.xcodeproj, open Xcode.
# Needs nothing but Xcode — no Homebrew, no sudo, nothing installed globally.
set -euo pipefail
cd "$(dirname "$0")"

TOOLS=".tools"
LOCAL="$TOOLS/xcodegen/bin/xcodegen"
URL="https://github.com/yonaskolb/XcodeGen/releases/latest/download/xcodegen.zip"

if command -v xcodegen >/dev/null 2>&1; then
  XCODEGEN="$(command -v xcodegen)"
elif [ -x "$LOCAL" ]; then
  XCODEGEN="$LOCAL"
else
  echo "Fetching xcodegen (about 4 MB, one time)…"
  mkdir -p "$TOOLS"
  curl -fsSL -o "$TOOLS/xcodegen.zip" "$URL"
  unzip -oq "$TOOLS/xcodegen.zip" -d "$TOOLS"
  rm -f "$TOOLS/xcodegen.zip"
  xattr -dr com.apple.quarantine "$TOOLS" 2>/dev/null || true
  chmod +x "$LOCAL"
  XCODEGEN="$LOCAL"
fi

echo "Generating FLASH.xcodeproj…"
"$XCODEGEN" generate --spec project.yml --quiet

echo "Opening Xcode…"
open FLASH.xcodeproj

cat <<'DONE'

Done. In Xcode:
  1. Pick your iPhone in the device menu (top bar).
  2. FLASH target -> Signing & Capabilities -> choose your Team.
     If the bundle identifier is taken, edit Config.xcconfig and re-run ./setup.sh
  3. Press Run.

First launch on the phone: Settings -> General -> VPN & Device Management
-> trust the developer profile.
DONE
