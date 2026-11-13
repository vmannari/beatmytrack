# Race retention and preview dependency boundary

LHF-RACE01 retains completed particle preparation before disposable road CPU buffers and independent road GPU caches. The 64 MiB shared allowance, 32 MiB road allowance, 64 MiB world allowance and 12 MiB proxy pool remain unchanged. Shared resources, live nodes, running workers and real pressure keep their previous ownership fences.

LHF-RACE02 changes only two cooperative world-cache parameter annotations from `NativeTrackVisual` to `Node3D`, matching the existing synchronous boundary. Car resource accounting can consequently load the cache without importing track builders. Every method body and byte estimate remains exact. The production callers still supply `NativeTrackVisual` instances and its cooperative interface.

## Observed performance

The final race comparison uses the same isolated project and a test adapter selecting the archived or current memory policy. Each arm has two warm re-entries per theme. No other heavy task ran during this pair.

| Desktop Compatibility observation | Before | After |
| --- | ---: | ---: |
| Winter first re-entry | 1490.624 ms | 657.327 ms |
| Winter two-entry warm median | 1111.919 ms | 661.660 ms |
| Desert two-entry warm median | 1143.589 ms | 793.655 ms |
| Pine two-entry warm median | 576.719 ms | 603.686 ms |

Winter's first re-entry reuses 32 rather than zero initialized particle proxies. Desert reuses 19/20 rather than zero/six. Pine retains the same 20/six reuse counts; its warm road stage remains 21–43 microseconds. Its observed 4.7% slower median is retained, without claiming either improvement or zero latency regression from these two samples. The initial separate-project pair overlapped another agent's headless test and remains available but is not the primary comparison.

Fresh-process component script loads, one process per arm and target:

| Script | Before | After |
| --- | ---: | ---: |
| CarShowroom | 2739.750 ms | 1481.500 ms |
| GaragePreviewCache | 2729.576 ms | 1548.447 ms |
| EditorMemory policy | 2754.645 ms | 2634.982 ms |

The candidate showroom/picture graphs leave `NativeTrackVisual` unloaded. All car builders still load. EditorMemory independently imports the track graph, so the lighter preview boundary may defer or divide later App work rather than remove the entire component cost from whole-menu latency. Parent combined-App measurements determine that outcome. No cold-driver, phone, or universal loading-time halving claim is made.

## Qualification and evidence

- Final quiet race pair: 77/0 each, identical source dictionaries. Tick zero, countdown 360, five laps, completed installation and same-Game retries remain checked.
- Retention regression: 15/0; archived ordering reproduces three intended failures out of 15. Original budget/race-cache checks pass 12/0 and 20/0.
- Initial native Winter retention check: 28/0, including exact active-view and re-entry pixels.
- Final annotation candidate: original cooperative staging 8/0, race-cache 20/0, Winter surfaces 12/0 and selective budget 12/0.
- Original prepared library: 468 resources, 1925 checks, zero failures. No geometry source guard or prepared asset is changed, and no rebake is required.
- Actual prepared Compact/full Garage: native control 5/0 and candidate 6/0. Both prove real prepared-cache hits under original guards; base/tree geometry, Garage geometry and complete native pixels compare exactly. The candidate retains an unloaded world-builder script even after full Garage construction. The capture was inspected.
- Final native Winter retention: 28/0, source-stable, with no teardown leak in this run. All eleven Pine/Winter PNGs are additionally byte-exact to the captures before the annotation change, including re-entry and before/after ordinary arbitration; [comparison](world-scenery-before-comparison.json).

The last native correctness runs overlap the parent's Android compilation. Their timing fields are diagnostic only. The final summaries are [summary.json](summary.json), [world-type-summary.json](world-type-summary.json), [verification.json](verification.json), and [world-construction-comparison.json](world-construction-comparison.json). Each run directory records its exact command, private profile, source hashes, exit status and diagnostics.

Failures are preserved: the first new fixture used `add_child` on an already parented proxy; the corrected fixture uses `reparent`. The first same-project adapter replaced the lazy memory facade rather than its `_policy` and failed before installation. The initial source patch used CRLF for newly authored LF files; the writer now emits LF, and strict reverse/isolated normalized forward checks pass. Windows certificate-store diagnostics remain. The original scenery check retains its known two-object/one-resource shutdown leak without relaxed assertions. An early non-isolated headless run recorded an unrelated Rivalry source edit and is excluded from final stable-source qualification.

Conservative custom Garage/header photograph identities can change once after a normal build, although original geometry keys and bundled photographs remain valid. No owner saves, device, backend, export/deployment or main Git index were touched by this subtask.

## Files and checkpoint

Changed shipping sources:

- `game/editor/editor_memory.gd`; byte-exact before: [editor_memory.before.gd](editor_memory.before.gd).
- `game/track/prepared_world_cache.gd`; byte-exact before: [prepared_world_cache.before.gd](prepared_world_cache.before.gd).

New game tests are `game/tests/test_race_effect_retention.gd` and `game/tests/profile_race_retention_policy.gd`. Other task additions are entirely inside this evidence directory. The construction/graph fixtures and preparation runners use task-owned isolated projects.

[task-source.patch](task-source.patch) contains the two shipping changes and two game tests. It passes a strict reverse check against current sources and exact normalized forward application in `build/loading-half-20261106/race-patch-check-v2`. The before archives and evidence helpers accompany it. [final-source-files.json](final-source-files.json) records the exact source/helper list and all accompanying evidence files and hashes.
