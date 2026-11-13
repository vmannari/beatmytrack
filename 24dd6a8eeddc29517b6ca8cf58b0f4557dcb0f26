# Electric car exterior rebuild — 2026-10-27

The owner rejects further local corrections and requests a new complete electric car model, targeting premium game-asset quality while keeping its complexity practical. This pass replaces the body and assembly construction from scratch. Shared automotive finishes, tyre construction, glass shading, the physical vehicle configuration and game systems remain reusable foundations.

[Review the matched before/after model](evidence/electric-rebuild-2026-10-27/before-after.html). Both detail levels, both desktop renderers, close views and the unchanged production camera are included. Actual Garage and race screenshots are linked separately.

## Requirements

| ID | Requirement |
| --- | --- |
| ERB01 | Replace the entire exterior construction rather than layering another local hood deformation |
| ERB02 | Coherent Lucid-inspired sporting proportions, low rounded nose, mainly convex bonnet, flowing canopy and controlled rear shoulders |
| ERB03 | Formed front/rear assemblies, fitted glazing, restrained optical depth, wheel/brake/mirror detail and clean panel outlines |
| ERB04 | Efficient full/racing detail, prepared resources and matching five-frame racing shadows |
| ERB05 | Current Garage template and all electric pictures, original customisation/finishes and actual Garage/race checks |
| R01 | Preserve physical wheel positions, handling, simulation, collision, camera, input, economy/saves and unrelated concurrent work |
| Q01 | Native evidence, source and asset audits, retained failures, actual completed commands and one isolated Git checkpoint |

## Construction and design

`electric_coachwork.gd` is replaced by a new direct section model. There is no inherited front lowering deformation, inverse correction cache or accumulation of local hood fairings. The new body uses a shared shoulder section, a crowned convex bonnet, a waist with a restrained lower-door hollow and formed end caps. The outer shoulder turns through a controlled roll rather than meeting the bonnet as a sharp slab.

The windscreen, roof and rear glass sample one continuous arched canopy, with side glazing and painted pillars derived from the same frame. The cabin has a curved roof plan and a narrowing upper section. The nose, optical band and lower inlet use the same front section; their openings have physical returns and inset backs. The rear combines a restrained deck lip, twin thin guides, an inset plate pocket and a small diffuser. Rounded bonnet/door/trunk outlines, a charging flap, slim mirrors and new swept five-blade wheels finish the exterior. Calipers steer independently of wheel rotation.

The earlier Lucid photographs remain proportion and surfacing references. The asset is an original fictional car with no manufacturer mesh, photograph, badge or texture shipped. AAA describes the owner's quality target; automated tests do not establish an aesthetic rating or replace appearance acceptance in the game's established style.

## Validation and limitations

The new whole-car check measures prepared positions/normals, full/racing budgets, symmetry/proportions, actual wheel-opening clearance, underside/pocket construction and the canopy section through the screens and roof. The original 40-check bonnet regression and functional model/Garage/racing checks remain unchanged. The old form-specific fixtures describe the replaced panel topology; their old named-panel counts and cross-sections are not treated as the specification for a from-scratch model. They are retained byte-for-byte, with their applicability stated in the report.

The initial construction attempt exposed a typed-array outline error. The first complete draft also had eight bonnet shelf failures near the cowl. Its source, measurements and images are retained. The cowl grade was corrected with the original bonnet thresholds unchanged. Subsequent native inspection corrected end-section joins, concentrated shoulder samples, outward normals for closed surfaces, plate depth and panel corners. Superseded draft resources are archived outside the active asset root.

Completed counts, actual command logs, final before/after measurements and hash audits are in [report.json](evidence/electric-rebuild-2026-10-27/report.json). Native screenshot saves and construction assertions are reported separately. Desktop renderer results are not physical-device performance measurements.

| Completed check | Result |
| --- | --- |
| Whole-car prepared geometry | 33 checks, zero failures; exact task-start 33/9 |
| Original convex-bonnet check | 40 checks, zero failures, unchanged thresholds |
| Functional native model and day/night optical sampling | 34 checks each in Compatibility and desktop Mobile, zero failures |
| Actual Garage and racing integration | 70 checks each renderer, zero failures |
| Electric racing representation | 23 checks, zero failures |
| Project parser | 1354 scripts, zero failures |
| Source-matched final native views | 22 each renderer, zero save failures |
| Derived assets | All seven refresh/import jobs exit zero; Garage template and 53 electric pictures refreshed |

Full visible geometry decreases from 158270 to 115686 triangles (26.9%); racing geometry decreases from 78940 to 36952 (53.2%). The new 120000/45000 full/racing budgets are met. The five racing shadow meshes total 3500 triangles, with 66 prepared racing mesh instances after batching/reduction. The unbatched exterior drops from 823 to 372 instances; unbatched counts are not draw-call measurements. This is a geometry/cost budget result, not a measured frame-rate guarantee.

The new canopy has 57 convex runs out of 57 measured comparisons in both detail levels. Its largest sampled grade change is 2.24 degrees full and 2.35 degrees racing, versus 6.54/6.30 before. The original tyre centres, 2.46 m physical wheelbase and 0.6512 m tyre diameter stay fixed. Actual painted arch/tub clearance is 32 mm in model coordinates, about 28.2 mm at the existing physical scale.

V14 contains 403 prepared mesh resources and one manifest. All 865 historical v13 files remain byte-exact. The other cars' shadow/provenance entries and electric picture dimensions remain unchanged. Twelve original shape/functional fixtures remain byte-exact; no existing fixture is edited by this task. Concurrent work independently changes Electric18 braking to Electric19 and updates its handling tests. Those files are retained, snapshotted separately and excluded from this visual checkpoint. Native commands retain their individual build identities; no whole-tree freeze is claimed.

The first baseline adapter omitted the original screen names and produced unavailable sections; it is corrected to sample both constructions without relaxing an assertion. The final baseline's nine failures concern the new geometry/component budgets and named pocket requirements, not a claim that the previous roof lacked an arch. Initial audit assumptions about all original handling fixtures being unchanged also exposed the concurrent tuning work. These findings and desktop App frame hitches remain in the evidence.

## Delivery

Runtime scope is `game/vehicle/electric_coachwork.gd` and `game/vehicle/electric_car_model.gd`, with a new whole-car check and versioned `electric_coachwork_v14` resources. The shared index remains untouched; the task-only binary patch is checked/applied in an isolated temporary directory and compared byte-for-byte. Historical v13 resources and concurrent work are retained.

Reload/rebuild an existing editor/game to see the new model. Owner appearance/motion acceptance and physical-device appearance/cost acceptance remain. No physical-device attachment query/test, APK, real authentication/purchase, owner-save/live mutation, deployment, owner-process restart or main-index staging/commit/merge/reset is performed.
