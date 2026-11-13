# Rally body-kit underside cleanup — 2026-11-08

RBC01–RBC04 cover the owner's request to review Rally body kits and remove artefacts beneath the car. All nine optional kits and stock were reviewed in both standard and simple geometry, with low front, low rear and underside captures.

## Finding and correction

Club, Touring, Endurance and Urban had diffuser-fin face triangles reaching from the rear diffuser to model-space `(y,z)=(0,0)`. Club and Endurance also had front splitter fences reaching that same origin. The plate helper treated its translation origin as an interior point of every outline; these body-space outlines do not contain the origin. This produced long triangular sheets underneath the car.

`game/vehicle/compact_aero.gd` now triangulates the rounded outline with `Geometry2D.triangulate_polygon`. Side-wall normals follow polygon winding instead of a direction from the model origin. A new plate cache key excludes obsolete immutable meshes. The helper also supplies Rally spoiler endplates, so both body and aero modules were compared against their source constructors.

No changes to kit dimensions, splitter/diffuser outlines, mud flaps, body profiles, physics, paint or saved customisation were needed. The original plate resources remain available under their old cache keys; production constructors select the corrected keys.

## Changed files and generated assets

- Runtime: `game/vehicle/compact_aero.gd` only.
- Review/regression: `game/tests/review_rally_body_underside.gd`, `test_rally_plate_solids.gd`, `test_rally_kit_modules.gd`, `check_rally_prepared_assets.gd`.
- Reproducible plate bake: `game/tests/bake_rally_plate_cleanup.gd`.
- Private-profile runner: `scripts/run_rally_body_review.py`.
- Generated: 56 corrected low-level plate meshes and their manifest entries; 78 Rally kit modules, four Rally bases, Garage and header templates; four affected body-kit preview pictures in each desktop renderer.

Other ongoing appearance changes were already present in the workspace. They are preserved. The first bake crossed a concurrent Rally glazing/build-identity update and was rejected as a complete receipt. The subsequent four-stage bake records zero source changes in `bake-changed-sources.json`. Generated Rally bases necessarily include the current glazing, rather than an older snapshot of someone else's work.

## Actual validation

All commands use the pinned Godot 4.7.2 console executable through `scripts/run_no_crash_dialog.py`. The runner assigns private APPDATA/LOCALAPPDATA directories under `build/rally-body-review`, disables the backend URL, and saves commands/output under [the evidence directory](evidence/rally-body-cleanup-2026-11-08).

| Check | Outcome |
| --- | --- |
| Original direct plate builder, offset outlines | 24 checks / 4 failures: translated plates escape their outlines |
| Corrected direct plate builder | 24 / 0: bounded outlines, watertight edges, clockwise fronts/normals and closed volume |
| Source all-kit native Compatibility review | 152 / 0, 60 captures |
| Source all-kit native desktop Mobile review | 152 / 0, 60 captures |
| Confirmed prepared-module native Compatibility and desktop Mobile review | 78 / 0 each, 120 captures; all 18 non-stock quality/kit cases per renderer use prepared modules |
| Existing source attachment suite | 5,114 / 0 |
| Focused body/aero source-versus-module comparison | 546 / 0 |
| Final scoped complete Rally asset preflight after preview refresh | 84 resources, 342 / 0 |

Representative [before](evidence/rally-body-cleanup-2026-11-08/before/standard-club-under.png) and [after](evidence/rally-body-cleanup-2026-11-08/after-compatibility/standard-club-under.png) views show the long sheets removed while the rear fins remain.

Reproduce from the repository root:

```powershell
python scripts/run_rally_body_review.py solids-final res://tests/test_rally_plate_solids.gd --headless
python scripts/run_rally_body_review.py solids-control res://tests/test_rally_plate_solids.gd --headless -- --before
python scripts/run_rally_body_review.py after-compatibility res://tests/review_rally_body_underside.gd --rendering-method gl_compatibility -- --phase=after-compatibility
python scripts/run_rally_body_review.py after-mobile res://tests/review_rally_body_underside.gd --rendering-method mobile -- --phase=after-mobile
python scripts/run_rally_body_review.py prepared-confirmed res://tests/review_rally_body_underside.gd --rendering-method gl_compatibility -- --phase=prepared-confirmed --prepared
python scripts/run_rally_body_review.py plate-attachments res://tests/test_compact_kit_attachments.gd --headless -- --source
python scripts/run_rally_body_review.py module-geometry res://tests/test_rally_kit_modules.gd --headless
python scripts/run_rally_body_review.py scoped-preflight res://tests/check_rally_prepared_assets.gd --headless
```

The bake commands are retained verbatim in `bake-plates.log`, `ready-bake-*.log` and `body-photos-*.log`. They use the existing `bake_modular_car_bases.gd`, `bake_modular_car_kits.gd`, `bake_garage_cars.gd` and `bake_header_simple_compact.gd`, scoped to `--vehicle=compact`. Preview bakes use `--photos-only --category=body --ids=club,touring,endurance,urban`.

## Retained failures and limits

The existing broad modular suite finishes at 1,269 checks / 1 failure: its final invalid-fourth-module rollback fixture does not observe the expected three preceding attachments. All geometry/material/attribute and individual replacement comparisons pass; the assertion remains unchanged. No claim is made that the whole suite passes. The first run crossed the glazing update and retained 31 failures; the stable repeat removes those geometry mismatches.

The global prepared preflight was run during concurrent appearance work and retained 277 failures, including stale unrelated vehicle receipts. The scoped Rally preflight is the task's complete asset gate. Global catalogue-preview provenance/export is not qualified by this task.

Initial native fixtures did not enable every prerequisite for prepared restoration and correctly failed their hit assertions; `prepared-confirmed.log` verifies actual restoration after fixing that fixture. The first original-source control tried to load a second named global class directly and stalled; those owned test sessions were interrupted. The final original control compiles the archived source without its global class declaration and produces the expected four geometric failures. An initial solid test used counterclockwise normals instead of Godot's clockwise front-face convention; the corrected test and original control are both retained. An initial script path error and unavailable Pillow montage attempt are diagnostic setup findings, not passes. Windows certificate-store diagnostics recur in the offline runs; no other engine error was accepted.

No device query/test, APK, owner save/process change, backend operation, deployment or main-index operation was performed. Fresh owner-PC appearance acceptance and any later tablet build remain. The source-only patch and final hashes are retained beside the evidence for review without staging concurrent work.
