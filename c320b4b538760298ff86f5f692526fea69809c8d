# Forklift kit design refinement

The owner rejected the previous kit designs. All 52 non-stock options have been reviewed and rebuilt around practical industrial construction. Fourteen choices remain in each category, with every saved item ID, ownership key and price retained. The complete backend catalogue is byte-identical to the task-start copy.

The [matched native before/after gallery](evidence/forklift-kit-refinement-2026-11-02/gallery.html) includes every option. Its photographs use the same camera and Garage lighting; the old geometry is reconstructed from the saved task-start builders in an isolated process. These are Godot renders, without image retouching. The designs use formed panels, believable joints and restrained finishes.

| Requirement | Review finding and resulting change |
| --- | --- |
| FKR01 | Review all four categories. The previous set had stacked lid ornaments, stick-like spokes, unsupported bars, segmented tubes and decorative roof structures. Earlier contact sheets and attempts remain in the evidence folder. |
| FKR02 | Full formed engine lids replace the factory lid. Recessed cooling pockets, fitted louvres, shallow crowns, hinges, a gasket and a flush latch replace piled-up blocks, exposed ribs and the ornamental fan. |
| FKR03 | Factory wheel centres are independently replaceable. New dished steel/cast faces have real apertures, small cast-edge bevels, rolled flanges, barrels and bolted hubs. They fit inside the tyre bead and within the factory stud projection; the raised overlay problem found in the first visual review is corrected. |
| FKR04 | Rear bumpers replace the factory part and connect through mounting shoes. Continuous bent cabin portals, fitted feet, supported lamps/mirrors/beacon, compact gussets and practical roof ribs replace fence-like bars, loose hoops and decorative racks. Clear operator sightlines replace rear cross ornaments. |
| FKR05 | Practical display names describe the actual designs. Original geometry, saved selections, independent preview/equip/reset, ownership, local reload, race and ghost construction are retained. Four base scenes, 104 full/simple module scenes and the forklift Garage template are regenerated. |

The shapes are original code-authored geometry. Manufacturer construction descriptions informed the design direction: [Toyota's stamped steel hood and bolt-on overhead guard](https://www.toyotaforklift.com/content/dam/tmh/marketing/en/pdf/product-spec-brochures/2024_Core%20IC%20Cushion_Spec%20Sheet_Digital.pdf), and [Linde's narrow roof struts and visibility emphasis](https://www.linde-mh.co.uk/en_uk/Landingpage/Diesel-forklifts/). No manufacturer branding, photographs or models are included in the game assets.

R01 validation uses pinned Godot `4.7.2.stable.official.ed1daf0bf`, isolated test saves and crash-dialog suppression:

| Check | Actual result |
| --- | --- |
| Every option, both qualities, distinct geometry and Original restoration | 741 checks, 0 failures |
| Exact original body **and wheel** comparison | 12 checks, 0 failures; zero unmatched geometry/UVs and zero normal difference |
| Closed volumes, consistent winding, exterior normals, finite vertices, fit envelopes and triangle budget for every custom assembly | 8,564 checks, 0 failures |
| Every prepared module versus its procedural source, both qualities | 1,580 checks, 0 failures |
| Compatibility Garage: 56 previews, equip, disk reload, appearance round-trip, ownership cancellation, reset, actual race and ghost | 187 checks, 0 failures; 56 captures |
| Desktop Mobile/Vulkan Garage, same workflow | 187 checks, 0 failures; 56 captures |
| Retained forklift model finish, fork/mast/chain/exhaust construction | 97 checks, 0 failures |
| Forklift backend catalogue, ownership and purchase/sync tests | 60 passed, 4 PostgreSQL cases deselected |

Original body comparisons match 127,864 detailed and 40,072 simple triangles. Original wheels match 17,648 and 10,672 respectively. The complete four-wheel kit peaks at 13,632 triangles, below the unchanged 14,000-triangle construction gate. This is a geometry budget, not a device frame-rate measurement.

The construction audit initially exposed 28 failures from panel boundary sampling, wheel seam precision and excessive detail. Matching clipped panels and boundaries to one 0.1 mm grid closed the seams; small hidden detail and angular sampling were reduced where they did not define the silhouette. The recessed-wheel iteration then exposed 68 failures from tiny aperture-tip slivers. Exact zero-width tips fixed them. The first small bevel iteration exposed 80 winding/normal failures at collapsed tip faces; normals now derive from a non-degenerate face. The final construction audit passes the same closure, normal, fit and triangle requirements. Initial logs and JSON certificates are retained; assertions and limits were not relaxed.

The first native review also caught excessively raised wheel faces and camera offsets expressed in world space. The wheel centres now replace the factory centres, allowing a seated fit. Final matched review cameras use the car's local axes. The first successful bake preceded the final wheel-edge refinement and was repeated afterwards; earlier bake logs are retained under `first-bake`.

Actual reproduction commands, from the repository root:

```powershell
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_forklift_refinement.ps1 -Stage geometry
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_forklift_refinement.ps1 -Stage quality
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_forklift_refinement.ps1 -Stage wheel-fit
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_forklift_refinement.ps1 -Stage edge-review
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_forklift_refinement.ps1 -Stage review
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_forklift_refinement.ps1 -Stage bake
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_forklift_refinement.ps1 -Stage gl
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_forklift_refinement.ps1 -Stage mobile
$env:PYTHONPATH='backend'
.tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_forklift_kits.py -k 'not postgres' -q --disable-warnings
python docs/evidence/forklift-kit-refinement-2026-11-02/make_gallery.py
python docs/evidence/forklift-kit-refinement-2026-11-02/finalize.py
python docs/evidence/forklift-kit-refinement-2026-11-02/checkpoint.py
```

Earlier attempts are recorded rather than represented as passes. An initial conditional typed-array assignment error was corrected before the completed geometry checks. The old and final model source hashes, per-assembly measurements, source/asset/image hashes and final outcomes are recorded in [report.json](evidence/forklift-kit-refinement-2026-11-02/report.json). Q01's [task-only binary patch](evidence/forklift-kit-refinement-2026-11-02/task.patch) is checked forward and reverse, with exact content comparisons in an owned temporary Git repository. [checkpoint.json](evidence/forklift-kit-refinement-2026-11-02/checkpoint.json) records the result. The baseline excludes concurrent documentation and unrelated vehicle-table changes; the main index is not written. The shared build identity is generated by `dev.ps1` and excluded from the patch.

Runtime changes are confined to `forklift_model.gd`, `forklift_kits.gd`, the new `forklift_kit_surface.gd`, and the forklift display-copy section of `vehicle_customisation.gd`. Supporting changes cover the catalogue authoring helper, option/Original-wheel tests, new construction/capture fixtures and isolated runner. Handling, collision contracts, item IDs, backend data and other vehicles' designs are unchanged by this task.

Owner appearance/touch acceptance and phone performance remain. New copy retains the existing English fallback. No device query/test, APK, owner-save change, owner-process restart, real purchase, live sync mutation or deployment was performed. Concurrent work is preserved.
