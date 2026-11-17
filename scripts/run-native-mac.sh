#!/usr/bin/env bash
# macOS local run of the native client + Python backend (Homebrew source). Builds into ~/.cache on first use.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
B="${OMNISTORE_BUILD:-$HOME/.cache/omnistore-build}"
V="${OMNISTORE_VENV:-$HOME/.cache/omnistore-venv}"
MEOUI="${MEOUI_SOURCE_DIR:-$ROOT/../MeoUI}"
PREFIX="$(dirname "$(dirname "$(command -v qmake6)")")"
[ -x "$V/bin/python" ] || { python3 -m venv "$V"; "$V/bin/pip" install -q -r "$ROOT/python/requirements.txt"; }
[ -f "$B/build.ninja" ] || cmake -S "$ROOT/src/native-ui" -B "$B" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$PREFIX" -DMEOUI_SOURCE_DIR="$MEOUI"
cmake --build "$B" --target omnistore-native
# Meo.System is Meo-desktop-only; the client falls back to MeoUI's built-in palette.
# The Homebrew source ships default_enabled=false: enable once with
#   $V python/main.py --set-plugin-enabled builtin.brew=true
OMNISTORE_PYTHON="$V/bin/python" QT_QUICK_CONTROLS_STYLE=Basic exec "$B/omnistore-native"
