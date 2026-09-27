#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
VENV="${BMT_MRT_VENV:-$HOME/.venvs/bmt-magenta-rt2}"
python3.12 -m venv "$VENV"
"$VENV/bin/python" -m pip install -r "$ROOT/tools/music_generator/requirements-lock.txt"
exec bash "$ROOT/tools/music_generator/scripts/run_from_windows_repo.sh" python tools/music_generator/verify.py
