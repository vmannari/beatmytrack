# Desert bridge dust correction — 2026-11-03

DBD01: Dust must appear on the visible desert bridge. DBD02: Ground and low-ramp clouds must remain blocked by higher decks. DBD03: Keep canonical driving, particle appearance, budgets and lifetime unchanged.

The desert road relief lowers bridge meshes and wheel emission positions by 0.30 m. The cloud shader still compared their world/birth heights with the original bridge. Its upper-bank classification therefore treated legitimate deck dust as below the roof. The original GPU test only probed canonical bridge heights and missed the integrated relief.

`game/vehicle/sand_dust.gd` now binds the active `BridgePresentation` relief offset, caches the presentation identity alongside the track, and resets the offset for absent/empty relief. `game/vehicle/dust_bridge_clip.gdshaderinc` converts the fragment, opaque surface and immutable birth heights into the same bridge coordinates for all three guards. The default offset remains zero, including existing trail users of this include. Presentation version advances to desert-dust-23. No canonical or particle-motion source changes.

`game/tests/test_desert_bridge_dust.gd` exercises the actual compiled Dust Cloud bridge, production GPU emission and newly born cloud material at the relieved road height. It retains low-ramp blocking and exact vehicle/track data checks. `game/tests/test_bridge_dust.gd` explicitly keeps its original analytic probes in canonical coordinates and adds relief binding, empty-field, same-track presentation-switch and leaving-desert assertions. No existing assertion or threshold was removed. `scripts/run_desert_bridge_dust.py` supplies isolated APPDATA/LOCALAPPDATA, offline API configuration, Dummy audio, scoped crash-dialog suppression and a 240 s owned-process timeout.

## Actual results

Pinned Godot 4.7.2.stable.official.ed1daf0bf; Windows RTX 3090. Mobile below means the desktop Vulkan Mobile renderer.

| Check | Compatibility | Mobile |
|---|---:|---:|
| Task-start source, integrated regression | 10 checks / 2 failures | Not run |
| Corrected integrated regression | 9 / 0 | 9 / 0 |
| Bridge masks, birth-height GPU witness and lifecycle | 125 / 0 | 125 / 0 |
| Existing roof occlusion, including disabled depth helpers | 241 samples / 0 | 241 samples / 0 |

The extra task-start check validates loading the archived script. Original emitted/newborn bridge dust changes **0 / 0 pixels** within the fixed 4,459-pixel road probe. Corrected actual emitted clouds change **4,459 pixels** on both renderers; controlled newborn clouds change **2,358 / 2,530**. Low-ramp birth clouds change zero pixels over the higher road. The existing prepared-resource test also passes **162 / 0 headless**. Earlier original mask tests pass 121 / 0 before and after, demonstrating why an integrated relief regression was needed.

Native before/after images were visually inspected: [original](evidence/desert-bridge-dust-2026-11-03/before-compatibility/emitted-deck.png), [corrected Compatibility](evidence/desert-bridge-dust-2026-11-03/final-compatibility/emitted-deck.png), [corrected Mobile](evidence/desert-bridge-dust-2026-11-03/final-mobile/emitted-deck.png). Each integrated capture directory also includes clean road, controlled newborn cloud and blocked low-ramp controls. Roof directories retain the existing guard stress views.

## Commands run

All paths below use `python scripts/run_desert_bridge_dust.py NAME SCRIPT OPTIONS`; complete commands, engine output and exit statuses are in the corresponding evidence logs.

```powershell
python scripts/run_desert_bridge_dust.py before-compatibility res://tests/test_desert_bridge_dust.gd --rendering-method gl_compatibility -- --before --output=res://../docs/evidence/desert-bridge-dust-2026-11-03/before-compatibility
python scripts/run_desert_bridge_dust.py final-compatibility res://tests/test_desert_bridge_dust.gd --rendering-method gl_compatibility -- --output=res://../docs/evidence/desert-bridge-dust-2026-11-03/final-compatibility
python scripts/run_desert_bridge_dust.py final-mobile res://tests/test_desert_bridge_dust.gd --rendering-method mobile -- --output=res://../docs/evidence/desert-bridge-dust-2026-11-03/final-mobile
python scripts/run_desert_bridge_dust.py masks-compatibility-final res://tests/test_bridge_dust.gd --rendering-method gl_compatibility
python scripts/run_desert_bridge_dust.py masks-mobile-final res://tests/test_bridge_dust.gd --rendering-method mobile
python scripts/run_desert_bridge_dust.py roof-compatibility res://tests/test_dust_roof_occlusion.gd --rendering-method gl_compatibility -- --output=res://../docs/evidence/desert-bridge-dust-2026-11-03/roof-compatibility
python scripts/run_desert_bridge_dust.py roof-mobile res://tests/test_dust_roof_occlusion.gd --rendering-method mobile -- --output=res://../docs/evidence/desert-bridge-dust-2026-11-03/roof-mobile
python scripts/run_desert_bridge_dust.py prepared-resources res://tests/test_prepared_race_resources.gd --headless
```

Initial direct-wrapper attempts are retained separately as `before-console.log`, `before-native.log`, `final-console.log`, `final-native.log`, and `bridge-before.log`. They encountered sandbox-denied user/cache log writes; the initial archived-script fixture also attempted to assign an unrelated dynamic script to a typed SandDust property and was interrupted. The corrected fixture holds its archived emitter in a separate Node3D variable. These attempts are not clean passes. An attempted process query was denied; no unrelated process was stopped. Final isolated tests exit normally. All native runs retain the environment's root-certificate-store error; there are no other errors in final isolated passing logs. Hitch diagnostics are recorded, not performance measurements.

## Checkpoint and limits

[Task-only patch](evidence/desert-bridge-dust-2026-11-03/task.patch) contains the two runtime files, two tests, isolated runner and this report. Its forward/reverse checks and exact normalized source round-trip are recorded in [checkpoint-check.json](evidence/desert-bridge-dust-2026-11-03/checkpoint-check.json). Original runtime sources are archived in `before/`. Concurrent settings, vehicle, backend and other work is preserved; no main-index write or commit was made.

Reload the game to pick up the corrected shader. Owner appearance acceptance and physical-device performance remain. No phone query/test, APK, owner-save or owner-process change, backend/live access, deployment or physics change was performed. The integrated visibility witness uses a stationary wheel cloud on the real deck; it does not establish a full driving lap or phone performance result.
