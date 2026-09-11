# CIRCUIT / 01 — Game specification package

**Version 2.0 · 11 September 2026 · Working title only**

This is the updated version of the original complete specification package, not a replacement concept poster. It incorporates the selected mature cel-shaded look, high-oblique overhead gameplay perspective and requested 15% tighter framing. The separate menu reference guides the general pages, not the gameplay camera.

## Start here

1. **`ui/UI_designs.pdf`** — 16-page visual guide: selected references, before/after camera calibration and all 11 updated interface views.
2. **`ui/UI_reference_gallery.html`** — original references and their exact intended use. Open after extracting the ZIP; keep its relative asset folders intact.
3. **`ui/UI_prototype.html`** — self-contained reference-based interaction prototype with embedded images. Navigation, earned gearbox installation, free tuning controls, friends distribution state, quota and simulated purchase flows remain available. It is not a playable game.
4. **`specs/Game_blueprint.pdf`** — 30-page master specification. Editable DOCX and maintainable Markdown editions are included.
5. **`technical/Rendering_and_camera.md`**, **`ui/Camera_contract.json`** and **`ui/Visual_acceptance.md`** — implementation and approval contracts for the new direction.
6. **`planning/`** and **`financials/`** — updated roadmap / requirements / backlog, original financial model, and explicit visual-scope cost reconciliation.

## What changed

The old light/teal interface screenshots and whole-circuit gameplay mockup have been replaced. The gameplay target is high, oblique and overhead, showing only part of a compact circuit: no horizon and no rear chase camera. The whole scene is magnified by exactly 1.15 in the framing mockup; the car mesh and road proportions are not altered. The live engine camera still requires calibration and phone approval.

The menu-only reference is included separately, so its material/typographic language cannot be confused with the rejected chase-camera row. The functional screens use dark charcoal surfaces, quieter typography, vehicle-led imagery and restrained highlights. Their layouts are reference-based proposals, not a claim that every new screen is user-approved.

The architecture now describes a 3D presentation and Camera3D rig above the canonical planar driving simulation. A P0-V art/performance slice is added to the roadmap, with reference-matching and physical-phone acceptance. The project label remains CIRCUIT / 01; no APEX or other new brand is introduced.

## Package contents

| Folder | Contents |
|---|---|
| `specs` | Master PDF / DOCX / Markdown; official source register |
| `ui` | Visual design PDF; 11-view HTML prototype; source gallery; selected original references; exact framing target; regenerated screen PNGs; art/camera/acceptance contracts |
| `technical` | Architecture; 3D rendering/camera handoff; API sketch; agent instructions; first task; retained schemas; 24 documentation/contract tests; framing reproduction script |
| `planning` | 51 requirements; updated backlog; 9 roadmap rows including P0-V; synchronized JSON; original economy tuning; launch/live-operation plan |
| `financials` | Original nine-sheet workbook, preserved byte-for-byte; new `Visual_scope_impact.md` |

## Financial interpretation and preservation

The workbook is unchanged from v1. Install/retention/conversion assumptions, monetization proposals and projected financial results have not been adjusted because the pictures improved. The existing no-paid-performance / free progression rules remain. No new premium currency, nitro product or paid tuning mechanic was introduced.

The provisional P0-V allowance is 2–4 additional productive person-weeks, not a complete estimate for all finished 3D cars and tracks. Read `financials/Visual_scope_impact.md` before interpreting the old workbook as the revised production budget. Actual art throughput, optimization effort and any outsourcing cash costs need measurement. Revenue scenarios remain assumptions, not forecasts.

## Source and prototype boundaries

The selected images are design references, not production-ready or automatically licensed vehicle/environment assets. The 1.15x PNG is a deterministic image-space framing mockup, not a newly rendered Godot scene. The source HUD was removed only from that derived mockup; the original reference is preserved unchanged. Menu art excerpts are low-resolution reference crops. Original/cleared assets are a release gate.

The HTML race is static; its controls illustrate placement. The editor places sample markers, not real road geometry. Purchase, publication, account and online interactions are simulations. Refresh resets the demo. No Android APK, shader, car mesh, production backend or actual purchase was created in this revision.

## Validation

Read `Validation_report.md` for the checks actually performed. PDFs and all UI views were rendered and inspected; prototype interactions were exercised in Chromium; all 24 supplied contract/documentation tests passed. The original financial workbook and canonical schemas were checked for byte-identical preservation. Physical phone handling, the 3D renderer, full replay determinism and real commerce remain untested roadmap gates.

Run the supplied tests from this folder in Python with `jsonschema` installed:

```sh
python -m unittest discover -s technical/tests -v
```

The camera mockup can be reproduced with Pillow:

```sh
python technical/tools/rebuild_camera_reference.py
```

## Scope of source checking

Rendering, Camera3D, spatial shading and the current Godot download information were checked against official documentation for this revision. The existing commercial/platform source register otherwise remains the v1 research baseline; this UI update is not a fresh legal, pricing or market review. Recheck applicable terms at implementation and release.
