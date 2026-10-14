# Shipping container model and colour

Owner request, 2026-10-12. CT01: believable shipping-container construction. CT02: change paint per container. CT03: rust stains and an original side logo. CT04: matching palette previews, placement/copy/undo/save integration. CT05: strict cosmetic data and unchanged canonical collisions. CT06: actual captures, regression evidence and review checkpoint. Preserve G01/R01/V04-V06/Q01.

## Behaviour and construction

Select a placed container and tap its colour swatch in the bottom toolbar. For new placements, choose **Objects → Props → Container**, tap the selected Container card again, and tap the swatch in its options. The picker offers six starting colours and an arbitrary opaque RGB colour. Closing it commits one undoable change; dragging inside the picker does not repeatedly rebuild the track. Copying, local saving/reloading, redo and editor tool restoration retain the colour. The card preview uses the same paint and model as the placed container.

The original code-built model now uses recessed folded steel walls and roof, boxed rails/posts, corner castings with visible socket faces, recessed double doors, seals, hinges, four locking bars, handles and a decorative placard. Small irregular corrosion cores sit inside faded rust stains with roof-origin runoff. The fixed fictional **BMT CARGO** mark follows the actual corrugation and reads from outside either long wall. Light paint receives darker lettering. No real freight-company identity, external model, uploaded image, generated image or new runtime dependency is used.

At standard size the model has 8,548 triangles and one shared opaque mesh/material path. Unit meshes are cached by prop revision, theme and paint with the existing 96-entry cap. Thumbnails use the existing 48-image cache and include paint and prop revision in their keys. Prepared-world keys now also include the prop revision. This prevents stale container models/colours without changing the unrelated terrain-kit revision. These are structural budgets, not a physical-phone performance measurement.

## Contract and files

Creator documents remain `creator-track-v5`, with optional `color: "#RRGGBB"` allowed **only** on container objects. Alpha, names, short hex, malformed strings and nonstrings are rejected by the runtime validator, schema and staged verifier. Legacy containers without a colour remain valid and receive the new muted blue default; loading does not insert a field into those documents. Rust/logo remain part of the original model and cannot be replaced with user imagery.

Compiler advances `creator-compiler-26` → `creator-compiler-27` to pin the newly accepted cosmetic document property. Physics remains `arcade-planar-0.56`, rules remain `standing-5-road-gates-v20`, recorder remains schema 12 and ordinary races remain five laps. The 6 × 2.5 m solid footprint, rotated/scaled blocking raster and road/gate geometry are unchanged. The audit loads the exact preserved compiler-26 source and verifies all eight old fingerprints before comparing new prepared geometry. Updated golden identities were measured after that comparison; replay inputs/times and car configuration hashes were not edited. New starter hash: `4c025cf036849e2784b7e9175aae1980aae3bfb3c5c547f977fd0a4a76998dd0`.

Runtime files: `game/track/container_visual.gd`, `creator_prop_visual.gd`, `prop_equipment.gd`, two placed-object/cache lines in `native_track_visual.gd`; `game/editor/container_paint.gd`, `container_color_button.gd`, `track_document.gd`, `track_compiler.gd`, `editor_canvas.gd`, `object_browser.gd`, `object_thumbnail.gd`; colour integration in `game/core/app.gd`. New source UID files accompany the new scripts.

Contracts/tests: `docs/schemas/creator-track-v5.schema.json`, `backend/deploy/stage_verifier.py`, `backend/tests/test_verifier.py`, only the measured manifest in `backend/tests/fixtures/verified_oval.json`, `game/tests/test_container_refinement.gd`, `test_container_contract.gd`, `test_creator.gd`, `test_winter_compiler_contract.gd`, `fixtures/compiler_raster.json`, and two new checks in `scripts/dev.ps1`'s Validate sequence. The preserved compiler/raster inputs live in the evidence folder's `before/` directory. Documentation: this file, AGENTS/status/phase entries and evidence.

## Actual verification

Pinned `4.7.2.stable.official.ed1daf0bf`; Windows RTX 3090. Godot commands below use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`. Tests use isolated local editor records; no account/backend data was written.

| Actual action / arguments | Result |
| --- | --- |
| `-Action Import` | Passed; new script UIDs imported |
| `-Action TestScript -ScriptPath res://tests/test_container_refinement.gd` | 59 checks, 0 failures |
| Same test with `-Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3` | 72 checks, 0 failures; 10 captures |
| Same test with `-Graphical -RenderingMethod mobile -RenderingDriver vulkan` | 72 checks, 0 failures; 10 captures |
| `-Action TestScript -ScriptPath res://tests/test_container_contract.gd` | 23 checks, 0 failures |
| Contract test with `-TestArgument --refresh-container-golden` | 23 checks, 0 failures before writing the measured identities |
| `-Action TestCompilerRaster` | 8 checks, 0 failures, no golden rewrite |
| `-Action TestCreator` | 113 checks, 0 failures; historical three-lap diagnostic fixtures retained |
| `-Action TestObjects` | 71 checks, 0 failures |
| `-Action TestApp` | 99 checks, 0 failures |
| `-Action TestScript -ScriptPath res://tests/test_prop_refinement.gd` | 594 checks, 0 failures; container 8,548 triangles |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | 603 scripts, 0 failures |
| `.tools/backend-venv/Scripts/python.exe build/container_refinement/refresh_backend_fixture.py` | Actual compiler-27 manifests measured; only expected manifest replaced |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_verifier.py -q --junitxml=docs/evidence/container-refinement-2026-10-12/verifier-junit.xml` (rerun used `-x`) | 69 existing tests passed, including historical full replay and standalone staging |
| Same pytest with `-k container_paint --junitxml=docs/evidence/container-refinement-2026-10-12/container-verifier-junit.xml` | New server-colour test passed; 69 deselected |
| `.tools/review/Scripts/python.exe build/container_refinement/check_schema.py` | Whole schema valid; 10 valid/invalid object cases passed |
| `-Action Doctor` | Exact engine/templates found; DN2103 attached |

The first restricted-environment pytest run had 26 engine-error failures/43 passes. Normal local Godot access resolved them; the full rerun passed. The earlier rust prototype used hard cell edges, and the first palette capture caught a preparing track with the card offscreen. Final evidence uses blended stain colours, small chipped cores and an explicit prepared-track/visible-card check. Tests were not weakened to accept those captures.

Final evidence: [blue container](evidence/container-refinement-2026-10-12/mobile/container-426878.png), [red](evidence/container-refinement-2026-10-12/mobile/container-8b4134.png), [light paint](evidence/container-refinement-2026-10-12/mobile/container-b6b6a4.png), [opposite-side logo](evidence/container-refinement-2026-10-12/mobile/opposite-side.png), [door hardware](evidence/container-refinement-2026-10-12/mobile/doors-detail.png), [matching palette card/options](evidence/container-refinement-2026-10-12/mobile/container-palette-1280.png), [compact picker](evidence/container-refinement-2026-10-12/mobile/colour-picker-960.png). Both renderer folders also contain selected-container/picker captures at 1280 × 720 and 960 × 540. Actual logs and JUnit reports accompany them.

## Review and remaining acceptance

The reviewable two-commit checkpoint is `build/container_refinement/checkpoint-repo`, with a scoped patch, SHA-256 ledger and commit details in the evidence folder. It preserves the existing dirty shared workspace; the main branch/index are untouched and unrelated work is outside its patch.

No Android export/install or physical-phone container test was performed, although Doctor sees DN2103. Owner review of shape, wear, logo/card readability and on-device cost remains open; automated checks do not establish AAA acceptance. No production deployment or physics merge was performed. Online authoring/racing of coloured documents requires the matching compiler-27 verifier rollout; local staging tests passed, while deployment is separately authorised.
