# Mobile performance review — 5 November 2026

The largest confirmed responsiveness problems are first-use race graphics and customized-header preparation during startup. Existing reuse substantially improves repeat visits. Current source review and desktop probes do not establish sustained performance, battery life or memory headroom on today's Android build.

Requirements: **MPR01** review current startup, racing, rendering, memory and Android packaging; **MPR02** collect bounded, offline measurements without changing shipping behavior; **MPR03** rank remaining work and distinguish observations from unverified device risks. This is a review, not an optimization implementation.

## Findings, in priority order

**1. High: first-use race preparation still produces long waits and individual stalls.** In the fresh review process, actual App entry into Pine took **69.289 s**, with a **7.687 s** maximum observed process-frame interval. Immediate re-entry took **2.988 s**, maximum interval **296.889 ms**. The world preparation issued 32 draw groups on first entry and one on re-entry; effect preparation reused zero then all 20 particle proxies. This is evidence that retained work helps, while the first-entry problem remains. It is not a measured regression against the earlier reports: those used different source/cache/diagnostic conditions.

The current controller still performs native world and effect preparation before revealing the countdown (`game/core/features/race.gd:379,427`). The independent [5 November attribution](FIRST_USE_GRAPHICS_2026_11_05.md) identifies 31.433 s of native program linking across its diagnostic run and a 6.482 s first particle-stage draw, primarily involving car/world programs. Its final actual-App first entry was 44.096 s; the six-surface shader pruning improvement was only a component reduction, 9.749 to 9.168 s. That trace establishes the earlier mechanism; this review did not repeat native compile/link attribution for its 69.289 s sample.

| Current actual-App entry | Ready in | Largest preparation frame | Reused particle proxies |
|---|---:|---:|---:|
| Pine, first in process | 69.289 s | 7,687.080 ms | 0/20 |
| Pine, immediate re-entry | 2.988 s | 296.889 ms | 20/20 |
| Winter, first after Pine | 41.386 s | 4,130.678 ms | 20/32 |
| Winter, immediate re-entry | 4.726 s | 346.900 ms | 32/32 |

Even retained entry still incurs noticeable time in this run; proxy reuse is not equivalent to skipping the full readiness sequence. Preserve these observations when profiling further rather than replacing them with the faster historical warm figures.

Next work: target the expensive car/weathering native variants and exact source reuse, measuring complete entry and the longest indivisible draw as separate outcomes. Retain full preparation coverage and countdown/input fences. Increasing batch size cannot guarantee shorter individual driver calls. The selected Compatibility renderer requires real warm-up draws; Godot's ubershader/pipeline precompilation path applies to Forward+/Mobile. Any renderer experiment therefore needs its own device and image comparisons, rather than a default setting change. [Godot 4.7 documentation](https://docs.godotengine.org/en/4.7/tutorials/performance/pipeline_compilations.html).

**2. High: a small customized header image blocks the first usable menu.** `game/core/app.gd:508` awaits `header_car_cache.prepare_selected()` before showing the destination screen. `game/ui/header_car_appearance_cache.gd:85` allows a 45-second wait for the selected image. A missing customized image starts native model/shader preparation even though the final image is only 176×112 pixels. The timeout loop cannot interrupt an individual native call.

| Fresh process, desktop Compatibility | Engine clock to first menu draw | App initialization | Header work |
|---|---:|---:|---|
| Stock appearance | 10.536 s | 0.584 s | No capture |
| Customized appearance, empty private PNG cache | 30.148 s | 21.869 s | One capture |
| Same customized profile, next process | 7.610 s | 0.690 s | One disk hit, zero captures |

App resource loading was 3.409–3.867 s across these samples. The three observations show the cache-state sensitivity; they are not statistical distributions or an A/B optimization result. Recommended first implementation: allow the shell to become usable while the exact customized image prepares, using an honest temporary placeholder and retaining appearance/account identity checks. Do not substitute the factory appearance for a saved custom design. Normal signed-in startup also awaits session restoration; this offline experiment does not measure that network path.

**3. Medium: Daily standings latency is still dominated by snapshot readiness and retry waits.** Current `game/ui/daily_result_card.gd:167–174` attempts up to four reads and waits the bounded server `Retry-After`, defaulting to five seconds, between preparation replies. The [4 November investigation](DAILY_STANDINGS_LATENCY_2026_11_04.md) measured about 5.019 s of waits after one preparation reply and 15.011 s after three, while rendering the card took only 4.4–9.1 ms. The current code retains that mechanism. This review made no live requests and does not assert that today's service is presently slow. Recommended work: prepare the five exact Daily car snapshots when publishing the event, retaining bounded refresh demand and client retry behavior. The recent Daily limits/CPU overlap solves a separate race-start dependency.

**4. Medium, device risk: retained-cache limits are not a total memory budget.** `game/editor/editor_memory.gd:4–5` limits estimated optional world/editor retention to 64 MiB and optional Garage retention to 96 MiB. The independent result queue reserves encoding and attempt headroom within 160 MiB (`game/backend/result_save_queue.gd:8–25`). These are different accounting boundaries; their constants must not be added and presented as measured memory use. Active scenes, imported resources, driver allocations and transient decoding need process-level measurement.

The [27 October tablet run](DEVICE_PERFORMANCE_RACE_WORK_2026_10_27.md) sampled up to **615.5 MiB PSS**, with live Garage around 367–401 MiB. That older workload does not prove low-memory-device safety or a leak. This review's native blend regression passes all nine assertions: 200 preparations each at 0, 1, 7 and 33 pieces produce **zero static-memory growth**. The previously diagnosed native leak remains fixed in this focused check; a full lifecycle soak was not repeated. Next measurement: repeated track/Garage/editor swaps, long attempts and pending result storage, including pressure and background/foreground transitions, with PSS/RSS and peaks. Android documents Meminfo for PSS and Perfetto for longer memory traces. [Android profiling tools](https://developer.android.com/games/tools).

**5. Medium, device risk: active Garage rendering has a substantially larger pixel allowance than racing.** `game/ui/car_showroom.gd:92–93,158–159` uses full-scale 4× MSAA for the live view and caps dimensions at 2560×1440, potentially 3.686 million main-view pixels. Two additional reflection views use 2× MSAA with a 768-pixel width cap (`game/ui/garage_reflections.gd:25–31,85`). Racing instead caps the mobile world at 1.5 million pixels (`game/core/game.gd:175,1142`), while preserving native UI resolution. Race graphics preferences do not control the Garage view.

Idle Garage rendering already retains its image, and off-camera record animation no longer forces draws. LOD preparation is also already implemented. The remaining concern is orbiting, washing, transitions and the visible record: those legitimately redraw the scene/reflections. The [1 November review](GARAGE_PERFORMANCE_2026_11_01.md) retains 201 draws and 543,068 all-pass triangles per frame in its rotating Hover sample after LOD. Those are historical desktop counters, not current phone GPU timings. Profile those active cases on high-density devices before choosing a mobile Garage pixel/AA policy or more batching; preserve the accepted default appearance until comparisons justify a change.

## What already works, and what not to repeat

- Startup modules load on demand; the three fresh startup probes loaded no optional feature controllers before the first menu. First-use `load(path)` remains synchronous (`game/core/app.gd:2944`), so measure tap-to-cover latency as well as the work under the cover when extending this design.
- Current mobile race scale, Night headroom, AA preferences and teardown restoration pass their focused checks. Canonical physics remains at 120 Hz with at most 16 catch-up steps per rendered frame. No evidence here supports changing the simulation rate.
- Exact checkpoint reuse, selected-track/event CPU work, Daily limits overlap, shared graphics receipts, prepared vehicles, retained scenery and one-shot menu pictures are already present. They should not be presented as new recommendations. The [checkpoint report](CHECKPOINT_PREPARATION_2026_11_05.md) still measures roughly 3.68–3.69 s for a fresh Star layout, so exact prepared layout artifacts remain a possible later loading investigation.
- Android export already excludes the reviewed obsolete mesh banks and posters. The [3 November controlled content export](OBSOLETE_ASSET_CLEANUP_2026_11_03.md) fell from 327.42 to 217.15 MiB. Do not repeat the obsolete-assets finding as unfixed. The debug preset still includes ARM64 and x86_64; evaluating architecture-specific delivery is a packaging opportunity, not an FPS optimization. No new APK/package size was measured here.

## Evidence and limits

All new runs use pinned `4.7.2.stable.official.ed1daf0bf`, the current shared workspace, separate APPDATA/LOCALAPPDATA under `build/mobile-performance-review-2026-11-05`, explicit offline `backend.cfg`, and Dummy audio. Native runs use Windows Compatibility, NVIDIA RTX 3090, driver 616.92, a 1280×720 viewport and an off-screen window. Runs are sequential. Driver/OS/project import caches were not erased, machine-wide load was not controlled, and this is a debug desktop engine. Private user caches start empty except the intentional customized-header restart pair. These are observational samples, not cold-install Android results or before/after improvement claims.

Startup time is the engine clock at the first post-readiness draw, not an OS launch trace. Race wall time starts immediately before `_start_race` and ends on readiness; it excludes fixture track compilation and initial menu startup. Pine is first in that process; Winter follows it and is not an independently cold renderer run. Frame intervals and draw-signal spans are wall-clock observations, not GPU timings. Four diagnostic screenshots are retained without a new visual-quality or pixel-equality claim.

The current race fixture checks readiness, tick zero/countdown 360, loading-cover removal and same-instance retry; it does not drive a lap. The previously recorded five-opening-lap results apply to their archived runs. The current review also does not measure real authentication/network latency, physical touch, audio latency, battery energy or thermal throttling.

Available physical evidence is encouraging but older and narrow: the [27 October Adreno 750 tablet](DEVICE_PERFORMANCE_RACE_WORK_2026_10_27.md) recorded 5,445 presented intervals near 20 ms in its 50 Hz mode, across driving/orbit windows; the [25 October Mali-G77 Desert run](DESERT_PHONE_PERFORMANCE_2026_10_25.md) measured about 59.35 presented FPS using a 0.5 world scale. Neither certifies today's full build, all tracks/cars, lower-end devices, 60 Hz operation or long thermal sessions. No device attachment query, device test, APK/export, owner-save/process change or deployment was performed in this review.

Actual invocation:

```powershell
python docs/evidence/mobile-performance-review-2026-11-05/run_review.py
python docs/evidence/mobile-performance-review-2026-11-05/validate_review.py
```

The runner verifies the exact pinned executable and records each full engine argument list, source changes, timeouts, exit status and diagnostics in [runs.json](evidence/mobile-performance-review-2026-11-05/runs.json). It deliberately uses the documented direct pinned-engine approach after inspecting `scripts/dev.ps1`, whose test action would regenerate shared build identity. Source receipts cover scripts, shaders, scenes and configuration outside `game/assets` and `.godot`; they do not freeze binary assets, import cache state or the entire workspace.

All **seven runs exit 0**, with **802 assertions and zero failures**, plus the three startup observations:

| Check | Actual result |
|---|---:|
| Graphics settings, headless | 146/0 |
| Tablet world-resolution budget and related presentation contracts, headless | 631/0 |
| Native blend allocation regression, headless | 9/0 |
| Actual-App Pine/Winter readiness and retry, desktop Compatibility | 16/0 |
| Three startup probes | Menu drawn, offline, header writes drained; all exit 0 |

No run has a timeout, script/shader error or recorded source change. Final verification requires the three startup result files, four race rows, positive assertion counts and complete matching source receipts; it does not treat exit 0 alone as success. The raw race output is [profile.json](evidence/mobile-performance-review-2026-11-05/race-pine-winter/profile.json), and each run's folder retains its complete log.

The [final evidence validation](evidence/mobile-performance-review-2026-11-05/validation.json) passes and confirms **1,903 source/configuration files unchanged** across the run sequence. The validator also parses the new runner and checks all reported sample/count boundaries. No full application regression suite was run.

Changed files are limited to this report and its new evidence directory, including the review runner, raw logs, JSON results, source receipts and diagnostic pictures. Shipping sources, settings and assets were not edited, and the main Git index was not written. Existing concurrent changes remain in place. Root-certificate-store errors from this offline Windows environment are retained in every run's log rather than hidden.

The next acceptance pass should pin the current source and release build on representative Android hardware, separate first launch/first track/re-entry, retain p50/p95/p99 and maximum presented frame intervals, and cover all five biomes, dense tracks, active Garage interaction, memory pressure and a sustained unplugged session. Until then, the concrete implementation priority is removing the customized-header dependency from first menu readiness, alongside targeted investigation of the large first-use native graphics cost.
