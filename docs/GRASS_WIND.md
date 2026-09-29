# Visible grass wind — 2026-09-28

## Lighting prototype rejected and removed

Owner rejected the preview, reporting mostly car colour changes. Removed all lighting-prototype shader code and its capture branch; restored original static surface shader byte-for-byte from HEAD. Generated blades remain removed (kit 85). Changed files: `surface_detail.gdshaderinc`, `test_grass.gd`, this document and status/plan notes. Requirements V02/V04/V05/Q01.

Diagnostic comparison of original preview frames 00 and 18 at car crop (625,350)-(670,375): source PNG average RGB difference is exactly [0,0,0], whereas the GIF averages [4.9564,2.2551,4.2676] on the same crop. GIF palette conversion introduced false car colour variation. The old GIF is rejected historical evidence, not a valid demonstration of stable non-grass colours. Future motion evidence should use video or a shared fixed palette.

Static Knot recheck: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureGrass -Screen static -Track track_1e3936d025fe7c82`: 21 checks passed; zero changed samples among 4082 grass and 13285 road pixels, no generated blades. `git diff --check` passed. No Android export or physical-device test in this rollback. Gameplay was already static because prototype strength defaulted to zero.

## Lighting-only prototype (opt-in preview)

Owner authorized trying lighting-only grass after rejecting texture displacement. Requirements V02/V04/V05/Q01. `surface_detail.gdshaderinc` adds an opt-in `grass_light_wind` parameter, default **0**: ordinary gameplay remains static, with no generated blades. Preview strength 0.08 alters normal angles plus a bounded smooth brightness response to an irregular travelling gust. Normal-only response was virtually invisible under cel shading (sample crop average change below 0.004/255); smooth brightness response avoids increasing angles enough to cross toon bands abruptly. No texture UVs, surface coverage, meshes or simulation values animate. This is an approximation of unresolved blade lighting, not simulated grass.

`test_grass.gd --screen=lighting` produces 48 fixed-time frames over four seconds at the normal Knot camera. Cloud shadows are hidden only in this diagnostic. [Lighting-only preview](evidence/grass-lighting/lighting-preview.gif). Actual commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureGrass -Screen lighting -Track track_1e3936d025fe7c82` passed 65 checks; the same command with `-Screen static` passed 21 checks after the final shader edit (0/4082 grass and 0/13285 road pixels changed). Desktop frame inspected. Existing review Python/Pillow assembled the 83 ms/frame GIF. No phone attached according to configured SDK `adb devices`; no device benchmark, export or install. Owner visual review is outstanding; effect is not enabled biome-wide.

## Final owner direction: remove blades and wind

Owner rejected the moving texture as unrealistic and explicitly requested removal of grass blades. This supersedes both wind revisions below (retained as historical evidence).

Requirements V02/V04/V05/Q01: kit 85 removes the generated `GrassTufts` construction from `native_track_visual.gd`, so runtime/editor track scenes no longer create these blade batches. Restored `surface_detail.gdshaderinc` to its original static pigment/normal sampling, restored the unused legacy tuft generator/shader, and removed the experimental `grass_wind.gdshaderinc`. Existing authored scenery and tyre clippings are outside this wind rollback. `test_grass.gd` now checks absence of generated blades and static grass pixels; the old wind-motion acceptance is superseded by the explicit owner request. Legacy generator unit checks remain isolated from production scenes.

Actual validation:

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureGrass -Screen static -Track track_1e3936d025fe7c82`: 21 checks, zero failures; no blade nodes in race scene, zero changed pixels among 4,082 grass and 13,285 road samples one second apart with cloud shadows hidden for diagnosis.
- `git diff --check -- game/track/native_track_visual.gd game/tests/test_grass.gd`: passed.
- `rg -n 'meadow_wind|grass_wind' game`: no remaining references.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestSurfaceProfile`: 928 checks, zero failures.
- Configured SDK `adb devices`: no phone attached. No Android export/install/device test.

Desktop [static meadow screenshot](evidence/grass-static/static-driving.png) inspected; [one second later](evidence/grass-static/static-after.png) saved. Restart the game to load the restored presentation. Remaining acceptance: owner visual review and device check.

## Revision 2: owner rejected tuft-only movement

The first revision below passed structural checks but failed the owner's visible-motion acceptance: the static meadow texture dominated the driving view. Those checks did not establish a noticeable effect.

Track kit 84 animates that visible meadow layer as well as the standing geometry. New `game/track/grass_wind.gdshaderinc` supplies a shared travelling wind field, with a bounded 10 cm displacement and a diagnostic fixed-time override (normal runtime uses shader TIME). `surface_detail.gdshaderinc` bends grass colour sampling and normals; macro patches, road masks and surface boundaries stay anchored. Winter/desert return before grass animation. `grass_tuft.gdshader` applies the same field to blade vertices and normals. `grass_tufts.gd` raises blades from 6.5–10.1 cm to 16–22.6 cm, spreads the existing 120 placements per cluster across a 3 m radius, and reserves 11 cm culling margin. Placement clearance remains 45 cm and maximum triangles/instances per batch remain unchanged; total accepted tufts/batches differ because distribution changed. `native_track_visual.gd` advances presentation version 83 to 84.

`test_grass.gd` now records exact 1/12-second wind phases with cloud shadows disabled. It compares rendered grass and road-interior pixels at times 0 and 1 second, using canonical surface classification away from boundaries. This directly tests visible movement instead of only valid placements. Paused race/camera and shader wind remain separate.

Actual checks:

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureGrass -Screen wind`: **53 checks, zero failures**; 8,092/11,292 grass pixels changed by >0.02 in an RGB channel, 0/7,378 road pixels changed. 13,818 tufts, 46 batches across the whole fixture.
- Same command with `-Track track_1e3936d025fe7c82` (Knot): **54 checks, zero failures**; 3,005/4,082 grass pixels changed, 0/13,285 road pixels changed. 96,016 tufts, 236 batches across the whole map (not the visible/GPU count).
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestSurfaceProfile`: **928 checks, zero failures**, rendering Ajorata and Stormy slalom with material isolation/swap checks.
- `git diff --check` on the changed runtime/test files passed.
- Configured Android SDK `adb devices`: no attached devices. No export, installation or phone performance test performed.
- Existing `.tools/review/Scripts/python.exe` / Pillow assembled the PNG sequences as 83 ms/frame GIF previews; no runtime dependency added.

Evidence: [normal driving view](evidence/grass-wind-v2/grass-wind.gif), [Knot driving view](evidence/grass-wind-v2/track_1e3936d025fe7c82/grass-wind.gif), and their source PNG sequences. Desktop still frames inspected. Pixel checks prove motion, not artistic acceptance or phone performance. Most ground coverage remains a shaded textured surface, now animated; standing blades provide additional geometry. Owner judgement on the revised movement and physical-phone frame pacing remain open. Restart the running game to load the revised shaders and taller geometry.

## Revision 1 (superseded)

Requirements: V02/V04/V05/Q01; owner requests more visible grass-biome movement.

`game/track/grass_tuft.gdshader` increases maximum tip sway from 6 mm to 45 mm, adds broad travelling gusts and converts a shared world wind direction into each tuft's local coordinates. Roots remain fixed. Existing shared tuft users also receive this motion. No geometry density, shadows, canonical simulation or gameplay camera changes. `game/track/grass_tufts.gd` adds 5 cm culling margin for shader displacement.

`game/tests/test_grass.gd` adds an optional `--screen=wind` capture branch using the production gameplay camera. Evidence: [animated preview](evidence/grass-wind/grass-wind.gif) and 36 source frames in that directory. Desktop frames 00 and 12 inspected; owner motion acceptance remains.

Actual commands and results:

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureGrass -Screen wind`: pinned Godot 4.7.2 Compatibility, RTX 3090; 51 checks, zero failures. Fixture has 14,118 tufts in 42 spatial batches. Existing placement, density, shadow, theme and canonical-cell checks passed; rendered shader compiled successfully.
- `.tools/review/Scripts/python.exe` with Pillow assembled the 36 PNG captures into `grass-wind.gif` (100 ms/frame preview; capture timers are approximate, not a performance measurement).
- `git diff --check -- game/track/grass_tuft.gdshader game/track/grass_tufts.gd game/tests/test_grass.gd`: passed.

No Android export, installation or physical-device performance test performed. Remaining acceptance: visibility during real driving, owner preference for strength, and phone frame pacing/thermal cost. Shader timing is presentation-only. No new assets or external runtime dependencies.
