# Forklift lower fitting removal and 80 km/h - 2026-10-25

F80-01/F80-02/R01/Q01 implement the owner's request to remove the bottom exhaust-like fitting and increase top speed to 80 km/h. The lower rear cylinder and its end bolt are removed; the upper exhaust stack and heat shield remain. Solid side panels, the single rear sticker, raised forks and the tighter rear steering remain as previously corrected.

The versioned `forklift-3` profile changes only the handling version and maximum speed, from 18.5 to 22.22222222222222 m/s. Actual powered speed measures 79.9999969482422 km/h, within floating-point tolerance of 80 km/h. The native config hash is `b8efe40fee6eafba448a1b6d3af917f3cc5bc05481ef3d6379835235f0d66cd6`; the verifier fixture pins this hash/version. No shared physics implementation change is made. Matching online contract rollout/revalidation remains separate work.

The detailed/racing models now contain 146,432/49,472 triangles and retain 40 prepared mesh instances. Native geometry checks inspect both detail levels for the absence of the low central rear protrusion and the presence of the upper stack. All 49 native Forklift appearance photos and its catalogue illustration are refreshed and imported.

All engine commands use `scripts/dev.ps1` and pinned Godot `4.7.2.stable.official.ed1daf0bf`. Native views, raw logs, commands, measurements, source hashes and the scoped checkpoint are in [the report](evidence/forklift-80-kph-2026-10-25/report.json) and [before/after gallery](evidence/forklift-80-kph-2026-10-25/report.html).

| Actual command/check | Result |
|---|---|
| `TestScript -ScriptPath res://tests/test_forklift_clearance.gd -TestArgument '--evidence-dir=res://../docs/evidence/forklift-80-kph-2026-10-25'` | 204 checks, zero failures; 54 bridge traversals at 3/18.5/22.22222222222222 m/s, 20 turning cases, recovery and exact replay |
| `TestScript -ScriptPath res://tests/test_forklift.gd` with the same evidence directory | 102 checks, zero failures; includes actual 80 km/h and low-fitting/upper-stack geometry checks |
| Same with `-Graphical -RenderingMethod gl_compatibility` and array arguments for evidence directory plus `--bake-art` | 111 checks, zero failures |
| Same with `-Graphical -RenderingMethod mobile` and evidence directory | 110 checks, zero failures; desktop Mobile renderer |
| `TestCars -CommandTimeoutSeconds 600` | 143 checks, zero failures; all seven cars, three five-lap fixtures and exact replay |
| Backend secure Python: `-m pytest tests/test_verifier.py -q -k 'real_engine_manifest_pins_every_competitive_config or real_five_lap_race_replays_identically' --tb=short` | 2 passed, 68 deselected; repeated after concurrent Electric fixture update with the same passing result |
| `TestScript -ScriptPath res://tests/bake_livery_previews.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--vehicle=forklift'` | 49 native captures complete |
| `Import` | Pass; final catalogue artwork and photos imported |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` | Final 1,156 scripts, zero failures |

The clearance suite retains the earlier 66.6 km/h cases and adds the new maximum speed; its radius, speed-retention, rail-collision and ramp-clearance assertions remain. The all-car suite and original-car trace comparisons retain their assertions.

Initial rendering attempts encountered a newly added concurrent font class before its import registration, followed by a font fallback runtime type error. The first Compatibility run timed out before App startup; both subsequent renderers reported the typed-array error. The minimal correction creates `Array[Font]` and assigns the intended fallback sequence explicitly, preserving the Japanese/Korean order. Both complete Garage/race suites then pass. Initial logs are retained. Concurrent localization/font assets, Electric handling and its manifest hash are preserved; only the two Forklift manifest fields belong to this change.

Changed sources: `game/resources/cars/forklift.tres`, `game/vehicle/forklift_model.gd`, `game/tests/test_forklift.gd`, `game/tests/test_forklift_clearance.gd`, the Forklift entry in `backend/tests/fixtures/verified_oval.json`, and the small startup type correction in `game/localization/game_fonts.gd`. Native assets, status entries and the original Forklift guide accompany them.

No phone/tablet attachment check or physical-device test, APK, purchase, live backend mutation, deployment or owner-process restart was performed. Reload the game to use the new model, artwork and handling. Owner/device driving feel, appearance and frame-pacing acceptance remain.
