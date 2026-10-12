# Tablet desert dust correction - 2026-10-09

Requirements **V04/V05/Q01/R01**. The owner reported blocky dust around the car and under bridges on the OnePlus Pad 2. Native screenshots reproduce large tiled intersections while Windows does not show them. A controlled tablet comparison isolates an **MSAA-dependent rendering artifact**: disabling MSAA removes the large tiles while retaining dense, lingering dust. A driver/Compatibility depth-resolve problem is the leading inference; the experiment establishes the MSAA dependency, not the precise driver implementation fault.

## Correction

`game/core/game.gd` selects single-sample rendering during **desert races on mobile Adreno hardware using Compatibility**, and restores the entry MSAA setting on race exit. All other profiles retain their entry setting. The existing 1.5MP world budget, native HUD, camera projection, simulation and dust density/lifetime remain intact. The original `sand_dust.gd` is byte-identical to the saved before source: SHA-256 FDA9B16719C9DA64E5B69BA65B2B717ED5B8DEA89711A4452B25C1BD65B1ED7D. No dust shader/asset/physics version change ships.

Single-sample rendering can make geometry silhouettes slightly less antialiased. The tablet screenshot shows smooth dust and a readable car. Four-sample MSAA was queued for comparison but USB debugging went offline before installation. FXAA is not a supported alternative in this renderer, according to [Godot's renderer table](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html#antialiasing); no FXAA setting ships.

## Actual evidence

| Tablet comparison | Median / p95 ms | Visual result |
| --- | --- | --- |
| Original dust, before | 20.123 / 25.876 | Tiled intersections reproduced |
| Explicit precision only | 20.393 / 26.105 | Tiles remain |
| Explicit base LOD / declared linear filter | 19.932 / 26.061 | Tiles remain |
| Manual four-texel depth interpolation | 20.016 / 25.390 | Tiles remain |
| Isolation baseline with MSAA | 20.008 / 25.945 | Tiles remain |
| Same shader, MSAA disabled | 19.899 / 25.542 | Large tiles absent |

[MSAA baseline](evidence/tablet-dust-2026-10-09/depth-isolation/driving-0.png), [MSAA disabled](evidence/tablet-dust-2026-10-09/depth-isolation/driving-1.png), [raw timing report](evidence/tablet-dust-2026-10-09/depth-isolation/results.json). Every accepted diagnostic drive has zero paused frames and matching scale. These are unscored practice fixtures; records/sessions/authored tracks are preserved and ordinary play restored after each completed run. Screenshot capture adds occasional diagnostic overhead; these short runs do not prove thermal soak or locked60FPS.

The isolation run also attempted fragment-depth and no-fade shader replacements. Those screenshots are **not controlled visual comparisons**: replacing the Shader resource changed material bindings. These two modes were removed. Precision/filter candidates were also removed. All rejected evidence remains for audit rather than being reported as a pass.

## Validation and files

Pinned Godot/templates **4.7.2.stable.official.ed1daf0bf /4.7.2.stable** through `scripts/dev.ps1`. TestDesert: **87 checks, zero failures**, including five-car deterministic replay. Final rendering regression: **481 checks, zero failures**, including viewport MSAA restoration, native HUD/projection, water equality and pixel budget. Focused exports pass import/startup/driving72/catalog21/menus48. Existing31-instance shutdown warning retained. Full Validate/replay suite not run for this presentation-only change.

Owned runtime change: `game/core/game.gd`. Diagnostics: `game/diagnostics/mobile_race_probe.gd` (isolated MSAA2x/4x/off modes, actual adapter/renderer/MSAA reporting), `scripts/profile-tablet.ps1` (optional per-stage foreground captures). Regression: `game/tests/test_tablet_render_budget.gd`. `scripts/dev.ps1` uses the validated res:// test path: its intervening absolute-path invocation returned no checks; using the validated project path executes all481. This report/status/phase notes and evidence complete the task scope; concurrent edits are preserved.

Actual commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestDesert
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_tablet_render_budget.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://diagnostics/mobile_race_probe.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action ExportAndroid -QuickValidation
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-tablet.ps1 -DeviceSerial f0ba474a -DocumentPath build/tablet-dust-2026-10-09/desert.json -Seconds 18 -Features baseline,msaa_off,dust_raw_depth,dust_no_fade -CaptureDriving -Output docs/evidence/tablet-dust-2026-10-09/depth-isolation -Install
```

The last command records the historical diagnostic modes, two of which were rejected as described above. The desert document is an ignored local copy of Ajorata with only its biome changed; it is not added to the shipping catalog. An attempted AA-isolation run failed before installing/creating a diagnostic marker because ADB reported offline. `adb reconnect offline` did not recover a usable transport; reconnection/unlock was requested from the owner. Final scoped-build installation and native under-bridge acceptance remain pending USB recovery. Other Adreno devices, longer driving/thermal tests and owner edge-quality acceptance remain unverified.

Prepared APK: 241140060 bytes, SHA-256 0bc38962383e7350ff5ebebd961dd7bebd3dfa3b8d24b7b2d9d008518bb3c6cd. Final export successful; this build is not yet installed. Task-only review patch/source hashes: `build/tablet-dust-2026-10-09/`. No combined Git commit/merge.

## Installation completed after USB recovery

Owner requested another retry; ADB now reports device/authorized. The latest checked workspace APK (including the dust fix and later authorized updates) installed with **Success** via `scripts/dev.ps1 -Action InstallAndroid -DeviceSerial f0ba474a` and launched with **Status: ok** via LaunchAndroid. SHA-256 **84D361FD882CC0F28E7D58EBA7DF8CA2C3FA1E372BE80258441AE98B2066863C**, 241155846 bytes. Running app process confirmed and `files/mobile_probe.json` absent. Records/sessions/authored tracks retained by in-place update. [Deployment metadata and logs](evidence/tablet-dust-2026-10-09/final-installed/deployment.json).

The short final dust-cloud/bridge diagnostic was attempted but rejected before marker creation because the tablet was securely locked. Installation is complete; final installed-build foreground/under-bridge visual acceptance remains pending unlock. Earlier unlocked physical-device MSAA-isolation evidence remains valid for that tested build. No new visual/performance pass is claimed for this locked launch.

2026-10-09 follow-up: the owner requested a fix preserving anti-aliasing and suspected shadows. The temporary MSAA-off profile is superseded by a native-tested explicit-fragment-depth dust correction with MSAA and all shadows retained. See [shadow/depth investigation](TABLET_SHADOW_DUST_2026_10_09.md) for controlled comparisons and current deployment status.
