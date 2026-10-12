#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
source "${BMT_MRT_VENV:-$HOME/apps/magenta-realtime2/.venv}/bin/activate"
export BMT_SCORE_FFMPEG="$HOME/.local/share/bmt-music-tools/ffmpeg"
python tools/music_generator/render_locked_in.py "$@"
