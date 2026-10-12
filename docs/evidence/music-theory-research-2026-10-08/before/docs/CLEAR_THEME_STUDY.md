# Clear melodic theme study - 2026-10-08

MUS33/MUS20-MUS32/Q01: the owner rejects the performed-flow soundtrack as
"utterly horrible music" and "basically just random notes here and there".
Its manifest records owner rejection, with source/audio/controller/preferences
preserved. Prior technical tests do not establish musical acceptance.

[Listen to one complete48-second theme and its melody alone](evidence/clear-theme-2026-10-08/audition.html).
This is a bounded composition review, with an explicitly written eight-bar tune,
statement/answer/bridge/return and tonic ending,160 BPM. The complete melody is
present from the start. Piano exposes it, with lower guitar doubling, bass,
sustained guitar support, restrained kit and later strings. No generated note
interpretation or spectral decomposition. It is not another game-bank replacement
or claimed AAA soundtrack, production loop or adaptive stem family.

Inspection found that the previous race opening isolated mainly bass frequencies
and filtered out much of the intended melodic register. The generated performance
had never established note adherence. This helps explain the design failure but
does not prove every aspect of the owner's listening experience. The new directly
rendered sketch also exposed a recording-level imbalance: its initial piano
melody was26.2dB below the complete mix. One constant gain per complete instrument
role corrects that imbalance while preserving each performance's internal
dynamics. Final melody RMS is1.94dB below the full cue. Earlier cue/ending/mix
versions remain preserved; v3 is the current study.

Changed files: `tools/music_generator/render_theme_sketch.py`, current bank
manifest rejection metadata, `docs/music/STATE.md`, detailed round feedback,
this delivery report, status/phase entries and review evidence. Game audio files,
runtime code, vehicle/menu SFX, loop guarding, settings, physics, camera, backend
and player files are unchanged. The current game still contains the rejected
bank; this study has not been promoted into it.

Source piano/strings use the previously pinned VSCO2 CE CC0 recordings; guitar,
bass and drums use the existing pinned Karoryfer CC0 inputs. Renderer, full event
score, original/master/output hashes, per-role gains and input licence metadata
are preserved in `build/music/clear-theme-2026-10-08/` and its revision folders.
No reference-game recording/melody, new dependency, model generation, metered
service or runtime API is used in this study.

Actual commands:

```powershell
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/render_theme_sketch.py
# Run for the first study, then preserved final-cadence and balanced revisions.
.tools/review/Scripts/python.exe build/music/clear-theme-2026-10-08/reject_bank.py
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python build/music/clear-theme-2026-10-08/review.py
.tools/review/Scripts/python.exe build/music/clear-theme-2026-10-08/browser_review.py
.tools/review/Scripts/python.exe -m py_compile tools/music_generator/render_theme_sketch.py
```

Actual final outputs are2,116,800 stereo frames at44.1kHz/48s, finite with zero
clipped samples. Full cue -10.414dBTP/-27.015dBFS RMS; melody-only
-12.185dBTP/-28.954dBFS RMS, same mix gain. Composer/output hashes and first four
explicit melodic events checked. Browser loads both48s cues, plays/switches
exclusively without errors; screenshot retained. These are technical checks,
not acoustic listening or artistic proof. No new Godot/runtime tests were needed
for the offline sketch/rejection metadata; preceding runtime checks remain
historical, with no new game acceptance claim.

Task-only checkpoint covers8 text files; reverse-application, Python compilation
and scoped whitespace checks pass. All37 game audio hashes still match the
task-start bank; rejection metadata is the only installed-bank change. No Git
staging/commit. The review-page screenshot was inspected.

Next is listening feedback on the tune and arrangement before another broad
adaptive-bank installation. The request for that feedback is creative judgement,
not a new permission requirement for already-authorized soundtrack work. No
agent acoustic listening/AAA claim, phone attachment check/audio test, Android
export/install, full Validate, backend action or deployment. Owner artistic fit,
natural driving/context mix and device acceptance remain unfulfilled.
