# Upbeat soundtrack and hover-sound correction - 2026-10-07

The owner rejected mix 2 as too melancholic and unsuitable for racing, requested
a more upbeat soundtrack and removed hover sounds from buttons/other objects.
[Exact feedback and revision hypothesis](music/rounds/2026-10-07-upbeat-r3.md).

[Listen to revision 3](evidence/upbeat-score-2026-10-07/audition.html), including
the actual Godot mixer and a matched old/new comparison. Musical acceptance remains
pending; no agent subjective listening or AAA-quality approval is claimed.

## Requirements and change

| ID | Result |
| --- | --- |
| MUS18 | Recompose the menu/race family with major-key D/G/A cadences, rising/answering mid-register piano phrases, rhythmic bass/chord articulation and a light pulse from the opening. Later layers add acoustic backbeat/bowed movement and expand the same motif. |
| MUS19 | Remove mouse-hover and keyboard-focus sound hooks and the focus cue itself. Activation/confirm/back remain unchanged. Objects outside the button system have no hover audio route. |
| MUS11-MUS17 / G01/R01/Q01/V06 | Keep exact race grid, adaptive progression, collision recovery, rewind/retry/pause, levels/preferences, car audio and provenance. Original source/exports preserved. |

One focused revised family retains the existing two-colour mapping: **Rolling
Start** replaces Open Horizon for Grass/Winter/Night/Storm; **Sunlit Sprint** is
the lighter harp/piano colour for Desert. **Paddock** is the related menu cue.
The menu moves from 90 to 108 BPM and its loop is now exactly 3,136,000 stereo
frames/71.111111s at 44.1kHz. Races remain 120 BPM, 32 bars, exactly 2,822,400
frames/64s; all five additive layers share the written score/clock. The room tail
is lighter. This targets mood/motion through composition, not increased loudness.

The original instrument recordings and renderer/performance technique are retained.
No new downloads, paid generation, runtime model/API or dependency. The one-minute
build and contact/reset/recovery logic are unchanged byte-for-byte in
`game/soundtrack/driving_score_progress.gd`; actual new output reaches full at
**61.929 seconds**. Mix-3 master/source provenance is under
`build/music/score-v1/masters-v3/`, with exports under `exports-v3/` and the
installed bank under `game/assets/audio/score_v1/`. The manifest records the
upbeat score tables/config, source-code hash, versions, licensed source hashes,
exact lengths and export hashes. Source licence/credits remain VSCO 2 CE CC0-1.0.

`audio_world.gd` no longer connects `mouse_entered` or `focus_entered` to sound.
`play_ui("focus")` also has no registered cue to play. The hover WAV/import is
preserved outside export under this task's evidence, while the rejected full
score remains in its original masters/evidence and the task baseline. Selection,
confirmation and back WAV hashes match the task-start originals exactly.
Visual hover/focus styling is retained. No player files are removed.

Shipping audio is **14 assets / 8,710,829 bytes**: 11 Vorbis loops and three
activation-only interface WAVs. Existing bus gains and output ceilings are retained.

## Actual verification

All engine commands use `scripts/dev.ps1` and pinned
`4.7.2.stable.official.ed1daf0bf`.

| Command actually run | Outcome |
| --- | --- |
| `wsl -d Ubuntu -- bash tools/music_generator/scripts/render_score_v1.sh --upbeat --revision 3 --evidence-dir docs/evidence/upbeat-score-2026-10-07` | 14 new exports, preserved prior renders, exact 64s race/71.111111s menu frame counts. Mix-3 exports copied to runtime; hover asset archived. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Import` | Exit 0; all revised loops imported with the pinned engine. |
| `… TestScript -ScriptPath res://tests/test_soundtrack.gd` | **1,065 checks, zero failures**; exact loops, ideal one-minute progression, adaptation/lifecycle, saved levels, hover/focus silence and 960 ticks of canonical state/input equality. Final rerun against current concurrent physics 0.52 also passes. |
| `… TestScript -ScriptPath res://tests/test_soundtrack.gd -Graphical` | **1,070 checks, zero failures**; real playback, silent hover/focus, audible activation and Audio settings screenshots. |
| `… TestScript -ScriptPath res://tests/capture_soundtrack.gd -Graphical -CommandTimeoutSeconds 340` | **11 checks, zero failures**, eight actual bus recordings, complete menu/race wraps, 61.929s full arrival, car/music recovery and interface capture. These use scripted qualifying/car signals, not a claimed naturally perfect player replay. |
| `wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/verify_score_v1.py --evidence-dir docs/evidence/upbeat-score-2026-10-07` | **14 assets, 32 combinations, eight captures; zero clipped samples**. Worst source/subset true peak -10.156dBTP; actual car/music mix -5.63dBTP, RMS -19.37dBFS. Hover/focus beginning and paused tails exactly zero; interface-only music bus silent. |
| `… python tools/music_generator/review_score_revision.py` in the same WSL wrapper | Existing music skill review helper compares equivalent 90s old/new race arcs at **-22 LUFS**, constant gains, -2dBTP ceiling, no limiting. Source hashes unchanged. Fresh output at `comparison-race/`. |
| `… TestApp`; `… TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | **99 / 1,434 checks, zero failures**, clean exit. App rerun after concurrent updates also passes. |
| Local Playwright/Edge check with `.tools/review/Scripts/python.exe` | Seven previews load, seek/play switching works, both matched 90s comparison files load, zero script errors. Screenshot/JSON retained; browser playback is not agent listening. |
| `python build/music/score-v1/checkpoint_upbeat.py`; scoped `git diff --check`; `python -m py_compile` for the three changed music tools | **16 task text changes / 28 changed source-export files / 27 evidence artifacts** pinned. Reverse Git-patch applicability, whitespace and source compilation checks exit 0. Binary sound files are identified by before/after hashes. |

No full Validate, quick export gate, Android export/install or phone listening was
performed for this focused correction. No camera/world UI redesign, physics tuning,
backend rollout or production action was performed by this task. New graphical
settings captures and the listening page provide presentation evidence.

## Scope, checkpoint and limits

Changed files: `game/soundtrack/audio_world.gd`, `game/assets/audio/score_v1/*`,
`game/tests/test_soundtrack.gd`, `game/tests/capture_soundtrack.gd`,
`tools/music_generator/render_score_v1.py`, `verify_score_v1.py`,
`review_score_revision.py`, toolkit README; this document, Music State/round,
original delivery's correction notice, status/phase notes and asset ledger.

Evidence, original baselines, runtime trace, source/export hashes, actual logs,
matched comparison and scoped Git patch are under
`docs/evidence/upbeat-score-2026-10-07/`. Text-patch reverse applicability and
source compilation/whitespace checks are recorded there. The workspace's unrelated
changes are preserved; no combined workspace commit was made.

The initial all-file hash audit detected concurrent edits in `game/core/app.gd`
and `game/vehicle/vehicle_simulation.gd`, advancing physics 0.51 to 0.52. The failure
and before/current hashes are retained in `contract-verification.json`; neither
file was edited/reverted or included in this music patch. A later audit also
recorded continuing external app edits; no frozen whole-workspace snapshot is
claimed. The final focused soundtrack rerun still passes 1,065 checks. The music observer,
game composition, state/config/rules/session sources and activation clips retain
their task-start hashes. Canonical equality/app checks were repeated on 0.52.

Remaining: owner listening for upbeat racing fit, motif/timbre quality, restraint
and replay fatigue; phone speaker/headphone/mono balance, Android decoder/thermal
and focus/ad/audio-route acceptance; naturally driven performance adaptation.
No phone attachment check or device audio test was performed in this round.
Artist acceptance of revision 3 is not inferred from this technical pass.
