# Race loading separated from track construction

Prepared races now install into `game/track/prepared_race_world.gd`. A fresh-process Star/Pine/Compact race restored its verified disk scenery without loading `NativeTrackVisual`, taking **5.324 seconds** from race request to ready. This is not yet the requested sub-five-second result. Completely uncached entry still took **13.511 seconds** in the final Compatibility sample.

## Implementation

- The runtime world owns cache restoration, cancellation checks and moving prop presentation. `NativeTrackVisual` inherits that common behavior and supplies construction/editor functionality only when needed.
- Cache identity/version checks and shared artwork no longer require the scenery builder. Artwork and the Desert reference sample load on demand.
- Winter CPU placement uses shared deterministic functions instead of instantiating the builder. The extracted placement and presentation bodies retain their original behavior.
- Road jobs receive verified cached CPU packets directly. On a miss, construction scripts initialize on main before the worker starts, retaining the existing engine-threading constraint. Metadata-only tracks conservatively initialize construction before compilation.
- Game tries runtime restoration first. On a miss it transfers the road packet, cache identity and profiling data to the builder, without a second disk lookup. Editing, unsupported persistence cases and uncached tracks retain construction fallback.
- Existing cache identity, source validation, budgets, mutable-resource isolation and renderer/theme restrictions remain in use. This does not introduce shipped prebuilt circuits or change checkpoint semantics.

## Measurements

Godot 4.7.2, desktop RTX 3090, private offline profiles, stock Compact, Star/Pine. These are individual desktop samples, not a controlled statistical comparison or device performance guarantee. Menu/startup and fixture compilation precede the race-entry timer; the countdown begins after ready.

| Case | Race entry | Re-entry | Retry |
| --- | ---: | ---: | ---: |
| Compatibility, completely uncached | 13.511 s | 0.348 s | see raw receipt |
| Compatibility, fresh process with disk cache | 5.324 s | 0.280 s | 10.8 ms |
| Desktop Vulkan Mobile, construction/RAM path | 15.407 s | 0.579 s | 16–17 ms |

An earlier cache-hit sample was 5.580 s. The final cache-hit receipt asserts that the builder is absent and the runtime world is installed. Returning through the test's menu subsequently loads editor features, so the second race may report the builder already resident while still using the runtime node.

The final disk-hit entry still spends about 1.964 s loading the race feature, 0.778 s loading Game, 0.701 s preparing support, 0.400 s validating world identity and 0.334 s reading the world. These timings have nested/overlapping scopes and must not simply be added. Further reduction should target the remaining runtime dependency graph and prepared support data. First-ever loading also needs prebuilt track artifacts to avoid geometry and checkpoint generation; this split alone cannot deliver a universal five-second limit.

## Verification

- New fresh-process dependency regression: **13/0**, including Winter placements, missing-cache behavior and unchanged placement after loading the builder.
- Final production parser: **564/0**.
- Native disk/RAM restoration: **316/0** across Pine, Desert, Winter and Storm, plus **126/0** for Star. The restored runtime node preserves exact encoded scenery, native rendered images, resource isolation and Winter leases. Unsupported Night persistence remains rejected.
- Actual Compatibility first-emission, vehicle/theme and interruption suite: **132/0**; all five biomes complete their opening lap with zero contacts. A separate interruption run passes **31/0**.
- Final actual App cold entry/re-entry/retry: **16/0**. Fresh-process disk-hit assertions: **19/0**. Desktop Vulkan Mobile construction and RAM restoration: **16/0**.
- Final 34-file source checkpoint applies and reverses exactly after newline normalization; scoped whitespace check passes. Concurrent vehicle, generated identity and unrelated work are excluded.

The full driving/cache matrices preceded the final small change that transfers miss diagnostics and suppresses duplicate fallback lookup; final App cold/cache-hit/Mobile checks and parser/dependency checks cover that final revision.

Retained diagnostics: the broad 2009-script scan finds outdated test overrides and a historical Garage fixture compile failure outside these edits. Disk-cache tests emit 20-object/8-resource teardown diagnostics; the driving/interruption suites emit 2-object/1-resource teardown diagnostics. The full driving run also logs a publication-lock-directory lookup race during a cache read, then completes its assertions. These are not claimed fixed or clean shutdowns. Final App profiling and dependency/parser runs have no such diagnostics.

## Reproduction and evidence

Use private `APPDATA` and `LOCALAPPDATA` directories, empty `BMT_API_URL`/`BMT_DEV_AUTH_KEY`, and an absolute `BMT_LOADING_OUTPUT` JSON path. Run the pinned Godot executable with `--path game --audio-driver Dummy` and:

- `--headless --script res://tests/test_race_runtime_dependencies.gd`
- `--rendering-method gl_compatibility --script res://tests/test_prepared_world_disk_cache.gd` (all supported themes); append `-- --star` for Star.
- `--rendering-method gl_compatibility --script res://tests/test_loading_fixes_first_laps.gd -- --first-emission --resume-backgrounded-ai`
- `--rendering-method gl_compatibility --script res://tests/profile_loading_fixes.gd -- --star`, then repeat in the same private profile with `--require-runtime-hit` appended. Source changes deliberately invalidate this artifact.
- `--rendering-method mobile --script res://tests/profile_loading_fixes.gd -- --star`

The production parser uses the existing `test_script_parse.gd` scanner with tests/build/tmp directories excluded; the unfiltered scan and its failures are also retained.

[Logs, measurements and final source hashes](evidence/race-loader-split-2026-11-14/) include `split-final.json`, `final-cold.json`, `native-laps.json`, `mobile-entry.json`, `sources.json` and the source-only `changes.patch`. No device test, export, backend request, deployment, owner-save/process change or main-index staging was performed. Build retention cleanup is run at completion.

Completion retention run succeeded: 23.28 GiB before/after, zero entries removed. The cleaner reports recent, protected or locked output above the 20 GiB target; no bypass deletion or new permanent build pin was used. Final 34-source hash fence is unchanged.
