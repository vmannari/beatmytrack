# Hovercraft and revised vehicle lineup

Latest model: [low sport redesign with twin fans](HOVERCRAFT_SPORT_REDESIGN_2026_10_29.md).

Latest model: [formed hull, curved cabin and detailed fan rebuild](HOVERCRAFT_MODEL_REBUILD_2026_10_28.md).

Latest handling: [UFO-inspired control with tighter recovery, hovercraft-4](HOVERCRAFT_UFO_FEEL_2026_10_28.md).

Current handling follow-up: [faster rotation and stronger thrust, hovercraft-2](HOVERCRAFT_POWER_TURN_2026_10_28.md). The figures below retain the original hovercraft-1 delivery evidence.

Owner request, 2026-10-28: add a hovercraft and remove the sports car and Formula.

## Requirements and implementation

- HOV01: the selectable roster is Compact, Hauler, Kart, Forklift, Volt and Hover. Rearsport (`classic`) and Formula are retired from selection. The parking hall's former sports car is replaced by the hovercraft.
- HOV02: `hovercraft-1` handling uses fan thrust, rudder yaw and retained world momentum. The air cushion ignores tire contamination and has low loose-ground resistance. Braking settles sideways motion; holding the brake at rest selects bounded reverse. No handbrake. Barriers, props, snow banks, jumps and bridge release remain canonical contacts. Shared physics stays `arcade-planar-0.75`; the new capability is omitted from other cars' snapshots.
- HOV03: original matte model with a segmented skirt, formed deck, glazed cabin, ducted rear fan, grilles, animated rotor and steering vanes. No wheels. Detailed geometry is 2,418 triangles; racing geometry is 1,626, with one 754-triangle shadow proxy. Livery, stickers, weathering, washing, night lights, native thumbnails and six original PCM fan loops use the existing presentation systems. Wheel marks, wheel particles and rolling/squeal audio are disabled for the hovercraft.
- HOV04: an append-only historical ID list preserves old livery/condition/appearance saves, version-one livery upgrades and achievement bits. Old selected cars fall back to Compact at startup. Historical records/resources are retained. Backend cosmetics, observations and achievement recognition include the new ID; the staged native verifier advertises the six playable vehicles.
- HOV05: three vehicle messages have authored copy in all twelve languages. Only the six retired catalogue messages were removed from translated catalogues. Source/English inventory was refreshed concurrently and preserved.

The model and sounds are authored locally; no external image, model, recording or generation service is used. Provenance is recorded in `licenses/ASSETS.md`, the vehicle-audio notice and `audio-provenance.json`.

## Changed files

Runtime sources: `game/vehicle/{vehicle_catalog,handling_config,vehicle_simulation,vehicle_models,hovercraft_model,car_visual,vehicle_audio,vehicle_audio_model,vehicle_livery,vehicle_condition,livery_catalog,vehicle_weathering}.gd`; `game/persistence/{local_records,achievement_progress,appearance_state,save_upgrades}.gd`; `game/ui/garage_car_cache.gd`; `game/core/game.gd`; `game/garage/parking_hall_data.gd`; and backend `vehicle_appearance.py`, `telemetry.py`, `achievements.py`. New handling resource: `game/resources/cars/hovercraft.tres`.

Both appearance schemas, four retained vehicle test fixtures, new hovercraft tests/replay/art helpers, `backend/tests/test_hovercraft.py`, `scripts/build_hovercraft_audio.py`, `scripts/translations/hovercraft.tsv`, twelve PO catalogues, native assets and provenance/status documents accompany the change. The evidence manifest enumerates files and hashes.

## Actual validation

All Godot commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, the pinned `4.7.2.stable.official.ed1daf0bf`, disposable workspace APPDATA and an empty `BMT_API_URL`.

| Command / check | Actual outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_hovercraft.gd` | 50 checks, zero failures before the final geometry consolidation; native final runs include all these checks |
| Same script, `-Graphical -RenderingMethod gl_compatibility -TestArgument --integration` | 60 checks, zero failures; Garage lineup, selection, save and ordinary race integration; captures in `gl_compatibility/` |
| Same script, `-Graphical -RenderingMethod mobile -TestArgument --integration` | 60 checks, zero failures on desktop Mobile/Vulkan; captures in `mobile/` |
| `res://tests/test_cars.gd` | 143 checks, zero failures; all six selectable vehicles complete five laps on each of three retained circuits and replay exactly |
| `res://tests/test_driving.gd` | 72 checks, zero failures |
| `res://tests/test_app.gd` | 141 checks, zero failures |
| `res://tests/test_records.gd` | 54 checks, zero failures |
| `res://tests/test_script_parse.gd` | 1,378 scripts, zero failures in the final run |
| Retained config/replay comparison | Five config hashes and 100 exact same-engine state checkpoints match task-start |
| `res://tests/generate_hovercraft_replay.gd` and independent staged native worker | Five laps, 20,403 elapsed ticks / 170,025 ms, zero contacts; normal trajectory acceptance and independent canonical simulation agree |
| `python -m pytest backend/tests/test_hovercraft.py backend/tests/test_electric_car.py backend/tests/test_rivalry_appearance.py -q -k 'not postgres' --tb=short` | 28 passed, 22 PostgreSQL cases deselected |
| Focused translations | All 36 values and placeholder checks pass |
| PCM audit | Six original mono 44.1 kHz/16-bit loops, two seconds each; peaks below -2 dBFS |
| Ruff on changed Python sources | Pass |

Measured straight-line cap is 129.999998 km/h. A 20 m/s, 60% steering, 50% power example has 17.8536 degrees of slide after 0.75 seconds. Braking from `(10,25)` m/s reaches the stopped band in 1.7667 seconds. These are fixture results, not owner feel acceptance or real-world hovercraft specifications.

Native baking commands: `res://tests/bake_garage_cars.gd`, `bake_hovercraft_art.gd`, `bake_livery_previews.gd --vehicle=hovercraft`, and `bake_news_car_photos.gd` with `--vehicle=hovercraft` and an evidence-root argument. Six prepared Garage scenes refresh their source guards against the current shared tree; the Electric scene includes concurrent owner work. There are 49 hovercraft livery photographs. Native Garage, lineup, gameplay and header pictures were inspected.

## Retained failures and initial findings

The broad rendering fixture reports two Forklift failures (five shadow casters / two front steering frames). The unchanged original fixture reproduces both with Forklift alone, 22 checks/two failures. The hovercraft alone passes all 22 model checks with its own fan/frame assertions.

The broad audio fixture reports 1,701 checks/two failures: the retained Electric reverse-pedal expectation and headless paused-loop playback. The original fixture with the prior roster reproduces both, with 1,948 checks/two failures. No production audio behavior or assertion is weakened to hide these failures. The graphical-only vehicle-batch capture was mistakenly invoked headlessly twice and reached its 300-second wrapper deadline while waiting for `frame_post_draw`; the wrappers retire only their owned processes.

An unfiltered initial backend run passes the same 28 tests but has 22 PostgreSQL setup timeouts at the configured local endpoint. No PostgreSQL execution is claimed. Full localization checking initially reports 770 issues; after adding the new copy/removing task-obsolete messages it reports 671 unrelated missing/untranslated/obsolete messages. No complete-catalogue pass is claimed.

Initial sandbox log/certificate-store errors, a concurrent generated-build constant mismatch, triangle-versus-quad deck construction, stale batched brake-light references, default compressed WAV import, a StringName fixture key, a missing staged class-cache import and a comma-joined bake argument were corrected and retained in the command logs. The final model authors the skirt and duct as combined surfaces to reduce cold construction work. No phone-performance or zero-hitch claim is made.

## Checkpoint and remaining acceptance

`docs/evidence/hovercraft-2026-10-28/report.json` records final outcomes, limitations, assets and hashes. `task.patch` is a source-only review checkpoint; regenerated binary assets are listed separately. Concurrent Garage/cache, Electric coachwork/brake, login, editor, backend and generated build-identity work is preserved and excluded from task ownership. One concurrent `maximum_deceleration()` edit is explicitly excluded from the patch.

Reload/rebuild the client for the new lineup. A matching authorized API/worker deployment and current track-contract publication are required for live online hovercraft racing. That rollout was not performed. Old production tickets/history were not rewritten.

Physical-device attachment was not queried; no device test, Android export/install, purchase/authentication, owner-save change, live backend write/deployment, owner-process restart, Git staging/commit/merge or destructive reset was performed. Owner appearance, sound/handling feel and mobile cost acceptance remain.
