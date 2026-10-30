# Rebuilt hovercraft model — 2026-10-28

The owner rejects the starter model and requests a substantial quality upgrade.
Original formed surfaces replace its flat cabin, slab fittings and faceted fan.
AAA is the ambition; desktop checks do not certify AAA quality or phone performance.

## Requirements delivered

- **HMR01:** crowned composite deck, rolled shoulder, continuous curved cabin,
  arched two-tone canopy and fitted roof/bow hatches. Cabin panels share their
  boundaries and their actual normals meet smoothly at the roof.
- **HMR02:** inflated bag, 52 shaped skirt fingers, binding seams and underside;
  restrained painted composite, rubber, brushed fittings and opaque analytic glass.
- **HMR03:** rolled open duct, six swept/twisted blades, shaped spinner, two safety
  cages, supports, cooling slots, steering airfoils, hinges and linkage. Rotor and
  rudders remain independently animated. Blade radius is below 540mm inside the
  553mm duct.
- **HMR04:** fitted lamps/matching night lenses, brake material, livery projection,
  graphics/weathering/ghost integration, 53 native pictures and a racing shadow.
- **HMR05:** simulation, handling configuration and `hovercraft-4` resource are
  byte-exact against task start. No camera, collision-scale, audio or canonical
  contract changes belong to this slice.
- **R01/Q01:** native views, exact baked arrays, prepared isolation and retained
  racing checks are recorded below. Owner/device appearance and cost acceptance remain.

## Native views and budgets

Matched 1280×720 model views use the same camera/studio setup:
[before](evidence/hovercraft-model-rebuild-2026-10-28/before-gl_compatibility/front.png),
[after](evidence/hovercraft-model-rebuild-2026-10-28/after-gl_compatibility/front.png),
[rear](evidence/hovercraft-model-rebuild-2026-10-28/after-gl_compatibility/rear.png),
[fan detail](evidence/hovercraft-model-rebuild-2026-10-28/after-gl_compatibility/fan-detail.png),
[skirt detail](evidence/hovercraft-model-rebuild-2026-10-28/after-gl_compatibility/skirt-detail.png).
Actual App:
[Garage](evidence/hovercraft-model-rebuild-2026-10-28/app-gl_compatibility/garage-1280.png),
[narrow Garage](evidence/hovercraft-model-rebuild-2026-10-28/app-gl_compatibility/garage-960.png),
[race](evidence/hovercraft-model-rebuild-2026-10-28/app-gl_compatibility/gameplay.png).
Corresponding `after-mobile`, `app-mobile` and `game/mobile` folders contain
desktop Vulkan Mobile views: 30 final native review views, seven original views,
and 53 refreshed shipping photographs in total.

| Geometry | Starter | Rebuild |
|---|---:|---:|
| Detailed triangles | 2,418 | 78,216 / 80,000 budget |
| Racing triangles | 1,626 | 24,968 / 30,000 budget |
| Racing shadow triangles | 754 | 838 |
| Batched visible meshes | 10 | 16 |

The racing model uses 68.1% fewer triangles than the new detailed model. Both
have finite vertices, unit normals and no indexed degenerate triangles. Geometry
cost increased substantially over the starter; there is no FPS/phone claim.

## Files and provenance

Runtime scope: `game/vehicle/hovercraft_model.gd`, new `hovercraft_surface.gd`,
the hovercraft headlight branch in `car_visual.gd`, and the hovercraft projection
entry in `livery_catalog.gd`. Shared finishes/shader sources are reused unchanged.

The new surface baker stores 350 immutable meshes in
`game/assets/vehicles/hovercraft_body_v2` (about 1.4MB compressed). Editor builds
reject source-mismatched bakes; instance finishes remain private. Every saved
vertex/normal/UV/index array round-trips exactly. Existing bakers refresh the
illustration/header, Garage thumbnail, 49 liveries, news photo and shadow.
Garage templates retain their conservative broad source guard.

New helpers: `bake_hovercraft_surfaces.gd`, `review_hovercraft_model.gd`,
`review_hovercraft_app.gd`, `review_hovercraft_prepared.gd` and
`inspect_hovercraft_template_context.gd`. The original UFO native driver only
gains an optional evidence-directory argument; default behavior/assertions remain.

Geometry and pictures are original project derivatives. Manufacturer photographs
informed general skirt/fan construction only:
[Christy enclosed hovercraft](https://christyhovercraft.com/hovercraft/christy-8199L/).
No source photograph, branded model, generated bitmap, external code or new
dependency ships. See the asset folder's `PROVENANCE.md` and `licenses/ASSETS.md`.

## Actual validation

Engine: pinned `4.7.2.stable.official.ed1daf0bf`, invoked through `scripts/dev.ps1`
with isolated `build/hovercraft-model-review` APPDATA and empty `BMT_API_URL`.
The Windows native test environment is approved; no owner profile is used.
Exact PowerShell batches and retained logs are under the evidence `commands/`
and `runs/` directories. Arguments below follow `-Action TestScript -ScriptPath
res://tests/`; graphical runs additionally select the named rendering method.

| Check | Observed result |
|---|---|
| `review_hovercraft_model.gd`, native Compatibility | 25 checks / 0 failures; seven views |
| Same, desktop Mobile | 25 / 0; seven views |
| `bake_hovercraft_surfaces.gd` | 350 exact resource round-trips |
| `review_hovercraft_app.gd`, both renderers | 10 / 0 each; actual selection, Garage sizes and ordinary race |
| `capture_hovercraft_ufo_drive.gd`, both renderers | 14 / 0 each; four actual Game phases and unchanged canonical state during presentation |
| `test_racing_car_models.gd --vehicle=hovercraft` | 22 / 0; articulation, lights, graphics, weathering, ghost and settings |
| `review_hovercraft_prepared.gd --hovercraft-only`, native | 4 / 0; original four per-car geometry/finish/isolation assertions |
| Same plus `--wrong-hover-glass` | 4 / 2, intentional wrong-tint rejection |
| Garage/art/livery/news bakers and import | Six initial templates, five later context refreshes, 53 photos, 838-triangle shadow; success |
| `test_script_parse.gd` | Blocked by unchanged historical `tests/fixtures/parking_hall_before/garage_page.gd:67`, missing `_build_wash_requirement()` |
| Preferred `-Action CheckScript` attempt | Blocked by concurrent Electric edit: undeclared `theta`, `electric_coachwork.gd:521` |

Raw prepared comparisons report 24/4 in headless and native runs: fresh
Compact/hovercraft uniforms can be unset `null`, while serialized equivalents
are explicit colour/`false` defaults. The review adapter keeps all original
per-car assertions, resolving only unset uniforms through declared renderer
defaults, as in the existing native shader preparation control. Deliberately
wrong glass fails both relevant assertions. Its first negative attempt assigned
a surface override below an existing material override and hit a native material
error; the corrected material override gives the intended two assertion failures.

Concurrent Electric and later Kart/shared CarVisual edits invalidate the broad
all-car guard during validation. All-car attempts retain 24/6 cache misses.
The focused native bake/adoption runs in one process and passes 4/0, leaving a
correct hovercraft template. The context audit records exact retained cached
Compact/Pickup/Kart/Forklift arrays, changed concurrent Electric geometry, and
unrelated stale guards. These compare cached resources, not concurrent live
builders or an immutable whole tree. No original failing assertion is removed.
The final actual App records have zero template hits: those views prove the
rebuilt live-construction path; prepared adoption is proved by the focused test.

Earlier candidates exceed the detailed limit at 102,848 and 86,056 triangles;
the final 80,000 budget stays. A close-up lip/deck overlap is removed by
shape-preserving interpolation. Initial execution-policy/nested-argument attempts
fail before dependent work; explicit batch files succeed. Limits remain recorded.

## Checkpoint and remaining acceptance

`report.json`, `assets.json`, `surfaces.json`, `template-context*.json` and native
records contain hashes/counts. `task.patch` is a Git reverse-checked source-only
checkpoint. It excludes concurrent Kart hunks in shared CarVisual, other authors'
sources, binary derivatives and generated identity. Before-text for exact owned
insertions is reconstructed only for this patch; owner files are not reverted.
Original task-start copies remain in `before/`. Asset hashes are dated snapshots,
including shared template context; they do not claim sole ownership of Electric.

Reload/rebuild to see the model. Owner appearance, glazing/style and motion
acceptance plus Android memory/frame/shadow cost remain. Glass is opaque and
analytic; a transparent cabin interior is not implemented. Desktop Mobile is
not a physical Android test. No physical-device query/test, APK, real auth/purchase,
owner-save/live backend mutation, deployment, owner-process restart or main-index
staging/commit/merge occurs. Concurrent work/identity are preserved and excluded.
