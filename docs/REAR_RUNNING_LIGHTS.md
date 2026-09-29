# Rear running lights

2026-09-29; requirements V01/V04/Q01. Owner requests continuously lit rear lamps with brighter braking.

Changed `game/vehicle/car_visual.gd`: initialize the shared rear-lens material after each vehicle is built, keep emission enabled independently of headlights, and increase running emission from 0.32 to 0.65 and braking from 1.0 to 2.2. Reuses existing meshes/materials without adding lights. All five vehicles use this behavior.

Updated `game/tests/test_headlights.gd` to check initial illumination and persistent daytime illumination; retained braking and release checks. Updated DEVELOPMENT_STATUS.md and docs/PHASE_0_PLAN.md.

Actual commands using pinned Godot 4.7.2:
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestHeadlights`: 61 checks, zero failures.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureHeadlights`: 61 checks, zero failures.

Desktop captures generated and inspected: [running](evidence/taillights-2026-09-29/running.png), [braking](evidence/taillights-2026-09-29/braking.png). The command also refreshes existing headlight on/off captures. Lamps occupy few pixels at ordinary gameplay framing; owner visual acceptance in motion remains.

No Android export or physical-device test performed; device attachment was not checked. Pre-existing working-tree changes preserved; no mixed Git commit created.
