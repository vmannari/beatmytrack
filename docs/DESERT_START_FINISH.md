# Desert start/finish marking

2026-09-24; V02/V04/V05/Q01; visual kit 72.

The supplied reference and follow-up correction supersede kits 70/71. Checker pitch increases from 0.42 to 0.54 m (29%); near-contiguous cells have shader-eroded edges instead of wide regular gaps. Cooler beige/brown pigments (#938267 / #635b4b) replace the orange tones. Amplified multiscale abrasion exposes irregular patches of the road throughout each square. Desert now has two narrow rows of subdued sand checkers. Thin, uneven mineral pigment lets the actual road texture show through instead of covering it with opaque orange blocks. Existing surface-factor artwork supplies broad wear and fine grain. Other biomes, timing geometry, camera and handling remain unchanged.

Changed files: `game/track/native_track_visual.gd`, new `game/track/desert_finish.gdshader`, palette/material assertions in `game/tests/test_desert.gd`, status/plan and refreshed desert evidence. The two existing material batches use alpha blending and do not cast shadows. No new artwork or external dependencies. Transparency adds a small overlapping surface cost; phone performance has not been measured.

Validation through pinned Godot 4.7.2:

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureDesert -Track track_3e26605a8a90165e`: 61 checks, 0 failures, including five-car deterministic replay and graphical shader rendering. Repeated after correcting an overly pale intermediate palette; final run passes.
- `git diff --check`: passes with existing line-ending notices.

[Final desktop screenshot](evidence/desert-apron/start-straight.png). Desktop image inspected. Owner style acceptance and phone visibility, dust/transparency overlap in motion and performance remain outstanding. No Android export or physical-device test performed for this change; device attachment was not checked. Existing unrelated working-tree edits retained; no combined commit made.
