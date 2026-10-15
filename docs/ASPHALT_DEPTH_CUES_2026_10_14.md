# Asphalt depth cues — 2026-10-14

The owner asks to try the proposed darker asphalt side, small rounded bevel and soft contact shading on sand. ADC01: 20% lower side pigment energy. ADC02: an actual 5 mm quarter-round lip. ADC03: narrow soft sand contact shading and continuity at bridge mouths. V05/G01/R01/Q01: retain flat sand/terrain, the 50 mm asphalt lift, canonical handling/support, cache bounds and actual native renderer evidence.

`asphalt_edge_profile.gd` appends three rounded bands and the closed side into the existing road surface. Explicit normals follow the quarter circle; vertex alpha carries a 1.0-to-0.8 shading weight without making the material transparent. Ground lips extend 5 mm outward (up to 10 mm at bounded corner miters); creator bridge lips fit inside the existing deck width. Native/painted raster asphalt and native bridge rims share the same profile. Bridge deck normals are generated before appending the separately shaded lip, preserving the original smooth ramp response. Night's existing road groups retain the new vertex-colour data.

The existing flat authored blend strip now reads as sand below raised asphalt, with sparse asphalt crumbs. A nominal 60 mm contact band fades smoothly outward with slight variation from the existing grain. The sand pigment and terrain/shoulder heights stay original; no extra shading texture sample, overlay, render target or draw is introduced. Native/painted raster roads share the bevel/dark-side treatment; contact shading follows the authored sand strips. Joined road/bridge mouths get no cross-lane bevel or dark stripe. Ground overlap ownership and bridge cap clipping remain in place.

The immutable `raised_road_edge` material role is compiled through the existing bounded shader preparation cache. Role/source/include fences preserve immediate updates and prevent stale shader reuse. Final kit201 invalidates intermediate kit200 experiments and old road/world artifacts. Physics, compiler27, pure `BridgeElevation`/`road_surface_height` support, camera, source palettes, dust/tire artwork and local condition are not changed by this task.

Actual pinned Godot 4.7.2 results, with isolated workspace APPDATA:

| Verification | Result |
| --- | --- |
| Initial full grass/support/actual surface and bridge checks with new depth treatment | Compatibility119/119; Mobile/Vulkan119/119; headless111/111 |
| Final four-biome bridge-mouth, paint, flat sand/fringe and actual captures | Compatibility69/69; Mobile/Vulkan69/69; unchanged grass simulation loop omitted from this final visual-only pass |
| Ajorata / Over and under / Star spline actual overlap ownership and six camera views each | Compatibility63/63; Mobile/Vulkan63/63 |
| Direct/prepared CPU-GPU attributes, retained road reuse, live masks and byte bounds | Editor407/407, including Night colour attributes |
| Disk material/mesh serialization and revision fences | Road cache70/70 |
| Prepared world restoration and bounds | 85/85; all-five resources265227248 bytes, one retained entry within67108864-byte cache |
| Covered bridge rendering preparation/restoration, countdown/condition/state and cancellation | 69/69 headless |
| Saved Winter / Desert / dirt geometry, normals, colours, UVs and roles | 10/10; prepared arrays byte-exact against saved native callbacks |
| Final project parse | 765 scripts, zero failures |

All 18 final Vulkan ownership views are pixel-exact after native preparation settles. Compatibility has 17 exact views and one shared-edge sample differing by one 8-bit colour level, within the existing one-sample/one-level bound. Fixed-view stability assertions pass. Actual before/final screenshots and measured image differences are retained; they are presentation comparisons, not bit-exact claims about every unaffected pixel. Initial short captures can include shader specialization and raster-edge differences outside the changed bands. Loose-surface preservation is independently established by byte-exact emitted geometry and disabled material roles.

Initial issues and corrections are retained in the session/evidence: automatic deck normal generation originally let bevel faces influence the broad lane; lips now append after original deck smoothing in the same draw. Priming only the first ownership view allowed a native prop format first visible in the second view to finish Vulkan specialization during comparison; all six sampled views/resources now prime before unchanged-image checks, with original tolerances retained. The preservation comparison found a normal difference on degenerate loose-surface triangles; the original fallback is restored and all three loose surfaces pass byte-exactly. A missing Python imaging package was handled by measuring the PNGs with the installed native Godot Image API, without changing the images.

Commands actually run:

```powershell
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path game --rendering-method gl_compatibility --script ../build/asphalt-depth/capture-before.gd
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path game --rendering-method mobile --rendering-driver vulkan --script ../build/asphalt-depth/capture-before.gd
# Final native visual and ownership scripts use the same two render methods.
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path game --rendering-method gl_compatibility --script ../build/asphalt-depth/test_grass_road_height.gd -- --visual-only
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path game --rendering-method mobile --rendering-driver vulkan --script ../build/asphalt-depth/test_asphalt_surface_ownership.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_loading_roads.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_road_cache.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_prepared_race_load.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_bridge_render_preparation.gd
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script ../build/asphalt-depth/review-unaffected.gd
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script ../build/asphalt-depth/compare-captures.gd
```

Native before/after views, ownership JSON, image differences, saved task-start sources, command/result receipt and source-only checkpoint are under `docs/evidence/asphalt-depth-2026-10-14/`. The earlier `after` folder retains the first normal-smoothing experiment; `final` contains the corrected views. Additional rim triangles/vertex-colour data increase geometry work within the existing caches; no paired GPU-time or phone-FPS claim is made. Owner appearance and physical-phone moving-view/performance acceptance remain. No phone test, APK or deployment was performed. Concurrent Garage/music/washing/rivalry/physics/car work is retained and excluded from the checkpoint.
