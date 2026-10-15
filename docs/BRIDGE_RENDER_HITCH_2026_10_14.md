# Bridge first-use rendering investigation, 2026-10-14

The live Pine/Compact/Compatibility freeze was captured at **6.100 s of driving**: **330.171 ms** between observed frames, with **305.045 ms between render signals**. Material preparation had already run. Bridge road, under-shadow and fascia were new candidates in the following 5 Hz visibility sample. See the [preserved live analysis](evidence/race-hitch-recurrence-2026-10-14/findings.md).

The cached public **Silmukka** document was copied into ignored `build/bridge-first-use-2026-10-14/track-document.json`. Compilation matches the live geometry hash exactly: `11bc2da60320c9b3e047b88c2dbf36ff22a7c20affb2ac03d48873e1ab4f68fb`. It contains one bridge. The diagnostic freezes the full countdown, simulation and condition, uses disposable records, disables normal callbacks, and reveals only the selected original bridge meshes. No player race or driver shader cache was reset.

On the RTX 3090 / Godot 4.7.2 / Compatibility renderer:

| Probe | First render boundary | Later/repeat boundaries |
| --- | ---: | ---: |
| Original bridge, all three groups | 105.256 ms | about 8 ms |
| Original road only, subsequent process | 18.052 ms | about 8 ms |
| Original under-shadow only, subsequent process | 8.230 ms maximum | about 8 ms |
| Original structure only, subsequent process | 12.279 ms | about 8 ms |
| Original bridge submitted from the starting camera during preparation | 22.649 ms under preparation | first visible bridge 8.069 ms; maximum of six 8.212 ms |
| Diagnostic fixed-role bridge-road shader variant, first run | 998.211 ms | about 8 ms |
| Same diagnostic variant with preparation, subsequent run | 65.212 ms under preparation | maximum of six first visible frames 8.237 ms |

These are separate runs on a shared desktop with evolving shader/driver caches, not a controlled cold-cache speedup comparison. The variant uses the project's existing `SurfaceShaderVariants.specialize` helper only in the probe; **production bridge shaders and material bindings are unchanged**. The measurements establish a bridge first-use delay and a particularly expensive first use of a new road-shader variant. They strengthen shader/program compilation as the explanation, but do not identify the native call responsible for the original 305 ms interval, nor isolate its cost to one of the three original groups. Earlier Desert captures without bridges still need a separate explanation.

The production mitigation submits the **actual existing bridge meshes** during the already-covered finish preparation draw. Their culling boxes temporarily include the starting camera, so offscreen meshes reach the renderer while their original vertices remain in place. The helper restores every original cull margin before releasing the cover, including cancellation and destroyed-scene cleanup. Creator road, fascia/stone, under-shadow and native raster bridge groups are included. It changes no camera, geometry, mesh/material resources, visibility, lighting, shadow settings, persistent condition, countdown or canonical state, and adds no race draw or geometry budget. Loading can still take the compilation time. Headless mode skips the render pass.

This follows Godot's documented Compatibility requirement to actually display/submit resources during loading; ordinary shader resource preload alone cannot avoid this first-use path. [Godot pipeline-compilation documentation](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html).

The automatic local logger now records covered bridge-preparation success, mesh count and shared finish/bridge draw wall time. Bridge camera-frustum candidates and their first appearances are sampled at **every pre-draw boundary**, retaining the existing 5 Hz sampling for the rest of the world. The row's `previous_bridge_context` accompanies its preceding render interval; temporary cull margins are ignored when describing actual geometry candidates. Candidates still do not assert actual GPU/shadow draws or compilation. The inventory cap of 128 meshes and existing file/event/byte limits remain; omitted inventory items remain explicit. No network upload is added.

Actual validation:

- Preparation: **64 Compatibility + 64 Mobile/Vulkan checks** for Pine, Winter, Desert, Storm, native raster bridges and no-bridge scenes; **12 + 12 additional Night City checks**. Before/after framebuffer bytes, camera, meshes/materials/transforms/layers/shadows/visibility, condition, canonical state and full 360-tick countdown are exact. Hidden groups and scene destruction are checked.
- Headless preparation: **58 checks**. Actual app bridge loading: **26 headless / 27 Compatibility**, including three starts, covered preparation markers, restored margins, cancellation, deadline recovery and suspended rendering.
- Hitch logger: **45 headless / 45 Compatibility**, including an immediate first bridge candidate, another sample inside the 200 ms world-sampling window, association with the measured interval, injected stalls, pause/focus suppression and the full eight-event file byte cap.
- Full project parse: **697 scripts**, zero failures. Menu quality **23 checks**, after matching its test override to a concurrent race-start API change.

Commands used through the pinned entry point:

```powershell
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_bridge_first_use.gd -Graphical
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_bridge_first_use.gd -Graphical -TestArgument '--only=road'
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_bridge_first_use.gd -Graphical -TestArgument '--only=shadow'
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_bridge_first_use.gd -Graphical -TestArgument '--only=steel'
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_bridge_first_use.gd -Graphical -TestArgument '--warm'
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_bridge_first_use.gd -Graphical -TestArgument '--specialize'
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_bridge_first_use.gd -Graphical -TestArgument @('--warm','--specialize')
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_bridge_render_preparation.gd -Graphical
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_bridge_render_preparation.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_bridge_render_preparation.gd -Graphical -TestArgument '--night-only'
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_bridge_render_preparation.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument '--night-only'
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_bridge_render_preparation.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_race_hitch_monitor.gd -Graphical
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_race_hitch_monitor.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_over_under_loading.gd -Graphical
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_over_under_loading.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_menu_quality.gd
```

Retained initial issues: the first probe incorrectly used positive world Z for track Y, putting the bridge outside the inspection camera; that run is marked invalid evidence. One native PowerShell `-File` array argument arrived as a single comma-containing string, so the intended specialization was not applied; its result is also marked invalid, and argument validation now rejects that input. Class discovery initially required an explicit script preload; a pinned import attempt failed because another Godot process held the audio extension's temporary DLL. A headless typed-array conditional assignment failed and was corrected to a typed empty array plus explicit graphical assignment; headless loading then passed. One build-identity scan hit a concurrently written kit asset's file lock; the command passed on retry. Full parsing found two old test override signatures affected by the concurrent optional loading parameter; only their signatures were updated. The metadata fixture was parsed, not run as an integration acceptance test for the unrelated API work. No assertions were relaxed.

Raw probe JSON/PNG, paired restoration captures, source snapshots, actual command logs and a scoped review patch/hash manifest are under `docs/evidence/bridge-first-use-2026-10-14/`. Concurrent editor write-queue, track-loading and car-kit changes are preserved and excluded from the bridge checkpoint. The game was neither restarted nor terminated. Restart it to load the new preparation and per-frame bridge diagnostics. Owner acceptance remains repeated Silmukka races after restart; an exact native CPU/GPU stack for any remaining stall and physical-phone validation remain outstanding. No phone test, APK export/install, full Validate or backend deployment was performed.
