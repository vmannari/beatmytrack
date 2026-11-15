# Challenger reference form — 15 November 2026

The owner rejects the current Challenger against the supplied clean white-car reference. This pass changes the bonnet and front proportions rather than continuing to preserve the rejected original bonnet exactly. The final [prepared Garage view](evidence/challenger-reference-form-2026-11-15/final/views-final/gl_compatibility/simple/white-front-quarter.png), [front view](evidence/challenger-reference-form-2026-11-15/final/views-final/gl_compatibility/simple/white-front.png), and [cowl close-up](evidence/challenger-reference-form-2026-11-15/final/views-final-close/gl_compatibility/full/red-cowl.png) use the actual rebuilt game assets. The [earlier cowl render](evidence/challenger-reference-form-2026-11-15/cowl-before.png) retains the dent found during visual review.

**CRF01 — Broader, rounded front.** A common final-coordinate taper widens the nose progressively by up to 9.5%, with the lamp carrier and trim following the same form. Four freshly authored circular projectors share a near-upright front plane. A rounded white rim, a real aperture cut, and the recessed black carrier replace the malformed grille edges. The central and lower grilles have geometric honeycomb cells. The new aperture has a 61 mm inner corner radius; its carrier radius is 63 mm. The frame and openings are geometry, with no runtime ray fitting.

**CRF02 — Regular bonnet and cowl.** A smooth bonnet crown, a restrained 42 mm central power bulge and rounded boundary replace the inherited bonnet folds. Its curved rear edge retains the windshield/cowl layout. Full and reduced bonnets use regular triangulation, unchanged vent paths, and native supported 2.5 mm markings. The fitted-hood height grid is regenerated in the existing attachment domain. The upper wing now joins that bonnet through a manufactured section using exactly the lower side's shoulder and width curves. This removes the dent below the windshield and keeps the long bend continuous. A close render exposed the dent after the first publication; this final chart is included in the final publication and fresh receiving-app checks.

The source also contains a thin inward returned skin near the nose. The shared fairing could put it just outside the visible skin, producing reverse normal hits. The converter removes only inward returns with outward paint proven within 5 mm at their centroids: 364 full and 266 reduced triangles. The existing shoulder normal/support/outward checks now pass in both tiers. No existing repository assertion was changed.

**CRF03 — Reference wheel proportions and preserved controls.** Factory alloy surfaces scale by 1.14 in the wheel plane and use darker gunmetal. The tyre radius, wheel centres, game scale, chassis, canonical configurations, driving/replay logic and purchased rim designs remain. Reduced factory lugs use six-sided hardware. Roof and rear source positions are retained; changed native body bounds introduce at most 0.068 mm of coordinate-packing difference. This is measured shape retention, not byte-identical native vertices.

| Native measurement | Task start | Final |
| --- | ---: | ---: |
| Front half-width, full | 786.92 mm | 863.24 mm |
| Front half-width, reduced | 788.07 mm | 862.28 mm |
| Lamp/grille median depth separation | 36.08 mm | 8.81 mm |
| Largest broad bonnet normal step, full/reduced | 102.06 / 86.54 degrees | 0.88 / 0.79 degrees |
| Largest cowl normal step, full/reduced | 0.541 / 0.529 degrees | 0.142 / 0.089 degrees |
| Front bonnet height drop across the surveyed 160 mm, full/reduced | 40.59 / 40.94 mm | 38.89 / 39.32 mm |

The normal surveys exclude intentional vent walls. Native cowl tracks have 137/137 supported samples each. The unchanged old side suite still rejects eight original-bonnet/bounds/pixel-coordinate/silhouette preservation checks: the owner now requests a different front and bonnet, and packed vertices differ below 0.1 mm. Its 18 shoulder tangent/support checks and two outward-shading checks pass; maximum shoulder normal steps are 4.97 degrees full and 7.66 degrees reduced. The complete legacy rejection is retained, with no assertion relaxed.

**CRF04 — Rebuild and verify the receiving paths.** All 48 native allowlist files differ from task start; four unused legacy native resources remain unchanged. Final raw stock counts are 49,462 reduced / 82,452 full, below the existing 50k/85k limits. Production reduced fixed/editable stock is 44,702 triangles in both cases. Compared with task start's raw 48,572/82,332, the geometry cost is +890/+120 triangles. The reduced bonnet uses 40 mm interior spacing with its boundary, vent paths and analytic normals retained.

| Final verification | Result |
| --- | --- |
| Independent reference-form survey / task-start control | 30/0 / 30/12 |
| Native allocation / live panel contours | 17/0 / 172/0 |
| Fitted hood / all Super Rally modules | 316/0 / 1,436/0 |
| Physics and replay / wash / driving | 3,677/0 / 1,655/0 / 72/0 |
| Production parser | 576 scripts, 0 failures |
| Prepared opacity / actual Garage and race App | 30/0 / 13/0 per desktop renderer |
| Prepared native views | 22 reduced + 6 full close-ups per renderer |
| Complete prepared preflight | 551 resources, 2,267 checks, 0 failures |
| Challenger scoped prepared preflight | 84 resources, 349 checks, 0 failures |
| Native catalogue / imports / workshop | 173 source hashes / 58 imports / 28 source hashes |
| Final consumed-input fence | 26,119 unchanged inputs |

Both desktop renderers use actual prepared cache hits. The final Mobile App passes its 13 assertions but retains a two-object/one-resource shutdown diagnostic; no clean-shutdown fix is claimed. No phone, FPS, pixel-identity, exact single-photo reconstruction, AAA finish or whole-project acceptance claim is made. Fine source faceting at fittings and some original edge joins remains.

Intermediate inherited-outline support failures, centre-crossing symmetry failures, stale prepared module/physics rejections, the retained inward-return survey, and a capture rejected during generated version stamping explain the discarded attempts. Final conversion inputs, native publication, source checkpoint, identity keys, current imports and preview provenance are checked again in `final-state.json`. Final native consumers were actually rebuilt; no asset metadata-only restamp substitutes for generation.

The [four-source incremental checkpoint](evidence/challenger-reference-form-2026-11-15/source-only.patch) applies and reverses byte-exactly in a disposable private repository. Concurrent model/UI/index work is preserved. Other car model sources and physical configurations were not authored. No owner save/process, device, export, backend, deployment or main-index staging action was performed. Standard build retention is recorded separately, with no task pin. Restart the game/project to discard cached in-memory model resources before appearance review.

Completed commands and exact arguments are retained beside the report. The final ordered invocation is:

```text
python docs/evidence/challenger-reference-form-2026-11-15/run_preparation.py
python docs/evidence/challenger-reference-form-2026-11-15/final_pass.py
python docs/evidence/challenger-reference-form-2026-11-15/checkpoint.py
python docs/evidence/challenger-reference-form-2026-11-15/retain_final.py
python docs/evidence/challenger-reference-form-2026-11-15/run_retention.py
```

The prescribed retention pass completed without a task pin. Build usage remained 33.13 GiB because recent/protected outputs were retained; no direct deletion bypass was used.
