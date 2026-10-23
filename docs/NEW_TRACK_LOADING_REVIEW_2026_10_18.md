# New-track race loading review — 2026-10-18

NTL01 measures the current first-visit path; NTL02 tests a different loading approach; NTL03 records the implementation boundary and tradeoffs. Q01/R01 require reproducible checks and unchanged canonical racing. This task adds a diagnostic and a local prototype. The shipping loader and backend are unchanged.

Owner direction after this review: server-side visual packs are declined. Loading improvements must run on the player's device. The earlier pack experiment below remains feasibility evidence; its distribution proposal is historical and is not the implementation direction.

The current recommendation is to prototype a native CPU geometry helper for the measured Desert subdivision/deformation bottleneck, using bulk typed buffers and the original geometry rules. First measure its cold-build time and geometry equivalence against the existing implementation. Then consider avoiding intermediate mesh construction/readback and extending bounded parallel work to the remaining serial stages. Prepare only the selected track during its detail view and retain completed work in the existing bounded device caches. Native Windows/Android builds, actual phone speed/thermal behaviour and appearance equivalence require validation; no native speedup is established by the pack timings. Godot documents [GDExtension](https://docs.godotengine.org/en/stable/engine_details/engine_api/gdextension/what_is_gdextension.html) as its native-library boundary.

## Current measurements

The diagnostic uses the existing three-piece Star spline fixture with Pine, Desert and Winter themes, pinned Godot 4.7.2 and disposable workspace storage. It runs the same CPU road job and consumes the packet used by `App._start_race`, then attributes the current `NativeTrackVisual.build` stages through a temporary subclass. Timing is desktop headless CPU attribution: it excludes HTTP, ticket requests, the complete Game setup, render submission, driver/shader compilation and countdown. Host workloads and already loaded resources can affect results. These are observations from this fixture, not guaranteed race-start times.

| Stage | Pine | Desert | Winter |
| --- | ---: | ---: | ---: |
| Compile track document | 396 ms | 415 ms | 621 ms |
| Cold road CPU job | 3,995 ms | 11,373 ms | 9,771 ms |
| Build world after prepared road packet | 818 ms | 24,996 ms | 1,689 ms |
| Desert deformation within world build | — | 24,172 ms | — |
| Winter cover within world build | — | — | 1,129 ms |
| Read/install saved roads in fresh process | 98 ms | 101 ms | 106 ms |
| World build with saved roads, fresh process | 527 ms | 23,148 ms | 1,466 ms |

Support construction is additional: 889/175/6 ms in the cold Pine/Desert/Winter samples. Pine is the first sample and includes first-use costs. Do not add rows that describe the same stage twice.

The important source ordering is concrete: `_build_creator_roads` remembers its road artifact before `NativeTrackVisual.build` calls `desert_relief.apply` on the assembled world. The saved roads therefore do not eliminate that later deformation. In the fresh-process saved-road sample it still takes 22,509 ms. Native race construction uses unsliced world building, so this work also blocks the main thread. The editor's newer cancellable preparation does not automatically change this race path.

The existing caches already help repeat visits. Both the in-memory complete-world cache and local compressed road cache remain useful. Making another road cache or moving the same road calculation to a worker does not address the largest remaining Desert cost. On this fixture the finished worlds fit the current 64 MiB world-cache estimate; the prototype does not propose increasing that budget.

## Finished-world prototype

The diagnostic duplicates the finished visual children using the existing world-cache ownership and instance-isolation helpers, saves a compressed **local-only** engine scene, exits, and loads those files in another engine process. It does not run the geometry builders during the pack-only pass.

| Finished local world | Compressed file | Existing resident estimate | Fresh-process read + instantiate |
| --- | ---: | ---: | ---: |
| Pine | 4,115,463 B | 57,238,520 B | 155.470 ms |
| Desert | 11,614,932 B | 65,134,048 B | 142.278 ms |
| Winter | 5,008,680 B | 45,952,480 B | 134.335 ms |

The estimates are the current cache's conservative accounting, not measured process peak RAM. File sizes include the local scene representation and referenced embedded resources; they do not establish the size of a future network format. Files remain under ignored `build/new-track-loading-review/` rather than adding generated scene binaries to the repository.

Recorded geometry signatures agree across cold generation, saved-road reconstruction, the finished holder and fresh-process finished-pack loading for all three themes. The signature covers ArrayMesh arrays, node hierarchy/class, transforms, geometry layers/shadow flags/groups and MultiMesh instance counts/buffers. It does not verify pixels, shader bindings, primitive/MultiMesh source meshes or live prop behaviour. No rendered or phone performance improvement is claimed. Initial disk reads share the OS file cache with preceding writes; this is a fresh engine process, not an evicted-storage measurement.

This demonstrates that most of the geometry-generation work can be removed from a first visit when a prepared artifact is available. It does not establish a 0.14-second complete race start. A production client still needs download time, validation, canonical support, fresh car/audio/UI/state setup and GPU preparation. For example, the Desert local file is about three times the existing 3,763,815-byte road-only artifact, so the network tradeoff matters.

## Earlier server-pack proposal — declined

1. Produce one immutable finished-geometry artifact per published content hash and supported visual revision, using the original builders. Reuse the existing worker/storage boundaries and deduplicate builds; browsing and downloading must not create another bake job per player. Packaged official tracks can be baked during a content build. Unpublished edits still require local preparation.
2. Define a bounded, data-only compressed wire format containing numeric geometry/instance data and identifiers for built-in materials/textures. The prototype's engine scenes and the existing private `.res` cache are **not** a download format. Keep scripts, arbitrary resources and supplied shaders out of downloaded artifacts. Validate manifest identity/hash, format, decompressed sizes, counts, finite values and indices before GPU allocation. Fence content/visual/format/engine compatibility explicitly.
3. Fetch the selected track's artifact under the existing loading cover, retain it in bounded local storage, and install finished geometry without recomputing unions, snow cover or Desert subdivision. Preserve locally compiled collision/checkpoints, exact pinned versions, fresh movable-prop buffers and canonical state. Reject incompatible or unavailable artifacts and use the existing local builder. Large active artifacts need not occupy the idle RAM cache.
4. Warm the selected track after its detail view settles, within the existing navigation/account/vehicle/version/cancellation fences. Keep this limited to the selected track; define network/data policy before speculative downloads. GPU preparation can overlap useful loading work but remains device-specific. Do not move it into the driving countdown and recreate the previously fixed first-use hitches.

A smaller client-only improvement is a persistent cache of the completed static world, including deformation. It helps process restarts and repeat visits; a first encounter still pays the initial bake. Speeding up the cold builders themselves remains valuable for creator edits and fallback cases. Native CPU implementation or bounded parallel geometry work should follow finer attribution and exactness checks if those cases need a major reduction.

## Commands, checks and scope

Commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`; `APPDATA` points at `build/new-track-loading-review/appdata`. Successful diagnostic runs used desktop native execution because the restricted engine initialization reports a certificate-store access error. No phone enumeration or backend calls are part of these commands.

```powershell
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/review_new_track_loading.gd -CommandTimeoutSeconds 420
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/review_new_track_loading.gd -TestArgument '--cached-only' -CommandTimeoutSeconds 420
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/review_new_track_loading.gd -TestArgument '--cached-bake' -CommandTimeoutSeconds 420
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/review_new_track_loading.gd -TestArgument '--pack-only' -CommandTimeoutSeconds 180
```

The cold diagnostic passes 12 checks; fresh-process saved roads 15; local finished-world bake 24; fresh-process finished packs 6; project parsing 858 scripts with zero failures. The bake helpers were present during the parser run; the subsequent single-argument convenience edit was compiled and exercised by the bake/pack commands. These checks exercise the diagnostic/prototype, not a deployed optimization or an end-to-end racing regression.

The first restricted command produced a completed zero-failure JSON but its wrapper failed on certificate-store initialization, so it is not counted as a passing command. An attempted pair of `-TestArgument` values did not cross the nested PowerShell boundary correctly and ran another cold diagnostic instead; its 12 passing checks and timings are retained separately and excluded from the primary comparison. The corrected `--cached-bake` invocation exercises the intended path. An outer PowerShell profile-policy warning preceded the first successful native rerun; it did not affect the child checks. Shared per-process-ID wrapper log folders were reused by unrelated concurrent work, so the retained JSON and task-specific command receipts are the evidence boundary; a wrapper build ID is not asserted to identify this entire review.

Changed files are the new diagnostic/UID, this report, evidence and the brief AGENTS/status/plan entries. Runtime, canonical physics/rules/compiler contracts, art, camera, backend and player files are unchanged by this task. Source hashes and actual outcomes are in [report.json](evidence/new-track-loading-2026-10-18/report.json); the reviewable slice is [task-only.patch](evidence/new-track-loading-2026-10-18/task-only.patch).

Production implementation, a validated download format, backend bake/storage rollout, network measurements, rendered equivalence, fresh instance/lifecycle/cancellation integration and owner/device acceptance remain. No phone attachment check or physical-device test, APK/export/install, deployment or FPS claim was made.
