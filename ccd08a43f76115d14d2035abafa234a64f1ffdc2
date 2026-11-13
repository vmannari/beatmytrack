# Forklift solid sides and rear sticker - 2026-10-25

FS01-FS03/R01/Q01 address the owner's thin-side rendering artefacts and obscured stickers. The Forklift now has closed side skins and wheel-arch shells, plus one sticker location on the clear rear counterweight between the tail lights. [Native before/after gallery](evidence/forklift-body-sticker-2026-10-25/report.html) and [evidence report](evidence/forklift-body-sticker-2026-10-25/report.json).

FS01 gives the formed sides 0.065 model metres of thickness and the rolled arches 0.045 model metres, including inner faces, edge returns and end caps. Arch trim sits 0.030 model metres farther out to avoid overlapping the side face. Both sides and all four arches are closed in detailed and racing models, with zero boundary or inconsistent edges. The saved original side has 194 open boundary edges. Detailed/racing models contain 146,792/49,688 triangles and retain 40 prepared mesh instances. This is a presentation change; handling, raised forks, speed, steering, body scale and collision remain as previously tuned.

FS02 reuses the existing primary sticker data slot on a rear-facing X/-Y projection. Its paint area is 0.78 by 0.44 model metres between the lights. The placement is pigment in the opaque paint shader, so no extra decal plane or overlapping draw pass is introduced. The old engine-lid sticker was hidden by the cooling recess/louvres. Only the rear sticker is enabled on the Forklift; its unused roof slot is not displayed. Existing saved sticker IDs, position, size and rotation remain intact, with no schema or backend change. New sponsor wordmarks start upright on the rear; other cars retain their existing orientation.

Garage offers a single **Rear** location. Selecting Stickers, selecting that location or entering placement focuses the actual rear panel. The placement board uses the matching rear paint projection. Leaving placement restores the normal preceding-view behavior. Existing Workshop navigation, ownership, preview, cleanliness and explicit purchase/equip rules remain.

FS03 refreshes all 49 current Forklift appearance photos and the native catalogue illustration. The photos now generate mipmaps like the established filtered previews. Other cars' images are not changed.

All engine commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` and pinned Godot `4.7.2.stable.official.ed1daf0bf`; the two-argument artwork bake uses a PowerShell `-Command` array invocation instead.

| Actual command/check | Result |
|---|---|
| `TestScript -ScriptPath res://tests/test_forklift_finish.gd` | 59 checks, zero failures |
| Same with `-Graphical -RenderingMethod gl_compatibility` | 77 checks, zero failures; before the final preview-filter assertion was added |
| Same with `-Graphical -RenderingMethod mobile` | 78 checks, zero failures; includes the final preview-filter assertion; desktop renderer |
| `TestScript -ScriptPath res://tests/test_forklift.gd -TestArgument '--evidence-dir=res://../docs/evidence/forklift-body-sticker-2026-10-25/regression'` | 98 checks, zero failures; batching, canonical original-car traces, rear steering, save and real offline race |
| Same with `-Graphical -RenderingMethod gl_compatibility` and array arguments for evidence directory plus `--bake-art` | 107 checks, zero failures |
| `TestScript -ScriptPath res://tests/bake_livery_previews.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--vehicle=forklift'` | 49 native captures complete |
| `Import` | Pass; refreshed native artwork and filtered previews |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` | 1,142 scripts, zero failures |
| `TestScript -ScriptPath res://tests/test_livery_patterns.gd` | Fails: pre-existing unfiltered new-car previews, then stale five-car fixture asks pattern index 50 from 48 entries. Forklift preview filtering is corrected here; Electric images and that test are unchanged. |

The focused test verifies real closed-mesh topology in both detail levels, loads the saved original body into an isolated process for the before render, and compares native sticker-on/off images. Compatibility records 13,616 changed rear pixels, zero front/side/top pixels and 13,640 weathered rear pixels. Mobile measurements are retained in its report. Both verify the actual Garage's one location, camera, placement, removal and save reload. A supplemental matrix exercises every pattern on each of the other six cars, including weathered paint, preserving their original panel mapping and mesh counts.

The first save assertion compared binary floating-point dictionary values after JSON encoding and failed on rounding below visible placement precision. IDs remain exact; the corrected assertion compares all four numeric placement fields with the engine's approximate-number comparison. The initial 38-check/one-failure log remains. The first graphical run passed 58 checks but its short placement screenshot revealed a camera reset to the front; the correction adds an explicit placement-camera regression and retains that initial image/log. No failing production behavior or legacy assertion was hidden or removed.

Changed runtime sources: `game/vehicle/forklift_model.gd`, `livery_catalog.gd`, `livery_graphics.gd`, `livery_finish.gdshaderinc`; `game/ui/garage_page.gd`, `garage_livery_menu.gd`, `garage_customisation_camera.gd`, `sticker_placement.gd`, `sticker_panel.gdshader`. New test: `game/tests/test_forklift_finish.gd`. Native assets, status files and the original Forklift guide accompany the change. The scoped source patch and native asset payload preserve concurrent workspace work without changing the Git index or HEAD.

No phone/tablet attachment check or physical-device test, APK, purchase, live backend mutation, deployment or owner-process restart was performed. Reload the game to use the changed model, shader and previews. Owner/device appearance and frame-pacing acceptance remain.
