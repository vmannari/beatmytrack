# Compact custom-kit review — 2026-10-25

The current compact catalogue has 43 independently selectable choices: 10 hoods, 13 rear-aero options, 10 rims and 10 body packages, including Original in each category. This review identifies three P2 visual-construction defects. No production model, material, thumbnail, physics, configuration, camera or existing assertion is changed.

Open the [native review gallery](evidence/compact-kit-review-2026-10-25/review.html). Every choice has current front, rear and detail views in Compatibility and desktop Mobile: 139 images per renderer. Twelve additional diagnostic views per renderer show the findings and detailed/simplified combined assemblies. Desktop Mobile means Windows Vulkan, not a physical-device test.

1. **CKR01 — Roof lip has no fitted attachment to the roof.** Its entire prepared surface is offset above the roof/hatch, with no supporting root, mounting pads or gasket. At sampled mesh vertices, the smallest vertical separation from the highest stock surface at the same X/Z is **0.01857 detailed / 0.01979 simple model metres**. The low side view visibly shows background under the lip. Source: [compact_kits.gd:186](../game/vehicle/compact_kits.gd#L186), especially the fixed vertical offset at line 191. Evidence: [Compatibility side](evidence/compact-kit-review-2026-10-25/diagnostic-gl_compatibility/roof-lip-side.png), [Mobile side](evidence/compact-kit-review-2026-10-25/diagnostic-mobile/roof-lip-side.png). Fit a continuous underside/root or explicit mounts to the actual roof, retaining the selected silhouette and saved `lip` ID.

2. **CKR02 — Six body packages have detached arch extensions.** Rally, Club sport, Heritage, Wide arch, Endurance and Gravel add closed flare shells but keep even their hidden returns outside the original rolled arches/panels. The generator forces a minimum outward offset; the decorative fasteners do not provide a connection to the original sheet. Native oblique close-ups show the resulting exposed edge/gap. Actual positive-side prepared vertices above Y=0.385 have a smallest sampled lateral clearance of **0.00949 detailed / 0.00995 simple model metres** across the six packages and both axles. Source: [compact_body_kits.gd:58](../game/vehicle/compact_body_kits.gd#L58), [outward clamp:64](../game/vehicle/compact_body_kits.gd#L64). Evidence: [Wide arch close-up](evidence/compact-kit-review-2026-10-25/diagnostic-gl_compatibility/wide-arch.png), [Mobile close-up](evidence/compact-kit-review-2026-10-25/diagnostic-mobile/wide-arch.png), [Rally](evidence/compact-kit-review-2026-10-25/diagnostic-gl_compatibility/rally-arch.png). Add an inward mounting return or fitted gasket while preserving original tyre clearance. The existing outer-face clearance requirement should remain; a mounting return needs its own attachment check instead of requiring every hidden vertex to remain outside the stock panel.

3. **CKR03 — Simplified dome inserts intersect the hood.** The Power dome and Vented dome accent patches have their own reduced tessellation and only a 1.2 mm analytical offset. Their actual triangles cross the independently triangulated hood. Downward rays at matching X/Z find **57/4,383** Power dome samples below the sheet, with a worst depth of **0.631 mm**, and **46/4,383** Vented dome samples, worst **0.852 mm**. The simplified combined native model has a visible blue break through the accent insert in both renderers. Detailed inserts remain above the sheet in all 4,385 sampled locations per hood; the initial apparent irregular detailed outline is not evidence of a detailed-model intersection. Source: [compact_hood_kits.gd:34](../game/vehicle/compact_hood_kits.gd#L34). Evidence: [detailed comparison](evidence/compact-kit-review-2026-10-25/diagnostic-gl_compatibility/full-combined-insert.png), [simple break](evidence/compact-kit-review-2026-10-25/diagnostic-gl_compatibility/simple-combined-insert.png), [Mobile simple](evidence/compact-kit-review-2026-10-25/diagnostic-mobile/simple-combined-insert.png). Share the actual supporting triangulation or derive the overlay from the final sheet surface.

The rims and larger wing assemblies have coherent silhouettes in the reviewed native views. This review did not identify an additional rim/window, tyre-envelope, plate-frame or glazing-clearance defect. That observation is limited to the captured views and existing checks; it does not establish universal intersection freedom or owner acceptance of every design.

The new diagnostic [review_compact_kits.gd](../game/tests/review_compact_kits.gd) reads the existing prepared resources. Insert heights come from actual triangle ray intersections. Arch measurements identify original surfaces by immutable mesh identity, then compare both ray directions to the outermost original side at matching Y/Z. They cover the positive side; the source mirrors the construction, but no independent negative-side numerical audit is claimed. Some rear samples near the opening have no stock ray hit and are reported separately. Lip measurements include all original body-mounted meshes near the roof. These are sampled vertical/lateral distances in unscaled model coordinates, not continuous minimum Euclidean distances or physical-car dimensions. Both renderer measurement JSON files agree exactly. No part is hidden for the screenshots, and diagnostic cameras do not modify production camera sources.

Actual retained checks on the current sources:

| Check | Result |
|---|---|
| Prepared fabricated construction | 1,354 checks, 0 failures |
| Geometry, normals, boundaries, articulation, wash and roll (`--parts-only`) | 5,223 checks, 0 failures |
| Complete catalogue, source/prepared equivalence and combination budgets | 1,543 checks, 0 failures; 1,260 prepared meshes |
| Rear aero fit/glazing/roll and retained editing | 836 checks, 0 failures |
| Independent part replacement, original wheels, paint and condition | 346 checks, 0 failures |
| Current parts-focus/preview/equip workflow, native Compatibility | 475 checks, 0 failures |
| Full project parser | 1,200 scripts, 0 failures |
| New diagnostic, Compatibility and desktop Mobile | Both execute successfully and save the three findings; process exit zero is not a clean-model acceptance result |

The current maximum visible assemblies have **166,016 detailed / 64,740 simple triangles**, retaining the 170,000 limit for all **13,000 combinations per detail level**. Source/prepared equivalence passes for every kit mesh. This review does not bake or refresh any shipping resource or photo.

The older `test_compact_kits.gd` remains red: **547 checks, 47 failures**. Forty-three selection checks and three Painting/Tuning transfers still require the camera to equal the pre-category transform; this conflicts with the accepted [parts-focus behavior](GARAGE_PARTS_FOCUS_2026_10_25.md), which the current 475-check suite covers. The remaining `actions fit (960, 540)` check measures the old `GarageActions` control while Parts explicitly hides it (`garage_page.gd:877–878`); the actual captured [960×540 Parts page](evidence/compact-kit-review-2026-10-25/workflow-gl_compatibility/tuning-960.png) has no visible bottom action row. Those failures are preserved, not removed or counted as passing. Updating those legacy expectations is separate work. Existing detailed/simple construction tests do not measure the three attachment/overlay defects above.

All engine commands use pinned Godot 4.7.2 through `scripts/dev.ps1`, with APPDATA/LOCALAPPDATA isolated under `build/compact-kit-review`. Exact commands, logs, hashes, measurements and dispositions are in [report.json](evidence/compact-kit-review-2026-10-25/report.json). Representative commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/compact-kit-review-2026-10-25/run.ps1 -Job construction
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/compact-kit-review-2026-10-25/run.ps1 -Job geometry
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/compact-kit-review-2026-10-25/run.ps1 -Job catalog
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/compact-kit-review-2026-10-25/run.ps1 -Job capture -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/compact-kit-review-2026-10-25/run.ps1 -Job diagnostic -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/compact-kit-review-2026-10-25/run.ps1 -Job focus
python docs/evidence/compact-kit-review-2026-10-25/review_tools.py
python docs/evidence/compact-kit-review-2026-10-25/finalize.py
```

The initial sandbox engine run could not read the Windows certificate store. Its first wrapper mistakenly recorded exit zero without retaining the child status; that run is invalid, and the wrapper is corrected. Successful native runs used approved certificate-store access. Two initial arch diagnostics accidentally selected only the named left stock surfaces because duplicate right-side node labels are renamed; their impossible roughly 1.77 m gaps are retained as invalid measurements. The final diagnostic selects both sides by resource identity. A first contact-sheet helper failed because Pillow is absent; the completed sheets use existing Windows System.Drawing without installing dependencies.

Q01 is review only; R01 retains existing assertions and records actual outcomes; G01 supplies a diagnostic/document-only isolated Git checkpoint and native evidence. Added files are this report, `game/tests/review_compact_kits.gd` and its UID, plus scoped runners/gallery/report helpers and evidence under `docs/evidence/compact-kit-review-2026-10-25`. The normal branch/index and concurrent work remain untouched by the checkpoint. Corrective model work is pending.

Final hash verification detected a concurrent change in `vehicle_simulation.gd`: the rear-drive launch-slip steering fade changed from `smoothstep(0.1,0.5,...)` to `smoothstep(0.1,0.35,...)`. The context snapshot and both hashes are retained separately in the report. All 1,536 pinned asset files and the other 33 source snapshots still match. The model findings are independent of that later propulsion edit; no physics-regression acceptance is claimed for it.

No device attachment check or device test, APK, purchase/authentication, live mutation, deployment or owner-process restart was performed. Owner/device appearance, motion, brightness and cost acceptance remain.
