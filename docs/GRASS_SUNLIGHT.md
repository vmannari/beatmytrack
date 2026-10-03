# Grass golden sunlight prototype — 2026-10-03

## Stronger follow-up

Owner found the first version imperceptible and requested phone deployment. `contact-lighting-10` increases maximum veil alpha from 0.19 to 0.42, moves its centre closer to the visible frame (0.62 to 0.48 normalized offset) and broadens its falloff (1.35 to 1.55). Existing cloud contrast and sun projection remain. No additional rendering resources. Changed shader, presentation revision and capture defaults/destination; earlier evidence retained.

Actual `-Action CaptureContactShading`: 49 checks, zero failures; stronger paired images inspected. `-Action TestContactShading`: 23 checks, zero failures, with three shutdown ObjectDB instance warnings. [Stronger before](evidence/grass-sunlight-stronger-2026-10-03/sunlight-before.png), [stronger after](evidence/grass-sunlight-stronger-2026-10-03/sunlight-after.png). GPU cost remains unmeasured; phone visual/motion and sustained performance acceptance remain.

Actual `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action DeployAndroid`: full built-in regression sequence passes, fresh Android debug APK exports, `adb install -r` reports Success and launch reports Status ok / COLD (820 ms). DN2103, serial PRQKU4U4PREQNRWG; package `org.circuit01.handlinglab`. Logs: `build/logs/DeployAndroid-7964/`. SDK build-tools fallback to 35.0.1 is reported; several headless tests retain shutdown instance warnings. No tests were removed or bypassed. App process existence checked after launch. This verifies deployment/startup only, not human driving, in-race phone visuals, FPS or thermal acceptance. Concurrent launch-notice edits are included in the workspace APK but excluded from this sunlight checkpoint; preserve those edits. Historical first-pass no-deployment statement below refers to the earlier prototype only.

Requirements V02/V04/V05/Q01. Owner requests trying the supplied warm sunlight reference in Grass after discussing performance. Presentation revision `contact-lighting-9` adds a soft golden veil to the existing Grass cloud shader. The veil fades in cloud shade and projects the existing sun direction through the active view matrix, so camera rotation changes its screen direction. Maximum alpha is 0.19; existing cloud coverage, drift and darkness remain. This is a stylized glare approximation, not bloom, volumetric rays or physically computed material highlights.

No additional pass, light, shadow map, texture read or render target. Added per-pixel projection, radial falloff and alpha-composition arithmetic has an unmeasured GPU cost. A zero-strength capture disables its visible contribution, not its shader arithmetic; it is not a performance baseline. No FPS or millisecond saving/cost is claimed. Existing sunlight/materials, canonical simulation, camera framing, HUD, other biomes and player files are unchanged.

Changed files: `game/track/cloud_shadow.gdshader`, `game/track/contact_shading.gd`, `game/tests/test_contact_shading.gd`, this report, status/phase-plan notes and `docs/evidence/grass-sunlight-2026-10-03/`.

Actual commands use `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `-Action CaptureContactShading`: 49 checks, zero failures, Compatibility/OpenGL on RTX 3090. Includes paired same-pose sunlight off/on captures, visible golden contribution, cloud motion, bridge/contact checks and opaque HUD isolation. Production and overview images inspected.
- `-Action TestContactShading`: 23 checks, zero failures; canonical preservation, pause/layer/contact and biome lifecycle checks.
- `-Action Doctor`: pinned engine/templates found; DN2103 attached.

[Before](evidence/grass-sunlight-2026-10-03/sunlight-before.png), [after](evidence/grass-sunlight-2026-10-03/sunlight-after.png), [overview](evidence/grass-sunlight-2026-10-03/clouds-0s.png). The bridge scene is a diagnostic fixture; the initial pair uses the production camera. Paused UI is not evidence of human driving. The source reference is guidance, not a shipping asset.

Remaining acceptance: owner warmth/strength review, rotating-camera motion/readability, representative track views, physical-phone A/B GPU timing and sustained thermal performance. A phone is attached but no device test, export or installation was performed. Desktop/device GPU profiling was not performed. This first pass does not reproduce the reference's asphalt highlights or strong upper-left bloom. No full replay/physics regression or backend/deployment action was needed for this presentation-only change.
