#!/usr/bin/env bash
set -euo pipefail
# The pinned CLI's download command is interactive; existing assets are reused.
bash "$(dirname "$0")/run_from_windows_repo.sh" mrt models init
exec bash "$(dirname "$0")/run_from_windows_repo.sh" mrt models download
