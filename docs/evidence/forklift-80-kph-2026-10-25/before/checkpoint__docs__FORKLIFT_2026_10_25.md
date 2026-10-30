# Forklift â€” 2026-10-25

Current body/sticker correction: [solid side panels and one rear sticker](FORKLIFT_BODY_STICKER_2026_10_25.md).

Current clearance/speed/turning correction: [Forklift raised forks and 66.6 km/h](FORKLIFT_CLEARANCE_2026_10_25.md). The historical `forklift-1` values below are superseded by `forklift-2`.

FL01â€“FL04/R01/Q01 implement the owner's new Forklift with turning rear wheels and the follow-up request to match the Compact's model quality. Native review: [gallery](evidence/forklift-2026-10-25/report.html), [model](evidence/forklift-2026-10-25/gl_compatibility/model-front.png), [Garage](evidence/forklift-2026-10-25/gl_compatibility/garage-1280.png).

The fictional industrial truck uses the Compact's paint, alloy, rubber and tire shader. Original curved wheel openings, rounded counterweight, pressed-steel hubs, tapered forged forks, open mast channels, hydraulic rams, hoses, lift chains, mirrors, lamp housings, guard, seat cushions, instrument console, steering wheel and pedals replace the initial block model. The native Garage render, carousel thumbnail, 49 appearance photos and catalogue artwork use this same model. Detailed/racing meshes contain 144,656/48,800 triangles and 38 batched mesh instances. Desktop measurements are not Android performance acceptance.

Rear wheels turn opposite the requested nose turn, while front wheels remain fixed. Canonical lateral motion follows the fixed front axle, so the tail sweeps outward; reverse changes yaw direction normally. The rear-brake axle model uses the rear wheel angle. Steering presentation reads the saved canonical steering and speed, without changing simulation state or loading a configuration each frame. Forks are fixed decorative geometry; collision retains the established planar circle approximation.

The `forklift-1` profile uses a 1.72 m wheelbase, 1.38 m track and a 12 m/s (43.2 km/h) speed cap. These balance values remain provisional. Rear-steering configuration enters the rules hash; false/default optional capabilities remain absent from existing-car snapshots. Server manifest, race-ticket comparison and publication contracts now use that same snapshot. The current shared workspace physics version is `arcade-planar-0.67`, also containing concurrent Electric work. Existing track contracts require the matching normal rollout/revalidation path; this task does not rewrite live publications or deploy anything.

The existing selection, atomic save, free preview, explicit equip/purchase, account, cleanliness and Compact-only fitted-parts rules remain. Forklift appearance and car IDs are accepted by the native client and backend appearance/telemetry/achievement boundaries. The existing cleared heavy engine bank supplies a single-speed Forklift voice. Challenge filtering follows the catalogue.

Changed runtime files: `game/resources/cars/forklift.tres`; `game/vehicle/forklift_model.gd`, `vehicle_catalog.gd`, `handling_config.gd`, `vehicle_simulation.gd`, `rally_handbrake.gd`, `car_visual.gd`, `vehicle_models.gd`, `prepared_car_cache.gd`, `vehicle_livery.gd`, `livery_catalog.gd`, `vehicle_weathering.gd`, `vehicle_audio.gd`, `vehicle_audio_model.gd`; `game/track/contact_shading.gd`; `game/backend/runner.gd`, `cloud_tracks.gd`, `track_lifecycle.gd`, `product_telemetry.gd`; `game/ui/challenges_page.gd`; backend `vehicle_appearance.py`, `telemetry.py`, `achievements.py` and the appearance/product-event schemas. Native images, focused/updated regression tests, provenance and status documents accompany them. Shared files also contain parallel changes, which are preserved and not attributed to Forklift.

All engine commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` and pinned Godot `4.7.2.stable.official.ed1daf0bf`.

| Actual command/check | Result |
|---|---|
| `TestScript -ScriptPath res://tests/test_forklift.gd` | 98 checks, zero failures |
| Same with `-Graphical -RenderingMethod gl_compatibility` | 106 checks, zero failures |
| Same with `-Graphical -RenderingMethod mobile` | 106 checks, zero failures; desktop RTX 3090 |
| `TestCars -CommandTimeoutSeconds 600` | 143 checks, zero failures; all seven workspace cars, three five-lap fixtures, exact replay and zero contacts for Forklift |
| `TestScript -ScriptPath res://tests/test_appearance_sync.gd` | 56 checks, zero failures |
| `TestApp` | 141 checks, zero failures |
| `TestScript -ScriptPath res://tests/bake_livery_previews.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--vehicle=forklift'` | 49 detailed native captures, then imported |
| `TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | 1,948 checks; existing `pause suspends loop playback` fails headless |
| `TestScript -ScriptPath res://tests/test_forklift_audio_baseline.gd` | Same audio-pause failure with actual task-start audio loaded only in this process |
| Backend secure Python: `-m pytest tests/test_appearance_sync.py tests/test_rivalry_appearance.py tests/test_product_analytics.py tests/test_achievements.py -q -k 'not postgres' --tb=short` | 71 passed, 1 skipped, 42 deselected |
| Backend: `-m pytest tests/test_verifier.py -q -k real_engine_manifest_pins_every_competitive_config --tb=short` | 1 passed, 69 deselected; real pinned engine |
| Scoped Ruff, `git diff --check`, final `Import` | Pass |

The all-car run preceded the detailed-model follow-up. The final focused suite subsequently checked detailed/racing construction, exact preservation of every triangle by batching, fixed front/rear articulation, canonical geometry dimensions, Compact paint properties, correct large-front/small-rear tire weathering thresholds, actual projected mesh bounds in the thumbnail and both Garage sizes, appearance/weathering/lights/audio, save reload and an actual offline App race. It also compares all five original cars with the task-start simulation at every tick, including rear-brake inputs, and proves serialized Forklift replay equivalence across 120 Hz/30 Hz presentation batches. Initial failures were retained and corrected; no existing invariant was weakened.

Initial setup attempts used a Python without pytest, then lacked the backend import path. The correct secure environment ran from `backend`. The first mixed-database appearance run passed 29 tests but had 27 PostgreSQL setup errors because the configured local server was unavailable; the explicit SQLite run above passed. Initial engine sandbox certificate errors, fixture return-type/variable-length-frame mistakes, missing preview images, empty batched-AABB corner assertions, offline race-contract setup, a detailed mesh array type and a briefly unfinished concurrent Electric preload are recorded in the evidence. Original assertions and initial model captures remain available.

Evidence and source hashes: [report](evidence/forklift-2026-10-25/report.json). The source checkpoint is checked with Git against its saved before tree and includes shared integration context; concurrent Electric hunks are identified as context rather than Forklift authorship. No branch/index or owner save is changed by checkpointing.

No phone/tablet attachment check or physical-device test was performed. No APK, real purchase, live mutation, deployment or owner-process restart was performed. Owner acceptance of appearance, driving feel and phone frame pacing remains. Reload the client to use the new code and assets.
