#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
exec "$ROOT/zombie-server" --headless -- --server --port "${PORT:-27015}" "$@"
