# Forklift clearance, speed and turning - 2026-10-25

FC01-FC04/R01/Q01 address the owner's report that the forks catch obstacles and bridge entries, the request for at least 65 km/h, and tighter turning including at higher speeds. The `forklift-2` profile reaches **66.6 km/h** (18.5 m/s). Rear-wheel steering, axle dimensions and the detailed Compact-material model remain intact.

The fork carriage, forks, locks and load backrest rise together by 0.60 model metres, or 0.528 world metres with the existing body scale. The fork underside rises from 0.1584 to 0.6864 m. Detailed and racing geometry clear both sampled bridge approach ramps by at least 0.218 m; the task-start forks penetrated them by 0.327 m. The model retains 144,656 detailed / 48,800 racing triangles and now batches into 40 mesh instances.

The game's planar collision circle is independent of the visible forks. Its old 1.85 m radius also caught bridge rails before the body reached them. The revised 1.40 m body footprint clears legitimate bridge entries while still colliding with rails. This Forklift task changes no shared simulation code or physics version; the handling version and its config hash change together. The backend's golden manifest pins the new Forklift hash. Matching online deployment and existing contract revalidation remain separate work.

FC04 increases the maximum rear-wheel angle from 0.88 to 1.00 radians, reduces high-speed steering reduction from 0.55 to 0.30, raises lateral grip from 27 to 42 and the yaw limit from 2.5 to 3.2 rad/s. Corner-energy retention rises from the default 0.50 to 0.95 so the sharper turn does not scrub away most of the speed. These are Forklift-only configuration values; mass, acceleration and brakes retain their existing settings. Actual full-steering radius at 66.6 km/h drops from 12.676 to 8.149 m, with both profiles sustaining that speed.

The turning regression compares 16 powered circles at 3/8/14/18.5 m/s, partial/full input, left/right. The steering control retains the task-start steering/grip values with equal speed caps and the same corner-energy retention; this isolates steering/grip while ensuring both vehicles sustain the requested speed. Every measured radius improves by at least 15%, both control and revised speeds exceed 85% of their cap, and all revised circles recover to negligible yaw/slip within two seconds after steering release. In fact, revised measured speeds reach their full caps in every case. The test retains the 15% radius criterion, adds a guard for the control's speed and records both actual speeds.

Changed sources: `game/resources/cars/forklift.tres`, `game/vehicle/forklift_model.gd`, `game/tests/test_forklift.gd`, new `game/tests/test_forklift_clearance.gd`, and the Forklift entry in `backend/tests/fixtures/verified_oval.json`. All 49 native Forklift appearance photos and its native catalogue artwork are refreshed and imported. Status documents and the original Forklift guide link this correction.

All engine checks use `scripts/dev.ps1` and pinned Godot `4.7.2.stable.official.ed1daf0bf`. Commands, raw logs, measurements, native screenshots, hashes and the scoped checkpoint are in [the evidence report](evidence/forklift-clearance-2026-10-25/report.json). The [native gallery](evidence/forklift-clearance-2026-10-25/report.html) includes the old and raised forks.

| Actual command/check | Result |
|---|---|
| `TestScript -ScriptPath res://tests/test_forklift_clearance.gd` | Final 152 checks, zero failures; 16 powered turning cases, 36 clear traversals and exact replays |
| `TestScript -ScriptPath res://tests/test_forklift.gd -TestArgument '--evidence-dir=res://../docs/evidence/forklift-clearance-2026-10-25'` | 98 checks, zero failures |
| Focused test with `-Graphical -RenderingMethod gl_compatibility` and PowerShell array arguments for evidence directory plus `--bake-art` | 107 checks, zero failures before steering follow-up; updated catalogue artwork |
| Final focused test with `-Graphical -RenderingMethod gl_compatibility` and evidence directory | 106 checks, zero failures; final steering profile |
| Focused test with `-Graphical -RenderingMethod mobile` and evidence directory | 106 checks, zero failures; desktop renderer, not a phone test |
| `TestCars -CommandTimeoutSeconds 600` | 143 checks, zero failures; all seven cars, three five-lap fixtures and replays |
| `TestBridgeContacts` | 16 checks, zero failures |
| `TestScript -ScriptPath res://tests/bake_livery_previews.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--vehicle=forklift'` | 49 native model captures complete |
| `Import` | Pass; refreshed preview textures |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` | 1,136 scripts, zero failures |
| Backend secure Python: `-m pytest tests/test_verifier.py -q -k 'real_engine_manifest_pins_every_competitive_config or real_five_lap_race_replays_identically' --tb=short` | 2 passed, 68 deselected; real pinned engine |

The new clearance regression uses real six-metre bridges at three headings, both travel directions, three lateral offsets and two controlled speeds, with exact 120 Hz / 30 Hz presentation-batch replays. It also proves the old footprint catches a clear entry, actual rails still block the revised truck, and actual fork vertices clear both sampled ascending ramps in both detail levels. The full all-car suite covers three five-lap fixtures for every workspace car. Focused Garage/race checks retain original-car trace equality, steering articulation, save reload, appearance and framing assertions.

The original run had 88 checks and 38 failures. The first revision had two remaining failures because the two fork meshes shared a name; stable left/right names fixed inspection of both forks. The corrected run passes all 88 checks. A first graphical invocation combined two command-line arguments, saving evidence to the wrong directory and omitting the art bake; its passing 106-check result is retained under `initial-cli-argument`. The corrected array invocation passes 107 checks including the bake. No assertion was weakened.

The subsequent steering request added turning assertions. The first grip/steering tune failed ten speed-retention checks; increasing corner-energy retention fixed that loss. Two radius comparisons still failed because the unchanged control slowed to about half speed and thus traced a misleadingly small circle. Matching the energy treatment and adding an explicit control-speed assertion corrected this fixture without changing the radius or recovery limits. The 136/10 and 136/2 initial results and raw measurements remain in the evidence, followed by the final 152/0 run. The earlier clearance-only results are retained separately.

The final 143-check full-car run and renderer runs used shared physics 0.67. Concurrent Electric work subsequently moved shared physics to 0.68 and updated its own manifest entry. The Forklift 152-check turning/bridge suite, 98-check integration/original-car trace suite and two real verifier tests were rerun on 0.68. The scoped checkpoint preserves those concurrent manifest values and changes only the Forklift entry. A strict patch whitespace check initially flagged existing CRLF endings; the corrected check explicitly recognizes CRLF and retains real whitespace checks.

No phone/tablet attachment check or physical-device test, APK, purchase, live mutation, deployment or owner-process restart was performed. Reload the client to use the changed code and assets. Owner acceptance of driving feel, appearance and phone frame pacing remains.
