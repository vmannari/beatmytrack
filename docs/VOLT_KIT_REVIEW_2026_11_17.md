# Volt kit review and surface repairs

VKR01 reviews all fifteen optional hoods, rear aero parts, rims and body kits, plus Original in each category. VKR02 repairs the visible faults. VKR03 verifies the receiving modules, Garage workflow and rebuilt pictures.

The native review covers both full and racing models on Compatibility and desktop Mobile. Each renderer has 352 final images showing every option, with hood close-ups, both front-wheel sides, complete cars and rear body-kit views. Compatibility also has 256 matched task-start images. The sixteen Original control PNGs remain byte-exact after the repairs. [Original image comparison](evidence/volt-kit-review-2026-11-17/stock-picture-comparison.json).

| Category | Final native gallery |
|---|---|
| Hoods | [Full](evidence/volt-kit-review-2026-11-17/after-gl_compatibility-hood-full.jpg) and [racing](evidence/volt-kit-review-2026-11-17/after-gl_compatibility-hood-simple.jpg) |
| Rear aero | [Full](evidence/volt-kit-review-2026-11-17/after-gl_compatibility-aero-full.jpg) and [racing](evidence/volt-kit-review-2026-11-17/after-gl_compatibility-aero-simple.jpg) |
| Rims | [Full](evidence/volt-kit-review-2026-11-17/after-gl_compatibility-rims-full.jpg) and [opposite side](evidence/volt-kit-review-2026-11-17/after-mobile-rims-simple-extra.jpg) |
| Body kits | [Front and side](evidence/volt-kit-review-2026-11-17/after-mobile-body-full.jpg) and [rear](evidence/volt-kit-review-2026-11-17/after-gl_compatibility-body-simple-extra.jpg) |

The carbon hood's original overlay cut through its metal backing. The old bonnet outline also broke into short fragments. The optional hoods now use the current factory panel outline, projected onto the rendered triangles. Their fitted strips retain their geometry at distance. A tapered carbon insert is clipped directly from the underlying triangle planes and offset by 0.8 mm. The same fitting method seats the body-kit sill inlays, front intake and rear valance, removing the paint and trim intersections.

Broader quintic crease transitions, a local gradient normal field and a 128 by 48 grid smooth the hood highlights. The racing versions retain that same hood grid. The full and racing hoods keep their individual relief designs and the established minus 20 to plus 30 mm envelope. Their 62 source-bank meshes are rebuilt and checked against freshly generated arrays. [Before carbon](evidence/volt-kit-review-2026-11-17/before-gl_compatibility/hood-volt_carbon-simple-detail.png), [repaired carbon](evidence/volt-kit-review-2026-11-17/after-gl_compatibility/hood-volt_carbon-simple-detail.png), [before creases](evidence/volt-kit-review-2026-11-17/before-gl_compatibility/hood-volt_blade-simple-detail.png) and [repaired creases](evidence/volt-kit-review-2026-11-17/after-gl_compatibility/hood-volt_blade-simple-detail.png).

The deck lip and ducktail have closed skins, backs and edge returns. Their preceding overlapping sheets are replaced by a single formed volume. Raised wings move 60 mm rearwards in the unscaled model and their support feet follow the actual deck mesh with an 8 mm seating allowance. The twin wing's supports reach its upper blade. The Aero disc moves ahead of the caliper and gains an outer return. [Before deck lip](evidence/volt-kit-review-2026-11-17/before-gl_compatibility/aero-volt_lip-full-detail.png) and [repaired deck lip](evidence/volt-kit-review-2026-11-17/after-gl_compatibility/aero-volt_lip-full-detail.png).

The first rear close-ups revealed five factory diffuser fences protruding through several painted bumper kits. Fifteen of thirty prepared body cases failed the independent coverage check, with the worst factory geometry extending about 15.05 mm past the new bumper. The revised rear profile covers the retained factory valance and fences, rolling the added depth into its closed upper return. Racing rear shells retain the full row count. Final checks require at least 2 mm of actual triangle coverage for the factory parts in every body kit and both qualities. [First rear review](evidence/volt-kit-review-2026-11-17/first-pass-body-gl_compatibility/body-volt_street-simple-extra.png) and [final rear](evidence/volt-kit-review-2026-11-17/after-gl_compatibility/body-volt_street-simple-extra.png).

A subsequent distance check found that the 768- and 384-triangle hood levels moved through the fitted carbon insert. The worst sampled intersection was 7.802 mm. The hood metal and the four body surfaces beneath fitted decoration now retain their master geometry alongside the trim at every distance. The revised bank retains all 62 preceding geometry-array hashes. A separate prepared-resource check requires protected metal backing and forbids distance replacements on those protected parts. [Measured distance intersections](evidence/volt-kit-review-2026-11-17/inspect-lod-fit.log), [array equality](evidence/volt-kit-review-2026-11-17/distance-lock-array-proof.json) and [distance policy](evidence/volt-kit-review-2026-11-17/distance-policy.json).

The three runtime sources are `electric_kits.gd`, `electric_body_kits.gd` and `electric_reference_mesh.gd`. The source publication includes those files, the hood-bank manifest and its 62 native meshes. All source bindings and task-start hashes are retained. [Publication](evidence/volt-kit-review-2026-11-17/publication.json).

The higher hood resolution and protected backing surfaces add geometry to equipped cars, including distant views. The measured maximum combinations have 154,009 full-model and 43,402 racing triangles, within the established 170,000-triangle ceiling. The count receipt lists each category and the actual combined assembly used to verify the additive maximum. Full and racing Original masters have 114,644 and 19,037 visible triangles. [Per-option counts and maximum combinations](evidence/volt-kit-review-2026-11-17/kit-counts.json).

The complete option regression passes 610 checks. The mesh, surface-exposure, closed-lip, disc-clearance, twin-support and fresh-bank checks pass 247 checks. The task-start builders fail 65 of the original 122 geometric checks. The final complete prepared comparison passes 1,934 checks across all 120 modules, stock assemblies, live replacement, materials, normals, UVs and ghost geometry. The intermediate rear repair also passes its separate 624-check body comparison. Exact results and engine commands are recorded in the closure receipt. [Closure](evidence/volt-kit-review-2026-11-17/closure.json).

| Final check | Actual result |
|---|---|
| Hood bounds and paint binding | 250 checks, 0 failures |
| Source surfaces and rebuilt native bank | 247 checks, 0 failures |
| Factory rear trim coverage | 30 cases, 0 failures |
| Protected metal and distance geometry | 198 checks, 0 failures |
| Complete prepared module comparison | 1,934 checks, 0 failures |
| Prepared source admission | 125 resources, 511 checks, 0 failures |
| Garage preview, equip, reload, cancellation, race and ghost workflow | 54 checks per desktop renderer, 0 failures |
| Production parser | 583 scripts, 0 failures |

Representative actual commands follow.

```powershell
python scripts/run_volt_kit_review.py before-native res://tests/capture_volt_kit_review.gd --rendering-method gl_compatibility -- --phase=before
python scripts/run_volt_kit_review.py bank-final-grid res://tests/bake_volt_hood_meshes.gd --headless
python scripts/run_volt_kit_review.py source-kits-fixed res://tests/test_volt_kits.gd --headless
python scripts/run_volt_kit_review.py surfaces-final-rear res://tests/test_volt_kit_surfaces.gd --headless
python scripts/refresh_volt_kit_review.py
python scripts/run_volt_kit_review.py rear-coverage-final res://tests/test_volt_kit_rear_coverage.gd --headless
python scripts/run_volt_kit_review.py final-body-modules res://tests/test_volt_kit_review_modules.gd --headless
python scripts/run_volt_kit_review.py final-after-gl res://tests/capture_volt_kit_review.gd --rendering-method gl_compatibility -- --phase=after
python scripts/run_volt_kit_review.py final-after-mobile res://tests/capture_volt_kit_review.gd --rendering-method mobile -- --phase=after
```

Initial candidates and rejections remain in the evidence. They include a body-node lookup that needed Godot's normalized node names, an excessive contour exposure corrected by adaptive refinement, stepped racing highlights, and insufficient rear clearance on the coarse Touring shell. The final clearance assertion retains its 2 mm requirement. An intermediate texture import rejected a generated-version change, followed by a fresh successful import under the same project-equality assertion. First-pass native views and prepared results remain separately available.

The private Git checkpoint verifies exact forward and reverse source bytes while preserving the main index. Reversing it requires rebuilding derived models and pictures. [Source patch](evidence/volt-kit-review-2026-11-17/source.patch) and [checkpoint receipt](evidence/volt-kit-review-2026-11-17/source-checkpoint.json).

Client reload, owner appearance review and physical-device rendering and performance acceptance remain. Physical-device testing was not performed.
