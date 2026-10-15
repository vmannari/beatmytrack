# Tribal and varied livery collection

LVY01–LVY04 / LE01–LE04 / LV01–LV06 / LM01–LM05 / V03–V06 / G01 / R01 / Q01: the owner requests more variety, including tribal designs. The library adds **16 original wraps**, bringing Patterns to **Midnight plus 48 wraps**.

The six tribal designs are Tribal Fang, Tribal Flow, Tribal Wing, Tribal Thorn, Tribal Crest and Tribal Surge. Their abstract motorsport motifs use curved hooks, flowing negative space, broad wings and barbs. All paths are original; no cultural or sacred symbols are reproduced. The other ten are Ink Brush, Paint Splash, Art Deco, Op Art, Paisley Drift, Ribbon Weave, Scale Shift, Petal Drift, Halftone and Graffiti Slash. They add different graphic families and authored three-colour palettes.

`scripts/build_livery_art.py` remains the editable vector source. Each addition has an opaque 512×512 accent/detail data mask and a 160×96 colour preview. The catalogue appends new stable IDs after the existing thirty-two entries. A direct comparison confirms the prior entries, ordering and palettes are identical. Existing photos and sticker SVGs also match the previous delivery SHA256s: 178 files checked, zero differences. The 24 decals, their atlas and menu categories are unchanged.

The native preview bake now accepts an optional `--patterns=id,...` argument so additions can be photographed without rewriting existing cards. This task bakes **80 photographs**, sixteen for each of the five actual car models, at 320×200 with mipmaps. New source PNGs total **4,937,869 bytes**; the complete library has 245 photographs. Photos use the existing native model, lighting, pose and studio camera. The production menu still uses static images, with the same retained actual showroom, car, camera and per-car controls.

All three colour roles remain editable. New IDs use the unchanged local version-two livery record and version-one pigment migration, under the existing dirt/snow and compatible with emblem/sponsor placement and fitted parts. There are no new car meshes, material passes, shadow geometry, shader texture reads or canonical handling/scoring changes. The four-mask cache, sixteen-photo kit cache and six-root workbench bound are preserved.

Changed source files are `scripts/build_livery_art.py`, `game/tests/bake_livery_previews.gd` and `game/tests/test_livery_patterns.gd`. Shipping changes are the appended `game/assets/liveries/catalog.json`, 32 new SVG masks/previews, 80 new native photographs and their mipmap import settings. Documentation and the isolated review checkpoint accompany them. Existing menu, car, shader, kit, trail, dust, bridge, backend and physics source changes are outside this task's delta.

Actual commands use pinned `4.7.2.stable.official.ed1daf0bf`:

```powershell
python scripts/build_livery_art.py
$liveryBakeArgument = Get-Content -LiteralPath 'docs/evidence/livery-variety-2026-10-14/bake-argument.txt' -Raw
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_livery_previews.gd -Graphical -RenderingMethod gl_compatibility -TestArgument $liveryBakeArgument -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_livery_patterns.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_livery_patterns.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180
```

New assets were imported with the pinned executable in the bounded asset-only project `build/livery-variety-import-2026-10-14`, using the same `res://assets/liveries/...` paths and the existing mipmapped import settings. Only new livery sidecars and prepared resource bytes were copied into the shipping project's cache. This preserves the open editor and avoids the previously recorded locked native-audio importer; no full-project import pass is claimed. `asset-import.log` and `photo-import.log` contain both successful imports.

Final validation passes **842 Compatibility + 842 Mobile/Vulkan checks**, and the project parser passes **710 scripts, zero failures**. Livery checks cover all 48 masks for distinct mipmapped images; all 80 new native photo dimensions/filtering; all 48 designs on the five simple-model constructions; original painted-surface counts; actual weathering shader bindings and washing restoration; per-car save/reload with new IDs; Midnight; native card input; selected-role colours; physical roof gating; independent emblem/sponsor placement; retained car/camera/tool roots; three UI sizes; tribal selection persistence; and the ordinary race construction with the saved tribal design and sponsors. Logs are in `delivery.json`.

Initial Mobile/parser runs encountered the concurrently added CompactAero class before registration, a temporary trail-preparation test syntax error and the game calling SandDust.prepare_track before that implementation was published. These errors are recorded; this task did not alter those source files or remove checks. Validation was repeated after the interfaces appeared.

Both-renderer actual captures are under `docs/evidence/livery-variety-2026-10-14/{gl_compatibility,mobile}/`. `new-patterns.png` is the sixteen-car contact sheet, in catalogue order: six tribal designs, Ink Brush, Paint Splash, Art Deco, Op Art, Paisley Drift, Ribbon Weave, Scale Shift, Petal Drift, Halftone and Graffiti Slash. Individual pattern pictures, all 48 wraps, 1280×720/960×540 tribal browsers, colour/sticker tools, physical-car variants and ordinary gameplay are also recorded. Native cards and full-size both-renderer sheets were visually inspected for different motifs, readable names and unobstructed car/tools.

The isolated checkpoint, task-only binary patch and SHA256 manifest are recorded in `delivery.json`; the real Git index and HEAD are not moved by the task's checkpoint. No phone commands, physical-device test, APK/export/install, backend writes or deployment were performed. Owner acceptance of the new artwork and physical-phone legibility/frame pacing remain; desktop captures are not a claim of completed AAA/device acceptance.
