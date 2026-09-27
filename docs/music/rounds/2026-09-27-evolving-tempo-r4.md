# R4 — same music, rising tempo

Requirements: MUS03/MUS06/MUS09/MUS10/V03/V05/Q01. Owner requested an additional mode where the same music evolves and BPM increases from state to state. This is a standalone workbench experiment, not runtime integration or artistic approval.

## Behavior

**Evolving tempo · same score** uses the current R3 instrument choices, or loads a random R3 drive if none is selected. Stages add instruments as before and use **90, 102, 114, 126, 138 and 150 BPM** respectively. These are an initial audition curve, not accepted balance values. The mix selector also exposes **Evolving score · rising BPM**. The original fixed 120 BPM mode and previous auditions remain available.

Each tempo is rendered from the exact same R3 note events, with the same note numbers, instrument programs and relative instrumental balance. This produces 108 exports: six instruments × three alternatives × six tempos. It does not speed up the original recording: every Web Audio source plays at rate 1, preserving sampled pitch and articulation. One random alternative per instrument remains fixed across stages; manual A/B/C comparison still works.

The transport tracks score position independently of wall time. Tempo transitions preserve that phrase position and start every replacement stem at the same audio-clock timestamp and offset. A 20 ms overlap fades the old render out and new render in. Musical position continues; no phrase restart or reshuffle. Stage changes are immediate, not bar-quantized or continuous accelerando. Existing gain controls, cumulative entries, solo, save/load, seeking, pause and restart remain available. The position slider represents reference score seconds at 120 BPM (two beats per second); the new readout shows actual BPM and beat within the 32-beat phrase.

Collision retains the existing reset-to-Focus/recovery contract and therefore drops this mode to 90 BPM. Clean-streak/recovery duration still uses wall seconds. Restart returns to the opening. Edits to loop trims and adding arbitrary recordings require leaving tempo mode, keeping this mode's shared phrase contract intact. Selected tempo buffers are preloaded and pruned to the current selection; a six-instrument drive keeps 36 tempo buffers. This is desktop audition tooling, with no phone-memory/performance claim.

## Changed files and provenance

- `tools/music_generator/render_score.cpp`: optional BPM argument, default 120 preserved; note timestamps and loop length use the chosen BPM, pitch calculation unchanged.
- `tools/music_generator/tempo_bank.py`: renders a fresh six-tempo bank from retained R3 score files; verifies finite/nonzero audio and applies one shared headroom gain across all tempos. Source manifest, score hashes, output hashes and upstream licensing are retained.
- `tools/music_generator/ui/app.js`, `ui/index.html`: tempo control/readout, musical transport, synchronized transitions, preload/cache handling and persisted tempo mode.
- `test_tempo.py`, `test_tempo_browser.py`: actual exports and browser behavior.
- `docs/evidence/music-r4/`: generation manifest, export/browser results, saved setup, desktop/compact screenshots.

Audio lives in `build/music/tempo/evolving-r4-20260927-194416-957936/`. Original R3 assets are unchanged. TinySoundFont / GeneralUser GS revisions and source license caveat are inherited and recorded in the manifest; see the [R3 provenance record](2026-09-27-additive-r3.md). No new third-party dependency or game/runtime API was added. Sample provenance review remains a shipping gate.

## Actual verification

```text
python tools/music_generator/tempo_bank.py
  PASS: 108 exports, six tempos, retained score files and raw float renders.
python tools/music_generator/test_tempo.py
  PASS: 5 grouped checks: hashes and unchanged score sources, exact tempo lengths
  within one sample, finite/nonzero stereo, all-choice/subset headroom, loop seams.
.tools/review/Scripts/python.exe tools/music_generator/test_tempo_browser.py
  PASS: 19 grouped checks, including actual nonzero playback, all six BPM states,
  synchronized timestamps/offsets, unchanged playbackRate=1, musical clock rate,
  collision, loop wrap, variation, save/load, pause, fixed-tempo return, automatic
  buildup and recovery, restart, compact layout and no JavaScript errors.
.tools/review/Scripts/python.exe tools/music_generator/test_browser.py
  PASS: existing 19 grouped checks.
.tools/review/Scripts/python.exe tools/music_generator/test_iteration_browser.py
  PASS: existing 9 R2 grouped checks.
.tools/review/Scripts/python.exe tools/music_generator/test_additive_browser.py
  PASS: existing 15 R3 grouped checks.
```

Additional actual regression: invoked `.tools/music-layer-renderer/render_score.exe` without the optional BPM on R3's `01-acoustic-motif-1.score` (bank 0, program 24); its raw output was byte-identical to the retained R3 float render. Old screenshot/result artifacts were preserved when rerunning their tests. The new desktop screenshot was inspected; two newly introduced punctuation characters lost through the PowerShell text pipe were corrected to HTML entities and the R4 browser test/screenshots rerun successfully.

All tempo exports have an all-choice/all-muted-subset PCM sample-peak bound below 0.681 and individual loop-boundary deltas below 0.002. These are technical checks, not subjective listening or oversampled true-peak analysis. Crossfades can briefly blend attacks from the two tempo renders; listening acceptance of tempo steps, transitions, melody, groove, repetition and timbres remains with the owner. No listening approval is asserted. No Godot change, Android export or phone/device test was performed.
