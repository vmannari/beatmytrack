# Magenta offline generation and standalone music workbench

2026-09-27. Owner authorizes implementation-plan steps 1–4, with a standalone
audition UI as the first part of step 4. Requirements MUS03/MUS06/MUS09/MUS10 and
R01/V03/V05/Q01 apply. MUS01/MUS02/MUS04/MUS05/MUS07/MUS08 runtime replacement is
outside this checkpoint. This tool has no dependency on game scenes or physics.

## Delivered

- WSL generator with pinned installed dependencies, explicit Ubuntu tasks,
  environment/GPU checks, unique runs, configuration/path validation, atomic
  manifests, explicit WAV output, failure records and audio provenance.
- Generated assets remain under ignored `build/music`, outside `game/`.
  Neither Magenta, Python, model weights nor workbench code enters Android.
- Separate loopback browser UI: actual audio playback; concept audition;
  endpoint-pair loading; arrangement/layer/manual modes; stage selection;
  clean-streak scrubbing; adjustable qualification/build/recovery/fade times;
  mute, multiple solo, track/master levels; seek, pause/restart; loop trims;
  local audio import; save/load mix setup; output peak indication.
- Four distinct 24-second concept takes, one corrected 20-second Focus take
  and one corrected 20-second Breakthrough take, plus a prepared endpoint pair.
  No full 18-take pool was generated. The supplied `open_horizon` family is a
  provisional audition label, not an owner-approved composition.
- Prepared pair uses one common gain, 10ms edge fades and PCM24. Equal sample
  length is a technical convenience, not harmonic or beat alignment. Source
  clipping warnings remain visible. No independent instrument stems claimed.

## Important findings and fixes

The owner already had `~/apps/magenta-realtime2/.venv` and the base checkpoint.
Reused these without reinstalling packages or redownloading the model. Installed
CLI help and Python source were inspected: `mrt jax generate` has no output/seed
flag; the adapter uses public `MagentaRT2Jax`, `embed_style`, `generate` and
`Waveform.write`. Python 3.12.3, Magenta 2.0.3, JAX/JAXlib 0.11.2, PyYAML 6.0.3.

The supplied long prompts exhausted MusicCoCa's **127 text-token** budget before
the distinguishing instructions. Initial concepts had identical SHA-256, as did
the initial endpoints. These takes are retained with `approval: superseded` and
excluded from the library. Specific instructions now lead, effective prompt and
conditioning tokens are recorded, and duplicate conditioning/PCM is rejected.
The corrected batch has four distinct concept hashes and distinct endpoints.

On this Windows host port 8765 failed with WinError 10013; default is 18765.
Initial large audio HTTP transfers stalled. Explicit 64KiB copy chunks and
TCP_NODELAY resolved the observed browser load failure; final browser tests pass.
Early Playwright attempts also found no bundled Chromium; the test now uses
installed Edge. A fixed 300ms audio-start assertion was replaced by waiting for
actual clock advance and nonzero output (same 30s maximum browser timeout).

## Actual commands and outcomes

Commands executed from repository root:

```powershell
wsl -d Ubuntu -- /home/ville/apps/magenta-realtime2/.venv/bin/mrt jax generate --help
wsl -d Ubuntu -- bash tools/music_generator/scripts/verify_mrt2.sh
wsl -d Ubuntu -- bash tools/music_generator/scripts/smoke_test.sh
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/generate.py layers --config tools/music_generator/configs/grass.yaml --limit 1
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/generate.py concepts --config tools/music_generator/configs/concepts.yaml
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/generate.py layers --config tools/music_generator/configs/grass.yaml --names 00_focus 05_breakthrough --variants 1
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/prepare.py
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/test_toolkit.py
python tools/music_generator/serve.py --no-browser
.tools/review/Scripts/python.exe tools/music_generator/test_browser.py
```

- GPU verification: RTX 3090 / 24GB, JAX backend `gpu`, device `cuda:0`, GPU
  matrix multiplication passes. Model present. Full working pip freeze pinned.
- Smoke: complete 4-second / 48kHz stereo, finite, non-silent; peak .623413,
  zero near-full-scale samples. First Grass run also completed. The initial
  PowerShell redirection wrapper returned 1 on native stderr warnings even
  though the generation manifest completed; later direct invocations return 0.
- Corrected concepts: all 24 seconds, 48kHz stereo, distinct hashes, finite and
  non-silent. Open Horizon has 25 near-full-scale samples; other three have zero.
  Preserve that warning: gain reduction does not undo clipping.
- Corrected Focus/Breakthrough: both 20 seconds, distinct hashes; prepared
  Focus peak .232361 and Breakthrough .5. Musical approval remains open.
- GPU allocator emitted failed-large-allocation/retry warnings during model
  loading, but the final direct generation calls completed successfully. No
  throughput/VRAM guarantee for another GPU is made.
- Toolkit: **9 tests pass** (path containment, duration/limit validation,
  normalized-name/selection checks, state-index preservation, specific prompt
  priority, failed manifests, catalog boundaries, audio validation).
- Browser: **19 documented checks pass**, including actual decoded nonzero
  output, arrangements/stack/manual, solo/mute/gain, collision, pause, adjustable
  build, seeking, setup round-trip, restart, compact layout and no JS errors.
  Desktop 1440px and compact 800px screenshots are actual browser captures.

Evidence: [desktop](evidence/music-toolkit/workbench-desktop.png),
[compact](evidence/music-toolkit/workbench-compact.png),
[browser results](evidence/music-toolkit/browser-results.json), and generated
manifest copies under `docs/evidence/music-toolkit`. Large WAVs stay local in
`build/music`; use the workbench library to audition them. Raw generation
manifests include effective prompts, tokens, source paths, hashes and metrics.

## Changed files and next acceptance

`tools/music_generator/` contains configs, pinned dependencies, WSL scripts,
generator, preparation tool, server/launcher, browser UI, tests and usage docs.
`.vscode/tasks.json` supplies launch/generation/verification tasks. This document,
status/phase notes and evidence record the outcome. No `game/` or `native/` source
was changed for this task; pre-existing winter work remains separate.

Next owner listening checks: choose a concept, judge the quiet opening and full
arrangement, compare endpoints, tune streak/build length, assess repetition and
clipping, and decide the thematic material to edit into compatible parts. BPM,
meter, key/chord timeline, musical loop seams, intermediate arrangements,
recovery-specific composition and finish ending remain unapproved/unprepared.
The UI intentionally supports auditioning these as they become available.
It cannot turn independent full arrangements into interchangeable stems.

No Godot build, Android export, installation or device test was performed; no
phone attachment check was made. No acoustic/listener acceptance is claimed.
The workbench passes commands on a browser timer, not the production native
sample scheduler; sample-aligned start of buffers does not imply bar-aligned
arrangement switching. Runtime integration remains a separate next step.

Upstream provenance: [Magenta repository](https://github.com/magenta/magenta-realtime),
[installation](https://github.com/magenta/magenta-realtime/blob/main/docs/installation.md).
Model/package licensing and any shipping asset notices must be retained/reviewed
when approved audio is promoted; no generated recording is a shipping asset here.
