# Grass cloud contrast — 2026-10-03

## Smaller cloud coverage — owner follow-up, 2026-10-03

The owner accepts the contrast and requests smaller cloudy areas with more sunlight. V02/V04/V05/Q01; `contact-lighting-8` raises the cloud mask's soft thresholds from **0.36–0.59 to 0.50–0.70**, shrinking each shadow footprint and opening larger sunny gaps. The accepted maximum shade strength (0.43), tint, sunlight, 26 m noise scale and slow drift remain. No additional renderer work or canonical/camera/HUD changes.

Changed files: `game/track/cloud_shadow.gdshader`, the presentation revision in `game/track/contact_shading.gd`, the evidence destination in `game/tests/test_contact_shading.gd`, this report, status/phase-plan notes and `docs/evidence/grass-cloud-coverage-2026-10-03/`. [Previous coverage](evidence/grass-cloud-coverage-2026-10-03/before/clouds-0s.png), [smaller cloud coverage](evidence/grass-cloud-coverage-2026-10-03/after/clouds-0s.png), [normal gameplay view](evidence/grass-cloud-coverage-2026-10-03/after/gameplay.png). Desktop images inspected; previous accepted captures are retained separately.

Actual `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureContactShading`: **46 checks, zero failures**, including visible shade/movement, pause/biome lifecycle, canonical preservation, contact/bridge tests and opaque HUD isolation. `-Action Doctor` finds the pinned engine/templates and attached DN2103. `git diff --check` passes for the task paths with status/plan CRLF notices only. No Android export/install, physical-device driving, mobile performance or thermal test; owner coverage/motion/phone acceptance remains. A local scoped checkpoint at `checkpoints/grass-cloud-coverage-2026-10-03` follows the previous Grass checkpoint without changing the active branch or ordinary index.

Requirements: V02 (mature natural/cel-shaded art), V04 (readable gameplay and bounded rendering cost), V05 (shared biome lighting), Q01 (actual verification). The owner requests a stronger sunny/cloudy difference in Grass, using the supplied gameplay reference. This supersedes the previous Grass cloud-opacity tuning; the reference remains visual guidance and is not a shipping asset.

Grass now has warmer sunlight and broader, deeper cloud shade. The existing depth-projected cloud pass shades opaque grass, roads, vehicles and scenery together. Fully sunlit gaps and soft transitions remain. Presentation version is `contact-lighting-7`.

- Maximum cloud opacity: 0.24 → 0.43. Dark shade tint: `(0.025, 0.035, 0.05)` → `(0.018, 0.028, 0.032)`.
- World-space noise scale: 18 → 26 metres; broad/detail weights 75/25 → 85/15; soft transition thresholds 0.40–0.68 → 0.36–0.59. These are noise-cell scales, not guaranteed patch diameters.
- Grass direct light: energy 1.20 → 1.32, colour `#fff1d8` → `#ffedce`. Ambient light retains its existing setting.
- Existing approximately 0.30 m/s movement, pause behavior and Grass-only lifecycle retained. No additional pass, texture lookup, light, render target or asset. No road artifact invalidation is needed for shader/light-only changes.

Camera, car size, geometry, canonical simulation/rules, track data, HUD source and player files are unchanged by this task. Other biomes retain their existing lighting. Transparent particles still render after the opaque cloud projection and are not relit by it.

## Evidence and actual checks

[Interactive before/after comparison](evidence/grass-cloud-contrast-2026-10-03/comparison.html), [sunny bend](evidence/grass-cloud-contrast-2026-10-03/after/starter-view-3.png), [sun/shade transition](evidence/grass-cloud-contrast-2026-10-03/after/starter-view-9.png), [cloud overview](evidence/grass-cloud-contrast-2026-10-03/after/clouds-0s.png), [normal gameplay camera](evidence/grass-cloud-contrast-2026-10-03/after/gameplay.png). Paired images use the same camera, vehicle pose and cloud time. Normal road views come from the installed original Starter Circuit's embedded creator document; the bridge fixture has an explicitly diagnostic overview camera. Images were inspected. Paused/countdown overlays are retained from the existing capture tools, not evidence of human driving.

All Godot commands use `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` with pinned `4.7.2.stable.official.ed1daf0bf`. Graphical captures use Compatibility/OpenGL on RTX 3090.

| Actual command / arguments | Result |
| --- | --- |
| `-Action CaptureContactShading`, baseline | 45 checks, zero failures. Baseline captures retained in `before/`. |
| `-Action CaptureContactShading`, final | 46 checks, zero failures. Adds a saved eight-second production-camera view; previous assertions retained. Covers visible shade/motion, opaque HUD isolation, bridge/deck exclusions and contacts. |
| `-Action TestContactShading` | 23 checks, zero failures. Includes canonical snapshot/cell preservation, jump/ramp/layer contacts, paused animation and exclusion from four other biomes. |
| `-Action CaptureStyle -StyleDocument 'C:\Codes\Godot\Beat my track\build\grass-cloud-baseline\starter.json'`, before and after | Both exit 0: native cells preserved, start/12 route/three model views saved. Selected paired route images retained. |
| `-Action Doctor` | Pinned engine/templates found; DN2103 attached. |
| `git diff --check -- <task source/report/status paths>` | Passes; status/plan CRLF-normalization notices only. |

The ignored helper `build/grass-cloud-baseline/capture_comparison.py` extracts only the installed original creator document and runs the two CaptureStyle commands, restoring final shader/light files in `finally`. Earlier preparation attempts failed before capture: PowerShell stripped quotes in an inline Python command, and the extraction initially assumed a nested `metadata` property. Native data stores `creator_document` at the top level; the corrected file-based helper completes both runs. These preparation failures are not counted as passing checks.

## Changed files and acceptance

- `game/track/cloud_shadow.gdshader`: cloud strength, scale, shape and tint.
- `game/track/track_theme.gd`: Grass sunlight only; the already-existing Night display-name edit is outside this task.
- `game/track/contact_shading.gd`: presentation revision.
- `game/tests/test_contact_shading.gd`: new evidence destination and eight-second gameplay capture.
- This report, `docs/CONTACT_LIGHTING.md`, status/phase-plan entries, and `docs/evidence/grass-cloud-contrast-2026-10-03/`.

No Android export, installation, physical-device driving, mobile GPU benchmark or thermal test was performed. DN2103 is attached, but attachment is not acceptance. Owner review of cloud strength and sunny warmth, moving-camera stability and bright-room phone readability remain. No physics/full replay regression, backend/service change or production deployment was needed for this presentation-only slice.

A scoped local Git checkpoint is saved at `checkpoints/grass-cloud-contrast-2026-10-03` using a temporary index. It contains only this task's code changes, new report/evidence and inserted status notes, excluding existing workspace edits (including the Night label). The active branch and ordinary index are unchanged. The initial checkpoint helper stopped on Windows' default text encoding before creating a commit; explicit UTF-8 fixes the helper. The baseline capture initially used the old diagnostic output destination; regenerated baseline images were retained under this task's `before/`, and historical tracked outputs restored to their committed versions.
