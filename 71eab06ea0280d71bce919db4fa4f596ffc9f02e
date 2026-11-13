# Electric rear window and trunk redesign — 2026-10-28

The owner rejects the previous rear as malformed and supplies a low Garage view. This task replaces the rear glass, its frame, painted lower transition, rear pillars/shoulders and trunk topology. The previous height-field correction and inset rectangular trunk outline are removed.

[Open the matched before/after viewer](evidence/electric-rear-redesign-2026-10-28/before-after.html). The initial view is the low Garage angle, with clean and synthetic-wear variants. These are native game renders using the actual CarShowroom and original Garage finishes/reflections, not image-generation mockups or the owner's saved wear data.

## Requirements and construction

| ID | Requirement |
| --- | --- |
| ERR01 | Replace the bowed rear glass with a clean outline and shallow, consistently convex glass surface |
| ERR02 | Separate the painted slope transition from the glass; form stable rear pillars and shoulders |
| ERR03 | Replace the domed inset lid with a flatter full-width trunk and fitted side seams terminating in the rear optical band |
| G01 | Keep full/racing geometry inside the existing 120000/45000 limits and retain lighting/articulation |
| R01 | Preserve front/bonnet/main roof, wheels, finishes, physical configuration, simulation, input/camera, saves and concurrent work |
| Q01 | Actual Garage-angle appearance review, native before/after, regression evidence, current derived assets, hashes and one isolated checkpoint |

The rear glass is now a separate ruled Bezier section with a shallow transverse crown and rounded aperture corners. Its rake remains convex through its lower portion; the glass no longer curls forward to meet a flat deck. A painted apron below the glass carries the slope change into a shallow trunk. Rear shoulders and pillars are rebuilt around those sections, with a lower, restrained trunk crown and a fitted tail edge.

The old closed rectangular trunk seam is removed. Two side seams run from beneath the window, along the trunk and down into the optical band, describing the actual boot opening. Rear optical surfaces, plate pocket and badge are fitted to the new rear section. The front, main roof and rolling hardware use the original construction. Runtime source scope is `game/vehicle/electric_coachwork.gd`, with `electric_coachwork_v16` prepared assets.

## Verification and retained findings

The earlier continuity-only checks did not detect the rejected glass curl and trunk dome. The new regression measures actual glass boundary vertices, longitudinal sections of the glass, trunk crown and trunk slope. It also checks the replacement boot topology. The rejected v15 sources remain available for an isolated baseline run. Existing whole-car, bonnet, lighting and continuity fixtures remain unchanged. The retained original App test reaches Garage and race, then fails on an obsolete D/R-button assumption at line 261; the current Electric21 configuration already used normal brake/reverse controls at task start. Its two failures remain recorded. A new owned App fixture preserves its applicable selection, geometry, racing, keyboard and controller checks, and exercises actual brake presses/drags, release and restart across the current layouts. No driving configuration or existing fixture is changed by this task.

Native review includes the owner's lower rear angle and actual clean/worn Garage renders. Baseline Garage captures disable prepared-template caches in the isolated review process so they cannot accidentally load the current geometry. No owner save is read or changed for synthetic wear.

An initial buffer-audit classification omitted four authorized rear optical end arrays; the final classifier names them explicitly and retains strict front/roof/wheel and front-side-vertex comparisons. A malformed PowerShell quoting attempt and a transient concurrent `project.godot` metadata-read lock are retained as tooling findings. Final engine commands run sequentially to avoid overlapping shared build metadata writes. No owner process is stopped. The initial new App fixture tapped relative analog pedals without dragging; the corrected fixture uses their existing neutral-then-drag interaction and retains all checks.

Completed outcomes:

| Check | Result |
| --- | --- |
| New actual-shape regression | 24 checks, 0 failures; exact rejected v15: 24 checks, 16 failures |
| Retained construction / convex bonnet / rear continuity | 33 / 40 / 58 checks, 0 failures |
| Native model and lighting | 34 checks each Compatibility and desktop Mobile, 0 failures |
| Current actual-App Garage/race integration | 58 checks each renderer, 0 failures; original stale-selector failure retained separately |
| Racing model | 23 checks, 0 failures |
| Project parser | 1379 scripts, 0 failures |
| Native matched captures | 26 before and 26 after per renderer; all save successfully |
| Prepared-buffer scope | 259 surface arrays and 3698 protected front-side vertices/normals exact; no unexpected changes |
| Geometry | Full 117126 / 120000; racing 37312 / 45000 triangles; five shadow frames total 3400 triangles |
| Derived assets | 409 current prepared meshes, Garage template and all 53 electric pictures refreshed; all 404 historical v15 files exact |

The lower glass base now has about 23 mm transverse crown instead of 96 mm. The trunk crown is about 14 mm instead of 76 mm; its maximum measured grade is about 5.06 degrees instead of 15.97 degrees. These measurements describe the corrected shape, without claiming manufacturing tolerances or a device performance result.

Actual completed outcomes, measurements, source and resource hashes, final captures and scoped checkpoint are in [report.json](evidence/electric-rear-redesign-2026-10-28/report.json). Screenshot saves and construction checks are counted separately; passing assertions are not a visual-quality certification.

## Delivery and acceptance

The matching electric Garage template, racing shadows and all electric menu/header/livery pictures are refreshed. Original v15 resources and rejected-model evidence remain. The task-only binary patch is checked/applied in an isolated temporary directory and compared byte-for-byte without changing the shared index. Existing source/test fixtures and concurrent work are preserved.

Reload/rebuild an existing editor/game to see the redesign. Owner appearance/motion acceptance and physical-device appearance/cost acceptance remain. No physical-device attachment query/test, APK, real authentication/purchase, owner-save/live mutation, deployment, owner-process restart or main-index staging/commit/merge/reset is performed. Desktop hitches remain in the logs; no phone/FPS guarantee is claimed.
