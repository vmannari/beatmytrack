# Challenger surface quality — 15 November 2026

Refined the existing Challenger through its offline Blender converter and Godot native baker. [Before nose](evidence/challenger-surface-quality-2026-11-15/before-views/red-nose.png), [after nose](evidence/challenger-surface-quality-2026-11-15/final/gl_compatibility/simple/red-nose.png), [before cowl](evidence/challenger-surface-quality-2026-11-15/before-views/red-cowl.png), [after cowl](evidence/challenger-surface-quality-2026-11-15/final/gl_compatibility/simple/red-cowl.png), and [prepared whole car](evidence/challenger-surface-quality-2026-11-15/final/gl_compatibility/simple/white-front-quarter.png) are actual engine captures. Materials, lighting recipes and runtime smoothing were not changed.

VSQ01 — Diagnosis. The upper wing combined masked geometric deformations with transferred source normals, irregular interior triangulation and thin returned skins. Native ray surveys found physical curvature kinks separately from normal discontinuities. The broad bonnet was already continuous; its crown, vents and all native hood attributes are retained. Roof, pillars, glazing, rear body and lower-side shape controls pass unchanged. The existing longitudinal side chart remains in use.

VSQ02 — Geometry. A regularised C2 tensor-product sheet is fitted to 2,333 full / 2,344 reduced uniformly measured outward-surface samples. Existing vertices are projected onto that measured design; only the eligible patch interior receives constrained triangulation. Its source border stations are retained. Geometry corrections reach about 12.85 mm at the deepest inherited creases; final native closest-surface distances are 5.675 mm reduced / 12.754 mm full. Complete body bounds and protected body points are exact in the decoded native controls.

VSQ03 — Normals and packing. Continuous exterior copies share the fitted surface tangents. Downward bonnet gutter returns remain a separate hard domain. Inward faces are removed only with an outward-face coverage proof within 6 mm. The native baker repairs poor interior diagonals without changing their boundary or triangle count; one interior station receives bounded X-only fairing where a constrained concave quad cannot accept a diagonal flip. No runtime mesh, smoothing pass, shader trick, roughness change or normal map was added. Winding and outward native shading pass.

| Measurement | Before | Final |
| --- | ---: | ---: |
| Assembled raw reduced triangles | 49,462 | 49,994 (+1.08%) |
| Assembled raw full triangles | 82,452 | 83,964 (+1.83%) |
| Production reduced stock, fixed/editable | 44,702 | 45,234 (+1.19%) |
| Broad longitudinal normal step, reduced | 8.716° | 1.349° |
| Broad longitudinal normal step, full | 7.787° | 0.662° |
| Mean P95 physical curvature-kink metric, reduced | 0.1972 mm | 0.1339 mm |
| Mean P95 physical curvature-kink metric, full | 0.1444 mm | 0.0842 mm |

The geometric metric uses independent 5 mm ray tracks, not the construction equations. Its mean P95 improves 32.1% reduced / 41.7% full. Maxima and all raw assertions remain in `candidate-quality.json`; this does not claim every individual triangle improves or every sharp panel boundary is smooth. Existing 50k/85k allocation assertions and all repository assertions remain unchanged.

The actual-App logs retain raw-Image selection-portrait loading warnings. All 64 image imports are current, but no export qualification or portrait-loader fix is claimed. Any shutdown diagnostics are preserved in `final-state.json` and the complete logs.

VSQ04 — Receiving assets. Published the native allowlist, rebuilt coarse recipes, base and kit masters, Garage/header models, 49 livery pictures, native artwork, Garage photographs and selection portraits, then refreshed texture imports. Prepared captures assert actual cache hits. The source fence covers 26124 stable inputs. Completed commands and individual counts are in `final-state.json` and their adjacent logs. Native surface qualification is 62/0; the original native control rejects 62/4. Allocation is 17/0 and panel contours 172/0. Fitted modules, all kits, physics/replay, wash, driving, production parsing, prepared preflight, opacity and actual Garage/race App checks pass. Both desktop renderers were exercised.

VSQ05 — Delivery. Source changes are `scripts/challenger_surface_quality.py`, its call in `scripts/challenger_reference_form.py`, and offline native packing repair in `game/tests/bake_challenger_hellcat.gd`. The three-source patch applies and reverses byte-exactly in a private repository. Car configurations, runtime SuperRallyModel and simulation source controls remain exact; four unused legacy native resources remain exact. Concurrent workspace/index changes are preserved. No task-authored shared-index staging or commit, owner-save/process change, physical-device test, game export, backend operation or deployment was performed.

Rejections are retained: the initial bounded chart candidate, prototype GLTF round-trip attribute differences, generated-version source-fence changes, the reduced-grid allocation rejection, and the final skinny-triangle normal rejection before the packing correction. The full diagnostic survey also includes intentional hard return domains; it is not a zero-normal-split claim. Desktop evidence does not establish phone FPS or AAA/whole-project appearance acceptance. Reload the project/game to release in-memory model resources before owner appearance review.

Reproduction uses the pinned Blender and Godot builds through:

```text
python docs/evidence/challenger-surface-quality-2026-11-15/run_preparation.py
python docs/evidence/challenger-surface-quality-2026-11-15/review_native.py
python docs/evidence/challenger-surface-quality-2026-11-15/deliver.py
python docs/evidence/challenger-surface-quality-2026-11-15/checkpoint.py
python docs/evidence/challenger-surface-quality-2026-11-15/run_retention.py
python docs/evidence/challenger-surface-quality-2026-11-15/finalize.py
```
