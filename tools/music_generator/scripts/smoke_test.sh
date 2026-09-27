#!/usr/bin/env bash
set -euo pipefail
exec bash "$(dirname "$0")/run_from_windows_repo.sh" python tools/music_generator/generate.py concepts --config tools/music_generator/configs/smoke.yaml --limit 1
