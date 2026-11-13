# Tablet loading fixes — 2026-11-07

TLF01–TLF03/TLFQ01 implement the car, snapshot and scenery priorities from [tablet phase profiling](TABLET_PHASE_PROFILING_2026_11_07.md). TLF04's startup scheduling experiment was measured and rejected. The final results below distinguish the saved stock Kart from an explicitly pinned fitted Compact. The universal half-loading target remains unmet.

## Implementation and technical choices

**TLF01 — exact fitted Simple-car reuse.** `game/vehicle/prepared_car_cache.gd` now admits completed procedural non-stock Simple models to the existing live restoration path. It retains the four-entry/16 MiB bounds, geometry keys, original shadow casters, articulation bindings, rest transforms and independent mutable materials. The modular Simple-fit shadow guard remains. This reuses exact completed models instead of substituting stock shadow proxies or adding an unbounded all-fit asset library. A first uncached construction is still needed. The historical target is Compact with wide body, scoop, biwing and turbine rims; the saved setup at this task's start is a stock Kart with Simple models enabled.

**TLF02 — snapshot writer lifecycle.** `game/backend/menu_snapshot_writer.gd` defers root attachment until the root finishes entering children, and `_ready()` preserves processing for values queued before attachment. Atomic writes, account scope, latest-value coalescing, queue limits and background eligibility remain. This fixes the busy-parent error and outside-tree writer recorded in every previous tablet run.

**TLF03 — numerical scenery worker.** `game/track/spatial_mesh_chunks.gd` delegates numerical grouping, triangle remapping and attribute copying to new `game/track/spatial_mesh_preparation.gd`, using the existing low-priority cancellable WorkJob. RenderingServer access, exact quantized normal preservation, ArrayMesh uploads and scene-tree installation remain on the main thread. Object assembly ranges, ordering, synchronous fallback, budgets and cancellation remain. Consumed worker result dictionaries are cleared as renderer resources take over. There is transient worker output, not a new retained scenery cache. This keeps thread boundaries explicit and avoids moving Nodes or renderer mutation onto an unsafe worker.

**TLF04 — rejected startup deferral.** The experiment waited for restored content/podium presentation before optional discovery/header/Garage preparation. Historical startup appeared 13% faster, but the fresh same-session control gave 5.695 versus 5.872 s and first Garage 1.585 versus 1.940 s. This did not justify shipping the scheduling change. The experiment and its test are archived, and only this task's App edits were reversed in the working tree. The final tablet uses the original installed App scheduling and direct Garage entry, with its original inline showroom and both reflections.

The final implementation contains four runtime files, three focused regressions (`test_snapshot_writer_lifecycle.gd`, `test_fitted_simple_cache.gd`, `test_spatial_worker_object_ranges.gd`) and the world-stage diagnostic `profile_loading_world_stages.gd`. Canonical simulation, handling, geometry, shaders and backend contracts are unchanged by this task. The proposed custom engine is not used.

## Source isolation, assets and packages

The initial desktop snapshot contained unrelated pending tuning/concurrent edits. Its first export was stopped before installation. Accepted tablet projects were reconstructed from the exact installed `e14bec0e820302b39bbb8c16684bda60` source and received only the loading changes. The [source proof](evidence/tablet-loading-fixes-2026-11-07/qualified-source-proof.json) compares 722 source/resource declarations and preserves installed handling byte-for-byte; final App scheduling is exact to the installed source. The [final runtime proof](evidence/tablet-loading-fixes-2026-11-07/final-runtime-proof.json) confirms the four delivered files match the working tree.

Concurrent Kart, model-detail, World Circuit and header work remains in the working tree. Its prepared assets were rebuilt against its own sources rather than overwritten with the older tablet snapshot. Both working-tree and isolated tablet asset passes report 468 resources / 1,925 checks / zero failures and five-picture provenance with 157 source hashes, with stable bake-source receipts. Generated assets include concurrent authorship and are not claimed as a task-only binary diff.

All packages use official pinned Godot `4.7.2.stable.official.ed1daf0bf`, standard templates and ARM64. The initial four-change profiling build `53a2cf440b6a8cab05137fc4bda81bb2` and uninstalled normal candidate `7d0333f6d23e3b022515df098c2aa58d` are archived under [rejected startup deferral](evidence/tablet-loading-fixes-2026-11-07/rejected-startup-deferral/decision.json). Both final packages were rebuilt after restoring original startup scheduling. The final observer adds explicit private configuration/hit checks; its five visual/checkpoint cache identities match the normal candidate.

Standard exports pass import/startup, prepared assets, driving72/0, catalogue21/0 and menus41/0. Final source audits change only generated identity/project metadata. This is a loading release qualification, not a full physics merge gate or custom-engine qualification.

## Desktop verification

- Writer lifecycle **12/0**: root-entry queueing, early allowed writes without external resume, background suspension, account scope and bounds. Original source reproduces the busy-root error; the standard runner stops before a completed assertion summary.
- Fitted-car initial headless **66/0**, extended actual presentation **138/0**: exact arrays/materials/casters/transforms, independent paint/brakes, moving-part bindings, ghosts, keys/budgets, steering, wheel/fan/rudder motion and suspension, with canonical state unchanged.
- Native Mobile **84/0**, with all six frames exact. Compatibility retains **85 checks / one strict pixel failure** for the arbitrary last-option Compact; the historical fitted target and other models match. The single changed pixel is an exact coordinate/RGBA subset of four changes in an independently reconstructed original. [Pixel proof](evidence/tablet-loading-fixes-2026-11-07/pixel-control.json) retains the strict failed assertion; it does not relabel it as an exact-frame pass.
- Existing cooperative chunks **71/0**; new exact original-versus-worker object-range/cancellation controls **71/0** native and **71/0** on the installed-base project headlessly.
- Initial-readiness experiment **4/0**, actual Rivalry **10/0**, private real-App account→tracks→race→Garage→owner-change flow **19/0**. The rejected readiness test is archived, not retained as a final implementation requirement.
- Installed-base opening-lap suites **123/0 Compatibility** and **133/0 Mobile**, each with five actual laps and zero contacts. Default loading/interruption suites **103/0** each do not drive without `--first-emission`.
- Final explicit-fit observer controls **24/0** each for forced construction and reuse, with stable source hashes and no script errors.

One prepared-road headless pair gives Star scenery 729.752→633.370 ms, partitioning 124.591→93.347 ms; Oval is 623.984→639.096 ms and shows no gain. These are component observations, not device/whole-loading claims. The final tablet evidence below supersedes them.

## Configuration correction and method

The first historical race comparison was invalid: original profiling used a fitted Simple Compact, whereas this task's initial private backup already records a stock Kart. Both the first candidate and fresh previous-APK control used that Kart. The apparent 64–81% historical repeat improvement therefore could not be attributed to this patch; that attribution was explicitly withdrawn. [Configuration correction](evidence/tablet-loading-fixes-2026-11-07/configuration-correction.json) and superseded comparisons remain available without being treated as acceptance.

The final observer records actual vehicle, Simple flag, parts and template-hit counter on every race. Normal runs retain the saved stock Kart. A separate fitted-Compact fixture changes only private practice preferences and checks that owner settings remain unchanged during every case. Its construction control clears only the process rest-template cache before each entry, forcing the unchanged procedural builder without bypassing shadow/material guards. Four fixed-fit runs use construction→reuse→reuse→construction order, separate initially empty diagnostic road/layout directories per arm, and a process restart per run. This isolates model reuse in the final implementation; it is not an old-APK whole-app comparison. All races stay at tick zero and submit no scores.

Existing app/driver caches remain. Two samples per mode/arm and fixed fixture order do not establish cold-driver behavior, all-car loading, online admission, sustained driving thermals, PSS memory or a universal 50% improvement. First-entry A and B have different disk-cache states and are shown separately below.

## Commands, retained failures and review scope

Actual commands and receipts are in [the evidence directory](evidence/tablet-loading-fixes-2026-11-07). Principal entry points:

```text
python docs/evidence/tablet-loading-fixes-2026-11-07/run_test.py <label> <test.gd> --project qualified [--native gl_compatibility|mobile] [--test-argument=--first-emission]
python scripts/prepare_car_assets.py --output build/tablet-loading-fixes-20261107/integrated-assets
python docs/evidence/tablet-loading-fixes-2026-11-07/export.py qualified
python docs/evidence/tablet-loading-fixes-2026-11-07/export.py profiled-qualified
python docs/evidence/tablet-loading-fixes-2026-11-07/tablet-qualified/same_session_control.py
python docs/evidence/tablet-loading-fixes-2026-11-07/tablet-qualified/final_profile.py
python docs/evidence/tablet-loading-fixes-2026-11-07/analyse_fit.py
python docs/evidence/tablet-loading-fixes-2026-11-07/tablet-qualified/deploy_normal.py
python docs/evidence/tablet-loading-fixes-2026-11-07/tablet-qualified/final_audit.py
```

Exports call pinned `scripts/dev.ps1 -Action ExportAndroid -AndroidPreset "Android ARM64" -QuickValidation -CommandTimeoutSeconds 600`. Tests use private offline APPDATA. Owner PC saves/processes are not changed. Normal tablet application reads/synchronization can refresh sessions, caches and acknowledged appearance.

Retained failures include sandbox/certificate access; an initial Forklift fixture assuming front wheels; a wrapped world fixture and early metric including road work; private Git ownership/path/ignored-copy setup; an incomplete Mobile lap attempt with exit zero but no completion/result; stopped unsuitable-snapshot export; one observer missing its private customisation dictionary; a run overlapping generated identity refresh; wrong previous-observer result directory causing JSON decoding failure; and host report encoding failure corrected to UTF-8. Successful lap/car runners now require completion markers. No strict rendering assertion is weakened.

ADB exited 255 during the initial post-install manifest; the recovered audit proves all 839 files exact before first launch. Two secure-lock pauses required the owner's unlock. Later replacements launch immediately before slow audits. Screen timeout remains 30 seconds and global stay-awake remains unchanged. Existing catalogue-anchor and embedded ICU-data warnings remain. The final all-appearance save audit exception is recorded below rather than hidden or overwritten.

Original APK/data backups, manifests, private native captures and rejected attempts remain in ignored build storage. Only task diagnostic files absent from the initial manifest are removed after archival. No player-data clearing, track sync, direct backend/admin action, backend rollout, main-index staging, commit or reset is performed. The reversible checkpoint covers owned source/tests/journal/text evidence, inventories image hashes, and excludes mixed-author prepared binaries.

## Final device results and delivery

The final saved-Kart matrix passes **304/0** and the four fixed-fit runs **536/0**: **840 checks / zero failures**. Android thermal status is zero throughout. Final stock-run battery temperatures are 30.1–30.2°C; fixed-fit temperatures are 30.0–30.0°C. Existing driver caches are retained. These are two samples per mode/arm and fixed fixture order, not broad population statistics.

The stock-Kart comparison below uses the reinstalled previous APK in the same session. First entry A starts with empty task road/layout storage; first entry B retains that storage but starts a new process. The values are kept separate because these are different cache states.

| Stock Kart fixture | Old A / B first entry, s | Final A / B first entry, s | Old → final repeat median, s |
|---|---:|---:|---:|
| oval/desert | 8.045 / 5.498 | 6.632 / 4.103 | 1.383 → 1.368 |
| oval/night_city | 5.603 / 4.595 | 4.598 / 3.957 | 1.107 → 1.130 |
| oval/pine | 11.372 / 9.144 | 7.507 / 6.201 | 0.607 → 0.584 |
| oval/storm | 4.380 / 3.738 | 3.546 / 2.552 | 1.133 → 1.115 |
| oval/winter | 3.881 / 3.185 | 3.646 / 3.053 | 1.269 → 1.196 |
| star/pine | 22.341 / 9.082 | 20.653 / 7.209 | 1.174 → 1.052 |

Actual initial menu readiness is **5.695→5.747 s** median; the sample ranges overlap. There is no established startup improvement. First Garage is 1.585→1.534 s, preserving the direct entry. Most menus are similar; first Editor is 1.976→2.154 s and remains unresolved. The repaired writer is inside the tree and completes snapshots in every final run.

| Menu | Old → final first median, s | Old → final repeat median, s |
|---|---:|---:|
| Biome | 0.378 → 0.399 | 0.420 → 0.398 |
| Challenges | 0.414 → 0.419 | 0.204 → 0.212 |
| Editor | 1.976 → 2.154 | 1.718 → 1.699 |
| Daily | 0.790 → 0.766 | 0.581 → 0.536 |
| Drafts | 0.684 → 0.679 | 0.209 → 0.201 |
| Garage | 1.585 → 1.534 | 1.049 → 0.398 |
| Profile | 0.195 → 0.196 | 0.120 → 0.112 |
| Rivalry | 1.395 → 1.370 | 0.299 → 0.292 |
| Settings | 0.285 → 0.276 | 0.135 → 0.115 |
| Store | 0.356 → 0.366 | 0.362 → 0.375 |
| Tracks | 0.163 → 0.171 | 0.158 → 0.159 |

For the **explicitly pinned fitted Simple Compact**, repeated model preparation is **2506.575→20.639 ms** median. The following full repeat loads compare forced original construction with template reuse in the final APK, with identical private car configuration and a verified hit/miss counter. They are not measurements of the saved stock Kart.

| Fitted Compact fixture | Construction → reuse repeat median, s | Reduction |
|---|---:|---:|
| oval/desert | 4.112 → 1.425 | 65.3% |
| oval/night_city | 3.887 → 1.193 | 69.3% |
| oval/pine | 3.490 → 0.589 | 83.1% |
| oval/storm | 3.591 → 1.142 | 68.2% |
| oval/winter | 3.482 → 1.283 | 63.2% |
| star/pine | 3.540 → 1.127 | 68.2% |

**The universal half-loading target is not achieved.** The fitted-car repeat bottleneck is addressed; startup, menus, the large Star first load and remaining native/render preparation still need work. No lower quality, alternate physics, new Garage modal or custom engine is used.

Normal build **`0.3.0-creator.f81f1e617b6c54213e17e5786f45875e`** is installed and foreground startup/direct Garage are verified. APK SHA-256: `cbd184eb6a5abe74256229ef7df6e3c7af075ecb6d73ec031157f7090b507d83`; 320,479,572 bytes; 8875 ZIP entries with valid CRCs; ARM64 native libraries match the original APK byte-for-byte. The final profiler is `0.3.0-creator.571a2d99eb312b1fdfb034a042797136`, SHA-256 `37a9511395b472a81fd5f9abedb57a523c66e303677a1745e1ebc1b7cbae61d3`. Standard export checks and source audits pass; only generated identity/project metadata changes during the final exports.

The original first-install timestamp, all **22 checked authored-track JSON files**, both PB dictionaries, selected stock Kart and Simple preference are preserved. Initial app-file count is 839; after final launch/normal cache updates it is 840. The first profiling installation preserved all 839 files before launch. The final replacement launches before the slow full manifest to avoid the secure screen timeout, so it does **not** claim every app file was compared before that launch. Final authored data/PBs/settings and installed APK hashes are audited afterward. Task diagnostic folders/marker/APK transfers are removed after private archival. The normal app remains open; stay-awake setting remains 0.

**Retained save-audit exception.** Strict comparison of every initial appearance preference fails: the unselected Compact body is now Rally rather than Wide arch, and its body/accent/detail colors and pattern also differ. Both the initial and final appearances match their respective acknowledged sync baselines. The cause of that remote-state difference is not attributed to this task. The diagnostic only pins a private Wide-arch fixture and checks that owner settings remain unchanged during those cases. Current acknowledged appearance was left intact and the original backup retained. On 2026-11-07 the owner explicitly confirmed keeping the current synced Rally body. No all-preferences-unchanged claim is made; the original strict deployment assertion and subsequent livery-audit failure remain recorded.

Private native startup and Garage captures are retained under ignored build storage. Public receipts: [final stock comparison](evidence/tablet-loading-fixes-2026-11-07/final-comparison.json), [fixed-fit ABBA](evidence/tablet-loading-fixes-2026-11-07/fixed-fit-comparison.json), [deployment](evidence/tablet-loading-fixes-2026-11-07/tablet-qualified/normal-deployment.json), and [reversible source/evidence checkpoint](evidence/tablet-loading-fixes-2026-11-07/checkpoint.json). The checkpoint excludes mixed-author prepared binaries and inventories image hashes separately. Concurrent work and the main index are preserved.
