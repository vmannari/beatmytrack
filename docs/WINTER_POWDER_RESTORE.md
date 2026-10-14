# Restored bank powder with optimized materials — 2026-10-13

The owner reports that driving-through-bank powder has disappeared and requests its return with better dust-cloud-style snow. The regression was reproduced: the visible-bank height bake found zero cells after fixed-role shader compilation replaced the original Shader objects. Powder then originated inside the taller cosmetic banks and was occluded.

## Requirements and change

- WSP04, restore the effect: `game/vehicle/sand_dust.gd` now recognizes the retained `smooth_road_bank` material role through the shader's public uniform interface. This covers optimized, disk-loaded and legacy bank materials, including the false role value on legacy geometry. It preserves the performance pass and its shader variants; no terrain shader, opaque order, mask packing or artwork is reverted.
- WSP05, appearance: `winter-spray-7` keeps the existing textured dust-cloud renderer and artwork. Pushed powder has a wider randomized birth area, more broken granular density and whiter highlights/cool shaded lobes. Compact puffs still expand briefly, spread outward, fall and fade over0.62 seconds; entry puffs last0.42 seconds. The existing44-slot/four-system bank budget, card sizes, gravity, damping and world/depth guards remain.
- G01/R01/V04/V05/Q01: accepted bank resistance, canonical physics56, camera, scenery, road/bank artwork and all other-biome effects remain. The once-built sparse surface lookup and fine contact index are retained; material-role discovery runs only while configuring the visual surface.

`game/tests/test_snow_bank_behaviour.gd` adds a regression using actual specialized bank meshes, a real disk save/load, exact height-map comparison and legacy false-role recognition. It retains the original nonempty height/actual GPU visibility assertions. This task also updates `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`; no new asset or dependency is added.

## Actual verification

All engine commands use pinned Godot `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`, with PowerShell process execution-policy Bypass and normal Windows graphics/certificate access.

| Arguments after `scripts/dev.ps1` | Actual result |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_snow_bank_behaviour.gd -Graphical -TestArgument @('--capture','--output-dir=res://../docs/evidence/winter-powder-restore-2026-10-13/baseline')` before the fix | Failed the existing nonempty height assertion; bake found0 cells, reproducing the regression |
| `-Action TestScript -ScriptPath res://tests/test_snow_bank_behaviour.gd -Graphical -TestArgument @('--capture')` after the fix | Final Compatibility:52,040 checks,0 failures;5 new cache/material checks;180 actual driving frames,80 pushing frames,two entry bursts |
| Previous final command with `-RenderingMethod mobile` | Mobile Vulkan:52,040 checks,0 failures; same contact/driving results |
| `-Action TestDesert` |87 checks,0 failures; original dust preserved |
| `-Action Doctor` | Pinned engine/templates found; DN2103 attached; no physical-device test performed |

Actual GPU hidden/shown comparisons detect1,836 Compatibility and1,781 Mobile powder pixels at the contact. Both captured the powder above the visible banks. Real disk-restored specialized materials produce the exact same height dictionary as the cold build. The additional test initially used a resource path where the cache writer expects an absolute directory; the fixture was corrected to globalize its owned scratch path. All original visibility/cache requirements are retained, and initial logs remain.

The existing fixed-position desktop GPU diagnostic varies with other desktop load: Compatibility visible medians0.708/0.738 ms, hidden0.778/3.728 ms; Mobile visible1.772/1.813 ms, hidden0.469/3.355 ms. These cannot establish a precise incremental effect cost. Captures pause particle positions for measurement and perform screenshot readbacks; the logged diagnostic frame gaps of roughly310–340 ms are not active-game frame-pacing measurements. No phone FPS/thermal claim or new biome-performance comparison is made. The fix preserves the existing44-particle allocation rather than increasing it.

## Evidence and acceptance

[Driving motion](evidence/winter-powder-restore-2026-10-13/motion.html), [powder still](evidence/winter-powder-restore-2026-10-13/push-visible.png), [Mobile motion](evidence/winter-powder-restore-2026-10-13/mobile/motion.html), [Mobile still](evidence/winter-powder-restore-2026-10-13/mobile/push-visible.png), [Native profile](evidence/winter-powder-restore-2026-10-13/powder-profile.json), [Mobile profile](evidence/winter-powder-restore-2026-10-13/mobile/powder-profile.json). The closer inspection camera belongs only to the diagnostic.

Restart the client so the corrected bank material discovery and powder variant load. Owner appearance acceptance remains for normal-camera visibility, glancing entry and deep/reverse travel. No phone play/performance test, APK export/install, full Validate, physics merge, backend test/deployment or live write was performed. Original dust-texture provenance remains.

The isolated task-only checkpoint/source patch is in `build/winter_powder_restore`, with main index/HEAD and concurrent work preserved. Large motion HTML and disposable road-cache artifacts remain in workspace evidence rather than being duplicated into the checkpoint.
