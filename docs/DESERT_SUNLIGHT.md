# Desert sunlight glow

2026-10-05, V02/V04/V05/Q01. Owner requests sunlight glow similar to Grass.

Desert now shares Grass's directional warm screen veil (sunlight strength 0.305), sun colour `ffedce` and energy 1.32. Its existing warm ambient fill remains. The shared shader disables cloud coverage for Desert, retaining clear skies and a steady glow. Switching themes updates the existing effect or removes it for other biomes. Sand materials, dust and canonical handling are unchanged. One existing full-screen shader pass is now used in Desert; phone performance has not been measured.

Changed runtime files: `game/core/game.gd`, `game/track/track_theme.gd`, `game/track/cloud_shadow.gdshader`; updated existing daylight assertion in `game/tests/test_desert.gd`. Documentation: this report, DEVELOPMENT_STATUS.md and docs/PHASE_0_PLAN.md. [Inspected desktop screenshot](evidence/desert-sunlight-2026-10-05/driving.png). Reviewable scoped Git diff: `docs/evidence/desert-sunlight-2026-10-05/scoped-change.patch`; unrelated working changes preserved.

Actual commands, pinned Godot 4.7.2:

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureDesert`: initial sandbox attempt failed accessing user logs; rerun with desktop access passed 104 checks, zero failures, including dust and deterministic vehicle checks. Log: `build/logs/CaptureDesert-32124`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestBiomes`: 107 checks, five failures, all `New repeats required selection with fresh identity` in creator flow. Those failing requirements remain intact. Log: `build/logs/TestBiomes-29812/biomes-test.log`.

No Android export, installation or device test performed; phone attachment was not checked. Remaining acceptance: owner comparison to Grass, readability during dense dust, selected camera modes and physical-phone rendering/performance. No backend deployment or physics contract change.
