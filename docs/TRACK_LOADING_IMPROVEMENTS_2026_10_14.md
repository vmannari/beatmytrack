# Track loading improvements, 2026-10-14

Owner authorization: ?OK, proceed with those improvements?, following [the measured loading review](TRACK_LOADING_REVIEW_2026_10_13.md). This implements the proven redundant-work and cache opportunities while retaining the existing covered render preparation. Requirements TLI01?TLI08 / Q01 / V03?V05 / G01 / R01 / B07.

Repeated stock-Compact race construction now takes **58?105 ms** in the twelve-scene desktop probe. Large Desert and Winter roads can persist across restarts instead of being rejected by the idle-memory limit. Unused ghosts no longer allocate a combined mesh. Cold CPU road generation runs through the existing cancellable worker while the loading overlay continues to render. First GPU resource installation and material compilation remain real work under the loading cover.

## Implemented scope

| ID | Change | Ownership and behavior retained |
| --- | --- | --- |
| TLI01 | Separate large-road disk admission from the idle road LRU. Install a verified disk artifact directly into the active world, even when it cannot enter the LRU. | Format `road-artifact-2`; private local resources, SHA-256 sidecar, exact engine/content/art key. Idle road RAM remains 32 MiB / eight entries. Files remain at most 32 MiB each, 96 MiB total / eight files. Expanded per-artifact estimate is bounded at 96 MiB; empty/oversized mesh lists are rejected. |
| TLI02 | Decide whether a compatible ghost can be shown before preparing its geometry; retain a bounded immutable combined ghost mesh. | Pose/PB recording is independent of drawing. Ghost-off/no-recording scenes build no ghost mesh. Nodes/material state remain fresh. Rest-pose ghost arrays match the original builder for all five cars, full/simple models and the tested fitted Compact. |
| TLI03 | Prepare bounded rest-pose car resources; restore stock detailed Compact assembly where both renderers pass exact pixels. | Four entries / 16 MiB estimate; exact mesh arrays, original construction hierarchy/matrices, original articulation and independently owned paint/brake/underside/livery bindings. Other cars, simpler models and fitted kits keep their original assembly path. Their immutable rest pose can still serve ghost generation. |
| TLI04 | Reuse particle emitter templates, shaders, curves and immutable finish data. | Sixteen entries / 2 MiB estimate. Fresh particle nodes, process materials, mesh wrappers and shader-material bindings. Original emission, biome profiles, nine-second Desert dust, bridge clipping and pause/reset behavior are retained. |
| TLI05 | Retain prepared audio streams and presentation-contact outlines. | Forty-eight streams / 24 MiB estimate; fresh playback players and per-race Windows impact adapter. Eight hulls / 1 MiB keyed by exact mesh identity and relative transforms; fresh contact episode state. Canonical collision/handling is untouched. |
| TLI06 | Run cold CPU road preparation through the existing road job; consume the prepared packet in ordinary race visuals. | Polling allows frames, checks navigation/account/selection/vehicle/overlay scope and cancels stale work. GPU/scene installation remains on the main thread. A superseding world/road-cache hit releases the unused packet. |
| TLI07 | Use one verified downloaded document snapshot and one ordinary metadata-race overlay; hydrate the bounded catalog. Move cold next-result hydration under the cover and Rivalry compilation to the existing background API. | Actual download SHA/size/document checks, independent cache-file verification, pinned tickets, source/version/account fences and fresh server starts remain. Rivalry still uses its existing overlay lifecycle; ordinary metadata starts are the consolidated case. |
| TLI08 | Skip identical retained metadata/alias and last-track writes, apply initial lighting once, and fetch copied MultiMesh buffers once. Stop unnecessary neighbour-page warming during a race. | Real updates and corrupt aliases still write; failed last-track saves roll back the in-memory setting so the next start retries. One-shot scene callbacks disconnect on owner teardown. No camera/menu layout or driving/scoring changes. |

The earlier review also identified early shader lookup, count-only world accounting and fresh typed spatial-chunk arrays. Those were implemented by concurrent render work; this task preserves them and does not claim their implementation. Bridge/hazard covered preparation likewise belongs to the parallel hitch investigation and is retained.

New retained caches have byte and entry limits. Their estimates sum to at most 59 MiB (car 16, ghost 16, effects 2, audio 24, outlines 1), in addition to the pre-existing caches. Shared meshes/resources may be counted in multiple estimates; these are policy bounds, not a measured process/GPU-residency figure. This task does not raise the existing road/world idle-memory budgets. Phone peak RAM and thermal behavior remain to be measured.

## Actual desktop measurements

Pinned Godot **4.7.2.stable.official.ed1daf0bf**, Windows, NVIDIA RTX 3090, Compatibility/OpenGL. The host is shared with other work; desktop Mobile/Vulkan is a second renderer, not a phone measurement.

Final [twelve-scene raw timings](evidence/track-load-improvements-2026-10-14/review-admission.json) include preferences, actual ghost mode/recording checks and complete prepared draws:

| Warm new scene | Game ready | Through prepared draws |
| --- | ---: | ---: |
| Pine, three repeats | 60.1?70.2 ms | 83.4?93.4 ms |
| Desert | 68.0 ms | 83.9 ms |
| Winter | 104.6 ms | 126.2 ms |
| Storm | 58.0 ms | 74.6 ms |
| Night | 98.8 ms | 119.9 ms |

Pine repeat components include stock Compact assembly 3.9?4.7 ms, particle construction 11.3?13.6 ms, audio-ready 8.3?10.8 ms, audio configuration 4.3?4.5 ms, and prepared-world restoration 0.9?1.3 ms. All twelve cases retain canonical tick zero, the full 360-tick countdown and five ordinary laps. Every no-recording case reports `ghost_mesh_built=false`; the probe's deliberately independent legacy `mesh_for` timing still builds a mesh for attribution and is not shipping ghost setup.

In the final paired [Compatibility resource fixture](evidence/track-load-improvements-2026-10-14/gl_compatibility/resources.json), original stock detailed Compact construction takes **201.222 ms** and its prepared restore **3.266 ms**. The earlier successful exact run was 200.316 / 3.184 ms. [Desktop Mobile/Vulkan](evidence/track-load-improvements-2026-10-14/mobile/resources.json) observes 675.665 / 3.169 ms on its pass; shared-host conditions differ between renderer runs. Other configurations' timing rows measure the preserved original builder, not a cache-hit speedup.

Final production disk-cache checks use the current visual version, with real Desert/Winter Star roads larger than 32 MiB resident estimate:

| Operation | Desert | Winter |
| --- | ---: | ---: |
| Generate exact roads | 10,453.681 ms | 9,566.159 ms |
| Save production compressed artifact | 87.992 ms | 69.889 ms |
| Actual artifact bytes | 3,752,055 | 3,559,175 |
| Same-process verified load/install | 83.947 ms | 69.910 ms |
| Fresh engine process verified load/install | 73.620 ms | 68.654 ms |

The fresh process shares the OS file cache from the write pass. Earlier fresh-process runs measured 305.826 / 188.064 ms; this is not a cold-storage guarantee. Both final artifacts round-trip exact arrays, transforms, layers, shadow flags, shader source, parameters and texture bytes, without admission into the oversized idle road LRU. The read-only test also checks that a hidden regeneration cannot masquerade as a cache hit. Final rows are [here](evidence/track-load-improvements-2026-10-14/large-roads-gl_compatibility.json) and [here](evidence/track-load-improvements-2026-10-14/large-roads-restart-gl_compatibility.json).

The earlier review's 612?678 ms repeat scenes are historical evidence from a different source checkpoint. Today's pre-change component probe and first optimization pass are retained separately; they are not a fully paired whole-loading benchmark. The final twelve-scene probe constructs Game directly for attribution, so its cold road generation remains synchronous in that diagnostic. The actual App-path test exercises the production worker, observes **200 loading frames**, one metadata overlay, full countdown/five laps and cancellation. That isolated workflow took 3,681.008 ms and is not a universal load-time or network-latency figure.

Immediate Race Again already retained and restarted the existing Game before this work. The new-scene numbers describe entering/reopening a race, not every retry. First scene/GPU preparation, Winter cover/weather, HTTP and pinned-ticket latency remain outside the standalone disk/car timings. A cached road can still need GPU installation/driver compilation. Existing malformed artifacts safely fall back to regeneration; the presence check may let that rare rebuild occur on the main thread.

## Exactness, rejected paths and integration corrections

Car-template admission and resource ownership are checked for all five models, their simple variants and fitted Compact full/simple configurations. Accepted stock detailed Compact restores have byte-exact framebuffer comparisons on both desktop renderers. Immutable geometry/global/local frames and resolved material data remain exact for all tested configurations; paint, wheel motion, brake state and teardown cannot mutate another car or the prepared template.

A broader template-restore attempt failed exact pixel comparisons. An uncached simpler-Compact control also exposed cold-render pixel variation between two original constructions. Neither observation justified weakening the accepted-cache invariant. Runtime restore was restricted to stock detailed Compact; other configurations use the approved original construction path. The renderer/order-dependent cause of those residual comparisons is not conclusively identified. Initial failure crops/control captures and command logs are retained. There is no all-car cached-framebuffer claim.

Integration failures were corrected or recorded rather than suppressed:

- Newly concurrent Compact-kit classes initially required refreshing the global class index with Import. A later concurrent compiler edit concatenated two cancellation returns with the following declarations; this task inserted the missing newlines only, retaining the cancellation work.
- The parallel hazard-preparation headless ternary yielded an untyped empty Array; an explicitly typed empty array plus the graphical assignment fixes the observed loading crash without changing hazard preparation.
- App teardown exposed a suspended neighbour-warm coroutine resuming after its owner was gone. One-shot process-frame callbacks retain the same warm/hide work and disconnect safely; races skip unneeded page preparation.
- The App fixture assumed gesture autosave had reached disk synchronously despite the existing ordered background writer. Its assertion remains exact; it now waits at most five seconds for queued writes to complete. Final App checks pass.
- Headless audio had one `pause suspends loop playback` failure because dummy output does not start real playback. The original assertion remains; the real graphical audio test passes all 1,469 checks. No shipping audio assertion or behavior was weakened.
- A headless resource rerun overwrote the graphical timing JSON. Diagnostic output now separates headless results, and the final Compatibility graphical pass regenerated the exact evidence successfully. A 104.743 ms frame in a driving test was captured by the existing hitch logger; this is not evidence that every first-use hitch has been eliminated.

## Commands and observed checks

All engine commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`. Command logs and command-specific build identities are retained in [commands.json](evidence/track-load-improvements-2026-10-14/commands.json) and its referenced folders. Principal commands actually executed:

```powershell
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_prepared_race_resources.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 420
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_prepared_race_resources.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -CommandTimeoutSeconds 420
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_prepared_race_resources.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_large_road_cache.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_large_road_cache.gd -TestArgument '--read-only'
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_race_preparation_reuse.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/review_track_loading_2026_10_13.gd -Graphical -TestArgument '--evidence=res://../docs/evidence/track-load-improvements-2026-10-14'
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_vehicle_audio.gd -Graphical
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_personal_ghosts.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_car_wash.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_prepared_race_load.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_start_failure.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_over_under_loading.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
scripts/dev.ps1 -Action TestRoadCache
scripts/dev.ps1 -Action TestDriving
scripts/dev.ps1 -Action TestRewind
scripts/dev.ps1 -Action TestApp
scripts/dev.ps1 -Action Import
scripts/dev.ps1 -Action CheckScript -ScriptPath res://vehicle/prepared_car_cache.gd
scripts/dev.ps1 -Action Doctor
```

| Completed check | Outcome |
| --- | --- |
| Exact prepared resources, Compatibility | 224 checks, zero failures, final rerun |
| Exact prepared resources, desktop Mobile/Vulkan | 224 checks, zero failures |
| Prepared resources, headless | 162 checks, zero failures |
| Production oversized road build/write/read | 14 checks, zero failures |
| Production roads, fresh process read-only | 12 checks, zero failures |
| Metadata integrity/overlay/worker/cancellation | 17 checks, zero failures |
| Existing road cache | 70 checks, zero failures |
| Prepared worlds and instance ownership | 85 checks, zero failures |
| App integration | 99 checks, zero failures, final rerun |
| Driving | 72 checks, zero failures |
| Rewind | 61 checks, zero failures |
| Personal ghosts | 38 checks, zero failures, final rerun |
| Local condition/washing | 1,383 checks, zero failures |
| Graphical vehicle audio | 1,469 checks, zero failures |
| Rivalry failure/pinned starts | 29 checks, zero failures |
| Over/under loading and deadlines | 26 checks, zero failures; intentional timeout warnings |
| Full project script compilation | 703 scripts, zero failures |
| Twelve-scene attribution | 12 complete tick-zero/full-countdown/five-lap checks |

## Files, checkpoint and remaining acceptance

Runtime files: `game/track/road_mesh_disk_cache.gd`, `native_track_visual.gd`, `prepared_world_cache.gd`; `game/vehicle/prepared_car_cache.gd` (new), `car_visual.gd`, `personal_ghost.gd`, `sand_dust.gd`, `vehicle_audio.gd`, `visible_contact_audio.gd`; `game/core/app.gd`, `game.gd`; `game/backend/cloud_tracks.gd`; the two newline repairs in `game/editor/track_compiler.gd`. New diagnostic tests are `test_prepared_race_resources.gd`, `test_large_road_cache.gd`, `test_race_preparation_reuse.gd`, each with UID. Existing App/Rivalry fixtures and the review probe were adapted as described. This report/status/plan and task evidence complete the slice.

The [task-only unified patch](evidence/track-load-improvements-2026-10-14/task-only.patch), [isolated Git bundle](evidence/track-load-improvements-2026-10-14/track-loading.bundle), base/final snapshots and `checkpoint-files.json` form the reviewable checkpoint. Git checks the patch against its isolated LF baseline; checking reverse application directly against several CRLF live files failed on line-ending matches, so the normalized snapshots provide reproducible verification. It includes only this task's runtime/test/document edits. Concurrent editor cancellation/writes, privacy/redaction, expanded kits/liveries, shader/spatial changes and bridge/hazard preparation are preserved in the baseline and excluded as changes; only the observed integration repairs are included. The shared worktree is not a clean task branch, so no broad shared-tree commit/reset was made. The isolated review repository contains only the selected baseline and this slice; its two-commit bundle is not a complete executable project checkout. `manifest.json` hashes retained evidence and source snapshots.

No artwork, racing camera, canonical physics/rules/compiler contract, ordinary five-lap scoring, local car condition, object populations or tire/dust budgets changed in this task. CPU generation remains expensive for a truly new track, and unsupported car-template restores remain deliberately on the original path. Physical-device cold/repeated loading, peak RAM, OS-cache eviction and thermal acceptance remain open. DN2103 was attached when Doctor ran; **no phone profiling/gameplay, APK/export/install/deployment or phone performance test was performed by this loading task** (Doctor only enumerated attached devices). Separate parallel phone-hitch results do not validate these loading changes. No production backend writes, full Validate or physics merge occurred. Existing automatic hitch diagnostics and covered finish/bridge/hazard preparation remain available for future freezes.
