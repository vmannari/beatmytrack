# Magenta RealTime 2 + WSL workflow

Use the project tooling under `tools/music_generator/` before creating parallel infrastructure.

## Current supported setup
As of 2026-09-27, upstream Magenta RT2 documentation describes:
- package: `magenta-rt`
- Python 3.12
- offline/batch JAX generation
- Linux NVIDIA acceleration via JAX CUDA wheels
- model setup via `mrt models init` and `mrt models download`
- JAX generation via `mrt jax generate`
- MRT2 can be steered by text, audio examples and MIDI at the model/system level

For this project:
- Godot and VS Code remain native Windows.
- MRT2 runs inside WSL2 Ubuntu.
- Generated assets are copied back into the Windows repository.
- MRT2 is an offline development tool, not an Android runtime dependency.

Always verify the installed version:
    mrt --help
    mrt jax generate --help
    python -c "import jax; print(jax.devices())"

Do not invent CLI flags from memory.

## Model-control rule
Prompting alone does not prove melodic or stem consistency.

If exact musical preservation is required:
1. inspect installed MRT2 conditioning/API capabilities;
2. use verified audio/MIDI conditioning if it can enforce the needed property;
3. test the output;
4. if it still drifts, keep MRT2 as ideation/performance rendering and recreate exact parts deterministically.

## Cost rule
The current project constraint is free/local generation. Do not call metered hosted music endpoints unless the user explicitly changes that constraint.

## Reproducibility
For each useful generation, capture:
- `magenta-rt` version
- model/checkpoint
- backend/device
- prompt/config
- conditioning files
- seed/temperature/top-k/etc. when exposed
- command/API call
- output hash
- date

Use `assets/provenance.template.json`.

## Sources
- Magenta RT2 installation: https://github.com/magenta/magenta-realtime/blob/main/docs/installation.md
- Magenta RT2 model card: https://github.com/magenta/magenta-realtime/blob/main/MODEL.md
- JAX install/support: https://docs.jax.dev/en/latest/installation.html
