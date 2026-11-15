# Challenger shoulder and front proportions — 15 November 2026

The owner rejected the remaining scalloped side reflections and the long front overhang, supplying a marked game view, a side view and a clean vehicle photograph. These override the earlier requirement to retain the extended nose. This pass addresses the marked shoulder itself and removes the added front length.

[Before, owner-side angle](evidence/challenger-side-proportion-2026-11-15/before-views/white-owner-front-right.png) · [After, same angle](evidence/challenger-side-proportion-2026-11-15/final/gl_compatibility/white-owner-front-right.png)

[Before, orthographic profile](evidence/challenger-side-proportion-2026-11-15/before-views/white-profile.png) · [After, orthographic profile](evidence/challenger-side-proportion-2026-11-15/final/gl_compatibility/white-profile.png)

CSP01 — Root cause. The old 4 mm shoulder bend had irregularly spaced source triangles crossing it. The earlier upper-wing refinement stopped above this bend. Smooth source normals could not keep the reflected boundary even on that topology. The new test measures three actual native normal-isocontours along the entire marked side, rather than only sampling the upper fender. The prototype comparison from the owner-visible side reproduces the old scallops and shows their reduction.

CSP02 — Geometry and topology. A robust C2 fit retains the measured broad side shape, with a 9 mm transverse shoulder-transition parameter. Constrained longitudinal edge rows explicitly resolve that bend. The existing 3D boundary stations and wheel-arch cutouts stay attached; no global subdivision is used. Coverage-proven inward returns free enough triangles for these rows. The allocation guard adjusts longitudinal spacing until the complete body fits its starting count. Materials, studio lighting and production shaders are unchanged. Normals come from the same surface; both native tiers pass the shoulder outward-hemisphere check.

CSP03 — Front proportions. A common monotone final-coordinate transform shortens the nose by 140 mm, fading to zero ahead of the front tyre. Body, bonnet, optics, grilles, trim, authored markings and stock splitter receive that transform together. The runtime fitted-hood coordinate helper and fitted splitter position follow it. Wheel centres, tyres, wheelbase, car configurations, simulation, roof and window shapes are retained. The attachment height grid keeps its existing source domain; no runtime smoothing or additional mesh layer was introduced.

| Native measurement | Before | Final |
| --- | ---: | ---: |
| Assembled raw reduced triangles | 49,994 | 49958 |
| Assembled raw full triangles | 83,964 | 83940 |
| Production reduced stock, fixed/editable | 45,234 | 45198 |
| Mean P95 reflection-contour ripple, reduced | 1.1465 mm | 0.1022 mm |
| Mean P95 reflection-contour ripple, full | 0.8324 mm | 0.0834 mm |
| Front shortening | 0 | 140.000 mm |

The reflection measure follows 15°, 20° and 22° transverse normal-angle contours using independent ray intersections and barycentric native normals at 10 mm longitudinal stations. Their mean P95 second difference improves 91.1% reduced / 90.0% full. This is a contour-ripple measure, not an FPS, universal curvature, pixel-identity or AAA acceptance claim. Full traces, coverage, assertions and the retained old-mesh rejection are in `candidate-shape.json` and `baseline-shape.json`. Protected roof points differ only by approximately 0.065 mm of native packing. Side marker Y/Z shape and triangle count are retained; their existing producer re-seats X on the new body with a checked 3 mm offset.

CSP04 — Pipeline and verification. Fresh source conversion, private native bake and independent shape checks precede the native allowlist publication. The original 50k/85k assembled allocation test and all 172 panel-contour assertions pass unchanged. Fitted hood tests, all Challenger kit permutations, physics/replay, wash, driving, production parsing, Challenger-scoped prepared preflight, opacity and actual Garage/race checks pass. Both desktop renderers use real prepared-cache hits. An initial all-car rebuild was rejected when concurrent Volt assets and the shared VisualGeometry source changed. A later wider repair was also rejected when the shared car-surface shader allowlist changed. Challenger consumers were rebuilt against the latest helpers, with all six default photographs/portraits regenerated. After the concurrent cache rebuild settled, the final complete preflight passes 551 resources / 2,267 checks with zero failures. The earlier out-of-scope findings are retained in their original receipts. Other car model sources were not authored and no cache metadata-only restamp was used. The Challenger bake closed a 26343-input fence. A later concurrent Garage-header edit rejected one broad capture fence; that capture was rerun successfully. The original portrait producer also rejected two concurrent nonstock-kit writes before completing with 25,585 stable inputs. Final prepared-resource consistency is qualified at this snapshot; wider product/device acceptance remains.

CSP05 — Delivery and limits. Four source files changed: `scripts/challenger_side_finish.py`, its call in `scripts/challenger_reference_form.py`, the final transform in `scripts/prepare_challenger.py`, and the fitted-part coordinates in `game/vehicle/super_rally_model.gd`. The source-only patch applies and reverses exactly in a private repository. Configuration/simulation controls and four unused legacy native files remain exact. Concurrent work and the shared index were preserved. All actual command arguments, results and diagnostics are beside this report. Standard build retention and task-only disposable cleanup are recorded separately.

Early sparse-grid budget rejections, a partial prototype conversion rejection, generated-version source-fence changes, and the initial over-strict amber-marker X-control rejection are retained. The marker check now verifies its intended attachment to the actual finished skin as well as its unchanged Y/Z profile. No existing repository assertion was removed or relaxed. Any retained portrait-loader warnings or shutdown diagnostics are listed in `final-state.json`; they do not establish export readiness.

No physical-device test, game export, backend operation, deployment, owner-save/process change or shared-index staging/commit was performed. Reload the project/game before appearance review so it releases old in-memory model resources. Owner appearance and physical-device acceptance remain.

Recorded workflow, including recovery from concurrent edits (exact arguments and exit codes are in adjacent receipts):

```text
python docs/evidence/challenger-side-proportion-2026-11-15/run_preparation.py
python docs/evidence/challenger-side-proportion-2026-11-15/review_native.py
python docs/evidence/challenger-side-proportion-2026-11-15/deliver.py
python docs/evidence/challenger-side-proportion-2026-11-15/resume_delivery.py
python docs/evidence/challenger-side-proportion-2026-11-15/finish_global.py
python docs/evidence/challenger-side-proportion-2026-11-15/finish_scope.py
python docs/evidence/challenger-side-proportion-2026-11-15/checkpoint.py
python docs/evidence/challenger-side-proportion-2026-11-15/run_retention.py
python docs/evidence/challenger-side-proportion-2026-11-15/finalize.py
```
