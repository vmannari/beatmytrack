# Garage car selection: performance and descriptions

<!-- GARAGE-STATS-SUBTLE-20261114 -->
## GCS05: quieter presentation after owner review

The owner asks for less visual emphasis. The current presentation removes the filled card, border, shadow and yellow display figures. Small inline label/value rows and a muted description sit directly over the workshop. A faint divider and text shadows retain readability. The standard layout is narrower and starts below the car-title line; the compact layout retains its complete description and existing input routing. Only `game/ui/garage_car_stats.gd` changes runtime behavior; figures, descriptions and selection logic remain as previously qualified.

Actual command: `python scripts/run_garage_car_stats.py gl_compatibility-subtle res://tests/test_garage_car_stats.gd --direct`. The existing actual-App suite passes **543 checks, zero failures**, including all six cars, four window sizes, eleven translated choices, saved-state preservation, immediate selection/cancellation and mouse/touch drag routing. The lower check count follows removal of three decorative/container nodes per layout, without changes to test assertions. This run exits zero with the previously observed two-object/one-resource shutdown diagnostic; no shutdown fix is claimed. No physical-device test or new Mobile-renderer qualification was performed.

Current views: [1280-pixel result](evidence/garage-car-stats-2026-11-14/gl_compatibility-subtle/super_rally-1280.png), [compact result](evidence/garage-car-stats-2026-11-14/gl_compatibility-subtle/super_rally-960.png). The earlier boxed view is retained as the comparison. The follow-up's scoped forward/reverse checkpoint is `evidence/garage-car-stats-2026-11-14/subtle-checkpoint.json`; the earlier checkpoint below describes the initial implementation. Build retention cleanup was run again. Owner appearance acceptance remains.
<!-- /GARAGE-STATS-SUBTLE-20261114 -->

GCS01–GCS04, 14 November 2026. Implemented the owner's marked left-hand information area with the existing Garage navy, Barlow fonts, yellow figures, fine borders and rounded cards.

The panel follows the browsed car immediately, including pending choices and cancellation. It shows configured top speed, clean unboosted 0–60 km/h acceleration, weight and a short driving description. All six cars exceed 60 km/h, allowing the same acceleration comparison for the 80 km/h Forklift. Compact windows retain both performance figures and the complete description, omit weight, and move the drag hint beside the panel. Mouse and touch drags pass through it. Workshop, washing and other sections hide it.

Acceleration is measured offline by the unchanged canonical 120 Hz simulation. The generated data records each complete handling snapshot's SHA-256; a mismatched tune shows an unavailable acceleration figure until rebaked. Top speed and weight come directly from the car's current configuration. Tests also compare the physics version and independently replay the crossing tick. Browsing does not construct a simulation or load race features to calculate figures.

| Car | Top speed | 0–60 km/h | Weight |
|---|---:|---:|---:|
| Rally | 166 km/h | 1.2 s | 1050 kg |
| Kart | 140 km/h | 0.8 s | 260 kg |
| Forklift | 80 km/h | 2.8 s | 2800 kg |
| Volt | 190 km/h | 0.9 s | 1680 kg |
| Hover | 130 km/h | 0.9 s | 560 kg |
| Super Rally | 198 km/h | 1.0 s | 1050 kg |

These are game handling figures. The acceleration measurement uses a clean straight road, full throttle and no countdown bonus; race conditions can differ. Cosmetic kits do not change these numbers.

Changed sources: `game/ui/garage_car_stats.gd`, generated `game/ui/garage_performance_data.gd`, narrow integration additions in `game/ui/garage_page.gd`, `game/tests/test_garage_car_stats.gd`, `game/tests/bake_garage_performance.gd`, `game/tests/probe_garage_stats_entry.gd`, `scripts/run_garage_car_stats.py`, `scripts/translations/garage_car_stats_2026_11_14.tsv`, seven entries in each of the twelve language catalogues and source template, and the linked status notes. Existing translations and concurrent Garage changes are retained.

Actual commands and outcomes (pinned Godot 4.7.2; disposable application storage, empty backend URL):

```powershell
# Initial checks used scripts/dev.ps1 through this runner.
python scripts/run_garage_car_stats.py headless
python scripts/run_garage_car_stats.py gl_compatibility
# Final follow-ups use the same pinned executable without restamping identity.
python scripts/run_garage_car_stats.py bake res://tests/bake_garage_performance.gd --direct
python scripts/run_garage_car_stats.py headless res://tests/test_garage_car_stats.gd --direct
python scripts/run_garage_car_stats.py gl_compatibility res://tests/test_garage_car_stats.gd --direct
python scripts/run_garage_car_stats.py selection res://tests/test_garage_selection_feedback.gd --direct
python scripts/run_garage_car_stats.py parser res://tests/check_model_refinement_parse.gd --direct
```

Final actual-App stats checks: **567/0 headless, 579/0 Compatibility**, covering all six cars, saved-state preservation, immediate/latest/cancelled choices, section visibility, real mouse/touch drag routing, 960×540 through 2560×1354 windows, and all eleven translated language choices. Existing selection regression: **20/0 headless**. Production parser: **573/0**. Targeted catalogue validation: **84/0**, seven messages across twelve languages, including placeholders and encoding. Native captures and machine-readable command receipts are in [evidence](evidence/garage-car-stats-2026-11-14/). These are desktop correctness checks, not phone latency or performance claims.

Visible results: [1280-pixel Super Rally](evidence/garage-car-stats-2026-11-14/gl_compatibility/super_rally-1280.png), [compact layout](evidence/garage-car-stats-2026-11-14/gl_compatibility/super_rally-960.png), and all six standard views in that directory.

Initial short layouts overlapped the drag hint (headless 331/2, native 343/2); moving the compact hint and correcting spacing resolved this. Longer French/Dutch compact descriptions then exposed four bounds failures (555/4), resolved by the wider compact panel and line spacing. Retained initial logs show these findings; no assertions were relaxed. Loading the complete authored translation table initially rejected the unrelated malformed first row in `track_editor_review_fixes.tsv`; only this task's seven messages were appended and validated, without rebuilding unrelated translations.

Desktop Mobile attempts did not finish Garage preparation. The separate actual-App control replaces the information panel with an empty component in process memory, without modifying production files; it also stops progressing after `GARAGE_STATS_CONTROL_SHOW_END`. That control was stopped after 76.578 seconds. The existing synchronous Mobile selection regression also stalled before results. Only verified task-owned processes were terminated. These attempts do not qualify Mobile App entry, identify its root cause, or establish a renderer regression caused by this panel. Raw receipts/logs are retained. The initial runtime-measurement approach was replaced with offline data so selection has no simulation construction cost.

The six-car offline bake writes the expected data and exits zero, but its standalone process retains a six-object/three-resource shutdown diagnostic; this is not reported as a clean shutdown. Final actual-App headless and Compatibility runs exit cleanly. Repeated bake output is byte-identical, and the independent actual-App crossing checks validate its figures.

No vehicle geometry, canonical simulation, handling resource, owner save, existing owner process, device, export or backend operation was changed by this task. Owner appearance review and physical-phone qualification remain. The source-only checkpoint and its forward/reverse verification are recorded in `evidence/garage-car-stats-2026-11-14/checkpoint.json`; generated identity changes from the initial dev runs and unrelated concurrent work are excluded. Main-index staging was not performed. Prescribed build retention cleanup was run at completion; recent/protected output can remain above the target.
