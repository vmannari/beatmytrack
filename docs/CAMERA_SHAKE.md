# Collision and off-track camera shake — 2026-09-20

Requirements: G01, R01, V01, V04, Q01.

## Lower-frequency off-road rumble - 2026-09-22

Requirements G01/V01/Q01. The continuous loose-surface vibration now uses slower layered frequencies (primary 61 rad/s and secondary 43 rad/s, with 53/37 rad/s cross-axis layers) instead of the previous 131/79 and 113/67 rad/s profile. Its maximum displacement, speed/resistance scaling, smoothing and HUD isolation are unchanged. Collision impact spring/noise is also unchanged, so impacts retain their short directional kick.

Changed files: `game/camera/follow_camera.gd`, `game/tests/test_camera_shake.gd`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, and this document.

Actual checks: pinned Godot 4.7.2 parsed `follow_camera.gd`; `res://tests/test_camera_shake.gd` passed 7/7 checks, including the explicit lower-frequency profile, bounded impact settlement, strength scaling and reset. `TestDriving` also passed 74/74 checks including all-heading framing. No screenshot is useful for a temporal-frequency-only adjustment, and no video was captured. No physical-phone test was performed; final frequency and comfort still require owner/device feel acceptance.

## Behaviour

- The rejected general-purpose jitter has been replaced by a directional camera impulse. The race presenter passes the actual post-minus-pre collision velocity change, so the camera kicks away from the struck surface.
- Collision displacement is a damped spring: one sharp movement, a small rebound and settlement. A trauma accumulator only supplies a minor squared texture component and prevents repeated contacts from restarting or stacking without limit.
- Loose-surface rumble scales with existing surface resistance and vehicle speed, then blends in/out continuously at a 9/s response. Its 0.05 m cap is approximately 1.5 px at calibrated framing.
- Shake is presentation-only. The collision cap is 0.32 world metres (approximately 10 px); canonical state, physics/replay versions, framing, yaw, pitch, zoom and the CanvasLayer HUD remain unchanged.
- Restart/snap clears all impulse, trauma and surface state.

## Impact glass follow-up

The rejected temporary starburst is replaced by an original generated transparent broken-glass texture, `game/assets/textures/impact_glass_v1.png`. It follows the owner's reference composition: dense irregular shards and fractures around all four edges with the central driving view kept broadly clear. The supplied reference is not shipped.

Meaningful impacts (resolved velocity change above 7 m/s) add persistent damage. A four-channel reveal shader tracks left, right, top and bottom independently. The resolved collision direction selects the struck screen edge, and repeated impacts gradually expose more fractures there. Only after that edge is completely fractured does excess damage begin filling the least-damaged remaining edge. Corner masks blend adjacent sides without a hard seam.

The glass remains for the complete race and clears only on restart/new race; small scrapes do not trigger it. All zones and total visibility remain capped. The overlay is input-transparent and presentation-only.

Generation used the built-in image-generation tool with the owner image as composition/material reference. Final prompt requested an original 16:9 photoreal transparent shattered-glass overlay, edge-heavy asymmetric damage, long inward stress cracks, clear central 55%, neutral highlights, no background/checkerboard/text/watermark/logo/blood/tint.

## Changed files

- `game/camera/follow_camera.gd`
- `game/camera/impact_cracks.gd`
- `game/camera/impact_glass.gdshader`
- `game/assets/textures/impact_glass_v1.png` and import metadata
- `game/core/game.gd`
- `game/tests/test_camera_shake.gd`
- `game/tests/test_impact_cracks.gd`
- `DEVELOPMENT_STATUS.md`
- `docs/PHASE_0_PLAN.md`

## Actual validation

- Both changed runtime scripts passed `scripts/dev.ps1 -Action CheckScript` with pinned Godot 4.7.2.
- `Godot_v4.7.2-stable_win64_console.exe --headless --path game --script res://tests/test_camera_shake.gd` — 6 checks passed, including directional dominance, scaling, bounds, settlement and surface blending.
- `scripts/dev.ps1 -Action TestTracks` — 167 checks passed.
- `scripts/dev.ps1 -Action TestSoil` — 155 checks passed.
- `scripts/dev.ps1 -Action Import` — generated glass texture imported successfully.
- `Godot_v4.7.2-stable_win64_console.exe --headless --path game --script res://tests/test_impact_cracks.gd` — 8 checks passed for threshold, texture binding, affected-side selection, gradual local accumulation, persistence, overflow to another side, cap and restart clearing.

## Limitations and acceptance

No physical-phone test was performed. Camera motion and persistent glass require owner acceptance in motion for directional kick, rebound timing, crack prominence, central visibility, prolonged off-track comfort and phone readability. Per-surface grass/sand/gravel vibration profiles, camera rotation, extra braking lag and a reduced-motion setting are not added in this focused correction.
