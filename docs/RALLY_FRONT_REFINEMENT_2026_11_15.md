# Rally grille and lamp refinement (2026-11-15)

The owner asks to improve the grille and round lamps in the supplied frontal view while using fewer triangles. This is a targeted design refinement after the accepted gradual reduction; it does not simplify the other cars.

**RFL01 — Cleaner front hardware with less geometry.** Six satin horizontal slats remain over a real recessed opening, with a quieter 24-upright dark backing lattice and fewer radiator fins. The surround retains the original mouth and rounded corner envelope; smooth perimeter and bow-aware slat normals replace the coarse highlight steps. Closed rails and fittings retain real depth rather than a flat grille image.

Each headlamp now has a smoother 32-segment racing / 40-segment full circular profile, one rolled bezel and one opaque prismatic optic. The separate reflector bowl, centre bulb cover and overlapping optical-shade layers are removed. The original procedural sealed-beam finish fades subpixel prism detail; opaque coverage avoids the old transparent stack and its faceted central patch. No bitmap, external artwork, new light or runtime mesh simplifier is introduced. Existing night caps stay in front of the daytime optic and retain the shared road light.

| Geometry | Before | Refined | Reduction |
|---|---:|---:|---:|
| Racing grille | 1,254 | 886 | 29.35% |
| Racing lamps, both sides | 1,384 | 960 | 30.64% |
| **Racing grille + lamps** | **2,638** | **1,846** | **30.02%** |
| Full-quality grille + lamps | 4,726 | 2,086 | 55.86% |
| Entire stock racing Rally | 16,653 | 15,861 | 4.76% |
| Equipped racing sample | 24,450 | 23,658 | 3.24% |
| Entire full-quality Rally | 102,556 | 99,916 | 2.57% |

The new racing total is 16.85% below the restored pre-10k 19,074 baseline. This task follows the owner's specific front-design request, without another blanket percentage reduction.

**RFL02 — Preserve fit and the previous reductions.** Lamp centres, envelope radius and the grille's steel/fascia opening remain unchanged. The original clipping outline retains its default stations; fewer trim stations only affect the hardware. The existing whole-frame source and bounds guards are retained. Two new fixed/editable complete-body recipes copy every non-front row exactly from the task-start registry, excluding only the changed lamp/grille members. This prevents changed source keys from silently discarding the previous low-visibility savings elsewhere in the car. Every fitted Rally kit is exercised during migration. The new hardware carries the existing authored-profile marker so generic coarse/LOD reducers cannot deform its joins.

The other ten stock/full master controls (Kart, Forklift, Volt, Hover and Challenger) retain exact GPU streams, articulation transforms and shadow modes. The existing conservative `compact_*.gd` dependency rule also invalidates Challenger's cache when the Rally builders change. Its dependent assets are regenerated from unchanged sources and checked exact; there is no Challenger model authoring. The remaining seven car identity keys stay unchanged. No dependency rule or source-validation assertion is weakened.

**RFL03 — Native review and consumer validation.** Matched stock/fitted front, rear, sides, top, distance and close lamp/grille/oblique views use the actual prepared assets and real shadows in both desktop renderers. Night views verify that the existing illuminated caps remain visible over the opaque optics. The fixture asserts equal original/current model root transforms and exact baseline restoration for every pair. Actual Garage/race integration, fitted modules, icon capture/cancellation and material weathering/reset are checked separately.

The initial legacy grille fixture relied on an older full-quality default and synchronous construction. Its retained assertions are run with explicit full/simple models, current readiness waits, and the intended full-stock rest-cache pair. The initial missing-key and cache-hit findings are preserved. All original fit, winding, closed-part, real-air-gap, radiator closure, source/bake, weathering, night-centre and canonical-state assertions remain.

A review caught an error in the first detached comparison fixture: copying the children omitted the CarVisual root scale. Those comparison images are rejected and moved under disposable build output. Before correcting the root transform, all three saved snapshots were checked against the original task-start GPU/relative-transform signatures; deep resource copies then preserve those exact streams. The correction only changes the review fixture. A further assertion now prevents mismatched root transforms. The initial Mobile night exact-restoration failure is also retained; final qualified images use the corrected fixture.

A broad parser attempt caught an in-progress, unrelated Garage helper using a nonexistent PackedByteArray method. The concurrent author corrected it; a later current-source parser passes without task edits to that helper. Garage and index work remain outside this task's checkpoint.

**RFL04 — Reviewable source and refreshed consumers.** Authored production sources are `compact_front_lamps.gd`, `compact_grille.gd`, the scoped original `car_detail_v1/compact_front_lens.gdshader` and two migrated recipe JSONs. The old headlamp shader remains unchanged for historical source compatibility. Prepared bases/kits/Garage/header resources and scoped pictures are derived from current sources, with complete source/key fences. The private source checkpoint excludes these derived outputs, which require rebuilding on reversal. It does not stage the shared main index.

[Before/after front and close views](evidence/rally-front-2026-11-15/front-comparison.png) show the final prepared Compatibility models at matched transforms. [Night optics](evidence/rally-front-2026-11-15/prepared-gl_compatibility-night/compact-stock-lamp-close-after.png) retain the existing illuminated caps. Fine baseline fascia corner patches remain outside this hardware refinement; no flawless-surface claim is made.

Stock racing mesh buffers fall from 618,594 to 574,798 bytes (**7.08%**) and surfaces from 52 to 50. The full master falls from 3,247,474 to 3,133,702 bytes (3.50%); fitted racing drops 43,796 bytes and two surfaces. Matched front studio viewport primitives fall 20,695 to 19,903, and distant primitives 20,543 to 19,751 in each renderer. Stock front draws fall 64 to 62 in Compatibility and 58 to 56 in Mobile. These are desktop counter samples including studio/shadow work. The existing 176px icon LOD selection draws **46 more Rally primitives** (19,098 to 19,144, +0.24%) for the smoother authored profiles, despite the smaller master and fewer surfaces; no universal per-view saving is claimed. [Measurements](evidence/rally-front-2026-11-15/measurements.json) retain every paired counter.

| Validation | Actual outcome |
|---|---:|
| Source counts and exact retained recipe rows | 6 / 0 |
| Prepared counts/hits and ten unaffected master controls | 30 / 0 |
| Retained grille/fit/winding/closure/weathering/night assertions | 270 / 0 |
| Rally fitted modules | 1,441 / 0 |
| Shared Challenger consumer modules, no model authoring | 1,436 / 0 |
| Corrected snapshot GPU/transform controls; glazing uniforms | 6 / 0 + 6 / 0 |
| Native daylight, 24 pairs per renderer | 101 / 0 each |
| Native illuminated optics, 8 pairs per renderer | 37 / 0 each |
| Actual Rally Garage/race App, complete canonical tune | 8 / 0 each renderer |
| Five-car icon appearance/capture/cancellation/disk reuse | 496 / 0 each renderer |
| Driving regression | 72 / 0 |
| Current production parser | 577 scripts / 0 failures |
| Full prepared preflight | 551 resources, 2,267 checks / 0 failures |
| Catalogue and imports | 6 pictures / 174 current source hashes; 3 verified native imports, 0 editor diagnostics |
| Final consumed-input fence | 18,698 stable inputs; seven other car keys unchanged |

Actual command entry points (per-command receipts record pinned-engine arguments and isolated paths):

```powershell
python scripts/start_rally_front.py
python scripts/run_rally_front.py baseline res://tests/survey_rally_front.gd --headless
python scripts/run_rally_front.py recipe-migration-final res://tests/stage_rally_front.gd --headless
python scripts/run_rally_front.py source-models res://tests/test_rally_front.gd --headless
python scripts/run_rally_front.py grille-smooth res://tests/test_rally_front_legacy.gd --headless
python scripts/refresh_rally_front.py
python scripts/run_rally_front.py prepared-models res://tests/test_rally_front.gd --headless -- --prepared
python scripts/run_rally_front.py snapshot-fixture-repair res://tests/repair_rally_front_snapshots.gd --headless
python scripts/run_rally_front.py snapshot-uniforms res://tests/check_rally_front_snapshots.gd --headless
python scripts/qualify_rally_front.py
python scripts/artwork_rally_front.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/compare_rally_front.ps1
python scripts/measure_rally_front.py
python scripts/record_rally_front.py
python scripts/close_rally_front.py
python scripts/checkpoint_rally_front.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

[Recipe migration](evidence/rally-front-2026-11-15/recipe-migration.json), [publication](evidence/rally-front-2026-11-15/publication.json), [closure](evidence/rally-front-2026-11-15/closure.json), [source checkpoint](evidence/rally-front-2026-11-15/source-checkpoint.json) and [binary review patch](evidence/rally-front-2026-11-15/source.patch) record exact scope and reversal. Derived scenes/pictures must be rebuilt if reversed. Rejected draft maps/captures stay under build retention; concise fixture rejection and repair receipts remain permanent evidence. Standard cleanup output is retained in `build-retention.log`.

Device testing was not performed; desktop primitives and mesh buffers do not establish FPS or GPU-time savings. Reload and owner appearance review remain. No export, backend request, deployment or owner-save/process action is included.
