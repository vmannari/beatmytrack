# Softer snow impact - 2026-10-23

SSI01/R01/Q01 soften the installed packed-snow impact at the owner's request. The same recorded low body remains, while compression rolls off at 2400 Hz instead of 2900 Hz, sharp crumble weight drops from 0.30 to 0.16, the attack fade rounds from 0.5 to 1.2 ms and final trim drops 1.5 dB. Net balance changes make the first compression about 0.8 dB quieter and the peak about 1.6 dB gentler. Energy above 2500 Hz falls to roughly one third of its former proportion. Strong onset remains **0.408 ms**, inside the existing 5 ms response guard.

[Before/after listening comparison](evidence/soft-snow-impact-2026-10-23/comparison.wav): two previous hits, then two softer hits. [Listening page](evidence/soft-snow-impact-2026-10-23/review.html). These are actual event-pool captures at the same 0.65 gain/0.90 pitch through the original Vehicle compressor and Master limiter. Exact sample and captured deltas are in [analysis.json](evidence/soft-snow-impact-2026-10-23/analysis.json).

Only the packed entry changes. Continuous snow, powder and heavy-bank alternatives remain byte-exact. Mixer/contact code, physics, cue gain/pitch, voice/cache bounds and native libraries remain unchanged. Existing Nox Sound Design CC0 sources and pinned source hashes remain; no new recording or dependency is added.

Changed source/assets: `scripts/build_snow_audio.py`, `snow_hit.wav`, revision-4 `snow_manifest.json`, vehicle NOTICE and asset register. The existing audition helper now accepts output/baseline/variant paths so this comparison retains the previous iteration's recordings. Status/plan/AGENTS, this report, evidence and a scoped binary patch complete the reviewable checkpoint.

Actual commands use the pinned `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`:

- `python scripts/build_snow_audio.py --audition-dir build/soft-snow-impact-2026-10-23/variants` builds the revision.
- `powershell -NoProfile -ExecutionPolicy Bypass -File build/soft-snow-impact-2026-10-23/capture.ps1` performs import, equal-level native capture (13 checks), snow response in Compatibility/headless (35/29 checks) and full parser (1037 scripts), all passing. The retained launcher records exact comparison paths.
- Asset/captured-output analysis: 12 checks pass for gentler energy/peak/high detail, prompt attack, headroom, silence and exact continuous/other-variant/mixer sources.
- Scoped source hashes, whitespace and reverse-patch receipts are retained in `report.json` and `checkpoint.json`.

Restart the client to load its cached sample replacement. Owner listening and physical-device acceptance remain; no phone/tablet attachment check, physical-device test, APK/export/install, native rebuild, live account/backend mutation, purchase or deployment was performed. No running owner process was interrupted. Concurrent work and the shared Git index are preserved.
