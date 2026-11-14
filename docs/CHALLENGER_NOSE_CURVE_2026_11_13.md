# Challenger nose continues the wing's plan curve (2026-11-13)

The owner marked the front corners in an overhead view: the previous nose suddenly widened ahead of the front wing. This pass removes that flare while retaining the sharp longitudinal shoulder crease requested in the preceding reference-photo pass.

Matched native overhead captures:

| Renderer | Before | Final prepared model |
|---|---|---|
| Compatibility | [Before](evidence/challenger-nose-curve-2026-11-13/plan-before/gl_compatibility.png) | [Final](evidence/challenger-nose-curve-2026-11-13/plan-final/gl_compatibility.png) |
| Vulkan Mobile | [Before](evidence/challenger-nose-curve-2026-11-13/plan-before/mobile.png) | [Final](evidence/challenger-nose-curve-2026-11-13/plan-final/mobile.png) |

These are orthographic Godot renders with the same camera, lighting and paint. Final captures assert a successful prepared-base cache hit. Workshop reference-angle and side captures are retained separately in `garage-before` and `garage-final` under [the evidence folder](evidence/challenger-nose-curve-2026-11-13/).

## Correction

CNC01: Dense native mesh sections locate an outward swell immediately ahead of the front wing. Across both sides and both quality tiers, the previous outline grows by up to **33.72 mm per side** after a local minimum. The original field blended the side skin into an independently specified wider nose wall; its transition was visible in plan view.

The final exterior receives one transverse taper after the existing longitudinal nose and shoulder operations. Two quintic blends start ahead of the wheel region and continue through the front corners. Each blend has zero first and second derivatives at its endpoints. The same operation moves the painted skins, bonnet, bumper, projector assembly, marker and trim, so a separate projecting cap is not left behind. The mathematical normal transform includes the taper's longitudinal shear. Source wheel geometry is excluded.

CNC02: Runtime fitted-bonnet positions use the identical taper, and the generated mesh-cache key advances to revision 6. The sharp shoulder topology, measured bonnet heights, existing 14 cm leading extension and source attribution remain. Axles, wheel contacts and the 198 km/h handling tune are unchanged.

The three authored production sources are:

- `scripts/challenger_reference_geometry.py`: common taper and its normal transform.
- `scripts/prepare_challenger.py`: apply it to all exterior layers at export.
- `game/vehicle/super_rally_model.gd`: matching fitted-bonnet coordinates and cache key.

No materials or handling sources were authored. Geometry allocation remains **49,768 triangles reduced / 84,724 full**; this correction adds no triangles.

## Geometry verification

The independent plan test sections the actual native body and bonnet triangles at 326 depths, on both sides and in both tiers. It includes vertices coincident with section planes. It checks continuous sections, a maximum 2 mm residual outward excursion, a maximum 0.75 mm outward step per 2 mm station, and a visible net taper from wing to front corner.

| Check | Result |
|---|---|
| Native plan sections | **3,912 checks, 0 failures** |
| Same plan gate on exact task-start meshes | 3,912 checks, **1,159 failures** |
| Maximum remaining outward excursion | 1.430 mm, below the 2 mm mesh tolerance |
| Largest outward station step | 0.092 mm |
| Net wing-to-corner taper | 49.7–57.6 mm per side |
| Sharp shoulder continuity, crease position and optical backing | **1,848 checks, 0 failures** |
| Source bonnet heights at the common transformed coordinates | **252 checks, 0 failures**; 2.339 mm reduced / 1.561 mm full maximum height error |
| All fitted choices | **316 checks, 0 failures** |
| Prepared modules/source/ghost comparison | **1,438 checks, 0 failures** |
| Prepared physics/replay | **3,677 checks, 0 failures**; 198 km/h cap retained |
| Washing | **1,655 checks, 0 failures** |
| Production parser | **557 scripts, 0 failures** |

The runtime/offline taper agrees at 70 stations within 6.67e-16 m. Ten thousand independent finite-difference Jacobian/normal comparisons have maximum vector error 1.70e-10. The taper's minimum determinant is 0.925, so it cannot fold the skin. See `transform-contract.json`, `before-plan-check.json` and `after-plan-check.json`.

The prior photo gate's explicit `nose half-width >855 mm` expectation describes the rejected wider front, so this pass replaces those nose-width assertions with the independent plan gate. The shoulder assertions retain their thresholds. Nine optical-carrier probes use the common transformed station coordinates; their coverage and facing thresholds are retained. The first run still probed the old outer coordinates and reported four missing rays; correcting the probe coordinates gives 1,848/0 without changing production geometry.

The previous report's relative `Challenger <= Rally +10k` budget failure is unchanged: the triangle counts are identical. This pass continues to enforce the owner's absolute 50k/85k limits and does not claim the inherited relative-budget assertion is fixed.

## Prepared assets and desktop checks

The initial Super-only refresh passed source stability but the broad preflight reported **932 stale cache findings**. `super_rally_model.gd` is conservatively treated as a shared input by the existing dependency manifest, so its changed hash invalidates other vehicles' prepared keys too. The findings are retained under `assets-scoped-attempt`; they were not dismissed as unrelated.

The refresh was expanded to every affected base, kit and Garage scene, using the current sources and preserving concurrent Forklift/Rivalry work. Its 15-command attempt passes the strict resource gate but correctly rejects the five protected catalogue images' old revision/scene provenance. A five-command presentation repair therefore renders all six catalogue images from their current prepared scenes, without repeating the completed geometry bake. Both phases fence source hashes and the complete per-vehicle build identities before/after. The failed scoped and protected-photo attempts remain visible in their separate receipt folders.

Final gates pass: **551 resources / 2,267 checks / 0 failures**, and **six native images / 161 current source hashes**. All **440** fenced inputs remain exact through the final refresh and live audit. Opaque-glazing/contact/absolute-budget checks pass **30/0 per desktop renderer**; actual App Garage/race checks pass **13/0 per renderer**. The workshop and overhead fixtures finish normally in both renderers. Results are in `validation-summary.json` and `final-audit.json`.

The main index, eight car configurations, two canonical handling sources and unchanged detail helper are exact against task start. Of 24 unrelated PNG controls, 19 are exact; the five other catalogue images were necessarily rerendered after their shared revision keys changed. They depict the current sources and pass the strict provenance gate; older pictures were not restored or relabelled. Other vehicle source code and configurations were not authored by this task.

## Evidence and fixture findings

Conversion uses the retained measured source panels and labels because the original downloaded blend remains owner-removed. Pinned Blender 4.5.15 runs with factory startup and embedded script execution disabled. Pinned Godot 4.7.2 checks use private saves and an empty backend URL. Preparation verifies stable inputs and fresh output for both tiers.

The first overhead showroom fixture saved its views but did not terminate normally; its two owned processes reached the runner's 300-second bound. Those command receipts and logs remain (`plan-before` / `plan-draft`). A smaller native orthographic fixture then completed normally in both renderers. This is a fixture limitation, not a passing shutdown check for the abandoned fixture. The final workshop captures use the separately qualified normal workshop fixture.

An initial runtime comparison exposed float32 rounding in `Vector3` constants used as taper parameters. Storing those scalar parameters in arrays retains double precision and produces the agreement above. Neither fixture correction changes the taper's intended shape or weakens the plan gate.

The first Vulkan opacity run reports two failures because the unmodified baseline view itself changes between samples. Its saved full-front pair differs at 15,876 pixels by at most 3/255 in a channel, with zero magenta pixels. A fresh isolated run of the identical 30 assertions passes with no fixture or production change. The rejected pair, command and result are retained under `opaque-initial`; no initial opacity pass is claimed. Both final App checks contain no script or teardown errors.

The source-only three-file checkpoint applies and reverses byte-exactly in a private scratch repository, with a clean whitespace check. Generated resources and concurrent source work are excluded from the patch. Native mesh/source hashes, comparison image hashes, exact commands and receipts are retained. Disposable debug arrays, private profiles and conversion output stay under the unpinned task build directory and follow the owner's retention policy.

Reload the game to consume the new resources. Owner appearance acceptance and physical-device qualification remain. No device query/test, APK/export, owner-save/process change, backend request, deployment or main-index staging was performed.

## Reproduction

```powershell
python docs/evidence/challenger-nose-curve-2026-11-13/run_preparation.py
python docs/evidence/challenger-nose-curve-2026-11-13/run_check.py native-final res://tests/bake_challenger_hellcat.gd --headless --audio-driver Dummy -- --source=res://../build/challenger-nose-curve-2026-11-13/converted
python docs/evidence/challenger-nose-curve-2026-11-13/run_check.py plan-export-final res://../docs/evidence/challenger-nose-curve-2026-11-13/export_plan.gd --headless --audio-driver Dummy
python docs/evidence/challenger-nose-curve-2026-11-13/check_plan.py
python docs/evidence/challenger-nose-curve-2026-11-13/guarded_assets.py
python docs/evidence/challenger-nose-curve-2026-11-13/extra_checks.py
python docs/evidence/challenger-nose-curve-2026-11-13/prepared_checks.py
python docs/evidence/challenger-nose-curve-2026-11-13/check_transform.py
python docs/evidence/challenger-nose-curve-2026-11-13/checkpoint.py
python docs/evidence/challenger-nose-curve-2026-11-13/audit.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

Run `plan_runtime.gd` with the evidence runner before `check_transform.py` when regenerating its runtime sample file. Exact final screenshot commands are retained in their `*-command.json` receipts.
