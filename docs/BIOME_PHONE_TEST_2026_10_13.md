# Winter and desert physical-phone test â€” 2026-10-13

Follow-up2026-10-14: native tracing attributes a matching Desert event to first-use Mali shader compilation. Covered hazard preparation removes the recorded route166 stall in a tested cold pass; other cold-start compiler events remain, including a first tire-draw lead. See [the hitch investigation](DESERT_HITCH_INVESTIGATION_2026_10_13.md) for exact APKs, commands, native evidence and limits. The original display-FPS measurements below remain unchanged and are not compared with instrumented trace timings.

Owner request: test the merged winter/desert performance work on the attached phone. Requirements BPERF01â€“BPERF08, TR01â€“TR04, WSP04â€“WSP06, DS23â€“DS25 and V04/V05/G01/R01/Q01; the parallel tire renderer takes precedence. Both biomes ran close to the display's roughly 59.4 Hz cadence in the clean samples. Occasional missed refreshes remain, and the first desert run captured a genuine early driving hitch. This is a current-build test, not a paired phone improvement measurement or unconditional performance acceptance.

## Build and method

Pinned Godot `4.7.2.stable.official.ed1daf0bf`; OnePlus DN2103 / Nord 2, Android 13, Mali-G77 MC9, GLES 3.2 Compatibility. Fresh debug APK SHA-256 `0C586B9FEE603ED948DE56D92ED8FADF5E808D8BD627CABE9FBD2D90C8E9AFB8`; the installed phone `base.apk` hash matches the frozen `build/biome-phone-test-2026-10-13/installed.apk`. It includes track-kit-186, winter-spray-8 and the merged joined tire ribbons/conservative visibility work. Subsequent shared-workspace changes are not implied to be in this frozen APK.

The existing explicit debug probe drove saved winter/desert tracks in unscored local practice, using actual canonical simulation and timed-route validation. No competitive ticket, PB or score upload was requested. Each baseline sampled 120 seconds after five seconds of warmup; a separate roughly 100-second SurfaceFlinger actual-present window excluded startup, warmup, screenshots and stage resets. Shipping 0.667 render scale, 2x MSAA, shadows, effects, dust, car and camera were retained at 2400Ã—1080 display pixels, approximately 1.153 million world pixels. These are debug/AI practice samples, not human-driven five-lap acceptance.

## Actual presentation results

| Sample | Measured span | Intervals | Average FPS | Median / p95 / p99 | Longest interval | Intervals >25ms |
| --- | --- | --- | --- | --- | --- | --- |
| Winter |99.608s|5,901|59.24|16.834 /16.988 /17.129ms|36.482ms|16 |
| Desert clean repeat |98.985s|5,873|59.33|16.834 /16.970 /17.066ms|67.176ms|5 |

The new poll-continuity guard reports zero presentation-buffer gaps in the clean desert repeat. The original winter trace has no long collection gap; its individual drops are retained. Counts above 25 ms describe long intervals, not an exact count of lost refreshes. No screenshot/readback or recording occurred inside these display windows.

Winter drove 1,163.47m/three completed laps; the clean desert repeat drove 1,056.27m/one completed lap. Both recorded zero paused frames. Callback p99 was 28.440 ms Winter /25.591 ms Desert; callback intervals and engine process monitors are separate observations from actual display presentation and do not establish GPU execution time.

Observed trail update mean/p99 was 0.183/0.445ms Winter and 0.181/0.449ms Desert in the clean runs. The final submitted instance counts were 4,320/3,804; these are endpoint observations rather than full-budget averages, and the probe does not report the separate retained ring count. This includes the merged trail work's ordinary driving cost, without a controlled before/after phone comparison. No further tire geometry, sampling, shading or budget change was made.

## First desert hitch and interrupted collection

The first desert drive captured a real 791.423 ms presentation interval at roughly 22 seconds after probe start. Its automatic local hitch logger independently captured an 808.617 ms game interval at tick 2316. The recorded render-signal wall interval was 787.983 ms, time between callbacks 806.777 ms and current measured callbacks 1.840 ms. Condition-save, recovery-callback and cloud-local-IO timings were zero; the condition-save counter stayed 5 across the surrounding frames. The early driving hitch did not recur in the clean repeat.

This places the observed delay outside the measured game callbacks, around the render boundary. It is not GPU execution time and does not prove shader compilation, driver work or OS scheduling as the cause. **The cause and fix remain unconfirmed.** The full bounded event and its surrounding frames are preserved in [desert-first-hitch.json](evidence/biome-phone-test-2026-10-13/desert-first-hitch.json), with a concise [summary](evidence/biome-phone-test-2026-10-13/summary.json). This supplies the physical-phone reproduction previously missing from [race hitch diagnostics](RACE_HITCH_DIAGNOSTICS_2026_10_13.md).

Separately, an ADB server restart lost presentation-buffer rows later in that first trace, leaving a 4057.315 ms collection gap. Its aggregate 56.49 FPS is invalid and is not a game FPS result. The raw trace and genuine hitch were retained; the clean repeat added explicit poll timing/history-overlap checks and completed with zero buffer gaps. The 0.8 s driving hitch is not dismissed as that later transport interruption.

## Visual, thermal and data checks

Actual phone [Winter](evidence/biome-phone-test-2026-10-13/winter-phone.png) and [Desert](evidence/biome-phone-test-2026-10-13/desert-repeat/desert-phone.png) captures show textured banks/terrain/roads and billowing desert dust; no Godot script or shader errors were found in the captured run logs. This is a visual sanity check, not owner appearance approval or exhaustive bridge/track coverage.

Two separate 36-second bank-excursion runs each produced nine snow bursts over about 233 m, with zero paused frames. The final run recorded 939 frames with the powder-emitter flag active; flags/counts alone do not prove pixel visibility. Screenshots at the ordinary camera are retained for owner review. Android `screenrecord` is absent on this phone (actual exit 127), so the first recording attempt failed after its successful driving/capture window. The runner now detects that capability and uses bounded timestamped screenshots instead. The final visual run completed successfully, preserving three sparse sequence frames and four additional bank stills. [Step through the actual frames](evidence/biome-phone-test-2026-10-13/winter-visual-repeat/frames.html); this is not native video, continuous motion proof or a performance sample. Readbacks and diagnostic bank resets stay outside baseline results.

The phone was already warm: initial measured HAL CPU/GPU 61.1Â°C, battery 34.3Â°C, skin 44.3Â°C. Recorded samples reached about 63.3Â°C CPU/GPU and 47.7Â°C skin; final HAL CPU/GPU 57.7Â°C, battery 35.7Â°C, skin 45.8Â°C. Android thermal status remained 0. The adaptive CPU cooling device reported state 1, so status 0 is not a claim that no thermal control was active. Stale cached temperatures are excluded. This is a bounded warmed-device check, not a long soak or controlled-frequency comparison.

All four completed/attempted run groups restored both original local-record/cosmetic files with identical SHA-256 hashes. Private record contents stayed on the phone. Diagnostic markers/backups were removed and the app relaunched normally; the new APK remains installed. No runtime code changed for this test task.

## Actual commands, checkpoint and remaining acceptance

PowerShell uses `-NoProfile -ExecutionPolicy Bypass`. The pinned engine/build entry point remains `scripts/dev.ps1`; normal engine caches/ADB required permitted access.

- `scripts/dev.ps1 Doctor`: matching engine/templates and DN2103 found.
- `scripts/dev.ps1 ExportAndroid -QuickValidation -CommandTimeoutSeconds 600`: import/APP_READY passed; Driving 72, Catalog 21, Menus 48 checks passed with zero failures; fresh APK exported. The earlier audio-DLL import lock did not recur. QuickValidation does not run full regression.
- `scripts/dev.ps1 InstallAndroid -DeviceSerial <attached-serial>`: install-r `Success`; installed APK hash independently verified.
- `scripts/test-biomes-phone.ps1 -DeviceSerial <attached-serial> -Phase Baselines -Seconds 120`: initial lock-screen attempt timed out before readiness; after owner unlock both drives/captures/cleanup completed, with the first desert transport interruption and genuine hitch above retained.
- Same runner with `-Biomes desert -OutputDirectory docs/evidence/biome-phone-test-2026-10-13/desert-repeat`: clean repeat completed, zero buffer gaps, exact record restoration.
- Same runner with `-Phase WinterVisual -Seconds 36`: first driving/capture window completed but recording failed because the phone lacks `screenrecord`; capability detection/fallback added. Final `-OutputDirectory .../winter-visual-repeat` completed with actual frames and exact restoration.
- PowerShell parser: zero errors. `build/biome-phone-test-2026-10-13/summarize.py`: measured summaries generated, all four record-restoration comparisons exact. Checkpoint whitespace/reverse-apply checks passed.

Evidence is under `docs/evidence/biome-phone-test-2026-10-13`; [summary.json](evidence/biome-phone-test-2026-10-13/summary.json) retains numbers, thermal samples, attribution limits and restoration proofs. The completed task-only review checkpoint is `build/biome-phone-test-2026-10-13/checkpoint-completed`, with its commit/manifest/text patch in `{checkpoint.json,task-only.patch}` under that evidence directory. It includes the runner, report, scoped shared-document notes and diagnostic evidence; runtime, parallel-task source changes, raw Android logcat, private records and APK binary are excluded. Shared Git index/HEAD are preserved. The earlier interrupted-attempt checkpoint is retained separately.

Remaining acceptance: identify and validate an attributable fix for the first desert render-boundary hitch; owner powder/road/tire appearance and ordinary human five-lap play; genuinely cold/evicted preview-cache transitions, sustained saturated-trail workloads, longer thermal soak and other devices. No paired pre-optimisation phone run, phone Vulkan test, full Validate, canonical contract change, backend deployment or live competitive write. The desktop 5% Compatibility and 28â€“36% Mobile/Vulkan component reductions remain desktop-only.
