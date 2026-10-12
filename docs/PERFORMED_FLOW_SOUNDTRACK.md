# Complete soundtrack recompose - 2026-10-08

Later owner feedback rejects this bank as "utterly horrible music" and "basically
just random notes here and there". Its manifest now records rejection. Numerical
checks below remain technical evidence only. A [directly written single-theme study](CLEAR_THEME_STUDY.md)
is under review; it has not replaced this game bank.

The owner rejects the sports-rock bank as irritating and musically unsuitable,
requests a complete recompose with racing energy and atmospheric development,
and reports menu cracks in the Windows game. The replacement is an original
eight-bar melodic/harmonic sentence and related phrases, performed with the
existing local Magenta RT2 model. Race arrangement targets160 BPM; menu112 BPM.
[Listen to the new score and actual game mixes](evidence/flow-recompose-2026-10-08/audition.html).

| Requirement | Delivered behaviour |
|---|---|
| MUS31: complete recompose | New F#-A-B-E written motif, eight-bar statement/answer/departure/return, extended major/suspended harmony, moving bass, guitar/piano/string colour and restrained kit. Previous parts are preserved. |
| MUS32: Windows menu continuity | New gentler menu arrangement uses uncompressed16-bit PCM with full-frame looping and a cyclic endpoint guard; previous recurring hat pattern is replaced. Real menus/nav and repeated wraps are recorded. |
| MUS20-MUS30/R01/G01/Q01/V06 | Existing confidence/PB/rival/sector/reset/rewind/breath/volume and silent-hover contracts stay intact. Five related palettes, bar entry/two-bar fades, reserved final component around60s. |

The source is one complete performed composition. Six complementary
spectral/rhythmic components derive from that same performance; these are
**not isolated guitar/drum/string stems**. They reconstruct its shared waveform
before the bounded seam repair. Rhythm, tonal detail, theme and sustained upper
colour enter through the existing confidence system. Narrowed stereo and common
family gain preserve headroom/mono support. Grass/Desert/Winter/Night/Storm retain
their related palette processing. This is a different compositional/performance
approach from the rejected short programmed riffs.

Two90s exploration takes are preserved separately. Text-only160 BPM prompting
produced roughly130 BPM pulses; one exploratory source has42 near-full-scale
samples and is excluded from the game. The original written MIDI score was then
fed through verified128-pitch activity/onset and drum-conditioning APIs with
streaming state. That performance still drifted: detector129.199 BPM, global
beat regression122.973 BPM. The latter sets pitch-preserving tempo ratio1.30109
for the arranged160 BPM clock. Input MIDI does **not** prove exact note/beat
adherence. Musical pulse, phrase alignment and theme fidelity require listening.

The preserved96s raw performance has three near-full-scale channel samples at
0.4234/0.4236s. The game uses a later retimed12-60s region with none of those
samples, including its crossfade context. The initial whole-source quality gate
failed; selecting clean source material addresses that failure rather than
hiding it with gain. All original raw takes and failures remain retained.

The prior menu's captured wrap was continuous; strongest recurrent sample
differences came from its recorded hat attacks. This does not prove what the
owner heard. The new PCM recording exposed a separate one-sample zero during
the first repeat. Godot's WAV mixer can decode its endpoint inclusively while
wrapping the offset; a copy of the next cyclic frame now supplies that read.
The frame belongs to the same cycle, with no zero padding, track shortening or
fade to silence. Source review: [Godot WAV mixer](https://github.com/godotengine/godot/blob/master/scene/resources/audio/audio_stream_wav.cpp),
[AudioStreamWAV](https://docs.godotengine.org/en/stable/classes/class_audiostreamwav.html).
Empirical acceptance uses the pinned local engine's recorded output.

Godot initially imported the WAV with lossy QOA compression; the shipping import
explicitly disables it. The first race export had two decoded percussion seams
above the retained0.008 threshold. A failed5ms repair and its masters are kept;
32ms damping on only the rhythmic component now meets a stricter0.001 check.
Other parts continue across the boundary. Tempo update also corrected the
historical53.333s fixture expectation to48s; no loop/headroom/hover assertion was
relaxed. A fixture indentation error was corrected before final checks.

Changed files: `compose_flow_performance.py`, `render_flow_performance.py`,
`repair_flow_loops.py`, new generation config and extended `verify_locked_in.py`
under `tools/music_generator/`; `game/soundtrack/audio_world.gd` for160 BPM/native
PCM guarding; `game/tests/test_soundtrack.gd` and new
`capture_menu_continuity.gd`; the replaced bank audio/manifest/notice and new
WAV import; music state/round/delivery, toolkit/status/phase/provenance documents.
The old menu OGG/import are archived outside export, not discarded. Gameplay,
vehicle SFX, physics, camera, backend and player files are outside this change.

Actual commands:

```powershell
wsl -d Ubuntu -- bash tools/music_generator/scripts/verify_mrt2.sh
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/generate.py concepts --config tools/music_generator/configs/flow_recompose_20261008.yaml
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/compose_flow_performance.py
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/render_flow_performance.py
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/repair_flow_loops.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Import
$env:BMT_MUSIC_EVIDENCE='res://../docs/evidence/flow-recompose-2026-10-08'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_soundtrack.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_soundtrack.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_score_flow.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestApp
# Bounded capture runs: story/palettes/events/menu with140/100/60/80-second bounds.
$env:BMT_SCORE_CAPTURE_SEGMENT='story'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/capture_locked_in.gd -Graphical -CommandTimeoutSeconds 140
$env:BMT_MENU_CAPTURE_PHASE='after'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/capture_menu_continuity.gd -Graphical -CommandTimeoutSeconds 110
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python build/music/flow-recompose-2026-10-08/verify_menu.py
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/verify_locked_in.py --evidence-dir docs/evidence/flow-recompose-2026-10-08
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/review_score_revision.py docs/evidence/sports-rock-2026-10-08/pine-clean-story.wav docs/evidence/flow-recompose-2026-10-08/pine-clean-story.wav --out docs/evidence/flow-recompose-2026-10-08/comparison
```

Local MRT2.0.3/Python3.12.3/JAX0.11.2 and CUDA are verified, with existing weights
and dependencies reused. Model-load allocation retries recovered; both draft
takes and the96s performance completed. No metered service/runtime AI/API or new
runtime dependency. Performance/input-score/renderer/repair/output hashes and
versions are traceable in manifests; raw sources/masters/first exports/repairs
are under `build/music/`. Google identifies code as Apache2.0 and weights as
CC BY4.0 and disclaims rights in generated outputs in its [model terms](https://github.com/magenta/magenta-realtime/blob/main/MODEL.md).
Weights are not shipped. Existing cleared Karoryfer/VSCO event and interface
source credits remain in the bank notice/manifest; no reference-game audio,
melody or conditioning is used.

Actual final checks: soundtrack1161 headless/1166 graphical, flow29 and App99
pass; real mixer segments4/10/5/3 and actual menu continuity pass. Verification
covers37 assets,160 layer combinations and18 mixer recordings, zero clipped
samples; strongest combination -7.881dBTP and minimum mono RMS ratio0.9989.
The scripted exceptional final component arrives59.955s; breath, pause tails
and silent hover/focus are checked. Race loops2,116,800 frames/48s; menu1,512,000
frames/34.285714s. Final shipping audio21,274,493 bytes.

Two actual Windows menu wraps have maximum10ms-window adjacent differences
0.004913/0.004822, below the retained0.008 check, with nonzero room/music and no
clipping. The failed first PCM wrap0.010284 and its one-sample zero are preserved;
guarded playback removes that defect. Settings screenshots and the review-page
screenshot are retained; the latter was inspected. Nine browser previews,
seeking/exclusive playback and equal-loudness90s comparisons pass without page
errors. Offline confidence illustrations retain the first source arrangement;
actual mixer recordings use the final repaired exports.

The technical source/listening boundary remains explicit: musical suitability,
irritation, repetition fatigue, car masking, natural PB/rival driving and
Ori-level artistic quality require owner listening. No agent subjective
listening/AAA approval, phone attachment check or phone audio test, Android
export/install, full Validate, backend action or production deployment.

Review checkpoint:21 text files/55 changed files; renderer/composer/repair and
export hashes verified, old menu files and unchanged activation cues verified.
Task-only patch reverse-application, Python compilation and scoped whitespace
checks pass. Concurrent gameplay/backend work is excluded; no Git staging or
commit. Restart the Windows game to load the new assets/controller. The review
page's menu repeats automatically; actual Windows seam excerpts and before/failed
recordings are in `evidence/menu-loop-repair-2026-10-08/`.
