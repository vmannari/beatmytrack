# Tyre resistance and loading local tracks - 2026-09-14

Owner request: much stronger tyre friction/car impact, and loading created tracks for continued editing. Covers G01, R01 and T02-T04. Local drafts remain editable; the owner's intended later publication rule is that a shared version becomes immutable. This slice does not implement publication locks: current clipboard/file exchange does not mark a track as published or lock it.

## Changes

Tyre sliding deceleration is 24 m/s2 instead of 6; effective stack contact mass is 260 kg instead of 65. These are arcade tuning values, not measured real-world tyre properties. The impulse still transfers momentum, stacks still move under a strong hit, and restart restores the authored positions. Canonical physics advances to **arcade-planar-0.14**; compiler-6 and creator-track-v5 remain unchanged. Car handling parameters and camera framing are unchanged.

The editor has **Load** beside Save. It preserves current work, lists saved local tracks, searches by name/creator and opens the selection directly for editing. It loads the existing ID, so subsequent saves update that track. A new editor view and undo history prevent editing state from leaking between documents. Saved tracks with unfinished laps can also be loaded for repair.

Invalid-lap drafts now render their actual map using a safe preview-only route, rather than drawing a phantom default road. The saved lap is untouched and racing remains disabled until the real route validates.

Changed files: `game/vehicle/loose_tyres.gd`, `vehicle_simulation.gd`; `game/core/app.gd`; new `game/tests/test_tyres_and_load.gd` and UID; `scripts/dev.ps1`; status/phase documentation and the screenshots linked below.

## Actual checks

Commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action <Action>` with pinned Godot 4.7.2.

The new `TestTyresLoad` initially reproduced both weak-response failures before tuning:

| Fixed scenario | Before | After |
| --- | ---: | ---: |
| Stack sliding from 10 m/s: stopping distance | 8.292 m | 2.042 m |
| Same stack: stopping time | 1.667 s | 0.425 s |
| Direct stack impact, car initially 20 m/s: remaining speed | 18.717 m/s | 15.634 m/s |

`CaptureTyresLoad` passes 15 checks: stronger resistance/impact, fresh-library loading, searchable selection, no-results handling, current-work preservation, same-ID editing/saving, reset selection/undo state, unfinished-draft loading, correct draft-map preview and two engine screenshots. Its headless counterpart omits only the two screenshot checks.

`TestRefinement` passes 29 checks with the new response, including exact JSON-input replay and restart. In its powered 360-tick push witness, two stacks move more than 0.5 m and continued pushing produces 425 contact ticks; contact counts represent repeated simulation contacts, not unique crashes.

Final `Validate` passed import, all 70 script parses, main-scene startup and all 940 regression checks: driving 56, native tracks 163, extra tracks 27, creator 86, editor 39, free editor 55, pieces 106, practice 31, workflow 96, construction 73, refinement 29, tyres/load 13, app 84, records 53, catalog 18 and menu presentation 11. Existing bridge/lap/replay checks remain passing. `git diff --check` also passed.

Reviewed Windows engine captures: [Load picker](evidence/load-track-picker.png), [loaded unfinished draft](evidence/loaded-track-editor.png).

## Remaining acceptance

Owner driving-feel acceptance and physical-phone input/performance checks remain outstanding. No physical-phone test or APK export was performed; configured Android tools and matching templates remain unavailable. Tyres retain the existing simple planar stack behavior, including no stack-to-stack collisions or vertical tumbling. Shared-version locking belongs to the later publication lifecycle; no local draft is locked by this change.
