# Road approval stalls — 2026-09-29

Owner follow-up: approving a road sometimes takes a long time. Requirements R01, T01–T04, V04/V05, Q01. This addresses the uncached scenery-build limitation recorded in BRIDGE_JUNCTIONS_AND_EDITOR_PERFORMANCE.md.

## Finding and change

The approval input handler was already short. Measuring the entire interval through preview completion reproduced a **1143.916 ms frame**, when the background compiler result triggered a complete synchronous scenery build on the main thread. The earlier approval benchmark measured only the click and its first frame, missing this later stall.

The editor now prepares replacement scenery invisibly in the existing scene tree using cooperative frame slices. The existing terrain/road/barrier slicing is enabled for editor replacements; shoulder overlap resolution, inner road-edge loops, kerb triangles, mesh vertex conversion and scenery children also honor the slice budget. This schedules the same geometry work across frames; it does not run scene-tree operations on a worker thread or change the road geometry.

The complete old scene remains visible until replacement is ready. Temporary approved-road overlays compare against the actually displayed scene, so they stay visible throughout the mesh build. The replacement waits until an active pointer gesture ends, then swaps atomically. A superseded build is discarded and the latest requested track is built. Leaving the editor frees the unfinished scene. Recent-scene caching remains bounded: two detached completed scenes, the displayed scene, and at most one in-progress replacement.

Initial editor opening remains synchronous. Some native mesh commits, mask preparation and other bounded operations remain indivisible, so this is not a guarantee of a particular frame rate on every map/device. Physics, compiler version, track identity and handling are unchanged.

## Desktop measurements

Pinned Godot 4.7.2, Windows/RTX 3090, 1280×720 graphical editor. Same oval and three successive curve approvals before/after; measurements include all frames through both compilation and scenery readiness.

| Measurement | Before | After |
| --- | ---: | ---: |
| Slowest frame during approval/preview | 1143.916 ms | 28.814 ms |
| Approval handlers, three samples | 11.343 / 13.340 / 15.902 ms | 10.872 / 12.574 / 13.925 ms |
| Approval through first frame | 17.760 / 19.808 / 23.427 ms | 16.721 / 18.947 / 20.299 ms |
| Three approvals through complete detail | 1731.111 ms | 1939.540 ms |

The complete detail takes slightly longer because the UI gets time between chunks. The gain is responsiveness: editing can continue while scenery finishes. Intermediate graphical runs measured 29.271 and 34.366 ms maximum frame intervals; these are desktop samples, not mobile guarantees.

Evidence: [before log](evidence/road-approval-slices/before.txt), [after log](evidence/road-approval-slices/after.txt), [approved roads while detail is pending](evidence/road-approval-slices/pending.png), [completed detail](evidence/road-approval-slices/ready.png). Both engine screenshots were inspected. Disconnected extra sections intentionally produce issues in this regression fixture.

## Actual verification

Commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action <Action>`.

- `ProfileRoadApproval`: 38 checks passed. Covers autosave, responsive navigation during construction, scenery supersession, cache/history behavior, leaving during an unfinished build, and exact mesh-array/transform equivalence between sliced and synchronous builds in grass, desert and winter.
- `TestWorkflow`: 207 passed, including gestures and blocked-start recovery.
- `TestPlacement`: 24 passed, including object-only preview and autosave paths.
- `TestSurfaces`: 50 passed. Its first run exposed an existing fixture problem: it installed a library after app initialization without setting an owner name; autosave then stamped an invalid empty creator. The fixture now supplies `Surface test` and fails cleanly if compilation returns null. Runtime validation was not weakened. The initially stalled test process was stopped after its null-track script errors.
- `TestSurfaceProfile`: 928 passed.
- `TestShoulders`: passed, union area 30, ten triangles, zero overlap/shading failures.
- `git diff --check`: passed.
- Android SDK `adb.exe devices`: empty list. No phone attached, Android export, installation or physical-device test performed.

## Files and acceptance

Implementation: `game/editor/editor_world.gd`, `editor_canvas.gd`, `game/track/native_track_visual.gd`, `shoulder_mesh.gd`. Tests: `game/tests/profile_road_approval.gd`, `test_surface_modes.gd`. Evidence/report and DEVELOPMENT_STATUS.md/PHASE_0_PLAN.md updated. Pre-existing unrelated visual and documentation edits are preserved separately.

Remaining acceptance: physical-phone responsiveness/memory, large dense maps, and human confirmation that the intermittent stall is resolved in the owner's editing session. Full-scene creation still consumes CPU, and this change does not claim to eliminate all editor costs or accelerate initial opening.
