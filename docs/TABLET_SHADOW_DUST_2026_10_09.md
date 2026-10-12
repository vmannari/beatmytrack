# Tablet dust/shadow investigation - 2026-10-09

Requirements V04/V05/Q01/R01. Owner requests an alternative to disabling MSAA and suspects shadows. Existing MSAA dependency is measured; the exact root cause remains open. This follow-up isolates directional, projected contact, bridge and particle shadow paths with the same 2x MSAA/world budget and original dust shader. No shipping shadow removal is authorized by the diagnostic result alone; the intended final behavior retains clean dust, anti-aliasing and appropriate shadows.

Owned diagnostic source: `game/diagnostics/mobile_race_probe.gd`; before saved under `build/tablet-shadow-dust-2026-10-09/before/`. Canonical simulation, player data and backend are unchanged. Initial compile check passes; focused export import/startup/driving72/catalog21/menus48 passes. Physical OnePlus Pad 2 is attached/authorized and was unlocked at the first check. Native comparisons and replacement fix remain in progress.

Native shadow-isolation completed six stages, zero paused frames, actual MSAA2x(1) or4x(2) and original1.5MP scale. All retained large dust steps: normal20.115/25.122ms, directional-shadow-off20.253/25.226, projected-contact-off20.010/24.402, bridge-shadows-off20.310/25.107, particle-shadow-casting-off19.952/23.975, MSAA4x20.001/24.334. Screenshots and raw results are under `isolation/`; no shipping shadow change is made based on these rejected fixes.

Depth candidates preserve every original shader parameter explicitly. Frozen desktop capture verifies all five material bindings and canonical snapshots, with zero failures after correcting a snapshot Array type and explicitly sampling presentation dust in the physics-disabled fixture. Initial diagnostic failures are retained, not passed. Native depth candidates remain in progress.

Native depth candidates completed five stages with MSAA2x, all shadows, zero paused frames and confirmed billowing/texture bindings. Baseline19.921/p9524.569ms retains steps; fragment-depth20.104/25.264 and explicit vertex-depth19.917/24.074 retain them. Removing soft fade19.924/25.243 creates visible bridge checkerboarding and is rejected. **Writing DEPTH=FRAGCOORD.z retains soft fade and removes the bands/checkerboarding**, median19.888/p9525.298ms. Actual-driver early-depth interaction is an inference; explicit fragment-depth behavior is directly measured. Evidence: `depth-candidates/driving-4.png` and results.json.

Shipping correction: restore the original project MSAA setting (remove desert Adreno MSAA-off branch from Game), and add explicit fragment-depth output only to Adreno/mobile/Compatibility dust materials. depth_draw_never remains, and no density/lifetime/geometry/shadow/camera/canonical parameter changes. Presentation dust identity11. Final TestDesert87 and render481 pass. Frozen desktop capture/state/binding checks pass after explicitly snapping the diagnostic camera; earlier blank framing is not evidence of a visual pass. Temporary concurrent NightAmbience class-cache and Windows extension-copy failures resolved after Import; existing project edits were preserved. Final export/install/native confirmation in progress.

## Final installed confirmation

The replacement exported with focused import/startup/driving72/catalog21/menus48 checks and installed **Success** on authorized OnePlus Pad 2 f0ba474a. APK **243,124,166 bytes**, SHA-256 **0D50749AD8A450603AE57340314B30984D75FC10C1EA4F0885C8A1FB013F46BF**. Two ordinary baseline stages of the final installed build confirm **actual MSAA2x(1), directional shadows enabled, billowing/texture bindings present, zero paused frames and the unchanged world budget**. Medians **19.866 /19.857ms**, p95 **24.570 /24.920ms**, approximately50FPS; no locked60FPS claim. [Final raw results](evidence/tablet-shadow-dust-2026-10-09/final-installed/results.json), [car/cloud](evidence/tablet-shadow-dust-2026-10-09/final-installed/driving-0.png), [second drive](evidence/tablet-shadow-dust-2026-10-09/final-installed/driving-1.png). Inspected native images show no large dust bands. The controlled candidate [bridge comparison](evidence/tablet-shadow-dust-2026-10-09/depth-candidates/driving-4.png) additionally shows retained bridge occlusion without checkerboarding, while the rejected no-fade candidate does not.

Runner cleanup completed; ADB confirms no files/mobile_probe.json and a running normal app process. Records, sessions and authored tracks were preserved. This is a local Android debug update, no backend/production rollout. Other Adreno devices, longer thermal soak, all camera modes/vehicles/tracks and owner visual acceptance remain outside these short measurements.

## Actual commands and review scope

All engine actions used pinned scripts/dev.ps1 and matching4.7.2 templates:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://diagnostics/mobile_race_probe.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestDesert
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_tablet_render_budget.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_dust_depth_candidates.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action ExportAndroid -QuickValidation
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-tablet.ps1 -DeviceSerial f0ba474a -DocumentPath game/tests/fixtures/dust_cloud.json -Seconds 18 -Features msaa_2x,msaa_2x_shadows,msaa_2x_contact_lighting,msaa_2x_bridge_shadows,msaa_2x_particle_shadows,msaa_4x -CaptureDriving -Output docs/evidence/tablet-shadow-dust-2026-10-09/isolation -Install
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-tablet.ps1 -DeviceSerial f0ba474a -DocumentPath game/tests/fixtures/dust_cloud.json -Seconds 18 -Features msaa_2x,msaa_2x_fragment_depth,msaa_2x_vertex_depth,msaa_2x_no_fade,msaa_2x_late_depth -CaptureDriving -Output docs/evidence/tablet-shadow-dust-2026-10-09/depth-candidates -Install
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-tablet.ps1 -DeviceSerial f0ba474a -DocumentPath game/tests/fixtures/dust_cloud.json -Seconds 18 -Features baseline,baseline -CaptureDriving -Output docs/evidence/tablet-shadow-dust-2026-10-09/final-installed -Install
```

Shipping changes: game/core/game.gd removes the temporary MSAA-off condition; game/vehicle/sand_dust.gd adds the scoped explicit fragment-depth output and presentation identity11. Diagnostics extend game/diagnostics/mobile_race_probe.gd; excluded desktop witness game/tests/capture_dust_depth_candidates.gd (+UID), reports/status/phase notes and evidence. No shadow shader, canonical simulation, rules, track data, dust asset/density/lifetime, HUD, camera framing or world-budget change. Native debug diagnostics require the existing local debug marker and do not appear in player UI.

Task-only review patch, source/binary hashes and preserved APK: build/tablet-shadow-dust-2026-10-09/. Extensive concurrent project changes are preserved and excluded from this patch. No combined Git commit/merge. Existing Thread cleanup warning from focused startup retained; full Validate/replay suite not run for this presentation-only correction.
