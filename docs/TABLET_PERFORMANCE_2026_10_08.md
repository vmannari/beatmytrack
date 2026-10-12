# OnePlus Pad 2 performance optimization ? 2026-10-09



Requirements **Q01/V03/V05/G01/R01**. Native USB measurements on the unlocked OnePlus Pad 2 verify a substantial improvement on the same Ajorata practice drive: original workload approximately **118 ms/frame (8.5 FPS)**, pixel-budget candidate **63 ms (16 FPS)**, and specialized terrain shaders **19.6 ms (51 FPS)**. This is roughly **six times faster** overall. Final shader comparison p95 is **24.05 ms**; sustained locked 60 FPS and the strict 20 ms tail target are not established.



The fixed biome flags are compiled as shader constants, permitting unused shader paths to be eliminated. Terrain sampling, shadows, lighting and visible detail remain intact. At matching resolution and frozen pose, specialized and dynamic shader desktop PNG files are byte-identical (SHA-256 F9CBED137E744DA9441FE8F98D96CFDB9AD03B00ADF312755448F67C999D9330). The likely GPU cause is unnecessary shader paths/register pressure; this mechanism is an inference, while the frame-time improvement is measured.



## Device results



All comparisons use the same unscored document, countdown, warmup and native 3000?2120 output; accepted stages have zero paused frames and matching requested/applied scale.



| Run | Median frame ms | p95 ms |

| --- | ---: | ---: |

| Original workload, first bracket | 117.590 | 120.717 |

| Pixel budget/dry lookup | 62.401 | 75.606 |

| Original workload, second bracket | 117.893 | 120.162 |

| Dynamic terrain shader, first bracket | 63.074 | 72.607 |

| Specialized terrain shader | 19.607 | 24.050 |

| Dynamic terrain shader, second bracket | 62.546 | 71.604 |



Raw evidence: [original comparison](evidence/tablet-performance-2026-10-08/phone-pine-retry/results.json), [feature isolation](evidence/tablet-performance-2026-10-08/phone-pine-isolation/results.json), [shader comparison](evidence/tablet-performance-2026-10-08/phone-shader-specialization/results.json). The first retry produced three valid stages but the collector miscounted a nested JSON array; the collector was corrected before subsequent successful runs. The earlier locked-tablet 0/3 attempt is retained as a failure, not usable timing evidence.



Disabling shadows or flattening terrain brought the pixel-budget build to approximately 20 ms; disabling roads, particles or audio did not materially improve its 63 ms median. Shader specialization achieves that gain while retaining appearance. Disabling backdrop shadow casting and hiding an occluded backdrop gave no meaningful gain; both production experiments were removed. Their raw evidence remains under phone-backdrop-casting and phone-hidden-backdrop.



## Candidate changes



- The previous mobile scale of `0.667` scales with physical screen area. At the tablet's measured **3000Ã—2120** landscape output it requests about **2.83 million 3D pixels**. The candidate caps the world buffer at **1.50 million pixels**, giving a scale of about **0.48564** and **47% fewer requested 3D pixels**. The corresponding measured gain is shown above. Smaller phones retain their existing scale when below budget, and the existing night cap remains. Native Canvas/HUD resolution, camera projection, speed zoom, car/track size and collision geometry are unchanged. Resize updates the budget; leaving a race disconnects its resize callback and restores the previous viewport scale.

- A race caches whether its actual ground raster contains water or shallow-water cells. Dry maps skip the presentation-only 81-sample/bilinear depth calculation. Wet maps call the original calculation unchanged. Canonical water physics, surface sampling and simulation are not modified. The final desktop lookup probe measured about **217.082Âµs original / 0.212Âµs cached** for this particular dry-depth lookup; these numbers do not represent whole-frame or tablet performance.

- The existing debug-only, unscored mobile profiler now has isolated document input, audio/music controls, previous-workload replay and finer water/audio/contact/history costs. It records the actual applied scale and rejects paused or overridden-scale results. Every measured stage uses the same standing/countdown setup. Its temporary screen-awake flag is restored afterward. The runner selects the explicit tablet, rejects a locked screen before creating its marker, keeps diagnostics out of authored-track storage, preserves existing diagnostic results and restores ordinary play. No new player-facing controls or labels were added.



Godot documents that [3D resolution scaling reduces GPU workload without changing 2D rendering](https://docs.godotengine.org/en/4.7/tutorials/3d/resolution_scaling.html). The tradeoff is softer world detail; native HUD text and controls are retained. The [Viewport API](https://docs.godotengine.org/en/4.7/classes/class_viewport.html#class-viewport-property-scaling-3d-scale) defines the scale; the diagnostic-only awake flag uses [DisplayServer](https://docs.godotengine.org/en/4.7/classes/class_displayserver.html#class-displayserver-method-screen-set-keep-on). No renderer switch, new dependency or asset/audio-bank revision was made by this task.



## Actual checks and evidence



Pinned engine/templates: `4.7.2.stable.official.ed1daf0bf` / `4.7.2.stable`. Windows graphical checks use the existing RTX 3090/Compatibility renderer, not the tablet GPU.



| Actual check | Outcome |

| --- | --- |

| Tablet budget regression | Final **479 checks, zero failures**; earlier headless/graphical revisions **477/477**, zero failures |

| Camera modes and speed zoom | **1499 checks, zero failures** |

| Soil/water | **163 checks, zero failures** |

| App flows | **99 checks, zero failures** |

| Project script parsing | **384 scripts, zero failures** at that run |

| Debug probe compile check | Passed, including the later screen-awake/countdown corrections |

| Focused export checks | Import/startup plus driving **72**, catalog **21**, menus **48**, zero failures on completed candidate exports |

| PowerShell runner syntax | Passed on the checked revisions |

| First tablet profile | **Failed: 0/3 stages**, no timing series; install returned **Success**, cleanup/restoration completed |



The desktop budget regression checks native viewport/HUD dimensions, unchanged projected world points, dry/wet depth equality including shoreline/bounds, and viewport restoration. These functional checks complement the native measurements above. The headless race fixtures retain the existing **31-instance shutdown leak warning**. No failing assertion was removed or relaxed. Full Validate/full replay regression was not run; canonical simulation source and versions were not changed by this task.



The final focused startup smoke also emitted a Thread cleanup warning while exiting; its `APP_READY`, zero-failure checks and exit status are retained separately from that warning. This has not been diagnosed as a tablet bottleneck or reported as a clean shutdown.



Inspected same-state **3000Ã—2120** desktop captures: [previous workload](evidence/tablet-performance-2026-10-08/desktop-review/previous.png), [candidate](evidence/tablet-performance-2026-10-08/desktop-review/candidate.png). Captures verify the applied getter values `0.6669999957` and `0.4856429398`; the inactive countdown overlay was removed from this diagnostic still. These images are desktop visual review, not tablet screenshots or owner visual acceptance.



The [earlier desktop race-start trace](evidence/tablet-performance-2026-10-08/desktop-before/) ran moving/stationary/moving Ajorata passes. It showed startup stalls and relatively small steady CPU sections on that PC; it cannot identify the tablet's GPU/CPU bottleneck. The [failed tablet configuration and logs](evidence/tablet-performance-2026-10-08/phone-pine-first/) are retained separately. Android window policy subsequently reported `showing=true`, `secure=true`, `mIsShowing=true`, with NotificationShade covering the focused game. Normal keyguard dismissal could not replace the owner's required unlock; no PIN or security setting was changed.



## Actual commands



All engine actions run through the pinned project entry point:



```powershell

powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ProfileRaceStart -Track track_acf29166cceaaa42 -CommandTimeoutSeconds 180

powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CheckScript -ScriptPath res://diagnostics/mobile_race_probe.gd

powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_tablet_render_budget.gd

powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_tablet_render_budget.gd -Graphical

powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestCameraModes

powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestSoil

powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestApp

powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_script_parse.gd

powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/capture_tablet_budget.gd -Graphical -CommandTimeoutSeconds 180

powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ExportAndroid -QuickValidation -CommandTimeoutSeconds 600

powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-tablet.ps1 -DeviceSerial f0ba474a -DocumentPath game/tests/fixtures/ajorata.json -Seconds 12 -Features previous,baseline,previous -Output docs/evidence/tablet-performance-2026-10-08/phone-pine-first -Install

```



ADB checks additionally used device enumeration, battery/thermal dumps, process-filtered logcat, normal wake/dismiss-keyguard/statusbar collapse, and window/power policy checks. The first attempted patch used an incorrect context line and was rejected without changing the file; the correct patch and subsequent compiler checks passed. The first export supplied profiling instrumentation; later exports supplied the rendering candidate. The original deployed APK and profiling baseline are retained privately under ignored `build/tablet-performance-2026-10-08/`.



## Files and remaining acceptance



Changed runtime source: `game/core/game.gd`; debug diagnostics: `game/diagnostics/mobile_race_probe.gd`; tooling: `scripts/profile-tablet.ps1`; excluded checks/review: `game/tests/test_tablet_render_budget.gd`, `game/tests/capture_tablet_budget.gd` and their generated UIDs; this report, status/phase notes and evidence. Existing concurrent audio, UI, backend and player files are preserved. There was no cloud rollout, backend/schema change, purchase/ad action or new asset/license acquisition.



Remaining acceptance: longer thermal soak, heavier biome/device coverage, touch feel and owner assessment of world sharpness. Current timings are Godot frame intervals, not independent SurfaceFlinger presentation measurements. The measured significant improvement is established for the tested drive; strict 60 FPS/tail acceptance remains open.

Additional changed files: `game/track/native_track_visual.gd`, `game/track/surface_shader_variants.gd` and UID, and `game/diagnostics/surface_material_probe.gd`. Shader variants use trusted project includes and a bounded cache; no runtime network dependency. TestBiomes: 107 checks, five existing New/fresh-identity failures reproduced with both preserved before-task runtime sources, retained in `biomes-original-baseline.txt`.

Successful native commands used `scripts/profile-tablet.ps1 -DeviceSerial f0ba474a -DocumentPath game/tests/fixtures/ajorata.json -Seconds 12 -Features terrain_dynamic,baseline,terrain_dynamic -Output docs/evidence/tablet-performance-2026-10-08/phone-shader-specialization`, and analogous baseline/shadows/terrain_flat/road_flat/particles/audio/baseline isolation. Final cleaned-source TestScript returned 479 checks, zero failures (dry lookup201.45us versus0.202us).

## Final installed build and confirmation

Cleaned production sources exported successfully with the pinned templates and focused startup/driving72/catalog21/menus48 checks. APK **241,126,237 bytes**, SHA-256 **E385B66EECD1F0415B19931B43406ACAC507C556EE8EB38154FCA4311B9EEAB2**. Install returned Success. Final `baseline,render_40,baseline` device run completed all three stages: median **20.533 / 19.817 / 20.046 ms**, p95 **26.489 / 24.316 / 24.699 ms**. The smaller world buffer gave little additional benefit; production retains the 1.5MP budget. [Final raw results](evidence/tablet-performance-2026-10-08/phone-final/results.json) and [native driving screenshot](evidence/tablet-performance-2026-10-08/phone-final/driving.png) are retained. Native screenshot inspected: vehicle, shadows, terrain, camera and sharp HUD remain visible.

Actual final command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-tablet.ps1 -DeviceSerial f0ba474a -DocumentPath game/tests/fixtures/ajorata.json -Seconds 12 -Features baseline,render_40,baseline -Output docs/evidence/tablet-performance-2026-10-08/phone-final -Install`. Final ADB check confirms no `files/mobile_probe.json` and a running ordinary app process. Records, authored tracks and sessions are preserved. Final build/test/install logs are in `final-clean-build/`.

Task-only review checkpoint: `build/tablet-performance-2026-10-08/scoped-change.patch`, source hashes and binary manifest. This isolates the optimization from extensive unrelated workspace changes; no Git commit/merge was performed.
