# Game and race loading fixes — 2026-11-13

Implemented the requested loading fixes: memory sampling avoids unused dependency graphs, repeated races retain contact geometry and ghost shader programs, and four qualified Compatibility biomes can restore completed scenery across processes. Final full native integration passes 132 checks in Compatibility and 143 in Vulkan, with clean shutdowns. All 17 owned implementation/test/runner files still match the verified source checkpoints. Known failures and renderer/biome exclusions are recorded below.

## Requirements and implementation

| ID | Requirement | Owned implementation |
| --- | --- | --- |
| LDF01 | Sampling or trimming memory must not load unused game/editor/render graphs. | `game/editor/editor_memory.gd` resolves only already-cached providers, samples newly loaded providers on subsequent calls, and retains the existing 64 MiB general/96 MiB optional-Garage allowances and worker safety. |
| LDF02 | Re-entering a race should reuse the same contact outline when its geometry is unchanged. | `game/vehicle/visible_contact_audio.gd` retains exact mesh references with the outline, observes resource changes, includes transforms/bounds in the key, and exposes bounded retention to LDF01. Sampling and contact behavior after configuration are unchanged. |
| LDF03 | Reuse completed scenery across processes without changing the world, advancing simulation, or accepting stale/corrupt artifacts. | `game/track/prepared_world_cache.gd`, `native_track_visual.gd`, new `prepared_world_disk_cache.gd` and `prepared_world_artifact.gd`. Five files/128 MiB committed total/32 MiB each; original RAM allowance remains five entries/64 MiB. Engine, renderer, source, track and geometry options participate in identity. Persistence is restricted to Compatibility Pine/Desert/Winter/Storm; Vulkan and Night keep their existing construction/RAM paths. |
| LDF04 | Reusing ghost geometry must not create another identical shader program for each race owner. | `game/vehicle/personal_ghost.gd` and `rewind_ghosts.gd` share one immutable shader per existing effect. Original shader text and private materials remain. |
| LDFV01 | Verify loading behavior, appearance, memory pressure, cancellation and driving with reproducible offline evidence. | New focused fixtures, an actual-App entry/re-entry/retry profiler, existing regression suites, pinned-engine runner and isolated prepared-asset qualification. |

This pass does not change canonical simulation, track geometry, vehicle tune, countdown length, graphics warm-up requirements, the renderer selection, or backend behavior. Separate concurrent car/Garage/Rivalry changes are preserved and are not claimed as loading-fix authorship.

## Measurements completed

Component timings are not end-to-end loading savings. Timings are Windows desktop observations, not Android performance claims.

* Cold loading of the memory-policy script fell from 2,315.979 ms for the exact task-start source to 33.110 ms. The original fails 40 of the 72 new no-eager-load assertions; the replacement passes all 72. Dependencies still needed for a race can load later in the race graph, so 2.28 seconds must not be subtracted from total race time.
* Across six prepared car models, repeated contact configuration changed from 8.419–36.722 ms to 0.115–0.171 ms in Compatibility and 48.539–169.146 ms to 0.083–0.206 ms in Vulkan. Exact outline equality, edits/transforms, lifetime, retention limits and pressure are checked. First use and evicted geometry intentionally rebuild. Fresh procedural Night headlight meshes can still cause a cache miss.
* Ghost shader tests verify the original shader text, persistent shader identity, private materials and exact before/after native pixels in both desktop renderers. This proves reuse and appearance, not a separately measured whole-race saving.

Raw timings: [memory candidate](evidence/loading-fixes-2026-11-13/memory-cold-headless.log), [memory original](evidence/loading-fixes-2026-11-13/memory-original-boundary.log), [six-model contact samples](evidence/loading-fixes-2026-11-13/contact-outline-summary.json).

The final actual-App Star comparison uses the same frozen project and private profile, with a fresh process for each row. The controls disable only the new persistent scenery cache. All four runs pass 16 entry/re-entry/retry assertions, accept prepared vehicle bases, and have unchanged production sources and assets.

| Ordered run | First race ready | App scene load to first race ready | Second entry in same process | First retry |
| --- | ---: | ---: | ---: | ---: |
| Persistence disabled, first control | 15,315.805 ms | 18,194.840 ms | 327.528 ms | 12.629 ms |
| Persistence enabled, first write | 7,712.260 ms | 10,497.778 ms | 346.169 ms | 10.927 ms |
| Persistence enabled, fresh-process disk hit | 6,199.941 ms | 9,042.974 ms | 311.772 ms | 12.318 ms |
| Persistence disabled, final control | 8,236.879 ms | 10,973.863 ms | 295.655 ms | 12.129 ms |

The disk-hit row explicitly records one accepted artifact, while the write row confirms publication. Compared with the final control, the hit saves 2,036.938 ms (24.7%) in race entry and 1,930.889 ms (17.6%) from App scene load to race readiness in this sample. The first control includes additional graphics warming (16 groups versus 10/10/12 in the following runs); its much larger difference must not be attributed to these fixes. This ordered desktop observation is not a statistical benchmark or a universal improvement guarantee, and other workspace activity was not suspended.

Cold source-checkout identity validation remains a cost: 474.706 ms for the Star write and 491.858 ms for its fresh-process hit, included in the ready times above. Star serialization takes 106.594 ms and total main-thread queue work 113.080 ms beneath the cover. Its 404.717 ms source recheck and checksum run as optional worker I/O; gameplay does not await publication. The earlier small-world native observations were 18–37 ms serialization, 27–48 ms queue work and 359–381 ms initial identity validation. These first-write costs are a tradeoff for reuse, not hidden first-lap work. Source-checkout results do not establish packaged Android timing.

All raw rows and source comparisons are retained in [closeout-source-audit.json](evidence/loading-fixes-2026-11-13/closeout-source-audit.json); each `closeout-star-*` receipt records the full command.

## Verification completed

| Check | Actual result |
| --- | --- |
| Memory dependency boundary | 72 checks, 0 failures; original control 72 checks, 40 failures |
| Contact retention under memory policy | 10 checks, 0 failures |
| Existing retention/effects/scenery budgets | 47 checks, 0 failures |
| Driving contracts | 72 checks, 0 failures |
| Shell loading flow and selected-owner lifetime | 19/0 and 12/0 |
| Feature parser | No parser failures |
| Contact outline retention | 52/0 headless, 52/0 Compatibility, 52/0 Vulkan |
| Ghost shader reuse/appearance | 20/0 Compatibility, 20/0 Vulkan |
| Existing personal ghost and rewind | 38/0 and 61/0, including private-snapshot reruns |
| Actual-App entry/re-entry/retry, headless | 16/0; both race entries accept a prepared base and retries reuse Game with tick zero/full countdown |
| Broad App composition/editor/test-drive regression, headless | 141/0 |
| Final scenery cache focused checks, headless test mode | 98/0; corruption, option invalidation, cancellation, pressure, teardown, worker ownership, atomic lock recovery and excluded-Night fallback |
| Private prepared-asset preflight | 551 resources, 2,267 checks, 0 failures; 6,797 relevant input hashes unchanged across the complete repair |
| Final production/feature parsing in frozen snapshot | 558 production scripts, 0 failures; feature parser also passes |
| Final strict native Compatibility integration | 132/0, all six cars, all five complete AI opening laps, first emissions and six interruption modes; clean verbose shutdown and unchanged source/asset guards |
| Final strict native Vulkan integration | 143/0 with the same full scenario coverage, clean verbose shutdown and unchanged source/asset guards |
| Private catalogue provenance | Six exact native images and 167 current source hashes pass after the final private identity generation |
| Final native actual-App Star comparison | Four fresh processes, 16/0 each; explicit write/hit controls, prepared-base acceptance and retry identity/state checks |
| Current live contact retention | 45/0 across the six updated models; no baseline override, so the seven historical source-control assertions are not repeated |
| Current live Compatibility entry/re-entry/retry | 16/0; prepared-base hits on both entries, tick zero/full countdown, accepted world publication and clean shutdown. Two unrelated Electric kit outputs changed during this run; no production sources changed |
| Final current live prepared audit | 551 resources, 2,267 checks, 0 failures; no source/asset changes during the final run and all 6,897 prepared input hashes exact across the closeout fence |
| Final current catalogue provenance | Six exact native images and 168 current source hashes; official six-image refresh repairs scene bindings after concurrent scene publication |

The visible-wall suite retains 21 Electric failures out of 200 checks in both the exact original and replacement contact source. Failure strings, all 30 contact rows and Game tick observations match. This existing failure is not reported as a pass or removed.

Initial persistent-scene Vulkan comparisons failed strict pixel equality even where original-versus-original controls were exact. These attempts remain in evidence. Persistent reuse is therefore restricted to the qualified Compatibility path; the failed visual criterion is unchanged.

All-five Compatibility fresh-write structural/native checks passed 346/0, but the subsequent fresh-process read failed one Night structural signature after deliberate corruption/repair (351 checks, 1 failure; native pixels still exact). That failure remains recorded. Night persistence is conservatively excluded; its existing RAM/build route remains. The other four biomes passed the same cross-process geometry/material/transform/group and native image comparisons.

Persistent scenery serialization runs on the main thread beneath the loading screen. Source/checksum verification uses a pure-file-I/O worker and overlaps remaining graphics preparation. Pending writes retain a weak owner and are discarded if its world generation/scene changes, cancellation wins, or the owner is freed. Atomic publication uses a fully populated temporary lock directory, so a crash cannot leave a permanently ownerless lock. Five files/128 MiB bounds committed and pruned payloads; at most two writes are pending per process, and simultaneous processes can temporarily exceed the disk allowance before pruning. GPU and scene objects stay off the I/O worker.

The final 98-check run follows a retained 98/2 Windows lock-recovery attempt. The optional nonblocking write safely missed during that attempt. The corrected fixture allows bounded next-frame recovery only after checking that no live lock is stolen and no candidate directory leaks; its final run recovered on the first try. This does not turn a failed write into a cache hit.

The first full native first-lap attempt timed out on Pine and was stopped after retaining that failure. A direct canonical diagnostic completed its lap at tick 2605; the actual-App diagnostic completed at tick 2640 plus all 360 countdown ticks, and an unchanged passive native rerun passed 12/0 with the same 2640 ticks in 24.993 seconds. The first failure did not include pause-state logging, so its cause remains unproven. The new `test_loading_fixes_first_laps.gd` wrapper retains every inherited assertion and offers explicit `--resume-backgrounded-ai`: only an active, unfinished, non-rewinding AI race paused by backgrounding is resumed through `Game.toggle_pause(false)`. The final Compatibility run recorded one such resume during Night at tick 1573; all five laps completed in approximately 25 seconds with zero new draw pipelines. Production focus/pause behavior is unchanged.

The final Vulkan run also completes every opening lap. It observes one draw pipeline created during the Desert lap; the existing first-emission checks still pass, and the largest recorded driving frame across its five laps is 12.792 ms. This is not a claim of zero runtime pipeline creation in every renderer.

A separate full native functional run passed 111 assertions but reported two objects/one resource still in use at shutdown. Headless two-entry shutdown, native 31-check interruption isolation, the passive native lap, and the final verbose 132-check full run all shut down cleanly. The original warning remains in evidence and is classified as not reproduced, not as a diagnosed/fixed leak.

## Commands and isolation

Tests use official Godot `4.7.2.stable.official.ed1daf0bf`, with private `APPDATA`/`LOCALAPPDATA`, empty `BMT_API_URL`/`BMT_DEV_AUTH_KEY`, and the Dummy audio driver. `scripts/run_loading_fixes.py` records the exact command, exit, errors, source hashes before/after, and asset size/mtime changes. Asset stamps detect concurrent writes; they are not byte-identity evidence.

Representative commands actually run:

```powershell
python scripts/run_loading_fixes.py ghosts-gl res://tests/test_loading_ghost_shader_reuse.gd --renderer gl_compatibility
python scripts/run_loading_fixes.py ghosts-mobile res://tests/test_loading_ghost_shader_reuse.gd --renderer mobile
python scripts/run_loading_fixes.py qual-personal-ghost res://tests/test_personal_ghosts.gd --project build/loading-fixes-20261113/qualification/game --profile qualification-checks
python scripts/run_loading_fixes.py qual-rewind res://tests/test_rewind.gd --project build/loading-fixes-20261113/qualification/game --profile qualification-rewind
python scripts/run_loading_fixes.py qual-profile-parse res://tests/profile_loading_fixes.gd --project build/loading-fixes-20261113/qualification/game --profile qualification-parse --check-only
python scripts/run_loading_fixes.py qual-entry-headless res://tests/profile_loading_fixes.gd --project build/loading-fixes-20261113/qualification/game --profile qualification-entry-headless --timeout 180
python scripts/run_loading_fixes.py qual-app-headless res://tests/test_app.gd --project build/loading-fixes-20261113/qualification/game --profile qualification-app --timeout 300
python scripts/run_loading_fixes.py qual-first-laps-final-gl res://tests/test_loading_fixes_first_laps.gd --project build/loading-fixes-20261113/qualification/game --renderer gl_compatibility --profile qualification-native-gl --timeout 900 --verbose -- --first-emission --resume-backgrounded-ai
python scripts/run_loading_fixes.py qual-first-laps-final-mobile res://tests/test_loading_fixes_first_laps.gd --project build/loading-fixes-20261113/qualification/game --renderer mobile --profile qualification-native-mobile --timeout 900 --verbose -- --first-emission --resume-backgrounded-ai
python scripts/run_loading_fixes.py closeout-live-contact res://tests/test_contact_outline_retention.gd --profile closeout-live-contact --timeout 180
python scripts/run_loading_fixes.py closeout-live-entry res://tests/profile_loading_fixes.gd --renderer gl_compatibility --profile closeout-live-entry --timeout 180
python scripts/run_loading_fixes.py closeout-live-prepared-stable res://tests/check_prepared_assets.gd --profile closeout-live-checks --timeout 180
python scripts/run_loading_fixes.py closeout-live-pictures res://../scripts/bake_garage_previews.gd --renderer gl_compatibility --profile closeout-live-pictures --timeout 180
python scripts/check_garage_previews.py
```

Every run's `*-receipt.json` under [evidence](evidence/loading-fixes-2026-11-13) contains its actual command. Earlier fixture errors and rejected attempts are retained and superseded only by identified corrected checks. The headless personal-ghost/rewind private reruns had stable production source while unrelated kit bakes ran; their timings are not benchmarks.

Concurrent external model edits invalidated live prepared assets during the initial work. Full native integration used a disposable private source snapshot; 6,797 relevant prepared inputs matched copied bytes and two stable source checks at creation. It has its own Git metadata for identity generation. The live index and owner profile were not used. Prepared binaries were not restored over newer live model work.

The missing live Super Rally family was repaired with the official per-vehicle bakers and 6,848-input guards; its receipt is [live-super-repair-receipt.json](evidence/loading-fixes-2026-11-13/live-super-repair-receipt.json). Later independent model work republished the other families. At closeout on 2026-11-14, an initial read-only live audit still found 467 stale keys while that producer was finishing; this rejected observation remains recorded. After the producer completed, the final independent live audit passes 551/2,267/0 with no concurrent source or asset changes. All 6,897 current prepared inputs match before/after hashes; the concise source manifest is [closeout-prepared-inputs.json.gz](evidence/loading-fixes-2026-11-13/closeout-prepared-inputs.json.gz).

A final preview check then caught scene-binding hashes changed by the last concurrent scene publication. The official native six-image baker refreshed accepted provenance, and the checker passes six exact images/168 sources. This final refresh leaves all six PNGs byte-identical to the pre-refresh controls. The completed live and frozen-source results are collected in [closeout-completion.json](evidence/loading-fixes-2026-11-13/closeout-completion.json).

## Checkpoints and limits

Verified source-only review patches and byte-exact forward/reverse receipts are retained for [memory policy](evidence/loading-fixes-2026-11-13/memory-policy-checkpoint.json), [contact retention](evidence/loading-fixes-2026-11-13/contact-source-checkpoint.json), [ghosts and loading fixtures](evidence/loading-fixes-2026-11-13/ghost-loading-checkpoint.json), and [world persistence](evidence/loading-fixes-2026-11-13/world-checkpoint-receipt.json). The exact owned file lists and hashes are in those receipts and the [final current-source reconciliation](evidence/loading-fixes-2026-11-13/closeout-source-audit.json). The [peer-review receipt](evidence/loading-fixes-2026-11-13/final-review.json) preserves its test-version boundaries; the later `qual-production-final` run parses all 558 production scripts with the final Night guard. No main-index staging is performed.

No device attachment query or device test, APK/export, deployment, live backend request, owner-save change or owner-process restart was performed. Desktop tests cannot qualify Android loading, memory, thermal behavior or driver compilation. Unavoidable first-use native pipeline work remains covered by the existing loading screen and graphics preparation. The fixes and regression verification are complete within the renderer/biome scope above; this is not a claim that every historical repository gate passes.

## Retention closeout exception

The prescribed `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply` completed successfully. Its observed output reclaimed 11 eligible entries, reducing build output from 25.37 to 23.72 GiB; recent/protected output remained above the 20 GiB target. Another cleanup replaced the shared last-run receipt before copying, so [the saved shared receipt](evidence/loading-fixes-2026-11-13/closeout-retention.json) has its own zero-deletion counters and is not presented as the 11-entry run.

The final completion-time invocation also exits 0: 24.12 GiB before/after and no further eligible entries, as captured directly in [closeout-retention-final.log](evidence/loading-fixes-2026-11-13/closeout-retention-final.log).

Automatic approval review rejected direct removal of both `build/loading-fixes-20261113/qualification` and the task's `.keep` marker, with the stated reason `blocked by policy`. Both commands were rejected before execution. No alternate deletion method or retention bypass was used. The private project/profiles and pin consequently remain in disposable build output, recorded in [closeout-cleanup-exceptions.json](evidence/loading-fixes-2026-11-13/closeout-cleanup-exceptions.json). Code and verification closeout is complete; this output-cleanup exception remains explicit.
