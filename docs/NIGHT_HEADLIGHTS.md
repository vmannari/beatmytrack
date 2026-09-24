# Night headlights — 2026-09-24

Requirements V02/V04/V05/Q01; owner requested optimized night-biome headlights and a physical mobile test.

Night races/practice enable lamps on the selected vehicle. All five vehicles have model-specific mounts; the compact retains its four round lenses and the classic its round lamps. One shared, warm-white SpotLight3D illuminates actual road/scenery surfaces, with a 22 m local range, 34-degree cone and downward aim. Lens geometry shares one unshaded material and is batched into one mesh. No shadows, transparent beam meshes, particles, volumetrics, extra render targets or per-frame script work. The light inherits body movement/suspension. Daytime and menu cars allocate no headlight nodes. Existing mobile night render scale remains 0.55. Canonical simulation, camera and track contracts are unchanged.

Changed files: `game/vehicle/car_visual.gd`, `game/core/game.gd`, `game/diagnostics/mobile_race_probe.gd`, `game/tests/test_headlights.gd` and UID, `scripts/dev.ps1`, `scripts/profile-features-phone.ps1`, status/plan and this report/evidence. All geometry/materials are original code-authored assets; no external assets or dependencies.

Actual commands (pinned Godot 4.7.2 through the build entry point):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestHeadlights
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureHeadlights
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestBiomes
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestVehicleBatch
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action ExportAndroid -QuickValidation
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/profile-features-phone.ps1 -HeadlightsProfile -Seconds 30 -ReportName headlights-phone-2026-09-24
```

Results: headlights 31 headless and 31 graphical checks; biomes 107; vehicle batching 35; quick export driving 74, catalog 18 and menus 22 checks, all zero failures. Headless headlights/driving emitted two ObjectDB shutdown leak warnings; graphical headlights did not. Full-project regression not run; no physics change. Desktop [on](evidence/headlights-2026-09-24/on.png), [off](evidence/headlights-2026-09-24/off.png) and [phone driving](evidence/headlights-2026-09-24/phone-driving.png) captured and inspected.

Physical test: attached DN2103, Android debug APK installed successfully. Automated same-track off/on/off/on stages use the production render scale, AI driving, real HUD, touch stress and normal street lamps. Each stage warms five seconds, then samples thirty seconds. The initial off stage was paused during Android startup (zero driven metres/zero simulated seconds); it is retained in raw evidence but excluded from moving comparisons. Phone screenshots confirm forward road illumination during driving. Raw reports, configuration, APK hash and battery readings are in `evidence/headlights-phone-2026-09-24/`.

| Moving stage | Median frame | p95 frame | Distance |
|---|---:|---:|---:|
| Headlights on | 16.659 ms | 20.124 ms | 311.7 m |
| Headlights off | 16.779 ms | 20.513 ms | 327.2 m |
| Headlights on (repeat) | 16.682 ms | 20.111 ms | 328.3 m |

No measurable frame-time regression in these moving samples; the small apparent improvement is run-to-run variation, not a claimed speedup. Battery sensor temperature went from 27.4 to 29.7 C. The final APK remains installed; the script removed diagnostic markers and relaunched normal play. The [final phone screenshot](evidence/headlights-phone-2026-09-24/night-phone.png) was captured after sampling, with the probe paused, and inspected.

Acceptance limits: shadow-free lighting can pass through nearby occluders; this deliberately avoids moving shadow-map cost. No fleet test, long thermal soak or exhaustive bridge/rollover/all-vehicle phone visual acceptance. Owner review of beam strength/reach remains. A median near 60 FPS does not guarantee every frame meets 16.67 ms.

## Wider near beam follow-up

Owner requested a wider beam from its beginning to suggest two overlapping headlights. Requirements V02/V04/V05/Q01. The virtual cone origin moves back up to 1.5 model metres, bounded to 80% of the nose distance for shorter vehicles. Angular falloff softens from 1.8 to 1.2. This gives width at the bumper while retaining one light, the same angle/range and no per-frame work. Lens positions remain at the actual lamps.

Changed runtime file: `game/vehicle/car_visual.gd`; this report, status/plan and `evidence/headlights-wide-2026-09-24/` document the revision. [Before](evidence/headlights-wide-2026-09-24/before.png) and [after](evidence/headlights-wide-2026-09-24/after.png) desktop evidence inspected. Initial fixed setback failed the existing kart forward-origin check; vehicle-size bounding corrected it. Final `CaptureHeadlights` passes 31 checks. `ExportAndroid -QuickValidation` passes driving 74, catalog 18 and menu 22 checks and exports the updated APK. Existing two ObjectDB shutdown warnings occur in driving tests. Commands use the same `scripts/dev.ps1` entry point as above.

Physical follow-up command: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/profile-features-phone.ps1 -HeadlightsProfile -Seconds 15 -ReportName headlights-wide-phone-2026-09-24`. This is a short device sanity comparison, not a thermal soak or an old/new beam benchmark. Beam appearance remains subject to owner review.

The attached DN2103 was initially locked; owner unlocked it and all four stages completed. Excluding the startup stage, moving headlights-on medians were 16.732/16.789 ms (p95 20.296/20.198), versus off 16.760 ms (p95 20.170). Each of these stages drove approximately 165 m. No material difference observed; occasional missed 60 FPS frames remain. Updated APK installed, diagnostic files removed and normal play restored. [Phone capture](evidence/headlights-wide-phone-2026-09-24/night-phone.png) inspected; full raw evidence retained beside it.

## Faint rear lights

Owner requested faint red rear lights. Requirements V02/V04/V05/Q01. Existing rear-lamp materials now emit red at 0.32 energy at night and 1.0 under braking; brake release restores the faint running light. Daytime emission is disabled. Material writes occur only when brake/night state changes. There are no extra dynamic lights, shadow maps, transparent glow passes or road-light projections. Compact, pickup, classic and Formula reuse existing lenses; the kart gains two small rear lenses (24 triangles, one batched mesh).

Changed files: `game/vehicle/car_visual.gd`, `game/vehicle/vehicle_models.gd`, `game/tests/test_headlights.gd`, this report, status/plan and evidence. Actual commands through `scripts/dev.ps1`: `CaptureHeadlights` passes 51 checks, including all-five-car night/brake/release/day transitions; `TestVehicleBatch` passes 35; `ExportAndroid -QuickValidation` passes driving 74, catalog 18 and menu 22 checks. Existing two ObjectDB shutdown warnings remain in driving tests. [Running lamps](evidence/taillights-2026-09-24/running.png) and [braking](evidence/taillights-2026-09-24/braking.png) desktop screenshots inspected. Owner acceptance of faintness and all-vehicle phone appearance remains; full regression/thermal soak not run.

Phone command: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/profile-features-phone.ps1 -HeadlightsProfile -Baseline -Seconds 20 -ReportName taillights-phone-2026-09-24`. This exercises the complete night-lighting setup, not an isolated taillight cost comparison.

Updated APK installed and tested on attached DN2103: 213.6 m driven, median 16.785 ms, p95 20.511 ms. Near-60 median with occasional missed frames; no new isolated overhead claim. [Phone capture](evidence/taillights-phone-2026-09-24/night-phone.png) inspected (side view; desktop rear views above demonstrate the running/braking difference). Diagnostic markers removed and normal play restored.
