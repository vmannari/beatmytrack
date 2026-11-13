# Saved profile-car livery at startup (2026-10-29)

The header next to the profile name could show factory paint despite loading the correct saved livery. The equipped-image worker required `startup_complete` and excluded both restoring and account screens. Its texture lookup returned a bundled factory picture on a cache miss, so the first menu could show the wrong design and the account screen could indefinitely postpone its replacement.

| Requirement | Change |
| --- | --- |
| PCS01 | Prepare the exact selected car's equipped image under the existing startup cover, before revealing the menu. Prioritize that car over queued dropdown pictures; reuse its persisted PNG when available. |
| PCS02 | Allow equipped-image completion on the account screen. A customized appearance awaiting its picture uses an empty image instead of incorrectly claiming factory paint. Actual stock cars retain bundled pictures. |
| R01/Q01 | Keep account/appearance validation, one temporary renderer, debouncing, disk cache and race-work gates. Record actual first-frame native evidence and separate-process restart behavior. |

Runtime changes are limited to `game/core/app.gd` (one startup call and one policy expression), `game/ui/header_car_appearance_cache.gd` (bounded selected-car preparation), and `game/ui/header_car_icons.gd` (readiness and accurate missing-image behavior). No vehicle geometry, saved appearance, handling or backend contract changes.

`game/tests/test_profile_car_startup.gd` loads actual on-disk synthetic settings, including paint, sticker and fitted parts. An offline guest normally starts on a sign-in page without a profile header; the fixture overrides only that startup destination to reveal the normal Free Race menu. It retains the real App startup and image worker, without real authentication. It inspects the texture before any follow-up navigation, counts every visible factory-picture frame, compares against an independent native render, and verifies appearance changes while the account screen remains open. The new race-control helper retains the existing regression's assertions and reverts just this task in process memory.

| Actual native run | Checks | Failures | First-menu factory frames |
| --- | ---: | ---: | ---: |
| Original startup, Compatibility | 13 | 6 | 1 |
| Compact cold start, Compatibility | 24 | 0 | 0 |
| Compact separate-process restart, stable revision | 23 | 0 | 0 |
| Kart cold start, Compatibility | 24 | 0 | 0 |
| Compact cold start, desktop Mobile | 24 | 0 | 0 |

The stable-revision restart needs zero startup captures and one PNG read; observed startup is 345.476 ms. Cold Compact startup is 2128.923 ms in Compatibility and 5912.580 ms in desktop Mobile, including other startup work. These are individual desktop observations, not performance guarantees. The startup helper has a 45-second bound. If a customized image remains unavailable, the slot stays empty and the existing worker can finish later; it does not show factory paint.

The existing headless `test_race_optional_work.gd` run reports 85 checks with three failures: empty Garage preloader sleep, sleep after a wake during racing, and visible pending Rivalry polling. The in-memory before control retains all 85 checks and reproduces exactly the same three failures. All header completion/publication, racing exclusion, account replacement and appearance replacement assertions pass in both runs. The App file receives a concurrent change to biome descriptions during the broader run; those edits are preserved and excluded from the task patch. The final current App and its dependencies pass the pinned engine's targeted `CheckScript` parse.

First-menu images were visually inspected: [original factory picture](evidence/profile-car-startup-2026-10-29/before-startup-menu/first-menu.png), [correct equipped Compact](evidence/profile-car-startup-2026-10-29/compact-cold-final/first-menu.png), [equipped kart](evidence/profile-car-startup-2026-10-29/kart-cold/first-menu.png), and [desktop Mobile](evidence/profile-car-startup-2026-10-29/compact-mobile/first-menu.png). Each passing native run also captures the updated account appearance after returning to the menu.

Actual commands use pinned Godot 4.7.2 through `scripts/dev.ps1`. The runner sets a workspace-local `APPDATA` and an empty `BMT_API_URL`:

```text
python docs/evidence/profile-car-startup-2026-10-29/run_checks.py before-startup-menu test_profile_car_startup.gd gl_compatibility --profile=user://profile-startup-before-menu --phase=seed
python docs/evidence/profile-car-startup-2026-10-29/run_checks.py compact-cold-final test_profile_car_startup.gd gl_compatibility --profile=user://profile-startup-compact-final --phase=seed
python docs/evidence/profile-car-startup-2026-10-29/run_checks.py compact-restart-stable test_profile_car_startup.gd gl_compatibility --profile=user://profile-startup-compact-final --phase=reuse
python docs/evidence/profile-car-startup-2026-10-29/run_checks.py kart-cold test_profile_car_startup.gd gl_compatibility --profile=user://profile-startup-kart --phase=seed --car=kart
python docs/evidence/profile-car-startup-2026-10-29/run_checks.py compact-mobile test_profile_car_startup.gd mobile --profile=user://profile-startup-mobile --phase=seed
python docs/evidence/profile-car-startup-2026-10-29/run_checks.py race-optional-work test_race_optional_work.gd headless
python docs/evidence/profile-car-startup-2026-10-29/run_checks.py race-optional-before-control test_profile_car_race_control.gd headless
python docs/evidence/profile-car-startup-2026-10-29/run_checks.py app-parse res://core/app.gd check
python docs/evidence/profile-car-startup-2026-10-29/build_checkpoint.py
```

Initial attempts are retained: the sandbox cannot read the Windows certificate store; normal-access offline runs resolve this. The first fixture tried inspecting a nonexistent sign-in header and was corrected to route only the startup destination. The first independent reference viewport did not request drawing; explicitly enabling viewport drawing fixes that fixture failure without changing the comparison tolerance. One restart crosses a changed full build identity, correctly regenerates the picture, and fails the fixture's zero-capture expectation; the subsequent stable-revision restart passes unchanged. Original logs, commands, reports and source hashes remain in the evidence directory.

The task source checkpoint excludes concurrent changes, checks forward and reverse application in a disposable local repository, and compares source contents with line endings normalized. It does not stage or commit the main index. Reload/rebuild and owner confirmation remain. No physical-device attachment query or device test, APK, owner-save/session edit, real authentication, live API write, deployment, or owner-process restart was performed. The startup rendering proof uses synthetic local appearances; live signed-in restoration and all-car/device performance are not certified.
