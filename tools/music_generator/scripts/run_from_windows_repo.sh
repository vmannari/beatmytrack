#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# Reuse the owner's installed environment, or the toolkit-managed environment.
VENV="${BMT_MRT_VENV:-$HOME/.venvs/bmt-magenta-rt2}"
if [[ ! -x "$VENV/bin/python" && -x "$HOME/apps/magenta-realtime2/.venv/bin/python" ]]; then
  VENV="$HOME/apps/magenta-realtime2/.venv"
fi
[[ -x "$VENV/bin/python" ]] || { echo 'Run install_mrt2.sh first.' >&2; exit 1; }
source "$VENV/bin/activate"
export JAX_PLATFORMS=cuda
export XLA_PYTHON_CLIENT_PREALLOCATE=false
export JAX_COMPILATION_CACHE_DIR="${BMT_MRT_CACHE:-$HOME/.cache/bmt-mrt2-jax}"
cd "$ROOT"
exec "$@"
