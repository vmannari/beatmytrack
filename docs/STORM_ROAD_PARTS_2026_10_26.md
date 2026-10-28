> The driving layouts and downloadable packs were revised again after the owner rejected their rhythm and difficulty. See [Storm driving variety](STORM_DRIVING_VARIETY_2026_10_26.md) for the current roads and Ville drafts. The measurements below describe the preceding validation repair.

# Storm tracks rebuilt with normal road parts — 26 October 2026

RP01-RP04/R01/Q01 correct the five Storm tracks and Ville's local drafts. The earlier implementation used layout-only roads. It compiled and drove, but did **not** meet the editor's connected-road/start-line requirements. The earlier checks missed that boundary. The complete original failure is retained: **30 checks, 25 failures**, including the actual Test drive route rejection and canonical import rejection for every track.

The roads now consist exclusively of ordinary **Straight** and **Curve** palette parts, forming one closed chain per track. Each has an explicit start line. Godot's unchanged `RoadPieces.route_from_pieces` generates every stored route; `layout` and `base_track` are empty. The editor, compiler and canonical validation rules are unchanged.

| Track | Normal parts | Route length | Objects |
|---|---:|---:|---:|
| Thunder Freight | 31 | 471.7 m | 39 |
| Blackout Switchyard | 31 | 523.8 m | 40 |
| Rainbreak Ridge | 29 | 411.1 m | 48 |
| Slatewater Quarry | 33 | 552.8 m | 40 |
| Eye of the Storm | 33 | 487.4 m | 40 |

All 207 objects, their positions, the working aprons and site identities remain. The fillet geometry is expressed with proper road sections and joined widths. Wet grip, tight bends, sustained cornering and actual braking demands remain; no car configuration, shared simulation, production camera or validation tolerance changed for this task.

## Actual checks

- Canonical/editor validation: **40 checks, zero failures**, including each original source and its Ville-authored draft. Actual `backend/runner.gd.compile_track` checks the connected road loop, placed start line and automatically generated route. No backend network service is used.
- Driving, geometry and retained content checks: **180 checks, zero failures**. All seven cars complete five ordered laps on every track: **175 laps**, zero diagnostic contacts. The Compact's five complete race inputs replay exactly. The loaded physics version and each vehicle configuration hash are recorded per run.
- Additional geometry-only audit: **65 checks, zero failures**. Full usable-road clearance, spawn clearance, separate prop footprints, biome kit and difficulty checks remain.
- Actual offline App workflow: **86 Compatibility / 86 desktop Mobile checks, zero failures**. Every saved draft appears once with a non-empty road preview; its real Edit track button opens normal selectable road parts with zero issues; editor Test drive is enabled; the actual Load track Test drive button starts the game in untimed practice and returns to Load track. Diagnostic AI remains ineligible for publication receipts. Native draft/editor/practice screenshots cover all five tracks in both renderers.
- Isolated Ville preparation: **46 checks, zero failures**. Exact owner copies preserve all other document fields and native geometry.
- Read-only verification of Ville's repaired PC library: **36 checks, zero failures**. All five saved originals match their expected repaired documents, have no publication binding and appear in the real draft scanner/browser. The Switchyard autosave exactly matches its saved original.
- Native parser: **1,233 scripts, zero failures** at that run. The repository-wide count may change with concurrent work.

The first new storage assertion compared widened JSON numbers directly against in-memory float32 route values and failed five times. Generation now recomputes from persisted part parameters, and the test compares exactly at the same persisted JSON boundary used by the editor. Canonical physical bounds remain unchanged. A verification fixture initially assumed a displayed draft must be the primary file; the existing valid WIP is now accepted only when its complete document exactly equals the saved original. These fixture failures and logs are retained.

## Ville's saved copies

The repaired data is installed in the same Ville PC profile established by the preceding draft-installation operation. Five saved JSON documents and the existing Switchyard WIP were replaced, with exact private backups. All **254 unrelated library files**, existing creation dates, session/account state and other drafts remain unchanged. No proof, test-complete flag, slot use or publication was created.

Open **Create → Load track**, reopening it if necessary, and search **storm**. The five drafts now show 29–33 road parts and route previews. Drafts remain local to this PC.

The private replacement plan, backup and hash manifest remain under `build/storm-road-parts-2026-10-26/`. [The public report](evidence/storm-road-parts-2026-10-26/report.json) contains only task-scoped results. [The repaired owner draft gallery](evidence/storm-road-parts-2026-10-26/ville-load-track.png) shows the actual local library without starting or altering the owner's running game.

## Regeneration and exports

```powershell
python scripts/build_storm_tracks.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/generate_storm_road_parts.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_storm_road_parts.gd
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_storm_tracks.gd -TestArgument @('--bake','--evidence-dir=res://../docs/evidence/storm-road-parts-2026-10-26') -CommandTimeoutSeconds 1800"
```

The Python author writes construction seeds under `build/`; only the native generator writes final creator sources after automatic route generation and road validation. Current sources live in `game/resources/storm_tracks/`; matching prepared built-ins live in `game/resources/tracks/`. [The corrected pack](evidence/storm-road-parts-2026-10-26/storm-tracks.zip) contains five current creator JSON documents and a guide. The prior download/publication-source links have also been refreshed; exact rejected archives and reports remain in this task's `before/` directory.

Other actual commands used `scripts/dev.ps1 TestScript` with `test_storm_editor_workflow.gd` in each renderer, `prepare_storm_ville_drafts.gd` with the new output directory and `--verify-live`, `test_script_parse.gd`, and `capture_storm_tracks.gd` with the new evidence directory. `python build/storm-road-parts-2026-10-26/replace_drafts.py` prepared the explicit repair plan; its `--apply` invocation performed only the authorized replacements. Native processes used isolated `APPDATA` directories. The final task-only patch is checked with `git apply --reverse --check`.

Owner/editor and physical-device appearance/feel/cost acceptance remain. The tracks are not published online. No device attachment check/test, APK, purchase, backend mutation, deployment, merge or owner-process restart was performed. Concurrent work is preserved.
