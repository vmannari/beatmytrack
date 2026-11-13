# Runtime loading fixes 1–3 — 27 October 2026

Implemented the three requested changes from the [runtime re-audit](COMPREHENSIVE_MOBILE_REAUDIT_2026_10_27.md). Rendering quality, canonical simulation, input, race rules, rewards and account ownership remain outside this change. Reload the client to use the new code. No owner process was restarted.

## Changes

| Requirement | Implementation |
|---|---|
| RL01 — Shared trail shader | `skid_trails.gdshader` contains the original shader source, now preloaded once by `SkidTrails`. Every trail instance still has a separate `ShaderMaterial`, bridge bindings, pigments and ring state. The normalized shader source hash remains `9be740414ed505547513a5830e9f0856fbe6d89bfaee6156aabf1fe13db5d609`. |
| RL02 — Staged particle preparation and bounded reuse | Actual App loading now prepares one additional particle proxy per completed covered draw, checking the existing navigation/account/car/selection fence after each await. An App-owned hidden pool retains initialized proxy nodes: **64 nodes / 12 MiB estimated maximum**, with shared resources counted once. Every checkout binds the current source's resources/settings. Large families can evict entries; retained matching nodes are reused. Temporary proxies keep emitting one particle through later lighting contexts, then are hidden, stopped and frozen on return. Original live emitters are never emitted or advanced during loading. |
| RL03 — Front construction | Adjacent nose cells reuse a grid of **double-precision** surface samples. Cooperative construction checks between small sample/triangle strips and grille meshes; complete immutable fitting meshes are reused under **eight entries / 2 MiB**. Materials stay private to each car. Cancellation publishes no partial mesh; a trim generation prevents an in-flight strip from republishing a cleared cache entry. |
| R01 — Ownership and pressure | The pool is a child of its App, not a global detached-node cache. Cancellation restores borrowed geometry/material state and never activates an unfinished game. Memory warnings evict idle proxies, prevent retaining outstanding leases on return and clear optional fitting meshes. Both caches appear in existing retention telemetry. No scene-tree or rendering work was moved to a worker thread. |
| Q01 — Verification and review scope | Tests cover exact original mesh arrays, private materials, shader identity, ring semantics, all cars/themes, first real emission, pressure, cancellation and teardown. Source-frozen projects isolate the checks from concurrent editor work. The [evidence ledger](evidence/runtime-loading-fixes-2026-10-27/report.json) retains commands, original failures, source hashes and the scoped checkpoint. |

Production scope is eight files: `core/app.gd`, `editor/editor_memory.gd`, `vehicle/skid_trails.gd`, new `vehicle/skid_trails.gdshader`, `vehicle/effect_render_preparation.gd`, new `vehicle/effect_preparation_pool.gd`, `vehicle/compact_detail.gd` and `vehicle/compact_grille.gd`.

The synchronous `EffectRenderPreparation.begin()` API remains available for isolated resource checks. Shipping App loading uses the new staged path. Cached particle nodes always receive the current source bindings; cache hits never bypass covered preparation or assume that a different theme has identical materials. Pressure removes optional retention without destroying a node midway through a required draw.

The normal synchronous model-construction contract remains available. Race loading and Garage preloading use the existing cooperative callback. Checkpoints are soft scheduling boundaries; individual mesh/driver calls remain indivisible.

## Measured results

The original isolated full front build took **110.6 ms**, and the simple build **43.5 ms**. The new full and simple front geometry has exactly the same surface arrays, normals, indices, ordering, transforms and bounds:

- Full: `5503ad3fddc1d2a6b8b43fbad62800ada648a2217605dc56d994ea099b5c82e7`.
- Simple: `08fa3912027f0245c609acfea97662b94077f5b5175d2fd1073a641c84cb448c`.

The first focused headless run split that construction through roughly **4–5 ms** callback intervals. Later native runs include larger indivisible renderer/driver operations; this is **not** a hard 4 ms guarantee. The final whole-car load profile still records a **48.8 ms** maximum construction slice in the broader `details` stage, so the entire vehicle constructor is not claimed to fit one frame.

The six-track native Compatibility comparison used the actual App, fresh processes with existing disk/driver caches, and each track twice. The final run uses source-frozen code and the completed keep-alive refinement. Repeat-load peak frames changed as follows:

| Track | Before | Final implementation |
|---|---:|---:|
| Star | 264.4 ms | 32.0 ms |
| Freight | 236.0 ms | 39.4 ms |
| Switchyard | 264.5 ms | 55.9 ms |
| Timber | 237.9 ms | 46.8 ms |
| Quarry | 207.4 ms | 56.2 ms |
| Floodgate | 207.0 ms | 56.7 ms |

The final repeat entries reuse all **20 Star / 24 Storm** proxy nodes. An earlier integration profile is also retained. Neither run is a clean-install Android benchmark, and unrelated owner processes were left running. Concurrent code was frozen for final verification; this is not a fully controlled cold-cache A/B experiment.

Staging exchanges some total loading time for shorter blocking intervals. Final repeat Star entry was **1.798 → 1.740 s**; the five repeat Storm entries were **0.688–0.787 → 0.851–0.893 s**. Do not claim an across-the-board loading-time reduction.

Cold rendering remains expensive: final first Star entry took **46.237 s**, with a **5.592 s** largest frame; the baseline was 50.344 s / 7.162 s. Cache state and concurrent work prevent attributing the cold difference to these fixes alone. That residual first-use work is the separately identified runtime item 4. These three fixes do not establish 10/10 runtime, hitch-free loading or target-phone frame time.

## Verification

Two new tests provide the focused contracts:

- `test_runtime_loading_fixes.gd`: shared shader/private uniforms, exact task-start mesh fingerprints, cooperative/cancelled/trimmed construction, cache eviction, all five emitter themes with bridges, reuse of admitted nodes, hidden idle state, world teardown and pressure.
- `test_runtime_effect_loading.gd`: real App loading for all seven cars and all five themes, frozen tick/elapsed time/countdown/full empty 16,384-slot ring, actual reveal, navigation/car/selection/account cancellation, pressure and App teardown. Its first-emission mode exercises the real emitters in the actual lit world, checks canonical state and checks Mobile draw-pipeline reuse.

Final focused assertions pass **66 headless / 744 Compatibility / 744 desktop Mobile**. The actual App suites pass **126 Compatibility / 138 desktop Mobile** with first-emission observations. Counts overlap and are not independent player scenarios. Detailed retained-suite results and final parser/profile results are in the ledger.

Retained headless checks include App141, grille272, kit construction1354, model optimization128, tire ribbons11, bridge tire marks30, trail preparation26 and result ownership254. These protect existing behavior; no physics or backend rollout is implied.

The old dynamic-effects fixture references a 14 October `SandDust` snapshot that differs from the approved current implementation. Its ten resource-parity failures occur before the changed preparation path executes. A source-isolated task-start control reproduces the same full native **466 checks / 13 failures**, including the cold-readiness failures. They remain recorded. An evidence-only adapter changes only that obsolete builder input to the exact task-start `SandDust` source; **all original assertions remain**. Its component checks pass **139 headless / 462 Compatibility / 472 desktop Mobile**, including real first-emission checks. The original 15-second readiness condition was not relaxed.

One first focused fixture incorrectly converted an unset headless shader default to an integer. Initial pool tests also exposed a freed-object argument guard and conservative texture accounting; these attempts are retained alongside the corrections. The final cache test requires reuse of every **admitted** matching node and retains the all-nodes identity assertion when the entire family fits. It does not demand exceeding the cache budget for the largest Winter family.

Two graphical shape fixtures were initially invoked headless and waited for `frame_post_draw`. Only their verified task-owned processes were stopped; native reruns retain their assertions. The task runner now checks this prerequisite and records owned PIDs before waiting.

The front-join fixture also assumed its builder-only static dictionaries existed after a cached Garage scene was restored. An evidence-only fixture explicitly selects the builder and retains all **3,031** geometry assertions, which pass. That run and one Mobile night run report four ObjectDB instances / one resource at shutdown; these are retained as unclean exits, not presented as fixed lifetime findings. A task-start Mobile night control passes its assertions and exits cleanly in one run, so the shutdown finding is not consistently reproduced. The new focused and actual App checks exit without those findings. No audio or general shutdown change is included.

Concurrent work introduced a global `JumpProfiles` class and briefly an undefined `PopupStyle` reference in a draft-terms dialog. The pinned import refreshed class registration; the owner-corrected dialog was copied into both private source snapshots. No root editor/terms/jump fix or rollback is part of this task. Earlier parser failures remain recorded. The import itself returned zero but also reported locked editor-reload DLL copies, isolated Android SDK settings and the sandbox certificate warning; it is not classified as a clean release build.

All runtime runs retain the environment's root-certificate-store warning. That warning was not suppressed, and no production verifier policy was weakened. No complete client/backend regression pass, release artifact or Android performance certification is asserted.

## Scope and remaining acceptance

The source archives and hashes identify the actual validation inputs. Shared public assets/imported data and native runtime libraries were read by the private projects; profiles, player saves, credentials and pytest databases are excluded from the evidence. Existing Garage source validation remains enabled. Read-only checks find all seven retained Garage resources match the final source snapshot. Concurrent asset/template and editor/terms/jump work is excluded from the task patch.

The task-only App and memory-coordinator patch is reconstructed from the saved task baseline using only the explicit changed blocks. Concurrent changes elsewhere in those files remain in the working tree and are excluded from the review patch. Root staging/commit/merge/reset is not used.

Remaining acceptance is client reload and owner/device confirmation of appearance, input, first use, sustained memory and frame time. Cache bytes are admission estimates, not RSS, Android PSS or driver allocation. No physical-device attachment query/test, APK/AAB, actual authentication/purchase, backend/player mutation, deployment or owner-process restart was performed.

The [task-only patch](../build/runtime-loading-fixes-2026-10-27/runtime-loading-fixes.patch) is checked/applied outside the owner repository and compared byte-for-byte. See the [checkpoint receipt](evidence/runtime-loading-fixes-2026-10-27/checkpoint-verification.json), [command record](evidence/runtime-loading-fixes-2026-10-27/commands.md) and [artifact hashes](evidence/runtime-loading-fixes-2026-10-27/artifact-hashes.json). Source archives preserve the executed production code; shared public assets/native libraries and private profiles are not included.
