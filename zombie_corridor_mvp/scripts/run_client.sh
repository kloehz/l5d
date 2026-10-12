#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/.tools/godot-4.7/Godot.app/Contents/MacOS/Godot" --path "$ROOT" -- --client "$@"
