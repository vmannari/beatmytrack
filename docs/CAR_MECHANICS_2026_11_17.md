# Mechanical car optimisation — 17 November 2026

Appearance remains the priority. This pass reduces the four scoped racing masters by **423 triangles**, from 61,449 to 61,026 (-0.69%), and removes another **656 submitted triangles at distance** across Rally, Kart and Hover. These are geometry measurements, not an FPS claim. Challenger and Volt source authoring are outside this pass.

| Car | Racing before | Racing after | Near saving | Additional distance saving |
|---|---:|---:|---:|---:|
| Rally | 13,114 | 13,114 | 0 | 144 |
| Kart | 16,396 | 16,322 | 74 | 104 |
| Forklift | 17,794 | 17,445 | 349 | 0 |
| Hover | 14,145 | 14,145 | 0 | 408 |

## Requirements and resulting changes

**CME01 — Mechanical detail and unused storage.** Fifty Forklift chain pins become bounded five-sided closed pins, 20 to 16 triangles each (-200). Their native normals/tangents follow the offline affine fit; every vertex remains inside the original culling bounds. Certified bidirectional surface upper bound 1.982414 mm retains the original 2 mm gate. The other two chain pins stay unchanged. Another 149 Forklift and 74 Kart triangles are removed only inside certified closed opaque solids, with 0.5 mm burial and exact same-frame geometry/finish bindings. Missing fitted-kit witnesses skip the change. Every retained encoded corner remains exact. Of 66 screened source candidates, 38 source identities are used by the staged replacements; repeated kit restoration is not a count of unique visible parts.

Kart's moving driver remains 3,545 triangles with all 10 poses and the original helmet. Exact raw-record compaction removes 86 unused vertices: 2,153 to 2,067, saving 19,792 bytes from 516,870 to 497,078. The published native asset passes 22 exact ordered-corner/pose comparisons plus name, finish and bounds checks. No triangle or FPS saving is attributed to this storage change.

**CME02 — Wheel interiors.** Kart's inner bore uses 294 rather than 320 triangles per rim only at distance (-104 across four wheels). Outer lips, spokes, tyres and every close master byte are retained. One initial angular gap exceeded the unchanged 12 mm distant bound; that collapse was rejected. Extra vertices at the irregular station bring the certified bound to 8.582 mm, with one closed component, no boundaries/nonmanifold edges and the original Euler characteristic.

**CME03 — Hover stationary rings.** Eight duct-rim/guard rings use 2,010 to 1,602 triangles at distance (-408). Near masters, hull, skirt and fan blades are retained. Engine-generated candidates introduced nonmanifold edges and were rejected. Offline endpoint collapses preserve the original closed torus topology; measured upper bounds 4.128–6.401 mm use conservative distance thresholds at least four times those bounds. Only component indices change; all other batch triangles remain exact.

**CME04 — Rally fine grille.** The fine lattice keeps 192 near triangles and uses 48 original front-face triangles at distance (-144). Main louvers, surround, dark backing, closure repairs and preferred lamps remain exact. This keeps real near geometry and existing finishes without another texture, alpha layer or material draw.

**CME05 — Publication and review.** Seven compact native index-table resources bind to exact final batch digests. They apply during offline baking, survive batching/packing and preserve existing farther levels. Runtime does no new mesh generation or registry lookup. Same-threshold regional indices are excluded from previous-output reuse, so rebakes cannot silently retain an older candidate;9 reuse checks cover 7 prepared groups. The source publication contains 63 native files plus the offline LOD helper. [Exact paths and hashes](evidence/car-mechanics-2026-11-17/publication.json) and the checked source patch identify the scope.

## Actual validation

Current source 29/0 and prepared 32/0, native storage/bounds 61/0, all-kit Rally 1,441/0, Kart 1,156/0, Forklift 1,726/0 and Hover 1,288/0. Prepared preflight 343 resources/1,415 checks passes. Each desktop renderer passes 64 matched plain stock/fitted pairs 276/0,30 distance-control pairs 149/0, steering 170/0 and actual Garage/race App 40/0. Near distance controls are pixel exact. The renderer submits exactly 144/104/408 fewer primitives for Rally/Kart/Hover; draw calls remain equal. Production parser 583/0, full-project parser 2,343/0 at its earlier checkpoint, driving 72/0 and recipe guards 8/0 pass. Four catalogue/four header pictures, six derived global portraits and 14 imports are refreshed. Final current-source fence: **22,130 inputs, zero changes**, including the offline helper.

The additional distance tables cost 37,542 index bytes across the tested stock mesh instances (sharing can reduce allocation). The seven compressed source tables total 31,376 bytes. These costs are separate from the driver's 19,792-byte saving; no paired whole-prepared-memory or phone/FPS improvement is claimed.

## Review views

[Compatibility stock](evidence/car-mechanics-2026-11-17/gl_compatibility-stock-review.png), [Compatibility fitted](evidence/car-mechanics-2026-11-17/gl_compatibility-fitted-review.png), [Mobile stock](evidence/car-mechanics-2026-11-17/mobile-stock-review.png), [Mobile fitted](evidence/car-mechanics-2026-11-17/mobile-fitted-review.png). Full native PNGs and comparisons are in the matching `prepared-*` and `distance-*` evidence folders. Decorated runs are additional paint integration views; their plain baseline is not presented as an appearance-matched paint comparison.

## Commands and retained controls

Commands, renderer, elapsed time, exit status and diagnostics for every required run are embedded in [closure.json](evidence/car-mechanics-2026-11-17/closure.json). Main invocations:

```text
python scripts/run_car_mechanics.py <label> res://tests/<fixture>.gd <engine options>
build/tools/blender-4.5.15-windows-x64/blender.exe --background --factory-startup --python-exit-code 1 --python scripts/check_car_mechanics.py
build/tools/blender-4.5.15-windows-x64/blender.exe --background --factory-startup --python-exit-code 1 --python scripts/check_car_mechanics_rim.py
python scripts/publish_car_mechanics.py
python scripts/refresh_car_mechanics_assets.py
python scripts/qualify_car_mechanics.py
python scripts/artwork_car_mechanics.py
python scripts/import_car_mechanics_images.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/compare_car_mechanics.ps1
python scripts/close_car_mechanics.py
```

Initial fixture null indices/path/directory mistakes, rejected Hover topology, the oversized rim gap, the pin culling/affine controls and a missing regional-table metadata/reuse control remain recorded. The pin's first bound-fitted profile exceeded 2 mm and was rejected; the final profile retains the same gate. A parallel Mobile near reference/restoration rejection is retained before a clean isolated repeat with the original equality checks. An importer overlapped a generated-version write; the final importer ran separately and retained the exact project-settings check. No runtime restoration/determinism or teardown fix is claimed.

The first broader refresh encountered separate Volt kit authoring; Volt fitted checks and whole-tree readiness are unqualified here. The four-car source routing retains the explicit identity-script digest: an initial filter mistakenly dropped that unchanged input from only one side of the comparison, and was corrected symmetrically. Current source, identity and all-module gates remain strict. An unreferenced task pin prototype was moved into the task's retained build output, preserving its bytes.

## Remaining acceptance and checkpoint

Reload the client to consume the refreshed assets. Owner appearance review and physical-device performance/appearance acceptance remain. Physical-device testing was not performed. No export, backend/deployment action, owner-save/process change or root Git staging occurred. A task-only private Git checkpoint verifies forward/reverse bytes; reversing source requires rebaking derived consumers/pictures. Concurrent work and the shared index are preserved. Standard retention ran: 30.12 GiB remains recent/protected/locked, with no new task pin or deleted entries.
