# Phone white terrain correction — 2026-10-12

Requirements: V04/V05/G01/R01/Q01, owner report that terrain textures are white on phone.

Attached OnePlus DN2103 (Mali-G77 MC9), OpenGL ES 3.2 Compatibility, reports
`The number of fragment samplers (17) is greater than the maximum number allowed (16)`.
This is a shader link failure, rather than missing texture artwork.
See `evidence/terrain-phone-2026-10-12/phone-render-errors.txt`.

Changed `game/track/surface_shader_variants.gd`: resolve road includes as well as terrain;
alias inactive biome samplers to the existing shared factor sampler. Constant-disabled
branches retain valid helper code without declaring additional texture units. Active
biome textures/samples remain intact. Declare the shared sampler before aliased helpers.
Optional absent flags are handled safely.

Changed `game/track/native_track_visual.gd`: specialize creator-road materials too;
track-kit-171 → 172 invalidates disposable old presentation caches. No canonical
track geometry, simulation, scoring, camera or player data changes.

Changed `game/tests/test_road_cache.gd`: compare actual shader source rather than
resource location, since generated shaders gain a subresource location on serialization.
All exact mesh/material/mask comparisons remain.
Added `game/tests/test_terrain_sampler_budget.gd`: build actual materials in all five
biomes, enforce at most eight authored samplers (eight units reserved for engine
lighting), and compile/render them in graphical mode. Captures are in
`evidence/terrain-phone-2026-10-12/{pine,storm,desert,winter,night_city}.png`.

Actual commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `Doctor`: attached DN2103 confirmed (sandbox ADB attempts first failed to create `.android`; elevated read succeeded).
- `TestGrass`: 15 checks, zero failures.
- `TestDesert`: 87 checks, zero failures.
- `CaptureGrass`: final 29 checks, zero failures, actual textured grass capture.
- `TestRoadCache`: final 70 checks, zero failures.
- `TestScript -ScriptPath res://tests/test_terrain_sampler_budget.gd`: final 57 checks, zero failures.
- Same with `-Graphical`: 57 checks, zero failures, five rendered captures, no shader errors.
- `git diff --check` for existing changed task files: passed (line-ending notices only).
- `ExportAndroid -QuickValidation`: two attempts blocked during import by failure to open
  `game/platform/windows/~bmt_windows_audio_v3.dll`. No APK produced or installed.

Intermediate issues corrected: sampler aliases initially referenced a later declaration;
cache comparison initially compared generated storage paths; the new fixture initially
omitted BridgePresentation's track argument and exposed an absent-flag bool conversion.
No failing acceptance requirement was removed.

Remaining: resolve the unrelated Windows extension import/build failure, export/install
the new APK, then verify normal racing on the physical phone in all biomes. Phone logs
were read, but the corrected build was **not physically tested**. Desktop captures are
not phone visual/performance acceptance. No backend operations/deployment/full physics
regression performed. Changes remain reviewable in the working tree; no Git commit made
in the shared tree containing substantial prior work.
