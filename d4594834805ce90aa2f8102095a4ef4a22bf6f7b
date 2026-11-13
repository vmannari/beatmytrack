> **Corrected on 26 October 2026:** the layout-only roads described in this earlier record failed editor validation. All five tracks and Ville's saved copies have now been rebuilt with normal connected road parts and placed start lines. See [the correction and actual editor/Test drive results](STORM_ROAD_PARTS_2026_10_26.md). The record below is historical.

# Five original Storm circuits â€” 25 October 2026

ST01 creates five playable, editable Storm tracks. ST02 requires demanding layouts. ST03 requires objects to form believable places and serve the route. R01 preserves ordinary five-lap rules, canonical handling and the Ellipse tutorial. Q01 records actual checks, native views and remaining acceptance.

| Circuit | Length | Road width | Placed objects | Driving character and setting |
|---|---:|---:|---:|---|
| Thunder Freight | 472.7 m | 8.5â€“9.3 m | 39 | Fast loading lane, a tightening dock loop and offset esses. Parallel container rows, a gravel loading apron, freight fencing and an operations building. |
| Blackout Switchyard | 525.3 m | 8.0â€“8.8 m | 40 | Two reversals break up the perimeter run. Maintenance buildings share a fenced service yard, with aligned stores and a parking bay. |
| Rainbreak Ridge | 411.9 m | 8.0â€“8.8 m | 48 | Alternating wooded bends and a late braking hairpin. Pines follow woodland edges; cut logs, a shelter and worker parking occupy one forestry lay-by. |
| Slatewater Quarry | 554.1 m | 8.5â€“9.3 m | 40 | Fast outer sweep, compact rock-cut infield and a double apex. Cliff sections, stone and scree form one quarry face; equipment stays in the maintenance yard. |
| Eye of the Storm | 488.5 m | 7.8â€“8.6 m | 40 | Narrower technical esses and a tightening basin return. A guarded holding basin and an emergency maintenance compound define the site. |

Every object is explicitly authored. Automatic scenery is disabled. Guardrails follow selected outside corners, directional chevrons face approaching cars before tight bends, and standing water occupies only part of the road shoulder. The wet biome's existing grip supplies the surface challenge. No handling, camera, shader, reward or online authority changes belong to this task.

The evenly spaced authoring knots avoid interpolation overshoot between straights and curves. Geometry checks cover a continuous 7.3 m swept corridor, both usable road edges, largest-car spawn clearance, separate prop footprints and the Storm object kit. An object's purpose is recorded alongside its index in [design.json](evidence/storm-five-tracks-2026-10-25/design.json).

## Play and edit

The five prepared native files are registered beside Ellipse in `game/resources/builtin_tracks.json`. They are selectable by the local catalogue. For immediate direct local play:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Run -Track storm_freight
```

Use `storm_switchyard`, `storm_timber`, `storm_quarry` or `storm_floodgate` for the others. The five current-format creator files in `game/resources/storm_tracks/` can also be imported through Create. [Download the creator pack](evidence/storm-five-tracks-2026-10-25/storm-tracks.zip).

Online Free Race continues to use the server's published catalogue. These new tracks have **not** been published to that service. `publish-documents.json` is a prepared source array for a separately authorized official publication; it contains no invented race, score, player or published version.

## Actual validation

- Final all-car content run: **165 checks, zero failures**. All seven cars finish all five ordered laps on all five tracks: **175 completed laps**, zero collisions on the conservative diagnostic line. The Compact's complete five-lap input stream replays exactly on each track, including final state and lap times.
- Final additional geometry/prop audit: **50 checks, zero failures**. No usable-road intrusion or separate prop-footprint intersection remains.
- Local catalogue, exact prepared/source geometry and real save/import/selection checks: **33 headless / 34 Compatibility / 34 desktop Mobile checks, zero failures**. Native browser capture adds one screenshot assertion per renderer.
- Existing first-play tutorial: **168 checks, zero failures**. Existing editor/track retirement: **31 checks, zero failures**. Their exact catalogue-count assertions now name Ellipse plus the five requested original Storm circuits; retired-track absence and the Ellipse lesson assertions remain.
- Full native parser run: **1,204 scripts, zero failures** at that run. Concurrent work may change the repository-wide script count.
- Native map and unchanged production-camera views are saved for all five tracks in Compatibility and desktop Mobile. These are desktop renderers, not physical-device tests or performance certification.

The conservative driver's flying laps span roughly 45â€“67 seconds across cars and layouts. These are low-pace clearance diagnostics, **not** predicted human racing times or proof of subjective difficulty. Challenge and appearance still require owner driving review.

Actual commands used the pinned Godot build through `scripts/dev.ps1`. Relevant invocations:

```powershell
python scripts/build_storm_tracks.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_storm_tracks.gd -TestArgument '--compact-only' -CommandTimeoutSeconds 600
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_storm_tracks.gd -TestArgument @('--bake') -CommandTimeoutSeconds 1800"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_storm_tracks.gd -TestArgument @('--geometry-only','--bake')"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_storm_track_catalog.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_first_play_tutorial.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_editor_retirement.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_script_parse.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/capture_storm_tracks.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 600
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/capture_storm_tracks.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 600
```

Test processes redirected `APPDATA` to dedicated `build/storm-five-tracks-*-user` directories. The ordinary Windows certificate store was inaccessible inside the sandbox; final native runs used the approved local execution path outside it. No private configuration was read for this task.

## Retained corrections and evidence

The first gantry was aligned along the road; rotating it across the road removes the support obstruction. The first uneven knot spacing made two curves briefly backtrack and miss ordered gates; uniform knots correct the actual road. A basin rail added during refinement intruded into the inside road edge; its shorter, recessed final position clears the full corridor. The first contact-sheet composition had mismatched image formats, and the first import fixture used a resource path where an absolute operating-system path was required. Both diagnostic issues are corrected. Shared boards labelled ?100? were replaced with correctly oriented directional chevrons because these compact approaches do not provide 100 metres of braking distance. The complete seven-car run was repeated after that correction. No assertion or tolerance was relaxed.

Original failure reports, initial native maps, logs, final hashes and the task-only review patch are under [the evidence directory](evidence/storm-five-tracks-2026-10-25/). The final [Compatibility overview](evidence/storm-five-tracks-2026-10-25/gl_compatibility/contact-sheet.png) and [Mobile overview](evidence/storm-five-tracks-2026-10-25/mobile/contact-sheet.png) use this reading order: Freight, Switchyard, Ridge, Quarry, Eye of the Storm.

Reload is needed to see newly registered built-ins in an already running client. Owner driving/appearance review, physical-device motion/cost acceptance and any online publication remain. No device attachment check or device test, APK, purchase, deployment, live database mutation or owner-process restart was performed. Concurrent workspace work is preserved; the scoped patch does not stage or commit unrelated changes.
