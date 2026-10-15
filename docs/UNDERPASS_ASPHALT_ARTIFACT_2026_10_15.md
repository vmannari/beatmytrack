# Underpass asphalt hole — 2026-10-15

The owner's Night screenshot shows a pale triangular patch across Underpass's lower returning bend. UPA01: restore continuous asphalt at that location. UPA02/G01/R01/Q01: retain bridge-mouth ownership, the existing road height/finish/camera, canonical track data and bounded preparation/cache behavior.

The original track document reproduces the patch in native Compatibility and Mobile/Vulkan rendering. This is missing asphalt exposing the brighter terrain under the headlights. `road_surface_height.gd::clip_bridge_mouths` previously clipped an entire polygon against an infinite bridge-mouth plane. Underpass's 216-degree curve crosses that plane again away from its bridge. The clip removed that distant part of the bend and joined the remaining boundary with a straight chord.

The helper now finds the offset mouth edge within 25 cm of the bridge-mouth centre and clips only the contiguous exterior cap around it. The original 16 cm ground-road extension still stops exactly at the deck mouth. Other exterior runs of a returning bend retain their vertices. The same helper supplies rendered asphalt and its presentation support. `NativeTrackVisual.VERSION` advances from kit201 to kit202 to invalidate prepared geometry, retained worlds and disk road artifacts. No shader, lighting, camera, track document, collision, physics, scoring, paint or car-condition change is involved.

Changed runtime files: `game/track/road_surface_height.gd` and the version constant in `game/track/native_track_visual.gd`. The regression is `game/tests/test_underpass_asphalt.gd`, with the unchanged original Underpass document in `game/tests/fixtures/underpass.json`. The fixture is copied from the existing local lab catalog; its native hash remains `259e7adadd65d5365d03af4210db47f199ff4f93d89f02364972cec7bc8ae3ce`.

Actual pinned Godot 4.7.2 verification uses separate workspace APPDATA profiles:

| Check | Actual result |
| --- | --- |
| Original mouth helper against the final geometric regression | 68 checks, 13 expected failures, including the original Underpass bend |
| Corrected returning bends, both directions and bridge ends; direct/CPU/prepared mesh coverage on Night/Grass/Storm; pinned native hash | Headless 82/82; Compatibility 82/82; Mobile/Vulkan 82/82 |
| Existing asphalt overlap ownership, headless geometry portion | 9/9 |
| Existing road disk-cache serialization/fences | 70/70 |
| Existing prepared worlds and cache bounds | 85/85; all-five bytes 265227248, one retained entry within 67108864 bytes |
| Existing editor direct/worker/prepared/reuse attributes and bounds | 407/407 |
| Existing four-biome raised-road/deck-mouth/sand/marking visual checks | Compatibility 69/69; Mobile/Vulkan 69/69 |
| Whole-project parser | Attempted: 769 scripts, failure from undeclared `_resolve_thread` at `game/ui/track_browser.gd:529,558,1110`, with dependent menu/application errors |

The parser issue is in separate, concurrently modified menu code; this task does not edit that file. The focused tests compile and execute the changed road code. There is no whole-project parse-pass claim.

Native evidence is in `docs/evidence/underpass-artifact-2026-10-15/`. For each renderer, compare `matched-before/pose-0.png` with `after/pose-0.png`; four headlight poses, a map view and brighter diagnostic views are retained. The before capture executes the saved original road-builder method and original mouth helper in a subclass of the current native visual. The world, shaders, car and camera remain shared. Captures establish the road repair; they are not whole-screen bit-exact comparisons, and focus-dependent debug HUD visibility can differ. `capture.gd` records the actual setup. `before/` contains task-start runtime sources; `logs/`, coverage JSON and `task-only.patch` retain results and the scoped checkpoint. No mixed-workspace commit is made.

Initial findings are retained: the first captures established that a standard opaque replacement material still showed the hole, excluding a road-shader finish error. A first regression metric treated numerical spurs in polygon-Boolean difference output as actual removed road, producing seven failures despite only about 1.626 m² of local cap removal. The corrected metric checks actual removed area/depth and exact retention of distant source vertices, alongside mouth coverage and triangulation. The saved old helper still fails 13 of those final geometric checks. `initial-coverage.json` retains the original diagnostic. The first `scripts/dev.ps1` attempt also printed an access-denied error; direct pinned-engine runs supplied the complete results above. Isolated profiles print a root-certificate-store diagnostic. Some full-game capture exits report existing audio/soundtrack object/resource cleanup warnings; targeted road tests exit cleanly.

Commands actually used (each run sets APPDATA to a named folder beneath `build/underpass-artifact-2026-10-15/`):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_underpass_asphalt.gd
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/test_underpass_asphalt.gd --audio-driver Dummy
# Same regression with --rendering-method gl_compatibility, or mobile --rendering-driver vulkan, without --headless.
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path game --rendering-method gl_compatibility --script ../build/underpass-artifact-2026-10-15/capture.gd --audio-driver Dummy -- --baseline --output=res://../docs/evidence/underpass-artifact-2026-10-15/gl_compatibility/matched-before
# Both renderers also run the capture without --baseline into their after folder.
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script ../build/underpass-artifact-2026-10-15/baseline-mouths.gd --audio-driver Dummy
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/test_asphalt_surface_ownership.gd --audio-driver Dummy
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/test_road_cache.gd --audio-driver Dummy
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/test_prepared_race_load.gd --audio-driver Dummy
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/test_editor_loading_roads.gd --audio-driver Dummy
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path game --rendering-method mobile --rendering-driver vulkan --script ../build/underpass-artifact-2026-10-15/bridge-seams.gd --audio-driver Dummy -- --visual-only
# bridge-seams.gd is the existing asphalt-depth visual test with only its evidence destination changed; also run with gl_compatibility.
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/test_script_parse.gd --audio-driver Dummy
```

No phone attachment check, phone test, APK, service change or deployment was performed. Owner and physical-phone moving-view acceptance remain. No FPS or general hitch-free claim is made. Saved tracks, original published identities and concurrent menu/Garage/car/audio work are retained.
