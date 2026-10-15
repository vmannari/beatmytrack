# Remaining racing-render work

2026-10-14. Requirements RRF01–RRF06 / V03/V05/G01/R01/Q01. The owner requests all remaining items after the car and spatial/terrain improvements. Weathering uploads, retained trail visibility, exact-zero particle shading and completed-world reuse already have implementations in [the biome followup](BIOME_PERFORMANCE_FOLLOWUP_2026_10_13.md); this pass preserves those and closes additional repeated preparation, upload and HUD work in the current race path.

## Changes and expected impact

| Area | Implemented change | Expected impact |
|---|---|---|
| Surface shader preparation | Look up the completed specialization before include expansion and regular-expression compilation. Source content, include revisions, every fixed role, packed slots and region channel fence the key. Keep each material's original dynamic source. Both shader and alias populations stay within 64 entries; aliases hold no extra shaders. Clearing/eviction/source/include changes force correct preparation. Missing optional region parameters use the existing disabled-channel default safely. | Substantially cheaper repeated material/world preparation; first unseen roles still need compilation. Generated shader code and GPU work are unchanged. |
| Static/moving props | Cache exact per-node rows and integrity, owning copies of mutable rows. Same-tick edits, resets and replacement nodes refresh immediately. | Resting props avoid repeated transforms, damage-phase visibility traversal and scale/rotation writes. Moving props keep their original presentation. |
| Debris | Keep all retained pieces and original ordering; upload only exact changed transforms. Population resize and replacement MultiMesh resource invalidate the cache. | Zero repeated uploads for settled debris; active changes remain immediate. No culling, population/lifetime reduction or collision change. |
| HUD | Rewind button redraws on eligibility changes; map marker redraws on exact rendered-position changes. Keep the original 0.08 s HUD cadence. Format debug text only while visible, timers only when their centisecond value changes, and lap counts only when changed. Build development status strings only in their existing development branch. Invisible checkpoint notices avoid an unused projection; unchanged active bearings/layouts retain their draw list. | Less CPU formatting and canvas invalidation while stopped/paused and for static controls. Moving markers, arrows and timers retain their established cadence/precision. |
| Rain | Set invariant lens fade once; cache exact lens/glass parameters by material identity. Reuse the current analytic lens sample when drawing its trail. Skip unchanged lightning energy and Control geometry writes. Preserve read-after-size arithmetic, since Control offsets can round requested sizes. | Fewer repeated uniforms/path evaluations, particularly while drops cling or weather is unchanged. Rain density, history, motion, refraction and reflections remain. |
| Lights/contact shadows | Skip unchanged beam masks, shadow volume properties and contact-strength writes. | Fewer scene/material writes on level driving and pause; bridge masks, jump fade and support calculations remain. |
| Prepared budgets / teardown | ArrayMesh resource accounting reads vertex/index counts instead of decoding whole arrays again. Decorated HUD panels use a weak-reference deferred callback and skip unchanged size uniforms. | Less preparation allocation/copy work; closing a race before deferred layout completes no longer calls a freed captured panel. World/road/car cache budgets remain unchanged. |

Existing tyre-transform guards and brake-light transition guards were already present and retained. Required moving scene, lighting, sky/reflection and particle work remains. No new player-facing label, setting, graphics reduction, schema, canonical contract or physics change is introduced. The existing **Simpler car models** preference continues to control the next race.

## Measured results

Pinned Godot 4.7.2-stable, RTX 3090, Windows desktop. Standalone fixtures use archived original callbacks/compiler source and actual native controls, prop meshes and materials; no account/score adapters. Results are component work/timing, not phone FPS.

- Repeated shader preparation, 80 calls, final alternating samples: Compatibility **850.886 / 811.907 ms → 90.082 / 51.550 ms**; desktop Mobile/Vulkan **597.975 / 562.728 ms → 67.800 / 24.603 ms**. Earlier quieter headless samples were **319.547 / 346.314 → 29.322 / 15.625 ms**. Samples vary with shared-host/import activity; repeat preparation falls roughly 89–96%, with first misses retained.
- Resting three-prop callback, 2,000 calls: final Compatibility **80.514 / 75.116 → 34.283 / 32.953 ms**; Mobile **30.644 / 51.794 → 21.352 / 16.800 ms**. Small component medians are load-sensitive.
- A retained 120-fragment fixture repeats **6,000 uploads → zero** across 50 unchanged updates; one in-place edit uploads exactly one piece, buffer replacement uploads all 120, and reset clears immediately.
- Across 24 unchanged frames, minimap callbacks **24 → zero**, forced rewind callbacks **24 → zero**, and six-lens/glass shader writes **600 → zero**. Changed values still update immediately.
- Final HUD and five rain hold/slip/reset captures are **pixel-identical on both renderers**. All original/optimized shader strings match across five themes, surface types, packed/remapped channels, 80 distinct source variants, eviction and include mutation. Five-car contact volumes/strengths and damage/prop states match exactly.
- The merged five-biome terrain/scenery fixture passes **72 + 72** checks with all 90 paired comparisons having zero changed pixels. This verifies appearance after compiler reuse; it does not isolate a new GPU improvement.

Raw final [Compatibility](evidence/racing-render-remaining-2026-10-14/compatibility-report.json) and [Mobile](evidence/racing-render-remaining-2026-10-14/mobile-report.json) reports preserve alternating samples and pixel/work counts. Selected paired [HUD before](evidence/racing-render-remaining-2026-10-14/hud-before.png)/[after](evidence/racing-render-remaining-2026-10-14/hud-after.png), [rain before](evidence/racing-render-remaining-2026-10-14/rain-before.png)/[after](evidence/racing-render-remaining-2026-10-14/rain-after.png) are retained.

## Actual commands and checks

All engine actions use `powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' ..."` and the pinned build. The following are actual outcomes:

| Action / script | Outcome |
|---|---|
| `TestScript -ScriptPath res://tests/test_racing_render_remaining.gd` | 281 headless checks, zero failures |
| Same fixture, `-Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3` | 450 checks, zero failures |
| Same fixture, `-Graphical -RenderingMethod mobile -RenderingDriver vulkan` | 450 checks, zero failures |
| `TestScript -ScriptPath res://tests/test_spatial_terrain_racing.gd -Graphical`, with both renderer arguments above | 72 + 72 checks, zero failures |
| `TestDriving` / `TestRewind` | 72 / 61 checks, zero failures |
| `TestScript -ScriptPath res://tests/test_breakable_props.gd` | 46 checks, zero failures |
| `TestScript -ScriptPath res://tests/test_checkpoint_notices.gd` | 533 checks, zero failures |
| `TestScript -ScriptPath res://tests/test_headlights.gd` | 81 checks, zero failures after safe panel teardown fix |
| `TestScript -ScriptPath res://tests/test_contact_shading.gd` | 23 checks, zero failures; obsolete Desert no-pass assertion updated to require the existing clear-sky sun veil with exactly zero grass cloud coverage |
| `TestScript -ScriptPath res://tests/test_bridge_hud.gd` | 144 checks, zero failures |
| `TestScript -ScriptPath res://tests/test_prepared_race_load.gd` | 85 checks, zero failures |
| `TestScript -ScriptPath res://tests/test_terrain_sampler_budget.gd` | 60 checks, zero failures |
| `TestRoadCache` | 70 checks, zero failures |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` | Final 699 scripts, zero failures; earlier runs interrupted by concurrent app-probe signature/dependency updates |
| `TestScript -ScriptPath res://tests/test_biome_followup.gd -TestArgument @('--output=res://../build/racing-render-remaining-2026-10-14/biome-followup')` | 133 checks, zero failures after concurrent prepared-car stable-name correction |
| `TestScript -ScriptPath res://tests/test_storm.gd` | 94 checks, **two existing spray failures**: front/rear wake balance and speed-dependent fan distance. Already recorded in [Storm background rumble](STORM_BACKGROUND_RUMBLE.md); this pass does not change water-spray sampling/artwork or weaken these assertions. All other Storm checks pass. |
| `Import` | Failed opening locked `game/platform/windows/~bmt_windows_audio_v4.dll`; no editor/audio process was closed. Runtime suites work independently. New regression UID exists; import success is not claimed. |

Initial fixture/API corrections retained all acceptance assertions: current TrackSession constructor and registered HUD/pause-menu types; the original prop callback runs on a plain host; fresh MultiMesh replacement avoids dummy-renderer duplicate-buffer limits. Thirteen exact rain-position assertions initially caught Control size roundoff; preserving original read-after-size arithmetic makes all of them exact. The shader fixture binds the original production region parameter. Pending panel layout initially reproduced a freed lambda capture in the headlight test, then passed after weak-reference binding. Concurrent prepared-car naming and app-probe signature changes were preserved and excluded from this task; transient merged failures are retained in logs. No pixel tolerance was widened.

Changed runtime files: `surface_shader_variants.gd`, `prepared_world_cache.gd`, `native_track_visual.gd`, `breakable_prop_visual.gd`, `contact_shading.gd`, `storm_weather.gd`, `car_visual.gd`, `game.gd`, `playground_hud.gd`, `hud_road_map.gd`, `rewind_hud_button.gd`, `checkpoint_notice.gd` and `popup_style.gd`. The new regression fixture and archived text sources are export-excluded. The contact test update reflects the existing Desert implementation; no cloud artwork changed. [Task-only patch](evidence/racing-render-remaining-2026-10-14/implementation.patch) / [checkpoint](evidence/racing-render-remaining-2026-10-14/checkpoint.json) preserve the shared branch/index and concurrent work.

No physical-phone test, APK export/install, full `Validate`, backend/online write or deployment was performed. Phone frame pacing, thermal/memory cost and owner acceptance remain; previous phone biome samples do not measure this pass. These changes remove identified duplicate work but do not guarantee a whole-race FPS gain or resolve the separately recorded first-use render-boundary hitch.
