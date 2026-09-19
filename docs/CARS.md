# Four-car local garage — 2026-09-15

## Requirements and scope

Owner request: add a pickup, rear-heavy classic sports car and classic Formula car, with track-dependent strengths and coherent menu/gameplay art. Requirements G01 (handling), G03/V03 (garage/menus), V02/V04/V05 (vehicle art), R01/R03/R04/R06/R07 (selection, deterministic rules, records and retries).

All four cars are immediately available through Garage's car selector. Selection is saved atomically with local preferences and carried into Home, Tracks PB lookup, races, results, retry and untimed creator practice. New cars have dedicated authored handling; the compact retains its five comparison presets, including the default Original+. New car handling cannot be replaced by selecting a compact preset. No progression, purchase, unlock or network dependency is added.

| Car | Character | Intended strength | Cost |
|---|---|---|---|
| Compact / 01 | Existing cream/blue hatchback | Versatile mixed circuits, quick rotation | Lower straight-line pace than Rearsport; less clean grip than Formula |
| Hauler / 02 | Cream/rust single-cab pickup, 2,200 kg | Loose surfaces, momentum and strong engine force | Slow steering/yaw response, long stopping distance, larger footprint |
| Rearsport / 03 | Sage/cream rear-engine fastback, 1,120 kg | Fast exits and long straights, 176 km/h cap | Lifting in a fast corner unloads rear grip and adds rotation |
| Formula / 04 | Ochre/cream open-wheel single-seater, 540 kg | Precise technical asphalt and braking | 140 km/h cap, abrupt grip breakaway, weak soil performance and greater collision loss |

These are fictional identities inspired by the requested classes. They are arcade approximations, not manufacturer performance simulations. Rear-heavy behaviour is represented by front/rear grip balance and bounded lift-off response rather than a full axle-load solver.

## Balance evidence

`TestCars` measures the same inputs on each car. Final five-second distances from rest (metres):

| Car | Asphalt | Dirt | Stop from 30 m/s |
|---|---:|---:|---:|
| Compact | 146.56 | 86.48 | 25.45 |
| Hauler | 131.40 | 90.92 | 35.91 |
| Rearsport | 154.01 | 85.84 | 23.91 |
| Formula | 138.68 | 53.77 | 16.10 |

`TestCarBalance` searches requested speeds with one geometric controller on an 18 m radius asphalt skidpad. Its scored second lap must stay within 2 m of the radius and below 0.35 radians slip. Formula: **3.608 s**, Compact: **4.525 s**, Rearsport: **5.567 s**. The shared controller found no qualifying pickup lap; this is a controller/handling limit in this fixture, not a claim that the pickup cannot turn a circle. Formula's first tune failed to beat the compact; faster lateral response and lower yaw inertia corrected this without raising its speed cap or reducing off-road penalties.

Twelve full runs use the existing conservative route driver: every car completes **five laps** on Pine Loop (`arto4`), Dune Run (`hiekka`) and Coast Oval (`ovaali3`) with exact same-engine replay and zero barrier contacts. That driver targets at most 12 m/s and is tuned for the compact; it is completion evidence, not a competitive balance ranking. The compact remains fastest in these conservative runs. Human laps across tight, flowing and loose tracks are still needed to approve the balance and feel.

## Implementation and contracts

- `game/vehicle/vehicle_catalog.gd`, `game/resources/cars/*.tres`: stable IDs, names, descriptions, artwork and independent handling Resources.
- `handling_config.gd`, `vehicle_simulation.gd`: vehicle ID, axle width, soil grip/drag and bounded lift-off rotation/grip loss. Fixed 120 Hz quantized simulation; no I/O, wall clock or random source in the step. Physics is `arcade-planar-0.24`, new-car handling `cars-1`.
- `car_visual.gd`, `vehicle_models.gd`: original pickup bed/cab, sports fastback/fenders and Formula cockpit/wings/suspension geometry with shared matte toon materials, selected ink outlines, lights, steering wheels, suspension and shape-specific rollover support.
- `skid_trails.gd`, `native_track.gd`: selected wheelbase/axle width drives trails and kerb sampling. Collision remains the existing circle approximation, with authored per-car radii; it is not exact mesh collision.
- `core/app.gd`, `core/game.gd`, `ui/handling_selection.gd`, `ui/menu_stage.gd`, `ui/playground_hud.gd`, `ui/track_browser.gd`, `ui/race_results.gd`, `persistence/local_records.gd`: selection, persistence, artwork, race/practice identity, results labels and per-car PB lookup. Unknown saved IDs fall back to compact at selection load; persistence accepts only catalogue IDs.
- Three PNGs and import settings under `game/assets/menu/`: original generated illustrations, native size and mipmaps. The long pickup is composed smaller in menus to leave its entire bed visible. Gameplay camera framing is unchanged.
- `scripts/dev.ps1`: `TestCars`, `TestCarBalance`, `CaptureCars`; both car domain suites are included in future `Validate` runs.
- `game/tests/test_cars.gd`, `test_car_balance.gd`, `capture_cars.gd`: physics/record/replay, suitability and graphical integration evidence.

PB keys already include the complete handling snapshot and physics version, so cars and tunes cannot overwrite each other's records. Existing files and old rules partitions are retained. The physics version bump means old-version PBs do not appear as comparable current PBs. Replay manifest schema 8 remains a snapshot dictionary and includes all new handling fields without changing positional state layout.

## Art and screenshots

The built-in imagegen skill/tool generated each illustration using the existing compact artwork as the style reference. Exact prompts: [CAR_ART_PROMPTS.md](CAR_ART_PROMPTS.md). No CLI/API fallback or runtime image generation. Assets live in the project, with SHA-256 provenance in `licenses/ASSETS.md`. No supplied branded reference is included. Generated menu art and simplified gameplay geometry remain subject to owner visual acceptance and shipping asset review.

[Pickup Garage](evidence/cars/pickup-garage-1280.png) · [Sports Garage](evidence/cars/classic-garage-1280.png) · [Formula Garage](evidence/cars/formula-garage-1280.png)

[Pickup model](evidence/cars/pickup-model.png) · [Sports model](evidence/cars/classic-model.png) · [Formula model](evidence/cars/formula-model.png) · [Formula gameplay](evidence/cars/formula-gameplay.png)

The model closeups use a separate evidence camera; normal gameplay captures use the unchanged follow camera. Menu evidence covers 1280×720, 960×540 and 1600×720. Any `results-fixture` image is a deliberately injected 100-second result, not a driven record. Capture saves are isolated from owner data.

## Actual verification and remaining acceptance

Commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` and pinned `4.7.2.stable.official.ed1daf0bf`.

- `Import` and `CheckScript -ScriptPath res://core/app.gd`: passed.
- `Validate`: passed import, 105 script parses, startup and all existing domain/UI suites ([summary](evidence/cars/regression-summary.txt)). Two-instance ObjectDB shutdown warnings remain in several existing editor/bridge tests; no script/test errors.
- `TestCars`: final-tune rerun passed 54 checks, including all 12 five-lap runs with zero barrier contacts and exact replay. [Log](evidence/cars/car-tests.txt).
- `TestCarBalance`: 1 check passed after the Formula correction; exact metrics above. [Log](evidence/cars/car-balance.txt).
- `CaptureCars`: final run passed 82 graphical integration checks, including results/record partition, retry identity and bottom-navigation bounds at all three sizes. Formula copy was shortened after screenshot review found wide-layout overflow. Screenshots inspected at standard, compact and wide sizes. An earlier expanded capture run failed because its result fixture assigned an untyped Array to typed lap_times; the fixture was corrected to Array[float] and rerun. [Log](evidence/cars/car-captures.txt).
- `git diff --check`: passed after removing a whitespace-only line introduced in Garage.
- `Doctor`: failed because matching Android debug templates, SDK/ADB/build-tools and JDK are missing. Device attachment could not be enumerated. **No physical-phone test or APK export was performed.**

Workspace note: existing uncommitted menu, road and handling work was present before this task and retained. Changes remain in the working tree; no unrelated changes were staged or committed.

Remaining acceptance: manually compare the four cars on tight asphalt, fast straights and loose tracks; test sports lift/catch and Formula breakaway, narrow bridges and pickup clearance; approve artwork and model silhouettes; validate touch selection, framing, frame pacing and thermals on a phone. Same-engine replay is not a claim of cross-device determinism or competition-grade route verification.
