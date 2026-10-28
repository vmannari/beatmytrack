# Device performance and four race-work findings - 27 October 2026

**The four race-work fixes are verified, real Android performance runs are complete, and cold Garage navigation now selects its existing staged opening.** Original finishes and reflections remain. Cold preparation still has measured stalls; this is not a blanket 10/10 or all-device performance claim.

Requirements: **RW01-RW04** close the four findings; **DP01** isolate and pin the Android test; **DP02** measure actual presentation and memory/thermal state; **DP03** restore responsive cold Garage entry; **DP04** block optional construction during race loading; **R01/Q01** preserve contracts, ownership, original assertions and evidence boundaries.

## Changes and verified race behavior

The four fixes were already present in the shared tree when this task started. Their implementation and earlier scoped patch are in [Race optional work fixes](RACE_OPTIONAL_WORK_FIXES_2026_10_27.md). Fresh checks verify:

| Finding | Current behavior |
| --- | --- |
| RW01: late menu snapshots | Keep the latest scoped RAM value; sleep before another optional disk dispatch while racing. Admitted atomic writes finish, and menu return resumes the latest pending value. |
| RW02: completed header images | Defer mipmaps, texture publication, notifications and late readback until eligible. Recheck owner epoch and appearance before publication. |
| RW03: pause-only state | Construct the presentation key while paused and clear it once on resume. |
| RW04: empty preloader | Reap outstanding reads, then sleep when empty/ineligible. Navigation, loading, appearance and foreground events wake it. |

The 35-second desktop driving windows record zero optional HTTP requests, cloud flushes, header captures/disk hits and optional snapshot writes. Required current-race condition persistence remains active. Ownership, late-completion, admitted-write, stale-image, menu-recovery and pause invalidation assertions pass.

A separate integration gap affected device responsiveness: `App._garage` did not select the existing staged opening when a prepared showroom was unavailable. The ordinary showroom could consequently construct inside the navigation callback. Two App lines now select staged entry only for that fallback and admit its construction only when the existing background-work policy and menu transition allow it. A prepared showroom still follows its existing adoption path. The original stock picture remains until the complete original studio, lighting, glass, shadows and planar reflections finish preparing.

The existing cold-opening test gains two checks that a race-loading overlay prevents studio construction and retains its picture. The race-work regression now waits for the completed retained studio before inspecting its original three viewports; its strict three-viewport and disabled-render assertions remain unchanged. Historical audit sources/assertions are untouched. The first attempt observed four disabled viewports while a temporary preparation view still existed; that fixture failure is retained.

## Physical Android results

Pinned engine/templates: `4.7.2.stable.official.ed1daf0bf`. Device: **OPD2403**, Android SDK **35**, **Adreno 750**, physical landscape surface **3000 x 2120**, current display mode **50 Hz**. The release engine reports `debug_build=false`; production frame limiting/VSync and graphics settings are retained. Race 3D keeps the existing pixel budget; the Canvas remains at its normal display resolution.

The separate offline package `org.beatmytrack.perf.r20261027a` uses private probe records and a task-only signing key. It was not installed over the real game. Final APK SHA-256, exact source inputs, commands and receipts are in the [evidence ledger](evidence/device-performance-race-work-2026-10-27/report.json).

| Final run | Result |
| --- | --- |
| Clean timing/presentation pass | **17 completed cases, zero probe errors** |
| Separate screenshot/PSS/thermal pass | **17 completed cases, zero probe errors** |
| Additional fresh-process Garage memory pass | **5 completed cases, zero probe errors** |
| Actual SurfaceFlinger presentation | **5,445 sampled frame intervals across eight driving/orbit windows; p95 about 20.00 ms, largest gap 20.0014 ms, zero gaps over 34 ms** |
| Clean active driving | Six windows, about **110 seconds**, Compact/Storm/Electric/Kart Night; **zero contacts** and movement verified in every case |
| Android PSS | Largest of **nine samples: 615.5 MiB**; live Garage samples about **367-401 MiB** |
| Thermal observations | Start/end status **0** in each final run; sampled battery temperatures **29.2-29.4 C** |

The display result demonstrates its sampled **50 Hz** mode. It is not a 60 FPS claim. The bounded diagnostic routes are not maximum-speed, large particle-burst, five-lap completion or physical-touch-latency acceptance. PSS samples can miss instantaneous peaks and do not establish a leak plateau or a low-memory-device budget. Endpoint thermal status and battery temperature under USB charging do not measure battery energy or sustained throttling.

### Garage responsiveness

In the clean full pass, first Garage navigation returned in **96.8 ms**, its stock picture was presented at **387.0 ms**, and the fully prepared live view was ready at **6.312 s**. Repeat navigation returned in **34.6 ms**; the repeat observation completed in **248.9 ms**, including twelve settling frames. Both live orbit windows passed.

The separate Garage-only process, with caches already exercised and diagnostics enabled, recorded **157.6 ms** dispatch, **274.7 ms** picture presentation and **2.938 s** to ready live 3D. These are different cache/workload states, not a controlled speedup comparison. [The entry picture](evidence/device-performance-race-work-2026-10-27/captures/garage_first_visit.png) and [the subsequent real orbit](evidence/device-performance-race-work-2026-10-27/captures/garage_first_visit_orbit.png) retain the original workshop, lighting and reflections.

An earlier desktop fixture blocked its navigation callback for roughly 21 seconds. The final native cold-opening test returns in **73.4 ms**, presents its picture at **506.0 ms**, and passes all **208** assertions. Different cars/cache states prevent interpreting those fixtures as a controlled cross-run speedup ratio.

### Remaining loading cost

Fixture compilation is now measured separately from App entry, which ordinarily receives an already compiled `NativeTrack`. Its latency is retained alongside total fixture-to-ready time.

| Clean device App entry | Time | Largest preparation frame |
| --- | ---: | ---: |
| Compact Star, first in process | 19.779 s | 200.4 ms |
| Compact Star, repeat | 8.476 s | 141.8 ms |
| Storm Freight, first | 6.229 s | 273.1 ms |
| Storm Freight, repeat | 5.805 s | 283.1 ms |
| Electric Freight | 7.944 s | 237.2 ms |
| Kart Night Freight | 13.745 s | 277.8 ms |

The clean Garage preparation also contains a **645.6 ms** frame under its picture. Fast navigation does not eliminate these compiler/geometry preparation stalls. The earlier first-install diagnostic Star observation, **39.487 s with a 2.260 s frame**, remains recorded separately. Final acceptance runs used existing private probe data and shader caches: Android denied the optional ADB reset, and no permission was bypassed. These are not matched before/after loading comparisons.

Covered material/particle draws follow [Godot's Compatibility shader-warming guidance](https://docs.godotengine.org/en/4.7/tutorials/performance/pipeline_compilations.html). Cold compiler calls and remaining indivisible preparation work still need their own budget/owner acceptance; no hitch-free loading claim is made.

## Desktop verification and source scope

| Final check | Actual result |
| --- | --- |
| Race-work regression, headless | **86 / zero failures** |
| Same regression, Windows Vulkan Mobile | **86 / zero failures** |
| Native cold Garage, Compatibility | **208 / zero failures** |
| Existing App suite | **141 / zero failures** |
| Initial loading/shader/geometry checks | **744 / zero failures** |
| Final real-App effect preparation on current root sources | **114 / zero failures**, all cars/themes and cancellation/pressure paths |

Earlier 85-check headless/Compatibility/Mobile runs and initial 114-check effect results are retained. Native Mobile above means Vulkan on Windows. These checks retain mesh/shader identity, all live emitters, frozen preparation tick/countdown/trail state, cache bounds and lifecycle fences. Existing sandbox certificate-store errors remain in desktop logs. Engine process/physics monitor fields are delayed/overlapping observations, not direct or additive CPU/GPU timings.

Physical results apply to the archived project snapshot with this task's App change. Concurrent V14 model, editor and rendering changes are listed separately and preserved; this is not whole-current-tree Android release acceptance. Current App `_garage`, policy/wake bodies and the four policy runtime files match the tested snapshot. The final 114-check desktop run also covers the later current-root effect/model sources. No geometry, shader, physics, scoring or reward source is changed by this task.

The task's production patch is two lines in `game/core/app.gd`, with regression fixture/check additions in two test files. The [Git-generated scoped checkpoint](evidence/device-performance-race-work-2026-10-27/checkpoint.patch) and its [round-trip verification](evidence/device-performance-race-work-2026-10-27/checkpoint-verification.json) exclude concurrent edits and the main index.

Initial controller collisions, invalid `bool(null)` probe readiness, truncated Android log messages, decorated SurfaceFlinger names, keyguard blocking, export ownership/provenance failures and the superseded four-viewport fixture failure are retained in the evidence archive. Final report decoding, case completeness, movement, preparation state and presentation samples have independent checks.

The temporary package was stopped and **uninstalled successfully**. The original stay-awake setting remains **0**. The real game, its saves, accounts and running owner process were untouched. No backend deployment, real authentication/purchase or main-index staging/commit/merge occurred. Reload/rebuild the client to use the source change.
