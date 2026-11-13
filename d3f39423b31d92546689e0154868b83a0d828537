# Electric rear window-to-trunk flow — 2026-10-28

The owner rejects the rear window's transition into the trunk. The task-start model connects a roughly 36-degree descending glass section to a nearly flat deck. The centre's measured slope change is 32.68 degrees and its prepared normal changes by 32.90 degrees. The previous whole-canopy check stops before this joint, so it did not catch the crease.

[Review the matched rear-focused before/after viewer](evidence/electric-rear-flow-2026-10-28/before-after.html). It includes the side, rear three-quarter, roof and close views, both detail levels and both desktop renderers. Actual Garage and racing captures are linked separately.

## Requirements and implementation

| ID | Requirement |
| --- | --- |
| ERF01 | Smooth the rear window-to-trunk height, tangent and curvature transition |
| ERF02 | Carry the same surface through the lower glass corners and rear pillars; remove the outward width flare at the base |
| G01 | Keep the existing full/racing geometry budgets, original tail lip and fitted rear fascia |
| R01 | Retain the front, bonnet, main roof, wheels, finishes, physical configuration, simulation, camera/input, saves and concurrent work |
| Q01 | Current prepared/derived assets, native evidence, focused and retained checks, source/asset audits and an isolated checkpoint |

The lower rear canopy now blends into one shared height field. A quintic section retains the upper glass's starting height and derivatives and approaches the existing formed tail lip. The trunk continues the glass/corner surface's height, tangent and curvature at its front boundary. The added trunk fairing vanishes with both derivatives at the original tail edge, so the deck still fits the rear fascia. Rear pillars use the same field rather than separate straight bridges. The rear canopy width now reaches its endpoint with finite derivatives instead of an infinite widening rate.

This changes the actual prepared mesh and its normals. It does not substitute a shader or change the Garage lighting. The front canopy and main roof remain outside the changed interval. Runtime source scope is only `game/vehicle/electric_coachwork.gd`, with versioned `electric_coachwork_v15` resources. The assembly and original regression fixtures are retained.

## Verification

The new independent regression clips actual prepared triangles at seven lateral stations, including the centre and both rear corners. It samples heights, adjacent slopes and interpolated normals on both sides of the glass/trunk joint for full and racing detail. The exact task-start model fails 28 of 58 checks; the new surface passes all 58. No threshold is relaxed.

The centre's slope change becomes 1.19 degrees. Across all fourteen full/racing sections, the largest slope change is 1.88 degrees and the largest normal change is 0.077 degrees. These sampled mesh figures include discretization and are separate from the analytic derivative construction. The visible geometry remains exactly 115686 full and 36952 racing triangles.

An independent prepared-buffer audit finds 365 of 403 surface-array sets byte-exact. The 38 changed sets are confined to the rear deck/shutline, rear glazing/border and rear portions of the side canopy/window sill. The original front, bonnet, roof, wheel and fascia buffers remain exact. All 404 historical v14 files remain untouched.

Actual command outcomes, matched source hashes, source/asset checks and native views are recorded in [report.json](evidence/electric-rear-flow-2026-10-28/report.json). Capture saves are reported separately from geometry assertions. The initial attempt to run an evidence-directory audit script is rejected by the pinned wrapper's required `res://tests/` path; the helper is moved into the required test directory and passes. The failed invocation is retained as a tooling finding.

| Completed check | Result |
| --- | --- |
| Rear window/corner/trunk continuity | 58 checks, zero failures; exact task-start 58/28 |
| Prepared-buffer scope audit | 2 checks, zero failures; 365 exact / 38 intended rear array sets |
| Retained whole-car construction / convex bonnet | 33 / 40 checks, zero failures |
| Native model and day/night lighting | 34 checks each in Compatibility and desktop Mobile, zero failures |
| Actual Garage and racing integration | 70 checks each renderer, zero failures |
| Electric racing presentation | 23 checks, zero failures; five refreshed shadows total 3494 triangles |
| Project parser | 1361 scripts, zero failures |
| Source-matched native views | 22 per renderer, zero save failures |
| Derived assets | All seven refresh/import jobs exit zero; Garage template and all 53 pictures refreshed |

The assembly, glass shader, existing tests, physical car configuration, canonical simulation, camera, showroom and shared finish sources match task start. Only the coachwork runtime source changes. No concurrent source edits are included in the checkpoint. The two new test helpers cover the previously unmeasured rear joint and the protected mesh buffers.

## Delivery and acceptance

The electric Garage template, matching racing shadows and all 53 electric pictures are refreshed. Only this car's entries are updated in shared manifests. The binary task-only patch is checked/applied in an isolated temporary directory and compared byte-for-byte, with the shared index unchanged. Original sources and the expected task-start regression failure remain alongside the final proof.

Reload/rebuild an existing editor/game to see the change. Owner appearance/motion acceptance and physical-device appearance/cost acceptance remain. No physical-device attachment query/test, APK, real authentication/purchase, owner-save/live mutation, deployment, owner-process restart or main-index staging/commit/merge/reset is performed. Desktop App hitches, if present in the logs, do not establish a phone-performance result.
