#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
venv="${BMT_MRT_VENV:-$HOME/apps/magenta-realtime2/.venv}"
source "$venv/bin/activate"
export BMT_SCORE_FFMPEG="$HOME/.local/share/bmt-music-tools/ffmpeg"
python tools/music_generator/render_score_v1.py "$@"
