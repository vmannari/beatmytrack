# Loading optimisation pass, 6–7 November 2026

The requested 50% reduction across startup, every menu and race loading is **not achieved**. This pass removes redundant startup work and incidental dependency loading, retains expensive race effects before disposable road intermediates, and builds/packages the custom Android engine locally. The static Rivalry picture experiment was **rejected and removed** because it shifted preparation into later menus without improving the whole journey. The verified race improvements below are desktop observations. No device query, tablet performance test, APK export, installation or backend deployment was performed in this pass.

The owner's previous Garage correction remains: entering Garage opens its original live workshop directly, with no added loading window. Camera, car appearance, reflections, canonical simulation, five laps, countdown and competitive rules remain unchanged.

## Requirements and implementation

| ID | Implementation and scope |
| --- | --- |
| LHF01 | Measure actual startup, populated menus and installed race readiness, including first and repeat entry, against frozen task-start sources. Distinguish first draw from fully settled native content. |
| LHF02 | Restore only the final active owner's selected track during boot. Avoid decoding a silent Guest/default soundtrack before the restored recording is known. Preserve sign-out, Guest startup and playback transitions. |
| LHF03 | Evaluate exact settled native Rivalry picture reuse across processes. Reject the candidate after whole-journey testing; retain the independent Profile renderer lazy-load boundary and original live Rivalry/Garage. |
| LHF04 | Evict cheap intermediate road work before initialized effect proxies within existing memory budgets. Remove an incidental world-builder import from car-cache resource accounting. |
| LHF05 | Schedule current published Daily standings work through the existing worker before the first reader needs it. Build the pinned custom Android engine using the explicitly approved project-local toolchain. |
| LHFQ01 | Preserve visuals, ownership, saves, cancellation, rendering quality and race contracts; record initial failures, unmatched cache conditions, rejected alternatives and remaining acceptance honestly. |

`game/core/app.gd` creates the existing default-track placeholder once, waits for account restoration, and restores Guest's remembered creator track only if Guest remains active. Account transitions still use the same restoration body. The initial candidate read the default twice on Guest startup; the corrected implementation passes the already-created placeholder into that helper. The focused actual-App fixture drives `_account_changed`, checks the exact selected owner's compiled track, verifies later sign-out restores Guest once, and confirms the Guest file remains unchanged. The fixture uses a synthetic offline identity; it does not measure authentication or saved-session network latency.

`game/soundtrack/audio_world.gd` retains the chosen record ID while startup is silent and loads its stream when the menu actually starts or enabled settings require it. The existing fades, playback cursor, muted state, race transition and teardown remain. The broader autoload dependency rewrite was discarded after repeat startup measurements failed to establish a gain; the original touch-controls source was restored byte-for-byte.

The rejected Rivalry experiment used a lightweight wrapper and a bounded raw RGBA8 picture store. Identity covered the complete car/livery/parts/condition, exact target size, build/source identity, engine, renderer, GPU and original AA. No resampling, reduced quality or HDR conversion was used. Native fallback, owner fences, atomic replacement, exact lengths/digests and a 24-entry/32 MiB disk bound passed their controls. Those correctness results did not establish a worthwhile whole-journey improvement. All ten candidate source/test files are archived byte-exact; both original Rivalry files are restored, and the two cache scripts plus five adapters/tests are removed from shipping. [Rejection and cleanup evidence](evidence/loading-half-2026-11-06/graphics/GARAGE_TRADEOFF.md).

The independent one-line `player_profile.gd` change remains: load its car renderer when Profile opens, avoiding an incidental renderer dependency merely to bind clickable driver names. No separate whole-menu speedup is claimed for that boundary.

`game/editor/editor_memory.gd` keeps the existing 64 MiB retained, 96 MiB optional-Garage and 12 MiB effect-pool budgets. Ordinary arbitration releases CPU road intermediates/private GPU road caches before completed effects; pressure, borrowed nodes and remaining excess still follow existing eviction rules. `game/track/prepared_world_cache.gd` changes only two parameter annotations from `NativeTrackVisual` to the already-used `Node3D` boundary plus an explanatory comment. All method bodies, preparation, cancellation, ownership and byte estimates remain exact. This avoids importing the world-builder graph solely to estimate car resource memory. Prepared-asset validation remains active; no invalid bake is accepted. [Race evidence and implementation](evidence/loading-half-2026-11-06/race/REPORT.md).

The backend adds `daily_snapshot_preparation.schedule` inside the existing publication/maintenance transaction. It considers only today's published selection and at most one compatible build, eligible visible owners and existing allowed car/population keys. It renews bounded demand through `HistogramDemand`; the normal worker owns snapshots, leases and payloads. Clean snapshots retain the worker's backoff. Dirty, missing-generation or invalidated snapshots can retain earlier priority. No request-handler work, schema change, scoring change or live deployment is introduced. The initial candidate overrode a clean worker backoff; a regression reproduced that failure and the final helper preserves it.

## Measurements and the 50% target

All measurements use pinned Godot `4.7.2.stable.official.ed1daf0bf`, Windows desktop Compatibility on an RTX 3090, private offline profiles and 1280×720 native windows. Before/candidate source trees were frozen; every accepted run records its command and source hashes. Driver caches were not reset. Native timing runs were serial and completed before compilation/parallel correctness checks. Results are small samples, not statistical or Android guarantees.

| Measured path | Before | After | Interpretation |
| --- | ---: | ---: | --- |
| Ordinary offline Account startup, two-process means | 5.416 s | 5.473 s | No demonstrated gain; approximately 1% observed increase, overlapping individual samples. |
| Synthetic restored-owner initialization with Guest creator selection | 663.660 ms | 451.040 ms | Skips the irrelevant Guest compile; one corrected native candidate, not whole real-account startup. Original focused assertions fail 2 of 12, final passes 12 of 12. |
| Rejected Rivalry candidate: settled entry, warmed control versus two restart hits | 5.140 s | 4.353 s mean | Earlier local improvement, subsequently rejected after downstream measurements. |
| Same rejected comparison, largest observed frame | 3.401 s | 1.777–1.792 s | Earlier first draw/hitch improvement did not eliminate later preparation. |
| Winter first re-entry | 1.491 s | 0.657 s | 55.9% reduction in this paired observation. |
| Winter two warm-entry median | 1.112 s | 0.662 s | 40.5% reduction. |
| Desert two warm-entry median | 1.144 s | 0.794 s | 30.6% reduction. |
| Pine two warm-entry median | 0.577 s | 0.604 s | 4.7% observed increase; no Pine speedup claimed. |
| Isolated CarShowroom script dependency load | 2.740 s | 1.482 s | 45.9% component reduction; later EditorMemory still needs world code, so this cannot be counted as equivalent whole-app savings. |

The first complete experimental control run took 57.453 s and the following candidate 25.907 s. **That is not an attributable 55% improvement:** their first-use graphics/cache states differ. Additional warmed control/candidate runs took 25.532/25.047 s for the full observation process. The subsequent same-source experiment below is why the picture-cache candidate was removed despite its earlier Rivalry-only improvement.

The historical warmed menu comparison is retained in [validation.json](evidence/loading-half-2026-11-06/validation.json). The following observations concern the **evaluated, subsequently rejected picture-cache candidate**, in milliseconds; each is one serial pair. Rivalry uses its stricter settled-content milestone, the other screens their visible-content readiness milestone. Fixed transition animation time remains included.

| Screen | First visit before / after | Repeat visit before / after |
| --- | ---: | ---: |
| Rivalry | 5058 / 4413 | 101 / 82 |
| Daily | 255 / 209 | 65 / 49 |
| Tracks | 658 / 573 | 49 / 41 |
| Challenges | 435 / 482 | 99 / 91 |
| Biome | 246 / 243 | 373 / 363 |
| Drafts | 829 / 791 | 42 / 36 |
| Profile | 314 / 211 | 41 / 33 |
| Settings | 417 / 517 | 53 / 41 |
| Store | 251 / 271 | 427 / 391 |
| Garage | 1186 / 2217 | 356 / 340 |
| Editor | 1018 / 955 | 481 / 431 |

These samples do not establish uniform menu improvements. The earlier candidate's first Garage was 1298 ms, while the next candidate was 2217 ms, triggering the additional investigation. All samples retain direct entry and full visual readiness. The first complete baseline race entries were Pine 49.244 s, Winter 27.002 s, Desert 23.615 s, Night 32.241 s and Storm 20.575 s. This pass does not demonstrate halving that expensive first-use graphics work. Immediate retry remains a different, already-fast path.

The final same-source instrumented experiment seeded the picture store, then ran live/cached/cached/live in separate processes under one private profile after all compilation/packaging finished. All five arms pass **36/0 each (180/0)** with unchanged source hashes. Two-per-mode means: Rivalry **5.255 → 3.918 s**, Garage **1.288 → 1.896 s (+47.2%)**, engine-to-Garage **17.228 → 17.492 s (+1.5%)**, and summed first-entry waits **9.769 → 10.115 s (+3.5%)**. One cached arm moved about 1.7 seconds into the next Daily entry; the other paid it during Rivalry. This is work shifting, not a demonstrated overall gain. Engine-to-Garage includes fixture setup, captures and draw fences; per-menu sums omit those gaps.

Both modes reached Garage with an incomplete preloader and discarded it through the existing guarded `take()` path. The shared sky and required scripts were already loaded. Native Garage preparation required more batches after cached podiums skipped actual rendering. A partial-studio transfer is a separate ownership/cancellation/readiness change; it was not introduced late or used to weaken the fully-drawn adoption fence. The candidate is archived for future focused work, while the original Rivalry rendering remains in shipping.

After rejection, the accepted source was frozen and checked again with the original live podiums. The measurement fixture now includes the same four radiance draw fences directly, without importing any picture-cache script. Three whole-menu runs pass **39/0 each**: initial baseline, accepted source, then warmed baseline. The first baseline has different first-use cache state and is excluded from speed attribution. The warmed baseline versus accepted sample is retained below. These are single observations, **not demonstrated menu speedups**; the observed increases remain visible rather than being described as a successful optimisation.

| Accepted-source check, first visit | Warm baseline | Accepted source |
| --- | ---: | ---: |
| Rivalry | 5.011 s | 5.287 s |
| Daily | 238 ms | 207 ms |
| Tracks | 412 ms | 389 ms |
| Challenges | 471 ms | 496 ms |
| Biome | 243 ms | 249 ms |
| Drafts | 781 ms | 851 ms |
| Profile | 176 ms | 248 ms |
| Settings | 430 ms | 455 ms |
| Store | 254 ms | 265 ms |
| Garage | 1.367 s | 1.468 s |
| Editor | 1.002 s | 1.133 s |

The final accepted Garage repeat is 352 ms, with both reflections and no loading window. No universal reduction, zero-regression guarantee or phone result is inferred from this pair. The robust retained benefit is reduced repeat-race effect work, with smaller startup/dependency components and backend preparation separately qualified.

## Correctness and reproducibility

The primary reproduction helpers are [run_case.py](evidence/loading-half-2026-11-06/run_case.py), historical [run_final_matrix.py](evidence/loading-half-2026-11-06/run_final_matrix.py), [freeze_project.py](evidence/loading-half-2026-11-06/freeze_project.py) and [validate.py](evidence/loading-half-2026-11-06/validate.py). Run receipts contain full commands and exact project/profile paths. The evaluated combined candidate remains frozen at `build/loading-half-20261106/frozen-1794003010490398500/game`, build `0.3.0-creator.790acef63c4bfd8847f2201ba8c61322`; it is historical evidence, not the accepted shipping source. The task-start baseline is `frozen-1793996701250524100/game`; the corrected startup-only candidate is `frozen-1794002987023544900/game`.

The accepted shipping snapshot is `build/loading-half-20261106/frozen-1794005128909172400/game`, build **`0.3.0-creator.7aac39deacf24f1291b735bf98f40145`**. Its [manifest](evidence/loading-half-2026-11-06/accepted-project.json) and three `accepted-menus-*` receipts record exact source hashes and native commands. Final validation checks the five retained game-source files against that snapshot and proves the two Rivalry integration files are restored byte-exact with both new cache scripts absent.

Actual final checks:

- Standard `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_startup_feature_parse.gd` through the private offline `standard_check.ps1`: `FEATURE_PARSE_FAILURES 0`. Initial sandbox access/certificate failure is retained; the same owned check succeeded with approved elevated access.
- Final accepted source through the same standard entry: **`FEATURE_PARSE_FAILURES 0`**. Three final whole-menu runs add **117/0**. The wrapper initially reused its fixed receipt filename; the prior log was recovered byte-exact against its pre-existing SHA-256 inventory and the final log stored separately. The wrapper now requires a fresh output name; [recovery receipt](evidence/loading-half-2026-11-06/parse-receipt-recovery.json).
- Four full experimental native menu runs: **39/0 each**, including first/repeat Garage direct-entry and both reflections. Three additional experimental Rivalry arms: **5/0 each**. Each accepted measurement run has no source changes, script errors or timeout; these passes do not imply acceptance of the rejected candidate.
- Corrected startup-owner native fixture: **12/0**; final deferred-audio fixture **8/0** and retained startup music **69/0** on the final combined source.
- Rejected Rivalry isolated evidence: **394/0**, comprising exact-pixel native checks on both desktop renderers, 205 retained live-car assertions, 67 actual-App readiness assertions, 45 storage/corruption/bounds checks and five timing arms. Standalone full-frame images match exactly. The earlier actual-App comparison differs only inside its live week countdown badge, which changed hours between captures; raw evidence remains. The later 180/0 journey experiment is separate.
- Race retention policy: **229/0** in the accepted policy evidence, including two 77-check timing arms, Winter appearance/retention, selective budgets and pressure behavior. Archived policy reproduces the intended three retention failures. Final two-annotation cache/ownership checks add **52/0**, native prepared Compact/Garage construction **5/0 + 6/0**, and final Winter **28/0**. Geometry, full Garage captures and all eleven Pine/Winter views match exactly; no performance claim uses these compilation-overlapping correctness runs.
- Final `python scripts/prepare_car_assets.py --verify --output docs/evidence/loading-half-2026-11-06/prepared-final`: **468 resources, 1925/0**, five exact native photographs and **156 current source hashes**, dependency audit passed. No asset rebake or gate weakening.
- Accepted-source repeat after the normal identity refresh, output `prepared-accepted`: **468 resources, 1925/0**, the same five exact photographs/156 source hashes and passing dependency audit.
- `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_daily_snapshot_preparation.py backend/tests/test_daily_fixed_limits.py backend/tests/test_daily_build_variant.py backend/tests/test_daily_lap_standings.py -q -k sqlite`: **24 passed, 1 skipped, 25 deselected**. Scoped Ruff passed. The test suite uses SQLite; PostgreSQL/concurrent-worker deployment remains untested here.
- Independent source review found no blocking App/audio lifecycle or scheduler transaction/ownership issue. This is review evidence, not additional executed test coverage.

Final accepted native screenshots: [Garage](evidence/loading-half-2026-11-06/accepted-menus-current/garage.png), [Rivalry](evidence/loading-half-2026-11-06/accepted-menus-current/rivalry.png), [Editor](evidence/loading-half-2026-11-06/accepted-menus-current/create.png). Garage was inspected after rejection; prior candidate Garage/Rivalry/Editor and the exact native construction controls were also inspected. These use private synthetic fixtures, not owner data. All earlier images remain beside their receipts.

## Alternatives and retained findings

A general background-loading rewrite is not accepted on assumptions alone. Godot documents that asynchronous requests can move resource reads off the main thread, but retrieving an unfinished request still blocks. The previous shared-script experiment also found lifecycle/teardown problems in this project. Deferring graph dependencies and avoiding unnecessary instances were narrower changes with direct controls. [Godot background-loading documentation](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html).

The Compatibility renderer still requires actual material/particle drawing to prepare native programs. Godot's newer ubershader/pipeline-precompilation mechanisms apply to Mobile/Forward+, and driver-specific binaries cannot be assumed portable. A renderer switch therefore needs device appearance, performance and lifecycle qualification; it is not a safe configuration-only shortcut. [Godot pipeline compilation documentation](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html). The prior pinned selective-program engine remains the higher-potential first-race experiment, but its existing desktop profiles do not qualify Android contexts. Unknown contexts keep ordinary compilation.

Font measurements found roughly 150–166 ms for the complete font script and about 41–43 ms for each large JP/KR font, with correct mixed-script shaping retained. This did not justify reducing multilingual coverage or starting another font architecture change. Existing persistent exact checkpoint artifacts already address the earlier repeated geometry bottleneck; this pass does not count that prior work again.

Initial/negative evidence is deliberately retained: original race-probe anchor mismatch; source-changing early fixtures; startup default double-read; rejected broader audio dependency split; earlier MP3/ObjectDB shutdown warnings; race fixture reparent/adapter mistakes; the contaminated early race timing pair; clean-backoff regression; unavailable local PostgreSQL attempts; and the old migration downgrade failure reproduced with scheduling disabled. Native sandbox runs report inability to read the Windows certificate store, with backend explicitly disabled. The final evidence reconciler initially misread PowerShell UTF-16 logs and used the wrong parse-summary delimiter; both were corrected without changing test outputs or acceptance requirements.

## Android engine preparation and remaining acceptance

The user explicitly approved the project-local NDK download after two automatic approval-review timeouts on the preliminary manifest read. Google's pinned NDK `29.0.14206865` archive was downloaded, verified and extracted under `build/loading-half-20261106/android-sdk/ndk/`. SHA-256 is `4f83a1a87ea0d33ae2b43812ce27b768be949bc78acf90b955134d19e3068f1c`; the official archive SHA-1 also matches. [Download receipt](evidence/loading-half-2026-11-06/engine/ndk-download.json).

The build preflight resolves engine/SDK paths before SCons changes directory. The first real build exposed Android discovery reading `ANDROID_HOME` from the process environment before parsing command-line options; the helper now supplies the validated SDK only to its child. Build 02 began ARM64 compilation but was deliberately stopped when the pinned Swappy frame-pacing dependency was absent. The exact `from-source-2025-01-31` release was then installed into the owned engine tree; all four ABI archives are hashed. Frame pacing remains enabled. External Perfetto profiling is explicitly `none`, matching the pinned default, instead of downloading an unpinned latest tracing package.

Build 03 succeeded in **553.344 s**. Its broad input snapshot was captured during compilation, and that timing limitation is retained. A fresh build 04 using the final helper then verified unchanged inputs before and after SCons, relinked from cached objects in **28.391 s**, and produced the same library bytes. Module `config.py`/`SCsub`, source patches and Swappy hashes now participate in separate build-input verification without changing the existing runtime profile fingerprint. Receipt paths must be fresh and project-owned. Packaging rejects stale inputs, changed libraries, and duplicate/conflicting build options. [Verified build receipt](evidence/loading-half-2026-11-06/engine/android-build-04.json), [package receipt](evidence/loading-half-2026-11-06/engine/packaging-result-01.json), [packaging instructions](evidence/loading-half-2026-11-06/engine/PACKAGING.md).

Actual local commands (from the repository root):

```powershell
python native/biome_shader_profiles/build_android.py --sdk build/loading-half-20261106/android-sdk --arch arm64 --target template_debug --jobs 8 --build --receipt docs/evidence/loading-half-2026-11-06/engine/android-build-04.json
python -B docs/evidence/loading-half-2026-11-06/engine/package_android_debug.py --package --build-receipt docs/evidence/loading-half-2026-11-06/engine/android-build-04.json --output build/loading-half-20261106/android-custom-debug --receipt docs/evidence/loading-half-2026-11-06/engine/packaging-result-01.json
```

These are completed historical commands; reproduction must use fresh receipt/output paths. The local debug AAR is **29,358,739 bytes / 53 CRC-checked entries**, SHA-256 `111716a9ce401aa5cd3684b1437276a5058d13ba026b1a26825f05e01922d637`. The matching Android source ZIP is **29,241,543 bytes / 159 entries**, SHA-256 `e88092d03aa50229f2ddb8dcfa5ba0bf8eb4ffe6919ffeeee60c30929ef9a45d`. Engine library SHA-256 is `01737d55f8e96836823cb9cc5c111c9d8183455a19288ae84fa3591ea44efb83`; the runtime/source fingerprint remains `78661746f7673e61fe81ac52e9189019f2992679e36dff3bf6496c9e85672c49`.

The task-owned packaging helper validates the pinned official Java/resources archive, successful matching native-build receipt, both AArch64 ELF libraries, exact NDK runtime, output entry hashes and CRCs. It preserves official Java/resources byte-for-byte, supplies the two matching ARM64 native libraries, and excludes unsupported ABIs/release artifacts. The final **21-case** identity/archive/flag regression suite passes; receipt-path guards add 4/0, with scoped Ruff passing. Earlier 14/19-case logs remain. This local library/template preparation is not an APK export, installation, Android runtime qualification or performance result.

Remaining acceptance is explicit: the universal half-loading target; first-use Android shader profiles and matching custom-engine client; tablet startup/menu/race timing and memory/thermal/lifecycle checks; owner appearance acceptance; and a separately authorized backend rollout. No real authentication, owner-save manipulation, cloud/admin action or owner-process restart occurred in this pass.

## Review checkpoint and workspace integrity

Task-start HEAD is `7b330ad5c36dbe040995842377a55b957ebc7c39`. The main branch and staged content remain unchanged. The main index's bytes changed during inspection (consistent with Git refreshing stat metadata after a restored source timestamp); no byte-identical-index claim is made. Initial/final hashes are in `validation.json`. Subsequent commands use `GIT_OPTIONAL_LOCKS=0`.

Generated `game/core/build_identity.gd` and `game/project.godot` reflect the normal standard-entry identity refresh and are identified separately from authored changes. Concurrent backend performance/cost review files are preserved and excluded. The task-only checkpoint records authored runtime/tests/tooling and journal additions; its isolated forward/reverse verification does not stage or commit the main repository. Final patch receipt: [checkpoint.json](evidence/loading-half-2026-11-06/checkpoint.json).
