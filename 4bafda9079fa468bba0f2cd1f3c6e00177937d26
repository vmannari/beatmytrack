# Electric brake and reverse — 2026-10-28

EB01 adds the ordinary brake input to Electric21, including keyboard/controller and all touch layouts. EB02 replaces the D/R selector with the existing stopped brake-hold reverse behavior (0.35 s delay, 7 m/s reverse cap); releasing the pedal stops reverse, and the accelerator returns to forward travel. EB03 retains regeneration20, the coast point, motor, steering, powered drift and disabled handbrake. R01 preserves unrelated work and other cars. Q01 covers native controls, deterministic replay and the local verifier.

The resource changes `single_pedal` to false and explicitly selects `handbrake_enabled=false` and `blended_regeneration=true`. The latter keeps the previous four-wheel automatic lift-off blend independent of the pedal layout. These optional capabilities disappear from unchanged cars' snapshots. The shared physics version remains 0.75. Electric21 hashes to `75f0052f7eb3340bbe98b0c719d98b75402f66d2ecc6726accb83d9fb0ccfa0b`. Only its local expected backend fixture identity changes. No server deployment is performed.

Six runtime scripts and one resource change: `driver_input.gd`, `handling_config.gd`, `vehicle_simulation.gd`, `touch_controls.gd`, `playground_hud.gd`, `vehicle_catalog.gd`, and `resources/cars/electric.tres`. The description updates English and eleven authored translations, their packaged PO entries, and the source catalogue. The actual race UI regression now exercises brake-hold reverse. The historical one-pedal suite loads the exact prior Electric20 resource; its original invariants remain. A new focused suite checks current behavior. Existing tune-specific Electric suites beyond those listed below were not rerun; this is not a full release regression claim.

Actual outcomes:

| Check | Result |
| --- | --- |
| Focused final headless | 106 checks, 0 failures, clean exit |
| Compatibility and desktop Mobile | 112 checks each, 0 failures, clean exits; six captures each |
| Historical Electric20 single-pedal | 63 checks, 0 failures |
| Shared handling | 88 checks, 0 failures |
| Project parser | 1,369 scripts, 0 failures |
| Over and under | 7 checks, 0 failures; five laps, 34,703 inputs, zero contacts, exact replay |
| Independent local backend verifier | Accepts 34,703 ticks / 289,188 ms, five lap boundaries, exact Electric21 identity |
| Electric copy | Eleven packaged translations match authored entries; Unicode and placeholders pass |
| Scoped checkpoint | Git reverse-apply check passes without using the main index |

Forward acceleration and lift-off are tick-exact against Electric20 across 3,600 mixed steering/power/lift inputs. The six historical other-car resource hashes remain exact. Concurrent catalogue work removes Classic/Formula from the active manifest and adds Hovercraft: the verifier comparison reports those absent identities explicitly and checks the other identities still present. Those catalogue edits and the concurrent air-cushion integrator are excluded from this task's patch.

From 72 km/h, the existing 26,000 N service brake stops the Electric in 1.2833 s. Lift-off retains its previous stronger automatic blend (the historical stop is 1.0 s); this task does not retune either force. Holding both pedals cannot launch or reverse the car. Malicious handbrake replay requests remain ineffective.

The actual Garage-to-race UI test was attempted but stops during App preparation because concurrent Hovercraft work has not yet supplied `assets/menu/header_cars_v1/hovercraft.png`. It is not counted as passed. Native focused captures exercise the actual HUD independently: [Compatibility buttons](evidence/electric-brake-reverse-2026-10-28/compatibility/buttonsfalse.png). The initial test fixture lacked its output directory; after creating it, the five-lap test passes. Initial sandbox log/certificate access failures, premature test resource teardown diagnostics, the missing historical-manifest keys, and both original logs remain. Adding the standard NativeTrack preload gives clean final exits. An automatic review rejected an initial broad localization snapshot restore; the completed update uses targeted description edits and exact guards against concurrent extraction changes. No approval remains pending.

The full localization check fails with 770 unrelated/current-catalogue diagnostics and is not a green release gate; an earlier broad extraction attempt reported 1,023 errors and was undone under an exact content guard. The Electric-specific packaged copy checks pass. No claim is made that all existing localization issues are fixed.

Commands actually run use the pinned engine through `scripts/dev.ps1`, with isolated task-owned APPDATA and an empty `BMT_API_URL`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_electric_brake_reverse.gd
# Also run with -Graphical -RenderingMethod gl_compatibility, and mobile.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_electric_one_pedal.gd -TestArgument '--evidence-root=res://../docs/evidence/electric-brake-reverse-2026-10-28/historical'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_electric_car_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--evidence-root=res://../docs/evidence/electric-brake-reverse-2026-10-28/game'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_electric_over_under.gd -TestArgument '--evidence-root=res://../docs/evidence/electric-brake-reverse-2026-10-28/driving'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestHandling
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
./.tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-brake-reverse-2026-10-28/verify_canonical.py
python scripts/localization.py extract
python scripts/localization.py check
python docs/evidence/electric-brake-reverse-2026-10-28/update_copy.py
python docs/evidence/electric-brake-reverse-2026-10-28/checkpoint.py
```

Raw logs, captures, exact before sources, replay, source hashes and the scoped review patch are under [the evidence directory](evidence/electric-brake-reverse-2026-10-28/report.json). Dev-wrapper generated build identities are excluded; concurrent work is not frozen. Client reload/rebuild, owner feel acceptance, a complete App rerun after the concurrent assets arrive, and matching backend/current Electric contracts remain before online use. No physical-device attachment query or device test, APK/AAB, real authentication/purchase, owner-save mutation, live submission/deployment, owner-process restart, main-index staging, commit or merge is performed.
