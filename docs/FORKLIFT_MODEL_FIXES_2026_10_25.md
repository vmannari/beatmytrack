# Forklift model corrections - 2026-10-25

FR01-FR04/R01/G01/Q01 resolve the four findings in [the model review](FORKLIFT_MODEL_REVIEW_2026_10_25.md). The native procedural model now has correctly wound fork sides, a closed round steering grip, continuous paired leaf-chain plates with pins, pulley wraps and fixed/carriage anchors, and a hollow exhaust with a dark bore and annular lip.

[Native before/after gallery](evidence/forklift-model-fixes-2026-10-25/report.html) · [Measurements and commands](evidence/forklift-model-fixes-2026-10-25/report.json)

The change is confined to `game/vehicle/forklift_model.gd`. Existing fork profiles, 0.60 model-metre carriage lift, body shells, rear sticker, upper exhaust location and wheel articulation remain. Handling resource `forklift-3`, shared simulation, `CarVisual`, model dispatch and livery projection sources match their saved task-start SHA-256 hashes. The config hash remains `b8efe40fee6eafba448a1b6d3af917f3cc5bc05481ef3d6379835235f0d66cd6`.

## Corrections and evidence

| Requirement | Change | Native evidence |
|---|---|---|
| FR01 | Reverse the two fork-profile side-face triangle orders. Each fork goes from 18 inconsistent edges and 14 triangles disagreeing with its normal to zero. Both detail variants remain closed. | `fork-side.png`, `fork-underside.png`, `batched-fork-side.png` |
| FR02 | Replace the flat steering annulus with a closed torus, 38 mm grip thickness in model coordinates. Exterior back-face culling remains enabled. | `cockpit-top.png`, `cockpit-low.png`, `batched-cockpit-low.png` |
| FR03 | Continuous paired chain plates run from a fixed base anchor, around the existing sheave, to an anchor on the raised carriage. Low-detail geometry retains the continuous silhouette and reduces pin density/curve segments. | `mast-front.png`, `mast-pulley.png`, `batched-mast-front.png` |
| FR04 | A continuous swept outer wall and dark inner wall replace overlapping capped exhaust cylinders. A 24 mm-radius bore remains open within the 32 mm-radius outside wall. | `exhaust-outlet.png`, `batched-exhaust-outlet.png` |

The detailed/racing models contain 149,328/51,680 triangles, compared with 146,432/49,472 at task start, and 41 prepared mesh instances versus 40. This is a small geometry increase, not a device performance certification. All 49 native Forklift appearance photos and the catalogue illustration are refreshed; their existing filtering/import configuration remains.

## Validation actually run

All normal builds and checks use `scripts/dev.ps1` with pinned Godot `4.7.2.stable.official.ed1daf0bf`. Commands, raw logs and JSON measurements are retained in the evidence folder.

| Check | Actual result |
|---|---|
| New `test_forklift_model_finish.gd --before`, saved pre-fix source | 43 checks, 18 failures; reproduces both forks' winding and the missing solid rim, continuous chains and hollow stack |
| Same regression, current model, Compatibility | 97 checks, zero failures; 13 native close-up/overview captures |
| Same regression, desktop Mobile | 97 checks, zero failures; 13 captures including the production static merger |
| Existing `test_forklift.gd`, Compatibility, separate evidence directory and `--bake-art` | 111 checks, zero failures; actual Garage 1280/960, driving, both detail levels, retained rear steering/replay, weathering and bounded 80 km/h |
| Existing `test_forklift_clearance.gd`, separate evidence directory | 204 checks, zero failures; 54 bridge traversals, 20 turning cases, recovery, rail blocking, fork clearance and exact replay |
| Native `bake_livery_previews.gd --vehicle=forklift` | All 49 captures complete |
| Pinned `Import` after artwork refresh | Pass; all 50 native PNGs imported |
| Full script parser | 1,160 scripts, zero failures |

The regression measures boundary/shared-edge orientation and normal agreement for the forks, body/arches, steering grip, chain plates and combined exhaust walls. Rays check the steering grip above/below its plane, both chain runs and the wrap, and the open exhaust bore with a surrounding metal lip. It checks fixed/moving anchors and verifies the unchanged handling snapshot. The historical review script and evidence remain intact; the new test inherits only its reusable topology/capture helpers and writes to a separate folder.

Initial failures are retained. A concurrently added symbol font was not yet imported; the normal wrapper aborted during preload before the editor could import it. One bootstrap import used the exact pinned executable directly, allowing the initial autoload errors to occur and the font import to finish; that run exits 1 and is not a passing validation. Normal wrapper checks then resume without changing the font source or wrapper. The initial lip test used a short segment on small triangles; the segment-scaled determinant tolerance rejected valid detailed lip faces. A normalized ray with the same finite length and samples away from shared triangle edges corrects the diagnostic; the bore/lip assertions remain and both detail variants pass. These diagnostic corrections did not change production geometry or weaken a production invariant.

Changed files: the Forklift model, new regression/UID, generated UID for the inherited review helper, native catalogue/appearance PNGs, this guide, evidence and task-only status entries. Text changes are in a scoped Git-checkable patch; refreshed native assets are in a separate archive. The patch is checked against saved task-start files without changing the owner's index or HEAD. Unrelated Kart, fonts/localization, Desert, website and account work is preserved.

No device attachment check or physical-device test, APK, purchase, live mutation, deployment or owner-process restart was performed. Reload the client to see the model and artwork. Owner/device appearance and frame-pacing acceptance remain.
