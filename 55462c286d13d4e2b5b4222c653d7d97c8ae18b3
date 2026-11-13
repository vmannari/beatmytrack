# Car simplification feasibility — 2026-11-07

Yes. The best next step is to extend the existing conservative, screen-size-based
mesh detail preparation to race models and fitted parts. Keep the current car
designs, finishes and close-up geometry. The new inventory establishes a coverage
gap; it does not establish the appearance or speed of a new implementation.

| Requirement | Outcome |
| --- | --- |
| CSR01 | Inventory all five current cars: detailed/simpler, stock/one fitted combination, plus five stock Garage templates. 25 rows, zero invalid triangle-surface findings. |
| CSR02 | Review the existing native Garage appearance evidence and its rejected canopy experiment. Preserve glass and layered-Hover exclusions in any follow-up. |
| CSR03 | Identify a bounded next implementation and distinguish geometry opportunity from unmeasured loading/FPS and appearance acceptance. No production model changes. |

Current stored base triangle counts, obtained with pinned Godot
`4.7.2.stable.official.ed1daf0bf`:

| Stock car | Detailed race | Existing simpler race | Detailed fitted sample |
| --- | ---: | ---: | ---: |
| Rally | 101,660 | 39,756 | 137,418 |
| Kart | 87,200 | 30,340 | 86,706 |
| Forklift | 145,512 | 50,744 | 144,532 |
| Volt | 120,580 | 38,410 | 144,474 |
| Hover | 72,060 | 22,644 | 98,572 |

These are base mesh triangles, not triangles visibly drawn in a frame. The counts
exclude shadow-only proxies from the visible totals and do not multiply outlines,
shadows or reflections. The existing simpler option is a separate presentation
choice; its lower triangle counts are not evidence of unchanged appearance.

None of the 20 sampled race configurations contains mesh LOD index streams.
Four stock Garage templates contain them: Rally 37 surfaces, Kart 53, Forklift 39,
Volt 79. Hover intentionally has none. Fifteen sampled race configurations restore
a prepared base; fitted simpler cars use the existing procedural fallback. Each
fitted sample selects the last catalogue option in each of the four categories;
this is not an exhaustive customisation sweep.

The [existing Garage review](GARAGE_PERFORMANCE_2026_11_01.md) records 25.72–45.09%
lower main-view primitive counts in the complete Garage composition, which
includes room geometry. It does not establish the same percentage for an isolated
car or for racing. Its thirty native image pairs include close views; the maximum
mean RGB difference was 0.051605/255. The rejected layered-Hover trial produced
visible canopy speckles despite small whole-image errors. The accepted version
keeps the entire Hover model and all glazing at full detail. These are historical
results, not new appearance tests from this inventory.

The proposed implementation should:

1. Reuse the offline index-only LOD helper for eligible race bases and fitted
   modules. Start with the existing conservative 0.5-pixel viewport threshold and
   preserve original GPU vertex attributes and the full-detail index stream.
   Use denser geometry automatically in close views. Godot selects mesh detail
   using projected size and viewport resolution; see its
   [mesh LOD documentation](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html).
2. Retain the current glazing and whole-Hover exclusions initially. Review
   fitted-part boundaries, overlapping layers, paint patterns, stickers, dirt,
   snow, shadows and wheel articulation in native images before accepting changes.
3. Profile the highest-cost opaque assemblies first. The stock Forklift has
   individual opaque surfaces of 61,620 and 28,380 triangles; the Volt has opaque
   surfaces of 54,012 and 24,400. These are prioritisation clues, not proof that
   those surfaces can be reduced by a particular amount without a visible change.
4. Retain the existing material and transform-frame batching safeguards.
   `visual_geometry.gd` already indexes and combines compatible parts. Additional
   batching must preserve independent paint, brakes, wheel/fan motion and the
   existing GPU transform arithmetic. No new shader split or material atlas is
   justified by this geometry inventory.

Changed task files: the read-only diagnostic
[`game/tests/profile_car_simplification.gd`](../game/tests/profile_car_simplification.gd),
this report, and its [inventory/log evidence](evidence/car-simplification-review-2026-11-07/inventory.json).
The diagnostic reads models in an isolated profile and writes only its report.
The standard development entry point also refreshed the already-modified
generated build identity. Concurrent source and index changes were preserved.

Actual successful command, from the repository root, with `APPDATA` and
`LOCALAPPDATA` directed to `build/car-simplification-review-2026-11-07/profile-normal`
subdirectories and `BMT_API_URL` empty:

```powershell
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_car_simplification.gd -TestArgument '--output=res://../build/car-simplification-review-2026-11-07/inventory-normal.json' -CommandTimeoutSeconds 180
```

Result: exit 0, 25 completed inventory rows, zero invalid triangle-surface
findings. The initial sandbox launch encountered certificate-store/access-denied
errors and stalled without an inventory. Normal Windows access completed the
isolated diagnostic. The failed launch was identified by its exact script command
line and its task-owned process tree was terminated; its shell's eventual exit 0
is not treated as an inventory pass. An initial diagnostic iteration over the
customisation dictionary was corrected to use the four category IDs before the
successful run. Neither initial finding was a production-car change.

Initial checkpoint verification detected Git line-ending conversion. The isolated
checkpoint and forward-apply checkout use `core.autocrlf=false` for byte-exact
content verification; the failed intermediate checkout remains under `build`.

No new visible-model implementation, visual comparison, race/FPS/loading
benchmark, device query/test, APK, deployment, owner-save change, live backend
request or main-index write was performed. Native before/after checks across
race/close views, all fitted modules and both desktop renderers, followed by owner
and device appearance/frame-time review, remain prerequisites for accepting a
new simplification pass. See the scoped task patch and receipt beside the evidence.
