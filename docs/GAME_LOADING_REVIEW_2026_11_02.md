# Game loading review — 2 November 2026

There is substantial scope to shorten startup and first race entry. The current workspace already contains race-loading changes beyond the earlier review: bounded batches of reused particle proxies, shared road/world accounting, world-priority trimming, and more selected-track CPU preparation. Those changes were preserved. This evaluation changes no shipping code and claims no implemented speedup.

Requirements: GLR01 review actual startup; GLR02 measure current first/repeated race entry and retry; GLR03 rank remaining improvements; GLR04 preserve reproducible evidence and a task-only checkpoint.

## Measurements

Pinned Godot `4.7.2.stable.official.ed1daf0bf`, Windows, RTX 3090, 1280×720, Dummy audio. Each race renderer used its own fresh private application/road-cache profile. Startup uses private stock/customized Compact profiles; the cached run reuses the customized profile after admitted PNG writes have finished. The API is explicitly disabled. No owner data or processes are changed.

These are development desktop measurements, with shared host activity and existing driver/OS caches. They are not controlled cold-driver tests, export benchmarks, renderer comparisons or Android predictions.

### Startup

| Profile | App scene/resource load | Initialization after App installation | Equipped header preparation | All Garage pictures preparation |
| --- | ---: | ---: | ---: | ---: |
| Stock, fresh private profile | 10.595 s | 0.281 s | <0.001 s | 0.034 s |
| Customized Compact, fresh image caches | 11.590 s | 28.288 s | 12.540 s | 15.535 s |
| Same customized profile, completed PNG caches | 11.511 s | 0.282 s | 0.065 s | 0.001 s |

Header/Garage columns are portions of initialization, not extra time to add. The customized fixture changes only the body paint. Cold initialization rendered one header image and one Garage image; cached initialization rendered neither. All five current catalogue vehicles have matching Garage pictures before the existing startup gate releases.

The resource timer measures an actual `load("res://core/app.tscn")` before reloading an instrumented App copy. Instrumented reload costs 0.899–0.999 s in these three runs and is excluded from initialization. The diagnostic has already loaded some dependencies before that timer, and process/engine/autoload startup is excluded. Consequently the table describes slices, not full launch-to-interaction totals.

A second probe without game-class references independently measures **12.088 s** to load the shipping App scene. A separate ordered-resource probe measures Game first at 7.769 s, Garage page next at 3.226 s, TrackBrowser at 0.519 s, Rivalry page at 0.537 s, then remaining App loading at 5.569 s. These are order-dependent resource/dependency loads; do not add them to the App-only run or treat their differences as recoverable savings.

### Race entry

Actual App sequence, offline Star fixture, default detailed Compact. Compilation happens before timing. Pine is first in each process; Winter follows and benefits from earlier shared work. Each theme is entered twice, leaving the Game between entries. Selection dwell/prefetch, downloads, competitive authorization and Daily limit requests are excluded.

| Renderer/theme | First entry | Reopen same theme | First-entry largest frame | Reopen largest frame |
| --- | ---: | ---: | ---: | ---: |
| Compatibility / Pine | 50.707 s | 0.514 s | 6.021 s | 78 ms |
| Compatibility / Winter | 22.701 s | 1.864 s | 3.449 s | 142 ms |
| Desktop Mobile / Pine | 36.020 s | 0.842 s | 4.556 s | 211 ms |
| Desktop Mobile / Winter | 12.529 s | 1.715 s | 2.821 s | 85 ms |

Compatibility Pine's first entry spends 4.971 s waiting for roads, 6.134 s in Game installation, 31.467 s in staged world graphics preparation and 7.995 s in effects/final preparation. Winter's corresponding phases are 3.271/4.553/10.033/4.771 s. Phase timers include cooperative yields, rendering/resource work and covered frames; they do not isolate CPU geometry, particle GPU time or native driver compilation.

All eight actual `App._retry_race(true)` calls reuse the same Game and take **12.556–19.240 ms**, excluding online authorization. Each entry preserves completed preparation, canonical tick zero, the full 360-tick countdown and five laps. No complete driving lap was measured.

The current results supersede using the earlier review's repeated-entry numbers to describe this workspace. They are not a controlled before/after test of the intervening changes.

## Recommended work, in order

1. **Move Garage picture misses off the startup gate.** `App._ready` awaits the equipped header, then *all* Garage pictures before showing account/Rivalry. The cold customized case spends 15.535 s on the latter even though the initial guest destination has no Garage. Keep exact equipped-header readiness; let Garage pictures prepare when background work is eligible. `_show_screen` already routes Garage navigation through `_open_garage_with_pictures`, so a direct early visit can still wait for matching images. Preserve cancellation, account changes, pressure/input/foreground handling and no-wrong-livery behavior. The measured phase is an opportunity ceiling, not a demonstrated 15.5-second saving; moving work may affect the first Garage visit and menu responsiveness.

2. **Reduce the resource graph required to open the first screen.** App has an eager `GAME_SCENE` preload plus editor, Garage, race and menu dependencies, including preloads written inside functions. A cached profile still pays roughly 11.5 s in the measured App loading slice. Split services/page factories and defer optional resource reads, with bounded preparation during eligible menu idle. Moving one constant is insufficient if typed references and other preloads still load the same dependencies. Measure a representative release export first, then verify actual launch-to-first-interaction and first navigation/race costs. The desktop source-script result does not establish an equivalent exported or phone saving.

3. **Target first-use graphics preparation, rather than another blanket warm pass.** Compatibility Pine spends 31.467 s in the world preparation phase and retains a six-second frame. Subsequent same-theme world preparation submits zero new groups. Evaluate a small representative staging scene or hiding earlier prepared groups to reduce repeated full-world drawing, while retaining the final complete covered draw. Measure exact appearance, largest frame, peak memory and a complete first driving lap; reject moving a stall past the loading cover. Current timestamps do not prove the cause of each large frame. Earlier native compile/link attribution in `NATIVE_SHADER_PREPARATION_2026_10_28.md` remains historical evidence, not fresh attribution. No unsupported background GL compiler or renderer switch is justified here.

4. **Fix the remaining Winter retention tradeoff within the current allowance.** Pine now stays cached: the trace records 28,245,312 bytes of shared roads and about 61.04 MB retained after trimming. Winter still repeatedly admits and evicts a 40,818,796-byte world. After eviction, approximately 36.03 MB remains, including 30,273,088 bytes of cached road GPU resources, with no shared-road deduction. This is not proof those road resources are unnecessary; inspect their identity/use and consider evicting unrelated idle roads or retaining a smaller costly scenery subset before dropping the current world. Keep the 64 MiB allowance and pressure cleanup. A snapshot taken immediately after entry sees one world and would miss the later eviction; the process-frame trace catches it on both renderers.

5. **Extend exact-event preparation and overlap independent waits.** Free Race already has a 650 ms selected-track preparation gate, now also priming query/gate/support data. Its validity checks explicitly require the `tracks` screen; Daily/Rivalry detail pages do not receive that same selection path. Reuse exact revision/car/account ownership for those modes rather than introduce another track-mutating worker. Daily limits currently finish before the later road-job stage; investigate overlapping independent CPU work with that read while preserving all day/revision/car/manifest and cancellation checks. Network savings are unmeasured because these profiles are offline. Never issue a competitive attempt speculatively.

Existing warm proxy batching should be measured further only after these changes; it already draws every actual source and does not infer shader equivalence from an emitter name. Ordinary and Daily retry reuse already exists, so rebuilding that facility would duplicate existing behavior. Disk scenery packets remain a possible later CPU-cache extension, with versioning, bounded decoding and corruption fallback; they will not by themselves resolve first-use graphics work.

## Evidence and reproduction

The three primary startup runs pass **60 checks / 0 failures**. Each race renderer passes **36 / 0**, giving **132 / 0** total, eight entries and eight retries. The two resource probes load all six requested resources successfully. Raw JSON/logs, per-run commands, before/after source hashes, profiles and the derived [summary](evidence/game-loading-review-2026-11-02/summary.json) are in [the evidence directory](evidence/game-loading-review-2026-11-02/).

From the workspace root, using `python docs/evidence/game-loading-review-2026-11-02/run_review.py`:

```text
startup-stock-v2 res://tests/review_game_startup_2026_11_02.gd --profile stock-v2
startup-custom-foreground res://tests/review_game_startup_2026_11_02.gd --profile custom-foreground --custom
startup-custom-drain res://tests/review_game_startup_2026_11_02.gd --profile custom-foreground --custom
startup-custom-cached res://tests/review_game_startup_2026_11_02.gd --profile custom-foreground --custom
race-compat res://tests/review_race_loading_2026_11_02.gd --themes=pine,winter --cycles=2
race-mobile res://tests/review_race_loading_2026_11_02.gd --renderer mobile --themes=pine,winter --cycles=2
resources-app res://tests/review_app_resources_2026_11_02.gd res://core/app.tscn
resources-parts res://tests/review_app_resources_2026_11_02.gd res://core/game.tscn res://ui/garage_page.gd res://ui/track_browser.gd res://ui/weekly_rivalry_page.gd res://core/app.tscn
```

These are arguments following the runner command, not standalone commands. Choose new labels/profile directories for fresh reruns rather than overwrite evidence. `python docs/evidence/game-loading-review-2026-11-02/summarize.py` derives the table and rejects failed runs or changes among recorded sources. The runner uses `scripts/run_no_crash_dialog.py` and a 300-second timeout scoped to its own process tree.

The initial startup probe rejected a nonunique track-read anchor before running App; the failure log is retained. An initial instrumented-load result was refined to time the actual shipping resource load separately. Early immediate-teardown/restart probes are supplementary: PNG completion and build identity affect cache reuse, so they are not the primary cached measurement. The final diagnostic drains admitted writes after the timing; the cached run confirms one header disk hit, five ready Garage images and zero native captures. Its runner additionally hashes build identity/project configuration. Earlier receipts cover their listed sources only, not those extra identities or the whole tree. Recorded source hashes remain stable within every primary run.

Every primary native log retains the sandbox's Windows root-certificate-store error. Runs exit zero with no script/shader errors, but this is not a clean environment-log claim. The first exploratory stock probe also retains two ObjectDB instances/one resource at shutdown; primary logs do not reproduce that finding. No invariant was relaxed.

Task files: two new diagnostic scripts, this report, evidence runners/summary/checkpoint helpers, and concise AGENTS/DEVELOPMENT_STATUS entries. Startup hooks are injected into a GDScript copy in memory; the race diagnostic reuses the existing instrumented actual-App probe. `checkpoint.py` produces a task-only patch and checks forward/reverse application and normalized contents in an owned workspace directory without writing the main Git index. Existing unrelated changes remain preserved.

No visible game changes or new appearance-equivalence claim. No phone/device query or test, APK/export, real authentication/purchase, backend/live access, deployment, owner-save change or owner-process restart. Remaining acceptance belongs to each proposed implementation above; genuine cold-driver, signed-in startup/network, all cars/themes, graphics-context recovery, first-lap and Android results remain unmeasured.
