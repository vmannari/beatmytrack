# Storm circuit driving revision — 26 October 2026

The owner rejected the five valid Storm roads as too easy and monotonous while approving their surroundings. This revision replaces their corner programmes, keeps the existing site scenery, and updates the five unpublished Ville PC drafts.

The previous circuits mostly joined similar 7–19 m rounded corners with nearly uniform widths. The new roads contrast 6–44 m radii, 7.4–10.2 m widths, faster approaches, tighter exits and linked changes of direction. Thunder Freight and Rainbreak Ridge now include turns exceeding 128 degrees. Switchyard and Eye of the Storm have offset chicanes: their centreline excursions are approximately 12.7 m and 9.2 m, respectively. These require a direction change across a 7.4 m technical lane.

| Circuit | Driving character | Parts | Length |
|---|---|---:|---:|
| Thunder Freight | Loading straight braking, dock hairpin, faster linked northern bends | 33 | 587.2 m |
| Blackout Switchyard | Short acceleration zones, tight depot turns, offset chicane | 36 | 616.7 m |
| Rainbreak Ridge | Faster woodland sweeps, linked bends, late hairpin | 29 | 507.0 m |
| Slatewater Quarry | Tightening bowl, rock-cut switchback, broad double apex | 33 | 688.2 m |
| Eye of the Storm | Basin esses, narrow exits, outside-bank chicane | 40 | 625.4 m |

All **120 fixed site objects** retain their exact fields and positions, including the start stations, buildings, freight, woodland, rock piles and basin protection. Working aprons and explicit start lines are exact. Corner barriers, direction signs and shoulder puddles follow the revised roads; the complete collection contains 204 objects. The authoring catalogue is [scripts/storm_track_sites.json](../scripts/storm_track_sites.json).

Every road uses ordinary Straight and Curve palette parts, one closed connected chain, an explicit start line and the editor-generated automatic route. Layout/base-track fallbacks remain empty. Validation rules, handling, shared physics, controls and production cameras were not changed by this task.

## Verification

- Unchanged canonical import and editor route validation: **40/40**.
- Full-width geometry audit: **65/65**, retaining the 7.3 m swept corridor, usable shoulders, largest-car spawn and separate prop footprints.
- All seven cars, five ordered laps on each circuit: **180/180 checks**, **175 laps**, zero contacts and five exact full-race Compact replays.
- Faster Compact review: three complete laps per circuit, **15 laps with zero contacts**. Flying laps contain six to eight distinct braking zones; their measured speed ranges span approximately 57–166 km/h across the collection. Individual traces and the same-controller comparison against the previous roads are retained in [pace-review.json](evidence/storm-driving-variety-2026-10-26/pace-review.json) and [pace-before.json](evidence/storm-driving-variety-2026-10-26/pace-before.json). These are diagnostic laps, not human difficulty ratings.
- Actual offline App Load track → Edit track → Test drive → return: **91/91 Compatibility and 91/91 desktop Mobile**, including closure of the loading cover before practice screenshots.
- Isolated Ville save/reload preparation: **46/46**; final local library verification: **36/36**.
- Prepared native catalogue/source equality: **33/33**. Project parser: **1,259 scripts, zero failures** at that run.

Initial clearance checks caught two road-edge furniture conflicts. The furniture was fitted outside the full road width. The first pace review also exposed shallow chicanes and a basin turn that caused a near-stop; the chicanes gained proper offsets, the basin exit was opened, and curve shaping was reduced to keep transitions smooth. The superseded candidate results remain in the evidence. Temporary concurrent mesh-preparation and thumbnail-signature errors interrupted early App runs; the final runs use the corrected current sources without modifying those concurrent files. An earlier fixture captured the loading overlay despite a prepared Game; the stronger final fixture waits for its removal and checks it explicitly.

## Ville drafts and access

Open **Create → Load track**, reopen the browser to refresh it, and search **storm**. All five are saved as Ville drafts. Existing Storm autosaves are updated to the same revision so that they cannot shadow the saved roads. The missing Switchyard primary draft is restored; existing creation dates, other tracks and account/session data are preserved. Exact previous draft files and the guarded installation plan remain privately under `build/storm-driving-variety-2026-10-26/`.

[Download the five editable tracks](evidence/storm-driving-variety-2026-10-26/storm-tracks.zip) · [Native layout gallery](evidence/storm-driving-variety-2026-10-26/gl_compatibility/contact-sheet.png) · [Report](evidence/storm-driving-variety-2026-10-26/report.json)

The two earlier download locations also contain this revision; previous packs are retained in this revision's before archive. Historical validation and driving evidence remain identified as historical. Nothing was published online. Owner keyboard/controller driving and appearance acceptance remain; no device test, APK, backend mutation, deployment or owner-process restart was performed.

## Regeneration

```powershell
python scripts/build_storm_tracks.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/generate_storm_road_parts.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_storm_road_parts.gd
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_storm_tracks.gd -TestArgument @('--bake','--evidence-dir=res://../docs/evidence/storm-driving-variety-2026-10-26') -CommandTimeoutSeconds 1800"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/probe_storm_driving_rhythm.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/probe_storm_driving_rhythm.gd -TestArgument '--before'
```

Use `test_storm_editor_workflow.gd` with `-Graphical -RenderingMethod gl_compatibility` and `mobile` for the actual App workflow. `prepare_storm_ville_drafts.gd --output-dir=...` stages isolated files; `--verify-live` only reads the exact selected library in its private plan. The private installer requires exact source/test hashes, existing-draft hashes, preserved site scenery and successful native workflow checks before replacing only the requested files.
