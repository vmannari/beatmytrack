# Go-kart — 2026-09-16

## Requirements and behaviour

Owner requests a go-kart with a smaller wheel span, tighter turning, very good grip, good acceleration and relatively low top speed. Requirements **G01, G03, V02–V05, R01/R03/R04/R06/R07**. This extends the existing local vehicle catalogue to five entries.

Garage now includes **Go-kart / KART / 05**. Home artwork, selected-car track PBs, races, results, retry and untimed creator practice use the same selection. Atomic preference persistence and the existing per-car rules keys include `kart`; no paid/unlock gate is added.

The kart has a 1.25 m wheel track (14% narrower than the compact), 1.55 m wheelbase, 260 kg arcade mass including driver and a 30 m/s / **108 km/h** cap. It uses high lateral grip, fast steering/yaw response and strong acceleration. Dirt and long straights remain disadvantages. The model's wheels, existing tyre trails and kerb samples use these same dimensions; collision uses the established circle approximation with a 1.05 m radius.

## Measured tradeoffs

Identical quantized input scenarios in `test_kart.gd`:

| Measurement | Compact | Formula | Kart |
|---|---:|---:|---:|
| 0–72 km/h | 1.450 s | 1.383 s | **1.025 s** |
| Low-speed full-lock radius* | 4.25 m | 4.69 m | **2.54 m** |
| Powered bend peak slip | 5.27° | 2.10° | **3.71°** |
| Speed after 10 s full throttle | 165.6 km/h | 140.4 km/h | **108.0 km/h** |

*Radius is speed/yaw rate after 0.5 s coasting at full lock from 10 m/s; it is a repeatable local response measurement, not a claim of physical steering geometry or every-speed turning radius. The powered bend starts at 14 m/s and uses 55% steering, 50% throttle for 1.5 s.

The existing 18 m radius clean-asphalt skidpad gives Formula 3.608 s and kart 3.792 s. This preserves Formula's faster flowing-corner advantage despite the kart's tighter low-speed turning. The kart covers 126.99 m in a five-second full-throttle asphalt run versus the compact's 146.56 m. Its initial launch advantage gives way to the lower speed cap.

Kart five-lap diagnostic runs completed with **zero barrier contacts** on Pine Loop (`arto4`), Dune Run (`hiekka`) and Coast Oval (`ovaali3`). Every replay exactly matched the original simulation state. The driver caps its target at 12 m/s; these runs verify completion/replay, not optimal lap-time balance. Human driving acceptance remains open.

## Changed files and versioning

- `game/resources/cars/kart.tres`: dedicated `kart-1` handling Resource. No existing car tune or canonical simulation-step code changed; existing PB keys remain unchanged.
- `game/vehicle/vehicle_catalog.gd`: fifth entry, display text, artwork and selection through existing catalogue APIs.
- `game/vehicle/handling_config.gd`: editor property ranges admit the kart's lower mass/inertia and shorter wheelbase. Default values and snapshot fields are unchanged.
- `game/vehicle/vehicle_models.gd`: original low tubular chassis, small exposed tyres, front fairing, side pods, seat, seated helmeted driver, steering wheel, finned engine, exhaust and rear axle; existing matte toon/ink materials.
- `game/vehicle/car_visual.gd`: kart steering animation, lower chassis compliance and kart-shaped rollover support. Presentation only.
- `game/core/app.gd`: slightly tighter Home card spacing keeps bottom navigation on-screen with the car selector.
- `game/ui/menu_stage.gd`: kart illustration framing and edge blending at standard/compact/wide menu sizes. Gameplay camera unchanged.
- `game/assets/menu/kart_illustration_v1.png` and import settings: original 1672×941 illustration with mipmaps.
- `game/tests/test_kart.gd`, `test_cars.gd`, `capture_cars.gd`: measured tradeoffs, kart replay filter and isolated kart captures.
- `scripts/dev.ps1`: `TestKart` and `CaptureKart`; future `Validate` runs include the kart behaviour suite alongside the existing all-car suite.
- `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, `licenses/ASSETS.md`, this document and the prompt/evidence files.

## Artwork and actual captures

The built-in **image_gen** tool generated the menu illustration using the existing original Formula illustration as a style reference. No Fal/CLI/API fallback, branded input asset or runtime generation is used. Exact prompt: [KART_ART_PROMPT.md](KART_ART_PROMPT.md).

Saved asset: [kart_illustration_v1.png](../game/assets/menu/kart_illustration_v1.png). SHA-256: `98F5849E234B88F95028F3450EE8186708E0C6268DB2CF8026E33403421ED1D6`.

[Garage](evidence/kart/kart-garage-1280.png) · [Compact Garage](evidence/kart/kart-garage-960.png) · [Wide Garage](evidence/kart/kart-garage-1600.png) · [Home](evidence/kart/kart-home.png)

[Gameplay](evidence/kart/kart-gameplay.png) · [Runtime model](evidence/kart/kart-model.png) · [Tracks](evidence/kart/kart-tracks.png) · [Results fixture](evidence/kart/kart-results-fixture.png)

The model closeup uses a separate evidence camera; gameplay uses the existing follow camera. The results image injects a 100-second fixture solely for UI/record/retry checks, not a driven result. Test saves use disposable directories, never owner records. Generated illustration and simplified 3D model remain subject to owner/shipping visual acceptance.

## Actual verification

Commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` and pinned Godot `4.7.2.stable.official.ed1daf0bf`.

| Action | Actual result |
|---|---|
| `Import` | Passed, including PNG and mipmaps |
| `TestKart` | 13 kart behaviour/geometry/persistence checks + 41 catalogue, mixed-input replay and three kart five-lap run checks; zero failures |
| `TestCarBalance` | 1 check; Formula retains clean skidpad advantage |
| `CaptureKart` | 23 graphical checks, zero failures; all saved captures inspected |
| `TestDriving` | 70 checks, zero failures; four ObjectDB instances reported at shutdown |
| `TestRecords` | 53 checks, zero failures |
| `TestApp` | 86 checks, zero failures |
| `TestSuspension` | 13 checks, zero failures |
| `git diff --check` | Passed |
| `Doctor` | Missing Android templates, SDK/ADB/build-tools and JDK; no export/device test |

Total: **300 passing checks**. [Saved logs](evidence/kart/verification.txt). The initial `TestKart` invocation was rejected because the new action was missing from the wrapper's allowed-action list; adding it and rerunning passed. No full `Validate` or physics merge was performed for this additional Resource/model slice. Canonical simulation version and other cars' rules snapshots are unchanged.

Device attachment could not be enumerated because ADB is unavailable. **No physical-phone test or APK export was performed.** Remaining checks: owner driving feel and artwork approval, kart clearance on narrow bridges, phone readability/touch reach/frame pacing and cross-device replay. Same-engine determinism is not a claim of cross-device equivalence.

## Review checkpoint

The kart-only change is saved on `cars/kart-20260916`, based on a snapshot of the existing workspace before this task. The normal branch, index and all existing local edits remain in place. Use `git show cars/kart-20260916` to review the single slice; it has not been merged.

## Stronger grass/dirt penalty, 2026-09-16

Owner follow-up, requirements G01/G03/R03/R07: kart-2 increases only the kart soil drag multiplier from 1.35 to 3.0. Clean asphalt acceleration, steering, grip and speed cap stay unchanged. The configuration version and snapshot separate existing records from this tuning.

At 30 m/s entry with full throttle for one second, grass speed falls from 17.505 to 13.914 m/s (63 to 50 km/h); dirt falls from 25.713 to 15.324 m/s (93 to 55 km/h). Five-second dirt distance from rest drops from 67.80 to 54.51 m. Both surfaces still allow more than 10 m of travel in two seconds from rest.

Changed implementation: `game/resources/cars/kart.tres`; behavioral coverage: `game/tests/test_kart.gd`. Actual command `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestKart` passed 18 kart checks and 41 catalogue/replay checks, including three five-lap kart runs with zero contacts and exact replay. Asphalt entry snapshots match the previous tuning every tick. Saved output: [soil verification](evidence/kart/soil-verification.txt). `git diff --check` passed. No UI/art changed; existing captures remain applicable. No full Validate or physics merge performed. Owner driving feel remains pending. No phone test or APK export performed; ADB was unavailable in the preceding Doctor check.

Review checkpoint: `cars/kart-soil-20260916`, based on the prior kart checkpoint and excluding concurrent unrelated work.

## Model alignment correction, 2026-09-16

Owner screenshot follow-up, requirements V02/V03/V05: center the seat, torso, helmet, limbs and steering assembly on X=0 (previously -0.10 model metres). Center the front fairing, match its cream stripe to the nose stripe, and meet the nose at its top rear edge. Increase the nose top half-depth from 0.18 to 0.24 so the shell helper's 0.22 corner bevel no longer folds over itself. Original matte/cel-shaded materials retained.

Changed files: `game/vehicle/vehicle_models.gd`, `game/tests/capture_cars.gd`, this document, status/plan and saved evidence. Presentation only; handling/collision and gameplay camera settings are unchanged.

Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureKart` passed first with 23 checks, then with 24 after adding an overhead diagnostic capture. Final [log](evidence/kart/model-alignment-verification.txt). Inspected [gameplay](evidence/kart/kart-gameplay.png), [model detail](evidence/kart/kart-model.png) and [overhead alignment](evidence/kart/kart-model-overhead.png) captures. The enlarged diagnostic camera is evidence-only. Scoped `git diff --cached --check` passed. Review checkpoint: `cars/kart-model-alignment-20260916`.

Remaining acceptance: owner visual review in motion and physical-phone appearance. No phone test or APK export performed; device attachment was not checked this turn. No physics regression suite needed for this geometry-only correction.

## Wheel-contact dirt slowdown, 2026-09-16

Owner follow-up, requirements G01/G03/R03/R07: kart-3 increases soil drag from 3.0 to 5.5 and enables `wheel_soil_drag`. Fixed-order probes at all four canonical wheel centers use the strongest loose-surface contact, so one wheel starts resistance before the chassis center leaves asphalt. Probes respect elevated decks. Partial contact affects resistance only; existing center-based grip, tire coating and rollover triggers remain as before. Other cars keep wheel probing disabled. Physics version advances from arcade-planar-0.25 to 0.26; comparable record keys change globally, with no deletion of old records.

Measured full-throttle entry at 30 m/s: after one second, dirt speed is 10.762 m/s (39 km/h), previously 15.324; grass is 11.046 m/s (40 km/h), previously 13.914. Along a dirt boundary with the chassis center on asphalt and two wheels on dirt, speed reaches 12.983 m/s (47 km/h). A single wheel costs speed on the first tick. Clean asphalt traces match prior tuning and escape from rest remains possible.

Changed runtime files: `game/vehicle/vehicle_simulation.gd`, `game/vehicle/handling_config.gd`, `game/resources/cars/kart.tres`. Tests: `game/tests/test_kart.gd`. Documentation: this file, status/plan, [saved verification](evidence/kart/wheel-soil-verification.txt).

Actual commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`: `TestKart` passed 27 kart checks plus 41 catalogue/replay checks (three five-lap runs, zero contacts, exact replay); `TestDriving` 70; `TestSoil` 111; `TestRecords` 53. Total 302, zero failures. Driving still reports four ObjectDB instances at shutdown. Edge coverage includes four headings, immediate single-wheel contact, sustained road-edge drag, asphalt rejoin and bridge deck isolation. Scoped cached diff whitespace check passed.

No UI/model/camera changes or new screenshots. No phone test or APK export; attachment not checked this turn. Owner driving feel and cross-device replay remain pending. No full Validate or physics merge performed; full regression remains required before merging. Review checkpoint `cars/kart-wheel-soil-20260916` uses a prerequisite snapshot of the existing simulation/config changes, preserving concurrent work and the normal index.

## Shorter turning radius, 2026-09-17

Owner follow-up, G01/G03/R03/R07: kart-4 increases steering angle from 0.72 to 0.92 radians and maximum yaw rate from 3.6 to 4.0 rad/s. The steering-angle editor range now supports this value. No physical dimensions or other car tuning changed. Versioned configuration separates new record comparisons.

Same 0.5-second full-lock coasting test, both left and right: at initial 6 m/s, effective radius drops from 2.152 to 1.497 m (30%); at initial 10 m/s, 2.543 to 2.249 m (12%). These are speed/yaw measurements, not steady-state skidpad radii. Powered-bend peak slip remains 4.59 degrees. Straight-line traces match prior tuning; acceleration, top speed and soil penalties remain unchanged.

Changed files: `game/resources/cars/kart.tres`, `game/vehicle/handling_config.gd`, `game/tests/test_kart.gd`, status/plan, this document and [verification log](evidence/kart/turning-verification.txt). Actual commands via `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`: `TestKart` passed 32 kart checks and 41 catalogue/replay checks, including three five-lap runs with zero contacts and exact replay. Legacy tracks are test fixtures only, not restored to the playable catalog. `CheckScript -ScriptPath res://vehicle/handling_config.gd` passed after expanding the editor range. Scoped cached diff whitespace check passed.

No UI/art changes. No phone test or APK export; device attachment was not checked. Owner driving-feel acceptance remains pending. No full Validate or physics merge performed. Review checkpoint: `cars/kart-turning-20260917`; unrelated workspace work preserved.
