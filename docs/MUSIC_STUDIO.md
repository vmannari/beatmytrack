# Local music studio redesign — 2026-09-28

Follow-up: [soundtrack packages, custom state counts, shared sidebar and
saved-track deletion](MUSIC_PACKAGES.md) supersedes the fixed-six-state,
schema-1 and no-saved-deletion descriptions below. This document records the
initial studio checkpoint and its actual tests.

The owner requests direct Magenta RT2 prompting, listening, saving/discarding,
editable state assignments and a complete workbench UI/UX redesign.
Requirements: **MUS03/MUS06/MUS09/MUS10, R01/V03/V05/Q01**. This is the local
authoring tool; game music, driving/collision rules and shipping audio are unchanged.

## Delivered workflow

Open <http://127.0.0.1:18765> after running:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/music_generator/launch.ps1
```

- **Create music:** working title, free-text prompt, three editable starting
  points, 4/16/24/32/60/120-second duration and optional musical state. One local
  GPU job at a time, with loading/generating phases and elapsed time. The prompt
  form survives reloads. Jobs continue when the page closes while the server runs.
- **Listen & decide:** real decoded waveform, play/pause, seek, loop, volume,
  WAV download, recorded prompt/model details, clipping/truncated-prompt notices,
  Save to library and Discard take. Nothing autoplays on completion.
- **Take inbox:** unsaved takes survive refreshes. Discarded takes are hidden
  from normal browsing, with a separate discarded list and Restore take.
  Source recordings are retained, not deleted.
- **Your library:** saved recordings, title/prompt search, musical-state filters,
  rename and explicit Save changes. Focus/Momentum/Drive/Flow/Lift/Breakthrough
  and Unassigned can be changed at any time. Earlier recordings can be auditioned
  and saved too. Labels organize recordings; they do not rewrite the music.
- **Mix lab:** a separate workspace with consistent styling/navigation, a
  collapsed panel for previous studies, playback, driving-arc simulation and
  mixing. Saved names/state assignments feed its recording picker. Original
  state identities remain available to the existing score presets.
- Responsive desktop/tablet/390px layout, labeled controls, keyboard focus,
  spacebar playback outside form controls, reduced-motion support, persistent
  player, explicit error/retry/reconnection states.

## Storage and generation contract

`build/music/workbench/library.json` (schema 1) atomically stores saved metadata
by asset ID plus generation-job history. `runs/<job-id>/<generator-run>/` holds
immutable WAVs/manifests. Adjacent `<job-id>.json` and `.log` retain the exact
input and process output. All remain local and outside Godot's export root.
Back up the **whole `build/music` folder**, including this registry, to retain
recordings and assignments. Saved metadata does not alter source manifests.

Windows serves the standard-library HTTP application; the existing WSL Ubuntu
wrapper runs the pinned `magenta-rt 2.0.3` adapter and `mrt2_base`. Prompts travel
as JSON data, not shell text. Manifests retain effective/full prompts, model,
versions, conditioning, audio metrics and SHA-256. The existing upstream fixed
generation RNG remains unchanged; identical prompts may produce identical takes.
The model's 127-token text limit still applies and truncation is surfaced.

Writes require a per-server token and the exact loopback origin/host; JSON size,
duration, names, states and catalog membership are checked. A process lock
prevents two library writers; a WSL file lock prevents concurrent CLI/UI GPU jobs.
Disk sources are kept separate from library metadata. Missing source files are
reported instead of silently deleting their saved entries.

Keep the server running until generation finishes. Server interruption marks
in-flight jobs failed on restart and preserves their prompt/files for diagnosis;
it does not resume a stopped render. A still-finishing WSL process keeps the GPU
lock until exit. There is no running-job cancel control. Longer-duration choices
are supported by the existing adapter; this UI acceptance used four-second takes.

## Actual verification

Commands run from the repository root:

```powershell
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python -c "import importlib.metadata as m; print(m.version('magenta-rt'))"
python tools/music_generator/test_studio.py
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/test_toolkit.py
.tools/review/Scripts/python.exe tools/music_generator/test_studio_browser.py
.tools/review/Scripts/python.exe tools/music_generator/test_studio_browser_errors.py
.tools/review/Scripts/python.exe tools/music_generator/test_browser.py
.tools/review/Scripts/python.exe tools/music_generator/test_iteration_browser.py
.tools/review/Scripts/python.exe tools/music_generator/test_additive_browser.py
.tools/review/Scripts/python.exe tools/music_generator/test_tempo_browser.py
```

- **8 service tests pass:** persistent rename/state/unassigned/restart, immutable
  sources, failed-disk-write rollback, discard/restore guards, validation, concurrent job rejection, renderer
  failure records, interrupted jobs, single writer, API authorization and catalog
  boundaries. Tests use temporary storage and an explicitly fake renderer.
- **10 existing toolkit tests pass.** Installed Magenta version is **2.0.3**.
- **10 real browser check groups pass**, including actual GPU rendering,
  page reload during generation, nonzero audio decode/play/pause/seek/loop,
  discard/restore, save/rename/reassign/unassign/reload, search/state filters,
  narrow layouts, Mix lab integration and no JavaScript errors.
- **5 additional browser failure checks pass**, using simulated API errors:
  generation error/retry, failed-job prompt recovery, inert HTML-like titles,
  connection loss/recovery and no JavaScript errors. Their screenshot is labeled
  simulated; it is not evidence of an actual GPU failure.
- Existing Mix lab regressions pass: **19 workbench, 9 R2, 15 additive and
  19 evolving-tempo check groups**. Their only navigation adaptation opens the
  separate Mix lab and its collapsed studies panel; assertions are retained.
- Two actual four-second renders completed. The first browser run stopped at an
  ambiguous test locator after saving; the scoped locator and refresh ordering
  were corrected, then the complete test passed. Final WAV: 48 kHz stereo,
  192,000 samples, peak 0.259125, RMS 0.072589, zero near-full-scale samples.
  GPU allocator retry warnings occurred during loading, as in prior tooling;
  generation completed. No subjective listening/quality approval is claimed.
- A rejected HTTP request initially reset its Windows socket before the JSON
  error arrived; draining the bounded request body fixed the regression.

Evidence: [Create](evidence/music-studio/create-empty.png),
[generation](evidence/music-studio/generating.png),
[ready take](evidence/music-studio/take-ready.png),
[library](evidence/music-studio/library-desktop.png),
[390px](evidence/music-studio/library-mobile.png),
[tablet](evidence/music-studio/library-tablet.png),
[Mix lab](evidence/music-studio/mix-lab.png),
[real browser results](evidence/music-studio/browser-results.json),
[manifest](evidence/music-studio/generation-manifest.json).
Desktop/narrow captures were visually inspected. Regression captures are stored
under this evidence directory, preserving the earlier rounds' historical files.

## Files and acceptance

Changed implementation: `tools/music_generator/workbench.py`, `serve.py`,
`generate.py`, `ui/index.html`, `ui/studio.js`, `ui/studio.css`, `ui/lab.html`,
`ui/app.js`, `ui/style.css`. Added three studio test scripts; adjusted four
existing browser test entry URLs/preset navigation. Updated README, music state,
development/phase status and this evidence/documentation.

Owner acceptance remains for the redesigned workflow, musical results, and
longer-session usability. Saving a track is not release approval or a claim of
stem/loop compatibility. No Godot build, Android export or physical-device test
was performed; no phone attachment check was made. The narrow layout checks ran
in desktop Edge. No new dependency, paid service or runtime API was added.
