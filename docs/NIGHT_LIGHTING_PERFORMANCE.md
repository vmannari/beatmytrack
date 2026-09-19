# Easy night lighting performance — 2026-09-18

Requirements: R01/G01/V02/V03/V05/Q01. Owner reports slow racing on **Easy night** and asks to check the lights. Attached device: DN2103, Android 13, Mali-G77 MC9; pinned Godot 4.7.2. Track `track_c7ad183a78f7a033` has ten authored street lamps. Player files and records are preserved.

## Diagnosis and changes

The original build was tested with lamps on/off/on, at the same 0.667 world resolution, with moon shadows enabled throughout. Actual SurfaceFlinger presentation intervals showed 230 missed refreshes in 23.87 seconds with lamps on, zero in 23.47 seconds with lamps off, and 247 in 23.77 seconds with lamps on again. Internal frame medians were 20.268 / 16.668 / 20.321 ms. This isolates a sustained rendering cost from the lamps, rather than only first-use loading.

`game/track/native_track_visual.gd` (track-kit-33) partitions night terrain into 16-metre tiles and road triangles into spatial groups. This allows the renderer to cull unrelated lights per mesh, while preserving every road triangle, normal and texture/kerb coordinate. Tiles retain continuous terrain sampling coordinates. The opaque terrain hides the enormous background under the lamps, so the background excludes point lights only when every lamp's conservative reach fits inside the terrain. Boundary/scaled lamps retain background illumination, including after editor object edits. All ten lamps retain their brightness, colour, range and shadow settings. Local road light coverage also improves compared with the old whole-track meshes: Compatibility has a default eight-OmniLight-per-mesh limit. See the engine's [OmniLight3D documentation](https://docs.godotengine.org/en/4.6/classes/class_omnilight3d.html).

Partitioning alone was insufficient: the fully lit 16-metre road version still missed 388 refreshes in 61.59 seconds. Larger road groups reduced drawing overhead but lost some local illumination. A vertex-lighting experiment visibly changed the terrain/shoulder shading and was discarded. Neither dimming lamps nor the faster incomplete-light-coverage variant is shipped.

`game/core/game.gd` therefore budgets mobile night races at **0.55 world resolution** instead of 0.667 (about 32% fewer 3D pixels). The HUD and touch controls remain native resolution. Daytime and desktop resolution stay as configured; an already lower setting is respected. Leaving the game node restores its incoming viewport setting, including transitions to menus/editor/daytime races. Canonical physics, camera, lamp properties, track geometry and player content are unchanged.

`game/diagnostics/mobile_race_probe.gd` adds opt-in light comparison, explicit render-scale selection and use of the actual game's scale. It reports lamp count/state. The existing unscored AI diagnostic drives the real race HUD and held touch controls without recording a personal best.

## Actual validation

```powershell
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/test_night_lighting.gd
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path game --script res://tests/test_night_lighting.gd -- --capture
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestSurfaces
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestBiomes
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 DeployAndroid -QuickValidation
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile_android_frames.ps1 -Seconds 60 -Output build/night-performance/present-shipping
```

- New night test: **15 checks, zero failures**, both headless and graphical. Checks exact triangle/attribute preservation, terrain area and UV continuity, lamp properties, boundary/editor behaviour, mobile/day/desktop render budgets and restoration when leaving a race. Included in full validation through `scripts/dev.ps1`.
- Surface tests: **50 checks, zero failures**. Biome tests: **41 checks, zero failures**.
- Final deployment's focused checks: import/startup successful; driving **70**, catalog **18**, menus **11**, zero failures; APK install and cold launch successful. Existing exit-time ObjectDB warnings remain. Full regression suite was not run for this presentation-only change.
- First 0.55 phone run: six completed laps, median speed 66.10 km/h, maximum 75.07 km/h, all ten lamps and moon shadows enabled. Its 61.18-second SurfaceFlinger sample contains 3,634 intervals, **zero over 25 ms**, p99 **17.07 ms**, maximum **17.33 ms**. The separate 90-second internal callback trace has ten intervals over 25 ms; callback jitter and actual display presentation are reported separately, not conflated.
- Final installed build, using the game's own mobile scale rather than an explicit diagnostic override: six laps, median speed 66.09 km/h, ten lamps. The 61.21-second display sample contains 3,635 intervals, **one over 25 ms**, p99 **17.08 ms**, maximum **33.70 ms**. The 90-second internal trace median is 16.81 ms, p99 21.43 ms, ten intervals over 25 ms. [Final display intervals](evidence/night-performance/present-shipping.json), [race report](evidence/night-performance/shipping.json), [phone screenshot during the diagnostic](evidence/night-performance/phone.png). The 10,000-lap practice target in that screenshot is diagnostic-only; ordinary races remain five laps.

Installed APK SHA256: `546B68A544E9EB3F0B68B2172B6231E00D03B53CC949BFC75723B35BCE6E925B`. After collecting the completed report, removed `files/mobile_probe.json`, force-stopped and relaunched the app successfully to restore normal play. No player data was cleared.

Evidence: [original light comparison](evidence/night-performance/baseline.json), [lights on](evidence/night-performance/present-lights-on.json), [lights off](evidence/night-performance/present-lights-off.json), [lights on again](evidence/night-performance/present-lights-on-repeat.json), [first optimized display sample](evidence/night-performance/present-scale055.json), [first optimized race report](evidence/night-performance/scale055.json), [before](evidence/night-performance/before.png), [after](evidence/night-performance/after.png). Desktop screenshots show the lighting/geometry comparison at the same camera; they are not phone performance evidence.

The tradeoff is slightly softer 3D imagery during mobile night races. Results apply to the attached device, compact car, this track and the measured sessions; they do not establish perfect frame pacing for every night track, lamp density, thermal state or manual driving path. Owner acceptance of Easy night's motion and image quality remains pending.
