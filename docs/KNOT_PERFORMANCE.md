# Knot mobile stutter — 2026-09-25

Requirements: R01 / V04 / V05 / Q01. Owner reports occasional stutter on Knot, with no clear pattern and no association with collisions.

## Findings and changes

Android steering haptics called the vibrator service synchronously from touch handling. A controlled phone comparison with four new steering presses per second reproduces frame stalls without collisions. Android requests now run through one bounded WorkerThreadPool task. A busy request drops additional feedback pulses rather than blocking driving or accumulating a queue; a completed task is reaped at the next request. Pulse duration and selected strength are unchanged. iOS retains its previous path and was not tested.

The pinned engine's [Input implementation](https://github.com/godotengine/godot/blob/4.7.2-stable/core/input/input.cpp#L1227) forwards handheld vibration directly to the platform. Its [Android wrapper](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/java_godot_wrapper.cpp#L438) obtains the calling thread's JNI environment and uses a global Java reference. The worker touches no scene-tree or canonical simulation state. A debug-only synchronous switch permits the same-APK comparison.

Knot also contains 85 tyre stacks. The tyre solver now exits after its existing broadphase and swept-car checks when every stack is stationary, all candidate pairs are separated, and the car cannot touch a stack. Overlapping piles and moving/contacting stacks retain the complete solver. Exact state equivalence passes 13,200 comparisons against the frozen reference, including ten added 85-stack scenarios. A five-repeat desktop benchmark against the immediate pre-change source measured 373.253 → 298.607 microseconds per stationary 85-stack tick, about 20% less CPU for this specific workload. This is not a 20% FPS claim. Handling/rules versions are unchanged because the optimization preserves results.

The old mobile probe incorrectly generated a new touch-down every rendered frame. After haptics were introduced, this flooded the vibrator service. The corrected probe uses down/drag/up events and alternates steering at four presses per second only when explicitly configured. It also accepts an arbitrary local track ID. Original diagnostic results are retained, but are **not representative normal-driving baselines**.

## Physical phone comparison

Attached DN2103 / OnePlus Nord 2, Android 13, Mali-G77 MC9, pinned Godot 4.7.2 debug APK, production 0.667 rendering scale. Knot ID `track_1e3936d025fe7c82`. AI drives the real simulation, HUD receives synthetic alternating touches, and records are not saved. Each stage warms for five seconds then samples 30 seconds. Haptic test amplitude is 0.2; saved user settings are not modified.

| Mode | Frame median | p95 | Frames >33.34 ms |
|---|---:|---:|---:|
| Original synchronous vibration | 16.024 ms | 44.667 ms | 184 |
| Worker vibration | 16.607 ms | 20.613 ms | 0 |
| Vibration off | 16.715 ms | 20.293 ms | 1 |
| Worker vibration, repeat | 16.670 ms | 20.909 ms | 2 |

The synchronous stage had zero collisions and zero moving tyres. This supports a vibration-induced hitch independent of impacts. The median alone hides this problem; the tail and missed frames show the improvement. This scripted comparison does not prove every owner-observed stall had this cause.

Final 120-second run with alternating steering presses: 1,096 m, two completed laps, zero collisions, 7,126 engine samples; median 16.683 ms, p95 20.533 ms, p99 22.639 ms, maximum 38.856 ms, four engine intervals above 33.34 ms. In the overlapping 61.59-second SurfaceFlinger window, **3,659 actual displayed-frame intervals had median 16.833 ms, p99 17.065 ms, maximum 17.385 ms, and zero intervals above 25 ms**. These measure different timing domains and windows; they must not be treated as contradictory or identical samples. Battery temperature rose 35.6 → 36.1°C, reported phone temperature 37 → 38°C. This supports smooth near-60-FPS delivery on the tested device without promising universal hitch-free play.

The final [phone screenshot](evidence/knot-final-2026-09-25/custom-phone.png) was inspected. The 10,000-lap target visible there is debug-only and avoids ending the unscored endurance run. Diagnostic markers/results were removed; `adb shell run-as org.circuit01.handlinglab ls files` confirmed their absence. Normal play was relaunched, preserving player tracks and records. The updated APK remains installed.

Raw measurements, APK hashes, configurations and temperatures are under `docs/evidence/knot-haptics-2026-09-25/`. Initial `knot-before` and tyre-only `knot-after` folders used the invalid repeated-down probe. Their 73–89 ms medians must not be compared with the corrected probe as a gameplay speedup. The first phone temperature was already 44°C (battery 41.6°C), versus 35°C at the controlled haptics comparison. The initial SurfaceFlinger capture also crossed the end of a stage; it is not a clean baseline window.

## Commands and regression status

Engine commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `-Action Doctor`: pinned engine/templates and authorized DN2103 found.
- `-Action Validate`: parses and early suites ran; driving 74, handling/replay 88, checkpoints 122, tracks 167, extra tracks 27, editor retirement 24, placement 24, road approval 19, start line 27, creator 112 and editor-v2 35 passed. Stopped at the unchanged free-editor UI assertion `library Edit opens original starter document`, followed by a nil `native_preview` access. Full suite is not green.
- `-Action TestTyreEquivalence`: 13,200 exact comparisons passed; optional local pre-change benchmark results above. Reference source saved with `git show HEAD:game/vehicle/loose_tyres.gd` to export-excluded `build/knot-tyres-before.gd`.
- `-Action TestTyresLoad`: 68 checks passed.
- `-Action TestPerformance`: 16 checks passed, including blocked-worker/nonblocking caller, bounded pulse requests and completed-task reaping. Historical optional dust/trail timings in this test are unrelated to this change.
- `-Action TestMobileControls`: 555 checks passed.
- `-Action TestHazards`: 150 checks passed, with two ObjectDB shutdown warnings.
- `-Action TestKerbs`: 31 checks passed; `-Action TestSuspension`: 28 passed.
- `-Action TestCars`: all five-car/five-lap replay checks completed; 92/95 checks passed. Three unchanged model-structure assertions fail for pickup/classic/formula (`detailed model has steering wheels and body`). No failed invariant was removed or weakened.
- `-Action CheckScript -ScriptPath res://diagnostics/mobile_race_probe.gd`: passed.
- `-Action ExportAndroid -QuickValidation`: import/startup, driving 74, catalog 18 and menu 26 checks passed; final haptics APK exported and installed.

Phone commands use the same PowerShell flags:

```text
scripts/profile-features-phone.ps1 -TrackId track_1e3936d025fe7c82 -SkipInstall -Seconds 20 -ReportName knot-before-2026-09-25
scripts/profile-features-phone.ps1 -TrackId track_1e3936d025fe7c82 -Baseline -Seconds 120 -ReportName knot-after-2026-09-25
scripts/profile-features-phone.ps1 -TrackId track_1e3936d025fe7c82 -HapticsProfile -Seconds 30 -ReportName knot-haptics-2026-09-25
scripts/profile-features-phone.ps1 -TrackId track_1e3936d025fe7c82 -Baseline -AlternateControls -SkipInstall -Seconds 120 -ReportName knot-final-2026-09-25
scripts/profile_android_frames.ps1 -Seconds 30 -Output docs/evidence/knot-before-2026-09-25/present
scripts/profile_android_frames.ps1 -Seconds 60 -Output docs/evidence/knot-after-2026-09-25/present
scripts/profile_android_frames.ps1 -Seconds 60 -Output docs/evidence/knot-final-2026-09-25/present
```

Changed code: `game/platform/steering_haptics.gd`, `game/vehicle/loose_tyres.gd`, `game/diagnostics/mobile_race_probe.gd`, `game/tests/test_performance.gd`, `game/tests/test_tyre_equivalence.gd`, `scripts/dev.ps1`, `scripts/profile-features-phone.ps1`; plus this report, status/plan and evidence. No artwork or camera changes.

Remaining acceptance: owner driving Knot with their usual steering/haptic settings, longer thermal soak and other Android devices; iOS untested. A busy Android vibrator can omit a pulse by design. Unrelated editor/model regression failures remain visible above.
