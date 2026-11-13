# Mobile performance improvements — 2026-11-06

Implements the owner's approval to proceed after the [mobile performance review](MOBILE_PERFORMANCE_REVIEW_2026_11_06.md), including additional improvements found during implementation. The existing Godot architecture, Compatibility default, 120 Hz driving contract, rendering quality and prepared car assets are retained.

The measured improvements are bounded Profile construction, much shorter header-related idle stalls, and persistent exact checkpoint preparation. Cold feature entry now draws feedback before loading its resource graph. A tested threaded UI-script alternative was rejected. Android delivery and custom-engine preflight tooling are ready; no APK was built or installed, and no phone-performance claim is made.

## Requirements and implementation

| ID | Requirement | Implemented behavior |
|---|---|---|
| MPI01 | Bound Profile work as local drafts and publications grow | Twelve rows per page, separate draft/publication page positions, cached previous pages, unchanged server pagination, verified counts and cancellation fences. Loading-status changes no longer rebuild unchanged rows. |
| MPI02 | Present cold feature entry before expensive resources | Lightweight cancellable cover for Garage and Editor entry, including Profile draft/publication actions. Race loading presentation is available without loading the race controller. Resource stages execute serially after actual draw fences. |
| MPI03 | Reduce automatic custom-header idle stalls | Use the existing shared material preparation queue; suppress incidental whole-car draws, keep the camera fixed during staging, restore visibility/cull margins, then retain the original five final capture draws. Separate renderer construction and the first native draw by a frame. |
| MPI04 | Reuse exact checkpoint layouts across processes | Explicit preparation workers read/write a bounded numeric artifact; ordinary session configuration, driving ticks and server verification remain disk-free. Geometry, preparation-source and engine identity guards preserve fallback to the existing builder. |
| MPI05 | Offer a smaller Android package without losing emulator support | Separate `Android ARM64` preset and explicit `-AndroidPreset` option. Original `Android Debug` preset retained byte-for-byte. Configuration and actual APK architecture/CRC checks precede promotion or installation. |
| MPI06 | Make custom Android shader-engine work reproducible | Pinned-source/module fingerprint checks, required-NDK preflight, explicit ARM64/x86_64 debug/release library commands. No automatic SDK download or profile promotion. |
| MPIQ01 | Validate ownership, exact driving rules, assets and appearance | Focused component tests, independent checkpoint review, real worker cancellation/restart tests, native views and frozen actual-App entry/driving checks. Initial failures and rejected alternatives retained. |

## Results and their limits

| Observation | Before | After | What was measured |
|---|---:|---:|---|
| Profile, 500 draft rows | 424.423 ms; 6,500 descendants | 11.802 ms; 156 descendants | Desktop headless row construction. Current page contains at most 12 rows. Does not include drawing, disk scanning or phone costs. |
| Profile, 100 draft rows | 95.027 ms; 1,300 descendants | 12.482 ms; 156 descendants | Same component boundary. Before values are the review's recorded baseline. |
| Worst idle frame in custom-header/Garage scenario | 11,803.632 ms | 4,271.526 ms | One frozen native desktop pair; final peak is outside the header draw stage. Driver/OS caches were not reset. |
| Header renderer construction interval | Combined with a large first draw | 2,901.767 ms | The next stage starts on a separate frame; individual native programs can still block. |
| Largest remaining staged-header interval | — | 1,312.417 ms | Material scheduling reduces combined stalls, not an individual driver's compilation latency. |
| Header ready after initial menu | 13.123 s | 13.527 s | Single pair. This change improves responsiveness, not total completion time. |
| Garage prepared in the same idle scenario | 31.310 s | 32.364 s | No total-loading improvement claimed. |
| Star exact checkpoint preparation | 4.025372 s | 31.880 ms | Fresh build including artifact encoding/write versus validated read in a new process. Same 105 gates and 159,200-byte canonical layout; file is 70,787 bytes. One desktop headless pair, warm filesystem, potentially overlapping native work, not whole-race loading. |
| Reverse Star checkpoint preparation | 3.952984 s | 31.004 ms | Same restricted measurement. |

Final native navigation observes the Garage entry call returning in 0.657 ms and the race entry call in 1.172 ms, with the appropriate cover already constructed. These are initial-call measurements, not resource-load durations: settings/feature graphs still take hundreds of milliseconds or seconds on the main thread. The cover is drawn before that work; its animation and Cancel handling cannot run inside a synchronous engine load.

The final actual-App header PNG is pixel-exact to its baseline. Separate five-car native comparisons include original-versus-original repeat controls: the earlier accepted component comparison changed 0–5 pixels versus 0–6 in unchanged controls, with the same maximum channel difference of 14. The tests additionally enforce camera, mesh visibility, cull-margin, owner, publication and cancellation invariants. This does not claim universal bit-identical independent renderer instances.

Evidence: [Profile results](evidence/mobile-performance-implementation-2026-11-06/profile/summary.json), [header implementation receipt](evidence/mobile-performance-implementation-2026-11-06/idle/implementation-receipt.json), and [checkpoint results](evidence/mobile-performance-implementation-2026-11-06/checkpoints/summary.json). Exact commands, private profile paths, logs, source receipts and captures accompany each run.

## Important technical choices

### Profile pagination instead of a new UI framework

The existing native rows are appropriate once their count is bounded. Draft IDs, publication version counts, safety filtering and asynchronous account cancellation are unchanged. More tracks still fetches the server's existing 12-item page. If filtering leaves a partial page, the first newly available row remains reachable; a newer Back navigation wins over an in-flight fetch. Normal small profiles retain the accepted layout because pager controls are hidden when only one page exists.

### Feedback before serialized feature loading

`core/race_loading_flow.gd` contains the original lightweight loading/presentation and admission checks, which no longer require the race feature graph. App resource installation remains on the main thread, with an actual draw fence between stages. Cold Garage/Editor entry pins navigation, account records, library, document identity, active game and cover identity. Cancel, replacement navigation and account changes prevent stale installation. Keyboard focus returns to the prior page on cancellation. A deferred Editor fit safely tolerates the page having departed.

Repeated race taps retain one operation. Existing track/account/car/selection checks and native countdown rules remain. A newly opened cold race has a bounded resource stage followed by the existing full 45-second preparation budget; a caller's existing ticket/download cover keeps its original deadline. Daily expiry checks remain monotonic and independent of that timer.

The resource-loader experiment did not qualify. A minimal frozen background load of the real header renderer leaked 45 zero-reference `RefCounted` objects, while the equivalent synchronous control was clean. The larger overlapping feature-navigation experiment timed out; that run also had source changes, so it is not treated as an isolated proof of an engine deadlock. The production code does not background-load those heavy UI script graphs. The prototype and logs remain under [navigation/threaded-prototype](evidence/mobile-performance-implementation-2026-11-06/navigation/threaded-prototype/) and [idle/rejected-async-renderer](evidence/mobile-performance-implementation-2026-11-06/idle/rejected-async-renderer/).

An independent small numeric worker-helper cold-load probe passed without leaks; this distinguishes the observed heavy-UI graph problem from all uses of worker threads. Existing Garage asset requests remain threaded. Their completed failure tokens are now consumed too, allowing genuine retries and releasing engine request ownership during teardown.

### Persistent checkpoint artifacts, with conservative invalidation

The file format uses a fixed numeric schema, bounded counts and allocations, exact layout field/key ordering, and no object or general Variant decoder. It validates file length, magic, identity, payload digest, numeric types/ranges, layer flags, indices and structural relationships before installation. Truncated, corrupt, stale and unsupported files fall back to the existing calculations. Writes publish the complete header/payload by atomic rename; retention is capped at 16 owned files and 8 MiB.

The key includes actual compiled geometry and preparation versions, a dedicated 37-entry numerical/native source manifest, compiler identity, engine version **and commit hash**, platform, architecture and numeric configuration. Unrelated Profile or App edits do not invalidate the numerical source manifest. Existing process-local cache generation, deep-copy ownership and pressure accounting remain in effect; canceled work cannot publish into a newer generation.

The artifact is a disposable app-private cache. SHA-256 detects accidental corruption; it is not authentication against a deliberately rewritten local file with a recomputed digest. Server/canonical verification does not call the disk preparation entry and reconstructs its own layouts. No cached client data authorizes a competitive result.

### Android delivery and shader-engine qualification

Use the new explicit option when an ARM64 APK is wanted:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action ExportAndroid -AndroidPreset "Android ARM64"
```

The default remains `Android Debug`, containing ARM64 and x86_64. The new option retains every resource and visual setting and writes `build/android/circuit01-arm64.apk`. The validator checks duplicate ZIP entries, every CRC, actual native-library ABIs and the Godot library for each required ABI. The existing debug APK passed 8,903 ZIP checks; no new package-size measurement exists because this task did not export an APK.

The custom engine preflight is available as:

```powershell
python native/biome_shader_profiles/build_android.py --arch arm64 --target template_debug
```

It correctly reports missing NDK **29.0.14206865** on this machine. The existing nine selective shader contexts are NVIDIA desktop contexts; none is promoted to Android. Building libraries, producing matching export templates, capturing exact device/driver contexts, and measuring loading, memory and sustained frame pacing remain necessary. The tool preserves both renderers and does not switch the application's renderer.

An AAB remains a delivery option supported by [Android's per-device package delivery](https://developer.android.com/guide/app-bundle). This task keeps it separate from the ABI-only APK change: the repository's current ad integration is debug-only, so a release bundle also requires reviewing release functionality and signing. Custom templates must match the engine build, as described in the [Godot Android compilation documentation](https://docs.godotengine.org/en/stable/engine_details/development/compiling/compiling_for_android.html).

## Verification

All execution used task-owned offline profiles. Native runs used pinned Godot `4.7.2.stable.official.ed1daf0bf`, desktop RTX 3090/NVIDIA 616.92, Dummy audio and 1280×720. Compatibility and desktop Mobile are distinguished from an Android device. Neither the OS/driver cache nor physical storage was made cold.

Accepted component checks include:

- Profile focused: 627/0 headless; 633/0 on each desktop renderer. Retained Profile: 400/0 headless and 412/0 on each renderer, with 32 native captures.
- Header final actual-App and gate checks: 9/0 and 30/0. Final frozen five-car staging: 39/0 on each renderer.
- Garage request ownership: 29/0 with real blocked workers, success/failure completion, retry and nonblocking retirement.
- Checkpoint: 91/0 fresh write, 100/0 true process restart, 173/0 contracts, 436/0 archived exact fields, 2,805/0 physical road/kerb coverage and 71/0 hairpin/replay; 3,676 assertions total, plus 5,144 shortcut candidates. The persistent-layout replay completes five laps/47,712 ticks with zero collisions and exact quantized replay.
- Retained race loading: 176/0; Daily overlap: 98/0. The race-loading fixture now explicitly checks immediate cancellation and waits for the new asynchronous feature-entry boundary before asserting the destination.
- Asset preflight: all 468 resources, 1,925 checks/0 failures; five exact bundled pictures and 156 source hashes. No rebake was needed.
- Android tooling: seven tests, preset equivalence and PowerShell parse pass; existing APK CRC/ABI validation passes. Missing-NDK preflight is an expected exit 2.
- Standard final `scripts/dev.ps1 -Action CheckScript -ScriptPath res://core/app.gd` passes in a private profile. Final generated build ID: `9d328fb6e64cdf51f72c95abc68c1d5f`.

The [frozen integrated native ledger](evidence/mobile-performance-implementation-2026-11-06/integrated-native.json) records seven successful processes, **269 checks/0 failures**, no timeouts, no script errors and unchanged sources during every run. It includes real race/Editor/Garage entry (24/0 on each renderer), final header staging (39/0 each), navigation (24/0), and five opening laps per renderer (Compatibility 57/0, Mobile 62/0), all with zero contacts.

At a 60 FPS cap, driving p99 frame intervals were 17.762?17.883ms on Compatibility and 17.741?17.955ms on desktop Mobile. Maximum driving intervals were 18.801/18.631ms, with no driving samples over 33.333ms. These are observed wall-clock intervals, not GPU execution times or an uncapped throughput comparison. Compatibility still recorded an 803.938ms Desert countdown hitch, outside the driving distributions. Mobile recorded one new Desert draw pipeline. Compatibility's zero pipeline counter does not establish zero native GL compilation. Production assets were not reduced to obtain these results.

## Retained failures and remaining work

Initial checkpoint work caught an invalid script-constant reflection call, StringName-versus-String dictionary-key differences, and a valid finish projection just beyond route length. These were corrected while retaining exact builder output and without weakening the final assertions. Independent review added the engine commit hash guard.

Initial navigation tests caught a freed lambda capture during cancellation and an Editor deferred-fit callback after departure; both are corrected. An old synchronous-navigation fixture failed until it was updated to wait for the real feature-entry boundary and also assert immediate race cancellation. The rejected threaded experiment's timeout and leaks remain recorded.

The standard entry point's first unisolated check was denied access to its default engine log directory; retry in a private profile passed. Direct engine tests report the existing Windows root-certificate-store error even though live transport is disabled. Some early native runs and retained Mobile Profile reported the existing ObjectDB/audio-resource shutdown warnings; the seven integrated native runs have no ObjectDB/resource-retention warnings, while the post-normalization navigation repeat again reports two ObjectDB instances and one retained `01-blacktop-thunder.mp3` AudioStreamMP3 resource. These intermittent shutdown findings are not counted as evidence of a memory improvement.

Phone/tablet loading, touch, thermal behavior, PSS/GPU memory and listening acceptance remain unmeasured. Garage AA/resolution and renderer selection are therefore unchanged. The source-integrated Android shader engine remains blocked by the missing pinned toolchain and lacks device profiles. Daily snapshot prewarming still requires separately authorized backend work. No real authentication, live backend request, owner-save/process change, deployment or main-index write was performed.

## Reproduction and checkpoint

`evidence/mobile-performance-implementation-2026-11-06/navigation/run_case.py` records every bounded engine command, exit status, source hash, private profile and diagnostic. `freeze_project.py` creates task-owned code/prepared-asset copies and shared static-asset links used only for reads. The initial manifest and final pre-test refresh are both retained. After the seven native runs, strict checkpoint validation caught unintended CRLF conversion and one terminal blank line; these were normalized without changing any source tokens. [Byte comparisons](evidence/mobile-performance-implementation-2026-11-06/source-normalization.json) prove every non-generated difference is only line endings or terminal blank lines. Standard parsing, startup 22/0 and native navigation 24/0 pass again after normalization and identity regeneration; the [repeat ledger](evidence/mobile-performance-implementation-2026-11-06/normalized-validation.json) includes the retained audio shutdown diagnostic. Generated `build_identity.gd` and project version follow the standard entry point; they are excluded from the task-only source patch because their task-start originals were not captured and unrelated generated churn must not be attributed to this task.

The component change manifests identify each edited file and exact task-before hash. The final source checkpoint uses those snapshots rather than repository HEAD, and validates forward application, byte-exact results and reverse application in a private Git repository. Concurrent workspace changes remain intact.

The [task-only patch](evidence/mobile-performance-implementation-2026-11-06/task.patch), [file manifest](evidence/mobile-performance-implementation-2026-11-06/task-manifest.json) and [strict checkpoint receipt](evidence/mobile-performance-implementation-2026-11-06/task-checkpoint.json) contain the reviewable source/document changes. Large captures, raw inventories and generated identity churn are retained separately in the evidence directory.
