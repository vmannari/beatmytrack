# Challenger nose corners rounded and slightly downturned (2026-11-13)

Finalisation on 2026-11-14: the native correction is unchanged, and the remaining Challenger prepared assets and photograph now pass 84-resource/349-check and 168-source validation. Prepared 30/0 and actual App 13/0 checks pass in each desktop renderer. The historical stale-cache conclusion below is superseded for Challenger by the [finalisation report](CHALLENGER_CORNER_FINALISATION_2026_11_14.md).

The owner marks the two upper nose corners and supplies a real Challenger front-quarter reference. The requested change is a softer corner and a slight downward sweep along the outer front sides. This pass keeps the preceding plan-view taper and the long, sharp shoulder crease.

## Native views

| View | Task-start geometry | Final geometry |
|---|---|---|
| White front-quarter | [Before](evidence/challenger-corner-roll-2026-11-13/garage-before/gl_compatibility/white-opposite.png) | [Final](evidence/challenger-corner-roll-2026-11-13/garage-final/gl_compatibility/white-opposite.png) |
| Red front | [Before](evidence/challenger-corner-roll-2026-11-13/garage-before/gl_compatibility/red-front.png) | [Final](evidence/challenger-corner-roll-2026-11-13/garage-final/gl_compatibility/red-front.png) |
| Red reference angle | [Before](evidence/challenger-corner-roll-2026-11-13/garage-before/gl_compatibility/red-reference.png) | [Final](evidence/challenger-corner-roll-2026-11-13/garage-final/gl_compatibility/red-reference.png) |

These are actual Godot renders. Before geometry is loaded from exact task-start native resources; the game source is not rolled back. The owner's photographs guide proportions rather than supplying photogrammetric measurements.

## Geometry

CRC01: The shoulder's front termination uses a graduated 1.5–13.5 mm analytic fillet parameter. Its return to the upright nose wall is moved below the rounded part, avoiding truncation of the new roll. The round is inscribed inside the original tangent envelope rather than puffing the corner outward. The long body crease retains its preceding profile.

CRC02: A common outer-corner map lowers the upper outer strip by up to 18 mm and turns the forward corner back by up to 16 mm. Smooth blend boundaries keep the centre front edge, lower lip, wheel region and fitted-bonnet domain fixed. All adjacent exterior layers use the same map. Its analytic Jacobian transforms normals consistently with the geometry.

The final native samples show **7.80–16.73 mm** of downward movement at the surveyed outboard upper skin. At the front-corner section, the normal transition broadens from **3.0–3.5 mm to 11.5–13.5 mm** across both sides and both tiers. The largest half-millimetre normal step also decreases in every one of those four comparisons.

Only two production sources are authored by this pass:

- `scripts/challenger_reference_geometry.py`.
- `scripts/prepare_challenger.py`.

Runtime fitted-bonnet coordinates need no new deformation: their entire domain lies inside the operation's onset. Source bonnet positions remain within native encoding precision. The 14 cm leading extension, contact positions and 198 km/h tune remain. This geometry correction adds no triangles: its assembled snapshot is **49,768 reduced / 84,724 full**. The later concurrent bonnet-contour feature adds 200 runtime triangles, making the latest checked model **49,968 / 84,924**, still within the owner's 50k/85k allocations.

## Surface qualification

| Check | Result |
|---|---|
| Independent native corner heights, sweep, complete sections and broader roll | **84 checks, 0 failures** |
| Same gate with task-start geometry as the candidate | **84 checks, 28 failures** |
| Existing plan-view shape and continuity | **3,912 checks, 0 failures**; maximum forward excursion remains 1.43 mm |
| Reviewed private candidate versus published native buffers | **44 resources / 264 checks / 0 failures**, positions/normals/indices/UVs/colours exact |
| Long shoulder and optical coverage | **1,848 checks, 0 failures** |
| Source bonnet heights | **252 checks, 0 failures** |
| Fitted choices | **316 checks, 0 failures** |
| Prepared modules/source comparison | **1,438 checks, 0 failures** |
| Prepared physics/replay | **3,677 checks, 0 failures** |
| Washing | **1,655 checks, 0 failures** |
| Final current production parser | **562 scripts, 0 failures** |

The independent native survey traces 24 cross-sections at 0.5 mm spacing directly through the encoded renderer triangles and interpolated normals. All 241 samples exist in each profile. An earlier physics-proxy survey missed several small faces; direct triangle intersections establish that the renderer faces are present. The surface gate uses the renderer data, not those incomplete proxy samples.

Twenty thousand finite-difference checks give maximum Jacobian error 3.45e-10 and normal-vector error 2.47e-10. The minimum sampled determinant is 0.78639, with no inversion. Ten thousand fitted-bonnet-domain samples remain fixed. The operation is geometric, not a material-only smoothing effect.

The first private draft lowered the corners but retained too tight a wall/fillet transition. It was not published. Its representative captures, source and measurements remain in `draft-one`. The refined private candidate passes the native gates before publication; published native buffers match it exactly. No source or binary rollback over concurrent work is used.

## Concurrent work, preparation and limits

Garage publication/provenance fixes, Kart changes and a shared material/contour refinement were written during this task. They are preserved. In particular, `super_rally_model.gd` receives concurrent finish/opaque-glass and pixel-integrated contour updates; this pass does not overwrite them. `concurrent-super-rally.patch` records that separate change against task start.

An initial task-private preview wrapper rejected the changed producer interface before rendering or publishing any image. The current production preview baker now supplies transactional private candidates, source/output fences and locks, so subsequent refreshes use that implementation. Its source changes are not attributed to this model pass.

Guarded preparation attempts retain the intervening source changes and failures. A broad vehicle-cache probe reports **487 findings with no Super rally findings at that instant**. Subsequent Kart and dependency-manifest writes invalidate the scoped source receipts too. The transient contour implementation also asserts during one artwork bake; its concurrently supplied canonical-topology fix is preserved. Script-error output is retained even where the engine exits zero. No failed guard is described as a pass, and whole-project readiness is not implied by this model's native surface results.

The final native/direct-render checks pass **29/0 per desktop renderer**, including opaque glazing, physical contacts and the absolute allocations. Actual App Garage/race checks pass **13/0 per renderer**. The 29-check mode deliberately disables prepared geometry; it is not described as the 30-check prepared mode. Every final renderer case has stable native/conversion and shared finish/contour input hashes across that case in `direct-render-fences.json`. The Compatibility App test retains two ObjectDB and one resource-in-use teardown diagnostics after its 13 passing assertions; no clean-teardown claim is made.

Repeated cache refreshes are rejected by continuing concurrent source changes, including the contour renderer, dependency manifest and subsequently added `bonnet_contour.json` / `challenger_panel_contours.gd` feature. The final read-only scoped probe examines **84 resources / 349 checks and reports 164 stale findings**. Catalogue provenance is also stale at that final probe. Those results are retained, and **current prepared/global readiness remains unqualified**. Source-checkout guards fall back to the corrected native model; no older source or frozen binary is restored over the concurrent work. The prior relative-to-Rally budget finding is not fixed by this pass.

The updated shader contour material required the fixture to recognise its shader/color parameter as well as the previous standard material; the one-contour/unshadowed assertions remain. A first Vulkan direct run has a moving unmodified baseline and two exact-pixel failures. Its pair/log remain under `latest-opacity-transient`. Allowing 64 settling frames retains all exact equality assertions and passes 29/0. Final before views are recaptured with the current shared finish, and a matched native close-up pair is retained in `closeup`.

All checks use pinned Godot 4.7.2, private saves and an empty backend URL. Pinned Blender 4.5.15 uses factory startup and disabled embedded scripts; preparation pins source geometry, labels and helpers and requires fresh tier outputs. The owner-removed original blend is represented by the retained measured source panels, with the original CC-BY attribution preserved.

The two-source checkpoint applies and reverses byte-exactly in a private scratch repository, with clean whitespace checks. The eight car configurations, two handling sources and unchanged detail helper are exact against task start. The main index and runtime Super rally source change during concurrent work; their current bytes are preserved, and no index write/staging is issued by this task. Nine of 24 unrelated PNG controls remain exact; 15 concurrently updated catalogue/header/news images are preserved. This task's preview command explicitly excludes the five other vehicles.

The final audit retains all 446 observed source hashes, rejected fences and current native hashes. The two owned conversion sources remain exact against the qualified preparation. A live-source guard failure is not hidden by the passing native checks. Generated debug arrays, conversion/native candidates and private profiles remain disposable under the unpinned task build directory. Standard retention cleanup is applied and its receipt is saved. Relevant comparisons and concise receipts stay in [the evidence folder](evidence/challenger-corner-roll-2026-11-13/).

Reload and owner appearance acceptance remain, as does physical-device qualification. No device query/test, APK/export, owner-save/process change, backend request, deployment or main-index staging was performed.

## Main reproduction commands

```powershell
python docs/evidence/challenger-corner-roll-2026-11-13/run_preparation.py
python docs/evidence/challenger-corner-roll-2026-11-13/run_check.py native-final res://tests/bake_challenger_hellcat.gd --headless --audio-driver Dummy -- --source=res://../build/challenger-corner-roll-2026-11-13/converted
python docs/evidence/challenger-corner-roll-2026-11-13/guarded_assets.py
python docs/evidence/challenger-corner-roll-2026-11-13/extra_checks.py
python docs/evidence/challenger-corner-roll-2026-11-13/prepared_checks.py
python docs/evidence/challenger-corner-roll-2026-11-13/check_plan.py
python docs/evidence/challenger-corner-roll-2026-11-13/check_corners.py
python docs/evidence/challenger-corner-roll-2026-11-13/check_corner_math.py
python docs/evidence/challenger-corner-roll-2026-11-13/checkpoint.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

Regenerate the task-start/candidate/final mesh exports and `native_corner_profiles.py` inputs using the exact saved `*-command.json` receipts when repeating the native section tests.
