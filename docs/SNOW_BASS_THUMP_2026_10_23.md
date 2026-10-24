# Softer, longer snow bass thump - 2026-10-23

SBT01-SBT02/R01/Q01 revise the installed snowbank impact toward the owner's requested soft, long bass "thump". The packed entry now lasts **0.54 s instead of 0.34 s**. A slowed recorded landing, filtered to 40-320 Hz, supplies the body. A gradual lift of its existing recorded tail, a 300 ms decay envelope and 90 ms release extend the sound. Quiet filtered snow compression retains a little texture. A 3 ms curved attack and lower level round the strike.

[Listen to the comparison](evidence/bass-snow-thump-2026-10-23/comparison.wav): two previous hits, then two new thumps. [Separate listening controls](evidence/bass-snow-thump-2026-10-23/review.html). These are actual game event-pool captures at identical gain 0.65 and pitch 0.90 through the Vehicle compressor and Master limiter, without per-cut normalization.

The captured peak falls **4.30 dB**, and the first 100 ms falls **1.63 dB**. Integrated bass energy below 220 Hz increases **33%**, despite the softer peak. The time containing 90% of the impact's energy grows from **38 ms to 178 ms**, demonstrating a longer audible body rather than just a padded file. The raw strong onset is **2.132 ms**, within the existing 5 ms guard. Exact asset and mastered measurements are in [analysis.json](evidence/bass-snow-thump-2026-10-23/analysis.json).

Only the packed impact changes. The continuous snow loop, powder/heavy-bank alternatives, contact logic, playback gains/pitch and Windows output source remain exact. The same pinned Nox Sound Design CC0 snow recordings supply all layers; no synthesized noise/tone, new dependency or Soundsnap sample is added. The non-looping asset remains below the existing 0.6 s event bound, and the captured event finishes naturally.

Changed production files: `scripts/build_snow_audio.py`, `game/assets/audio/vehicles/snow_hit.wav`, revision-5 `snow_manifest.json`, vehicle `NOTICE.txt` and `licenses/ASSETS.md`. Status/plan/AGENTS, this report and scoped evidence complete the checkpoint. Existing capture and response tests remain unchanged.

Actual commands, using pinned Godot `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`:

- `python scripts/build_snow_audio.py --audition-dir build/bass-snow-thump-2026-10-23/variants` generates the revision. A repeated build retains exact installed asset/manifest hashes.
- `powershell -NoProfile -ExecutionPolicy Bypass -File build/bass-snow-thump-2026-10-23/capture.ps1` imports, captures actual mastered playback (13 checks), verifies snow response in Compatibility/headless (35/29 checks) and parses all 1041 scripts. All pass; each engine log is copied immediately to a separate retained receipt.
- `python build/bass-snow-thump-2026-10-23/review.py`: 20 asset/capture checks pass for gentler entry, increased bass, extended body/tail, prompt attack, headroom, silence and exact retained sources.
- Independent Git index binary diff, whitespace and reverse-apply checks pass; task source hashes and receipts are in `checkpoint.json` and `report.json`.

Restart the client to replace its cached impact sample. Owner sound-character listening and physical-device acceptance remain. No phone/tablet attachment check, physical-device test, APK/export/install, native rebuild, account/backend mutation, purchase or deployment was performed. No running owner process was interrupted. Concurrent work and the shared Git index are preserved.
