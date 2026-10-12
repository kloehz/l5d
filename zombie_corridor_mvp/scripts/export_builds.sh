#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$ROOT/.tools/godot-4.7/Godot.app/Contents/MacOS/Godot"
mkdir -p "$ROOT/builds/macos" "$ROOT/builds/linux-x86_64" "$ROOT/builds/linux-arm64"
"$GODOT" --headless --path "$ROOT" --editor --quit > "$ROOT/logs/export-import.log" 2>&1
if grep -Eq 'SCRIPT ERROR|Parse Error' "$ROOT/logs/export-import.log"; then cat "$ROOT/logs/export-import.log"; exit 1; fi
for PRESET in 'Client macOS' 'Linux Dedicated Server x86_64' 'Linux Dedicated Server ARM64'; do
  "$GODOT" --headless --path "$ROOT" --export-release "$PRESET"
done
/usr/bin/unzip -q -o "$ROOT/builds/macos/Zombie Corridor.zip" -d "$ROOT/builds/macos"
chmod +x "$ROOT"/builds/linux-*/zombie-server
python3 "$ROOT/scripts/package_builds.py"
