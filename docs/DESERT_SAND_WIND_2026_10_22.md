# Desert wind-lifted sand trial — 2026-10-22

The owner requests wind lifting sand from the Desert ground, informed by the supplied dune photograph. This local trial adds thin, warm, branching sand veils that lift about 0.35–1.1 m and drift downwind. The reference is direction only; it is not shipped or copied into a texture.

## Requirements and implementation

- **DSW01:** Seat the windward foot on loose sand, lift into a shallow curved veil and fray it into elongated fingers and grains. Existing wind audio supplies the gust envelope; slower local modulation varies individual sources. Actual directional/ambient lighting shades the sand.
- **DSW02:** Integrate into Desert races and editor test drives through the existing race weather lifecycle. Pause, application suspension and hiding stop updates; finish fades and retry clears the effect. A biome change detaches and frees the node.
- **DSW03:** One world-aligned MultiMesh, at most 81 instances / 2,592 triangles, with one shared subdivided plane and the existing original baked Winter flow texture. Sources update only after crossing a six-metre grid cell. Reuse the prepared Desert visual-relief object; no new field build, texture generation, CPU image readback, whole-world mesh search, persistent cache or simulation work runs in the effect. Source cells exclude compacted road, water, rock, out-of-map points and overhead bridges.
- **G01/R01/Q01:** Preserve world/camera/road dimensions, canonical cells/route/content identity and actual driving snapshots. Retain vehicle dust and existing audio, account and race workflows. Capture both renderers and check meaningful lifecycle/depth behavior.

Runtime files: `game/track/desert_sand_wind.gd`, `game/track/desert_sand_wind.gdshader` and four small integrations in `game/core/game.gd` (ownership, presentation, retry and weather replacement). New `.uid` files retain resource identities. `game/tests/test_desert_sand_wind.gd` owns the disposable circuit, invariants and native captures. No new bitmap or external dependency is required by the game. The evidence encoder uses the already available local review environment, outside the game.

The source anchor reads the prepared cosmetic road depression. A soft depth intersection uses each renderer's depth convention and suppresses fragments behind opaque terrain, cars and props. Sand physically in front of a low object can still be visible; this is not a blanket screen-space exclusion around cars.

## Native evidence

- [Compatibility motion](evidence/desert-sand-wind-2026-10-22/gl_compatibility/motion.html) and [compact animation](evidence/desert-sand-wind-2026-10-22/gl_compatibility/motion.webp).
- [Desktop Mobile motion](evidence/desert-sand-wind-2026-10-22/mobile/motion.html) and [compact animation](evidence/desert-sand-wind-2026-10-22/mobile/motion.webp).
- Each renderer directory retains `before.png`, `gust.png`, `detail.png` and `occlusion.png`. The detail view is a fixture camera; runtime camera settings remain unchanged. Motion is 120 actual Godot frames, sampled at 30 presentation steps per second, with a wind lull near the end. HTML retains pause/play controls; WebP is an encoded preview of those same frames.
- Final paired overhead frames change 74,696 Compatibility pixels and 76,194 Mobile pixels. These are visibility observations, not a quality/performance score. In both renderers all 783 projected interior pixels on an opaque roof above the maximum loft remain exact when sand is enabled.

Both native runs use the desktop NVIDIA GeForce RTX 3090. Mobile means the desktop Vulkan Mobile renderer, not Android execution.

## Actual verification

Pinned engine: `4.7.2.stable.official.ed1daf0bf`. All engine work uses `scripts/dev.ps1`; the older PATH alias is unused. Engine startup needs normal Windows certificate-store access in this session, so engine runs used the approved local execution context after the sandbox startup failed.

Final commands and outcomes are recorded in `evidence/desert-sand-wind-2026-10-22/report.json` and adjacent logs. Core commands:

Final outcomes: focused **65 headless / 71 Compatibility / 71 desktop Mobile**, existing Desert **87**, Desert ambience **111**, biome **108** and project parser **926 scripts** all pass. Import and scoped whitespace validation also pass; the receipt identifies their logs.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_sand_wind.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_sand_wind.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_sand_wind.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_ambience.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_biomes.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180
.tools/review/Scripts/python.exe docs/evidence/desert-sand-wind-2026-10-22/encode_preview.py
git diff --check -- game/core/game.gd game/track/desert_sand_wind.gd game/track/desert_sand_wind.gdshader game/tests/test_desert_sand_wind.gd
```

The focused checks cover bounded valid sand sources, pause/background/hidden/invalid input behavior, calm/finish/retry, real race ownership, shared ground support, unchanged actual driving state, biome teardown, exact canonical data and native depth/visibility. Existing Desert driving, wind audio, biome and parser results are in the receipt.

## Retained corrections

1. The initial direct PowerShell invocation was blocked by local execution policy. The subprocess uses the established `-ExecutionPolicy Bypass` invocation. The sandbox engine startup then reported certificate-store access denial. The subsequent approved engine context started normally. No external action or deployment was attempted.
2. Initial import rejected a normalized vector method in a constant expression. Keeping the same unit vector as literal components corrected parsing; `import-retry.log` retains that first parse failure. Final parser and runtime checks compile the class.
3. Initial Compatibility evidence was too faint against the sand. Its images remain in `initial-gl_compatibility/`. The revised veil has a lighter pigment, a fuller but bounded opacity, a narrower seated foot and slightly higher loft. Runtime behavior and budgets remain unchanged.
4. The first occlusion fixture incorrectly counted physically visible powder in front of a low box's sides as overpainting (70/1). The corrected fixture isolates a roof above maximum loft. The initial Mobile capture also showed the OS focus pause menu's frozen screen instead of live sand (70/2); the fixture now dismisses that overlay before drawing. Its screenshot remains in `initial-mobile/`.
5. A subsequent Mobile fixture found no pixels with its strict magenta threshold because renderer fog/tone mapping changes that colour (70/1). Both final renderers use the same inset projected roof polygon, independent of colour, retaining strict pixel equality. Final Compatibility and Mobile each pass 71 checks with 783 unchanged roof pixels. No runtime guard or equality assertion was relaxed.
6. Receipt generation initially assumed UTF-8 logs; Windows PowerShell wrote UTF-16 logs. BOM-aware decoding corrects the receipt without rewriting the original logs. Repeated receipt generation preserves the original status snapshots and does not duplicate entries.

Capture readbacks and deliberately disabled physics/render stepping cause `RACE_HITCH` diagnostic messages in graphical logs. They are not gameplay timings or a performance measurement.

## Delivery and acceptance

The task-only source patch and fingerprints are retained with the evidence. The workspace contains substantial concurrent work, including graphics preferences in `game.gd`; the patch baseline removes only this task's exact integration blocks from the final source, preserving those concurrent changes.

Restart/reload the local client and enter a Desert race to try the effect. Owner acceptance of density, speed, colour and lift remains. The static editor overview does not run race weather; editor test driving does. Physical-device appearance, frame pacing, thermals and overdraw remain unmeasured. No phone attachment check or device test, APK/export/install, live account/progression change, backend action or deployment was performed.
