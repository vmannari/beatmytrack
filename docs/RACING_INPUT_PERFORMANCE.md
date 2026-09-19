# Racing HUD and touch performance — 2026-09-18

Requirements: R01/G01/V03/V05/Q01 and the owner's continued random, possibly speed-related stutter report. Attached DN2103 / Android 13 / Mali-G77 MC9; pinned Godot 4.7.2.

## Reproduction and correction to earlier acceptance

The previous Ajorata probe ran the timed validator inside an editor-practice HUD, hiding the ordinary race cards, and did not generate touch input. Its smooth display trace did **not** establish smooth ordinary racing. The diagnostic driver also topped out at about 12 m/s (43 km/h), below fast human racing.

With the **full racing HUD and two held/moving simulated fingers**, the current shipping code reproduced substantial stutter: 740 of 2,901 actual-present intervals exceeded 25 ms over 61.32 seconds. Display p95 was 33.738 ms, p99 33.816 and maximum 50.694. Internal process median was 23.543 ms; controls rebuilt their artwork 4,566 times in 95 seconds. The test remains unscored and cannot save an AI PB.

The first fix retained controls while their pressed mask stayed unchanged. Identical workload: 1/3,634 displayed intervals over 25 ms in 61.19 seconds, p99 17.033 ms. Internal process median fell to 12.867 ms, with only two control redraws over 95 seconds.

## Final implementation

- `game/ui/touch_controls.gd`: immediate touch ownership/hit-testing is preserved. Observe the four pressed states once per rendered frame, including keyboard, cancelled touch and external input clear. Input events no longer rebuild drawing commands.
- `game/ui/touch_control_art.gd`: retain each button's pressed and released vector artwork separately. Prepare both during the countdown; switch opacity on transitions, avoiding hide/show invalidation of Godot's cached drawing commands. Resize/style changes still rebuild the geometry. Transparent inactive variants contribute no visible artwork.
- `game/tests/test_mobile_controls.gd`: check held drag reuse, every pressed combination, external clear and keyboard changes. The graphical suite has 689 checks; the existing headless hit-area/multitouch suite has 555.
- `game/diagnostics/mobile_race_probe.gd`: instantiate the real race HUD, simulate held or frequently changing controls, and record speeds plus artwork rebuild counts. Probe results are kept separate from PBs; choosing Ajorata may update the last-selected-track preference.
- `game/input/route_driver.gd`: optional diagnostic speed multiplier, default 1.0, for faster device stress. Human controls, handling constants, canonical simulation, collision geometry and camera remain unchanged.

Retained artwork uses the original draw transforms. Twenty exact image comparisons (all five vehicle skins, four input masks each) match the previous artwork byte-for-byte. An initial per-node transform implementation had small antialiasing differences; it was corrected before the final build. The comparison harness and baseline source snapshot are under `build/racing-pacing/`; before/after captures are retained as evidence.

## Device and test evidence

First retained-art high-speed stress (diagnostic speed multiplier 2.5, alternating steering four times per second plus accelerator/brake changes): 7,202 actual-present intervals over 121.27 seconds, median 16.833 ms, p99 17.055, maximum 33.669, two intervals over 25 ms. This intermediate build preceded the exact-art-transform correction. Final installed-build measurements follow below.

That 185-second intermediate run covered 3,259 m and completed seven laps, with median speed 65.44 km/h and maximum 98.15 km/h. All eight artwork variants were built once: eight total artwork draws throughout the run despite frequent button changes. This addresses the speed coverage missing from the previous conservative test.

Final build checks: headless controls 555/555; graphical controls 689/689; artwork comparisons 20/20 byte-identical; export's focused checks (startup/import, driving 70, catalog 18, menus 11) pass; install and launch succeed. Final APK SHA256: `67D497AA270C5EC1CB623296309D7B1228EEBD0D6FE8DB5DBCE8135336D24961`.

**Final installed build, speed multiplier 3.0:** 185 seconds including warmup; seven laps / 3,376 m driven, median 67.16 km/h and peak 105.38 km/h. Eight initial artwork draws, no subsequent artwork rebuilds. The clean actual-present collection spans 141.41 seconds / 8,398 intervals: median 16.833 ms, p95 16.971, p99 17.049, maximum 33.702, **three missed refreshes**. Thus a major source of the reproduced stutter is removed, but this is not a claim of perfectly uninterrupted rendering. Internal process median is 14.177 ms under the faster workload.

[Final game metrics](evidence/racing-input-performance/fast-final.json), [final display metrics](evidence/racing-input-performance/present-final.json), [phone screenshot after the diagnostic run](evidence/racing-input-performance/device-race.png). The screenshot's 10,000-lap target is diagnostic-only; ordinary races remain five laps. No screenshot was taken during final display sampling.

The diagnostic marker was removed and the app relaunched normally. Tracks, drafts and PBs are preserved. The owner repeated Ajorata driving and reported **"Noticeably smoother"**. This confirms the improvement in actual use; the three rare missed refreshes above remain a measured limitation, and broader tracks/devices/long sessions are not accepted by this one report.

Evidence: [ordinary race baseline](evidence/racing-input-performance/full-hud-baseline.json), [baseline display trace](evidence/racing-input-performance/present-baseline.json), [first fix display trace](evidence/racing-input-performance/present-cached.json), [intermediate fast race](evidence/racing-input-performance/fast-intermediate.json), [original artwork](evidence/racing-input-performance/art-before-9.png), [retained artwork](evidence/racing-input-performance/art-after-9.png).

Commands actually used:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestMobileControls
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path game --script res://tests/test_mobile_controls.gd
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path game --script 'C:/Codes/Godot/Beat my track/build/racing-pacing/compare_controls.gd'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 DeployAndroid -QuickValidation
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile_android_frames.ps1 -Seconds 120 -Output build/racing-pacing/present-fast
```

Probe marker: `{"track_id":"track_acf29166cceaaa42","seconds":180,"sustained":true,"touch_stress":true,"alternate_controls":true,"speed_scale":2.5}`. Stress inputs update the real controls but the AI supplies canonical input, so artwork changes do not deliberately crash the car. This does not reproduce the entire Android touch dispatch stack or replace owner driving acceptance.

Full app validation still has the previously documented stale navigation/model-count failures. This presentation-only pass does not change those assertions or claim that suite passed. A bounded test cannot promise zero stutters on every circuit, temperature or device. The earlier practice-only result is superseded by the ordinary-race workload above.
