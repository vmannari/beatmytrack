# Startup, race and Garage loading review — 4 November 2026

The largest remaining opportunities are to shrink the startup dependency graph, keep prepared car assets usable, and redesign first-use graphics preparation. The current appearance does not need to be simplified to pursue these. Repeated race entry, race retry, retained Garage navigation and picture persistence already work substantially better than first use; replacing those existing facilities is not the priority.

This is an investigation, with new diagnostics and documentation only. No shipping implementation, visual assets, quality settings, renderer, physics, saves, backend or build identity was changed by this task. Requirements: LR401 current startup measurements; LR402 race entry/re-entry/retry; LR403 Garage immediate/deferred/retained entry; LR404 alternatives preserving appearance; LR405 reproducible evidence and a task-only checkpoint.

## Current measurements

Pinned Godot `4.7.2.stable.official.ed1daf0bf`, Windows, RTX 3090, Compatibility, 1280×720, Dummy audio. Every run has a private application directory and an explicit empty backend configuration. The same customized private profile is reused only for the declared cache tests. OS and graphics-driver caches were not erased. These are development-checkout desktop observations, not Android, exported-build, fresh-driver or statistical performance claims.

### Startup

The boot-only probe has no game-class dependencies before loading the actual App, and does not reload instrumented source. It waits for the first rendered menu after `startup_complete`. Times from engine initialization exclude OS process creation and are not a signed-in network benchmark.

| Boot-only scenario | App resource load | Initialization after installation | Engine initialization to first menu draw |
| --- | ---: | ---: | ---: |
| Fresh private stock profile | 9.026 s | 0.179 s | 12.481 s |
| Customized profile with exact persisted header | 8.778 s | 0.201 s | 11.431 s |

A separate fresh-process resource-only probe measures **9.001 s** for `res://core/app.tscn`. This supports the resource-graph finding independently of the boot fixture.

The timestamp-instrumented actual-App probe separates the customized-image miss:

| Scenario | Initialization | Equipped-header portion | Header captures / disk hits |
| --- | ---: | ---: | ---: |
| Customized Compact, missing picture | 9.687 s | 9.505 s | 1 / 0 |
| Same profile, completed image persistence | 0.204 s | 0.017 s | 0 / 1 |

These are initialization slices, not full launch totals. The instrumented script loads some dependencies before its App timer and adds a separately measured 0.71–0.73 s source reload; do not add its resource timings to the boot-only results or claim all of the difference is recoverable. The missing-header run also observes an 8.806 s frame interval. That includes all work between frames, not an isolated shader-compilation measurement.

Garage preparation no longer gates startup. In these actual-App observations the picture service does not exist at the readiness observation, while the equipped header is ready. This confirms the November 2 deferral is present; recommending it again would duplicate completed work.

### Race

Actual offline App, detailed Compact, Star spline document with Pine then Winter, two entries per theme. Track compilation is outside the entry timer. Each re-entry destroys/recreates Game; each retry calls the existing actual App retry path. Selection dwell, downloads, signed-in authorization and Daily limits are excluded.

| Theme | First entry in this sequence | Re-entry | Retry of existing race | Largest first-entry frame |
| --- | ---: | ---: | ---: | ---: |
| Pine | 42.381 s | 0.509 s | 11.7–13.2 ms | 5.026 s |
| Winter | 22.668 s | 1.618 s | 11.7–19.6 ms | 2.868 s |

Winter follows Pine and benefits from shared preparation. These rows are not independent cold starts or a renderer comparison.

| First entry phase | Pine | Winter |
| --- | ---: | ---: |
| Road job/wait | 3.796 s | 2.804 s |
| Game installation/preparation | 7.352 s | 7.040 s |
| Staged world graphics | 24.092 s | 8.696 s |
| Effects/final preparation | 7.030 s | 4.070 s |

The graphics phase submits 34 groups for Pine and 11 for Winter; neither re-entry needs those groups again. Phase durations include yields, draws, resource work and driver waits. They do not prove that 24 seconds is solely shader compilation. Road preparation alone cannot remove the dominant first-entry cost.

All four entries and four retries preserve prepared completion, canonical tick zero, the complete 360-tick countdown and five laps. The diagnostic passes **36 checks / 0 failures**. No driving lap was measured here.

The cache trace still shows Winter's completed world being admitted and then evicted by ordinary memory arbitration after each entry. Pine reuses its completed world. The Winter entry's end snapshot alone would miss this eviction. Keep the existing 64 MiB retention allowance; investigate which inactive road/scenery components to keep before increasing it.

### Garage

| Scenario | Dispatch to the Garage page | Full live scene ready from dispatch | Retained reopen dispatch |
| --- | ---: | ---: | ---: |
| Initial stock observation | 113 ms | 26.515 s | 2.6 ms |
| Customized Compact, fresh image caches | 115 ms | 17.633 s | 2.3 ms |
| Same profile, completed PNG caches | 104 ms | 3.737 s | 2.4 ms |
| Same cached profile, passive phase follow-up | 131 ms | 3.887 s | 2.5 ms |
| Stock, after background studio preparation | 94 ms | 94 ms | 2.5 ms |
| Same cached customized profile, after background preparation | 81 ms | 81 ms | 2.7 ms |

The stock background preparation itself takes **26.304 s**, including **59 warm draws**, with one warm-draw observation of **1.965 s**. Its quick later navigation is a transfer of already completed work, not removal of that work. All settings remain unchanged, including both live planar reflections.

The matched cached-customized idle follow-up takes **3.861 s** before entry, also with **59 draws** (maximum observed warm draw 159 ms). Its roughly 81 ms handoff follows that work. Compared with the same profile's 3.737–3.887 s direct entry, this supports earlier scheduling, not a demonstrated reduction in total preparation. It does not establish that the two warming implementations have equal cost on first use.

The initial stock observation crossed a concurrent edit to `weekly_rivalry_page.gd`; retain it as supporting evidence, not a frozen-source benchmark. The customized runs, race run, boot-only runs, asset audit and stock idle run have unchanged recorded sources within each run. Shared driver/OS caches and different preparation paths prevent attributing the entire 17.6-to-3.7-second Garage difference to PNG persistence. The header's capture/disk-hit counters give a much more direct explanation of the startup difference.

The cached direct-entry phase follow-up observes roughly 1.16 s from car construction beginning to first-draw staging, then 2.40 s in that staging before final settling. Its completed scene contains 201 visible geometry instances and 45 groups under the current world-preparation key; grouping them in eights would give 56 batches. Those are workload observations, not proof that 45 draws are sufficient in every rendering context. This supplementary observer enumerates keys at readiness and adds diagnostic overhead; use the ordinary startup/Garage fixture for primary timing. The initial stock and customized paths all preserve the actual car paint, full showroom readiness, both reflection views, retained page identity and completed image writes.

## Concrete findings and recommended order

### 1. Restore reliable prepared assets, then make invalidation precise

Read-only inspection of all current catalogue cars finds:

| Prepared asset family | Inspected | Current key and source checks match | Rejected |
| --- | ---: | ---: | ---: |
| Modular car bases | 20 | 4 | 16 |
| Full Garage car templates | 5 | 1 | 4 |
| Compact header template | 1 | 0 | 1 |

Only Volt's four modular bases and its Garage template pass both checks. The other modular bases fail keys and source hashes; the other Garage templates have matching geometry keys but stale source sets. The Compact header fails its validity check and source hashes. Live Compact follow-ups record zero hits for all three prepared-template families.

Relevant sources: `vehicle/modular_car_base.gd`, `ui/garage_car_cache.gd`, `ui/header_simple_cache.gd`, `vehicle/car_visual.gd`, `scripts/build_identity.ps1` and `scripts/garage_preview_identity.ps1`.

The safety fallback is correct. Do not bypass validation or bless old geometry. Regenerate the rejected assets from final current sources, validate native image equivalence, and make the build reject unintended fallback for supported prepared configurations. Then replace broad source-set invalidation with verified dependency manifests: for example, Compact's Garage template currently rejects changes in Electric/Forklift builders. Shared helpers must remain dependencies. Cache immutable geometry separately from paint, wear, mutable instance state and rendering-context readiness.

This is a relatively contained first implementation. It should reduce procedural CPU work; the audit does **not** quantify the saving, and it will not eliminate first-use native graphics work. Source-check behavior also differs in packaged builds, so desktop rejection counts are not a measurement of APK fallback rates.

### 2. Replace the monolithic startup dependency graph with a small shell

`core/app.gd` eagerly preloads `core/game.tscn` and editor tools and references large Garage, track-browser and Rivalry classes. Loading the initial account page consequently pays for features that have not been entered.

Split navigation/session state from Race, Editor and Garage controllers. The initial shell should load only shared chrome, account/session restoration, the initial destination and an exact cached header. Request the likely next feature in the background after the first usable draw, with cancellation and memory/input priority. Optional feature types and preload chains must leave the shell too; replacing a single `preload()` with `load()` is insufficient if another dependency still pulls the same graph in.

Keep the existing UI designs and scene builders behind those module boundaries. This targets the observed 8.8–9.0 s resource-load slice, but that is an opportunity boundary, not a promised saving. A splash that simply loads today's entire App asynchronously improves responsiveness while retaining most of the work. Godot's background loader supports this staging, but calling `load_threaded_get()` before completion still blocks; poll readiness first. [Godot background-loading documentation](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html).

### 3. Unify and reduce redundant graphics preparation

There are separate preparation strategies for race world geometry, effects, the live Garage, preloaded Garage, header and thumbnail studios. Race world preparation already skips further instances after drawing one bounded batch for its current key. Garage preparation still walks groups of up to eight and the preloaded studio renders its full scene as groups become available. Immediate Garage entry uses a small warming viewport followed by complete final-view/reflection settling.

Prototype a shared preparation service for actual mesh/material/render-context combinations, with exact owner and graphics-context lifetimes. Separate mesh decoding/upload, first program use, and final full-scene settling. Test a small staging target for preloaded Garage, matching its real lights, formats, shadows, AA and reflection contexts. Reuse immutable meshes and completed preparation where valid; keep mutable car/particle state private. This can remove redundant work without removing visible objects or effects.

Do not assume equal names/material labels imply equal pipelines. Preserve all actual particle sources and first-use coverage, the final complete frame, cancellation, foreground/input gates and memory-pressure cleanup. Verify before/after native images and first-lap hitches, not just loading-screen completion.

Compatibility is the project's desktop **and mobile default**. Godot's ubershaders and pipeline precompilation apply to Mobile/Forward+, not Compatibility; Compatibility still needs actual first draws. A renderer switch is a separate appearance/device experiment, not a free setting change or the first recommendation. [Godot 4.7 pipeline-compilation documentation](https://docs.godotengine.org/en/4.7/tutorials/performance/pipeline_compilations.html).

### 4. Prepare the exact selected event earlier and retain useful scenery

Free Race already has a 650 ms settled-selection CPU worker. `App._selected_preparation_obsolete()` explicitly requires the `tracks` screen. Extend the same owned, cancellable job to the exact Daily/Rivalry event once track revision and car are known. Daily currently waits for limits before the later road job; independent CPU preparation could overlap that read. Ordinary ticket/road overlap already exists and should not be rebuilt. Never issue an attempt speculatively or loosen day/revision/account/car checks.

For Winter, investigate retaining expensive immutable scenery separately from cheaper road/cache components rather than requiring the complete world to survive as one cache entry. Preserve active-world ownership, shared-resource accounting and pressure eviction. Measure physical-device memory before changing any budgets. Network benefits are unmeasured in this offline review.

### 5. Longer-term alternative: compile presentation content before play

The larger redesign is a versioned presentation-content pipeline: generate exact immutable road/scenery/car components during authoring/build or a local cache fill, then decode and instantiate them during play. The project already bakes Garage architecture, car templates and road artifacts; extend that machinery rather than add a competing cache. Store track revision, geometry version, engine/render schema and asset dependencies; use bounded decoding and an intact procedural fallback for missing/corrupt content. Keep mutable effects, physics and per-player cosmetics outside the immutable artifact.

Start with local artifacts for repeated tracks. Server-distributed track presentation is a later option with download, storage, trust/versioning and bandwidth costs. It may reduce CPU reconstruction but does not remove device-specific graphics preparation. A complete engine rewrite is not supported by the evidence.

An exact full-Garage opening snapshot could also improve perceived readiness while the live scene prepares. It must match car, paint, wear, trophies, record display, camera and viewport; the carousel's different thumbnail studio cannot stand in for it. This would preserve the first image, but does not reduce live-scene cost or make interaction ready sooner. Treat it as presentation work after the real bottlenecks above.

## Validation and reproduction

Use new labels/profiles when repeating. The runner invokes the pinned engine through `scripts/run_no_crash_dialog.py`, records commands, owned process IDs, exit status and before/after source hashes, and has a bounded timeout scoped to its own process tree. The startup phase fixture only adds timestamp hooks to an in-memory App copy. The passive phase subclass observes public/current diagnostic state; it does not replace the loading implementation. The asset audit reads prepared-resource metadata and hashes without rewriting it.

Commands from the repository root:

```powershell
python docs/evidence/loading-review-2026-11-04/run_review.py resources-app res://tests/review_app_resources_2026_11_02.gd res://core/app.tscn
python docs/evidence/loading-review-2026-11-04/run_review.py startup-stock res://tests/review_loading_2026_11_04.gd
python docs/evidence/loading-review-2026-11-04/run_review.py startup-custom res://tests/review_loading_2026_11_04.gd --profile custom --custom
python docs/evidence/loading-review-2026-11-04/run_review.py startup-custom-cached res://tests/review_loading_2026_11_04.gd --profile custom --custom
python docs/evidence/loading-review-2026-11-04/run_review.py race-compat res://tests/review_race_loading_2026_11_02.gd --themes=pine,winter --cycles=2
python docs/evidence/loading-review-2026-11-04/run_review.py asset-eligibility res://tests/review_loading_assets_2026_11_04.gd --headless
python docs/evidence/loading-review-2026-11-04/run_review.py garage-idle res://tests/review_loading_phases_2026_11_04.gd --idle
python docs/evidence/loading-review-2026-11-04/run_review.py boot-stock res://tests/review_boot_2026_11_04.gd
python docs/evidence/loading-review-2026-11-04/run_review.py boot-custom-cached res://tests/review_boot_2026_11_04.gd --profile custom
python docs/evidence/loading-review-2026-11-04/run_review.py garage-direct-phases res://tests/review_loading_phases_2026_11_04.gd --profile custom --custom
python docs/evidence/loading-review-2026-11-04/run_review.py garage-custom-idle res://tests/review_loading_phases_2026_11_04.gd --profile custom --custom --idle
python docs/evidence/loading-review-2026-11-04/summarize.py
python docs/evidence/loading-review-2026-11-04/checkpoint.py
```

Raw logs, commands, timings, asset mismatches, phase observations, source receipts and the derived [summary](evidence/loading-review-2026-11-04/summary.json) are retained in [the evidence directory](evidence/loading-review-2026-11-04/). Native/headless logs retain the sandbox's Windows certificate-store error. The stock boot-only probe additionally reports two leaked ObjectDB instances and one resource at teardown; it is an observed timing with exit zero, not a clean teardown pass. A scoped process-status query was denied by the sandbox; no process was terminated, and the run completed normally. No performance assertion or runtime invariant was relaxed.

All eleven engine runs exit zero. The six startup/Garage runs total **117 checks / 0 failures**; with the race probe the assertion total is **153 / 0**. The two boot-only observations, resource-only probe and 26-resource eligibility audit are observations, not additional assertion counts. The initial stock run's concurrent source change and stock boot-only teardown errors remain disclosed above. There is no blanket clean-log or frozen-whole-workspace claim.

Task files are four new diagnostic scripts, this report, evidence runner/summary/checkpoint tools and concise repository tracker entries. No visible UI changes were made, so this review makes no new screenshot-equivalence claim. The task-only patch is checked forward and backward in an owned directory, without writing the main Git index. Concurrent workspace edits remain intact.

The final `git diff --check -- AGENTS.md DEVELOPMENT_STATUS.md` reports an existing blank line at `DEVELOPMENT_STATUS.md` EOF. The task base has the same blank ending and identical final 256 bytes; that unrelated whitespace was preserved. The task-only patch's forward/reverse/content checks pass.

No phone/device query or test, APK/export, owner-save/process change, real login, live/backend request or mutation, deployment or renderer change. Remaining acceptance for any proposed implementation: controlled fresh/warm samples, exact final-image and reflection comparisons across cars/themes/cosmetics, cancellation and account/version races, first-lap performance, packaged startup, signed-in network paths and representative Android memory/thermal/input behavior. Savings are not promised until the corresponding before/after experiment passes.
