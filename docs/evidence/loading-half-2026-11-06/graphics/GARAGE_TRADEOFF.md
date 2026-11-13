# Podium image reuse shifts work into later menus — rejected for shipping

The final same-source journey does not justify shipping podium image reuse for the owner's all-menu loading objective. Recommend retaining the prototype and its exact-image validation as evidence, restoring the original live Rivalry integration, and retaining independently justified startup/dependency changes. The first Rivalry image appears sooner, but native work still happens in the idle Garage preloader and first Garage entry. The measured complete journey is slightly slower. No speculative showroom handoff was implemented.

The five serial desktop Compatibility processes used one frozen project and one private offline profile: seed, live-a, cached-a, cached-b, live-b. Seed is excluded from the comparison. All five passed **36/0 each, 180/0 total**, with `source_changes=[]`, no script/shader errors or timeout. The sole diagnostic is the existing Windows certificate-store error. Each cached arm had three image hits and zero native podiums; each live arm had three native podiums. Both Garage visits in every arm asserted direct entry without a full-screen loading window and retained both planar reflection views.

| Boundary | Live A | Live B | Cached A | Cached B | Live mean | Cached mean |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Rivalry tap to settled | 5.294 s | 5.215 s | 2.671 s | 5.165 s | 5.255 s | 3.918 s |
| Next Daily tap to ready | 0.207 s | 0.243 s | 1.919 s | 0.249 s | 0.225 s | 1.084 s |
| Garage tap to ready | 1.237 s | 1.339 s | 1.967 s | 1.826 s | 1.288 s | 1.896 s |
| Engine start to Garage ready | 17.232 s | 17.223 s | 17.217 s | 17.767 s | 17.228 s | 17.492 s |
| Sum of first-entry waits | 9.662 s | 9.876 s | 9.708 s | 10.522 s | 9.769 s | 10.115 s |

The Garage mean increases **608 ms / 47.2%**. Engine-to-Garage increases **265 ms / 1.5%**; the first-entry wait sum increases **345 ms / 3.5%**. Two samples per mode establish a repeated Garage regression here, not a statistical estimate for all devices. Cached A moves substantial work into Daily; Cached B pays it before leaving Rivalry. Neither mode has a network/account-restoration workload. The menu sequence is Rivalry, Daily, Tracks, Challenges, Biome, Drafts, Profile, Settings, Store, Garage, repeated once. The absolute journey includes unchanged screenshot/PNG I/O and navigation gaps; the wait sum excludes those gaps. Rivalry always crosses the same four extra native draw fences after ordinary readiness.

The instrumented phases narrow the cause:

| First Garage phase | Live mean | Cached mean |
| --- | ---: | ---: |
| Dispatch including feature construction | 702 ms | 943 ms |
| Opening to actual entry draw | 293 ms | 301 ms |
| Resource wait after entry draw | 0.8 ms | 0.9 ms |
| Car/studio/reflection setup | 24 ms | 31 ms |
| Warm-proxy setup and queue | 31 ms | 41 ms |
| Native preparation queue | 212 ms | 501 ms |
| Native queue batches | 12 | 17 |
| Largest native queue draw | 24 ms | 105 ms |
| Original four full-view/reflection settles | 25 ms | 72 ms |
| Opening showroom to live reveal | 634 ms | 997 ms |

CarVisual, NativeTrackVisual, EditorMemory and the studio scripts were already loaded before Garage in every measured arm. Drafts had already activated the memory policy. Therefore late loading of the world type graph cannot account for the Garage regression. The shared sky object already existed before Garage and remained the same object through opening in each process; this is also not simply creation of a missing sky.

No preloader eviction or pressure request occurred. The existing idle preloader constructed one studio in every arm and performed **28/28 draws in live controls versus 23/27 in cached controls**, but none reached `prepared=true`. At Garage entry, `take()` followed its existing incomplete-studio fallback, resetting that world with `retain_assets=true`; the subsequent active-Garage reset released the preloader's remaining decoded-asset ownership. The same fallback therefore affects both modes. Geometry rebuilding itself is only 24–31 ms; it cannot explain the whole regression.

Every mode entered Garage with **zero shared graphics receipts** and published 171 only after the final full-view settles. There is no loss of an already-issued shared receipt. The observed additional queue draws and slower native programs in cached mode are consistent with losing the earlier native podium rendering's process-local preparation, together with less progress in the idle preloader. This instrumentation does not isolate individual driver programs or radiance operations; it establishes the shifted work and its location without claiming a precise shader-only breakdown. Picture-script parsing itself took 258/266 ms after live podium graph loads versus 1631/1886 ms after cache hits, showing another part of the work moving into the existing idle service.

A possible follow-up is to continue an already-created incomplete showroom inside the existing inline Garage presentation rather than destroy it. That is a separate lifecycle change, not a safe late one-line fix: `take()` intentionally accepts only fully prepared worlds, `adopt()` releases the current held geometry, and `_allowed()` rejects retained-Garage ownership and the Garage screen. A resumable transfer would need an explicit preparation owner, the same account/appearance pins, cancellation during input/navigation, target-size and reflection revalidation, preservation of the pending queue/local preparation state, and the original full main/reflection settle before reveal. It must own a single world under existing budgets and must preserve the direct page and inline car. The potential savings from preserving that partial queue are unmeasured; bypassing the fully-drawn adoption fence would be incorrect. Do not add earlier native work merely to make the Garage number smaller.

Both final Garage pictures were visually inspected: the same full workshop, car, deck reflection and page are present. The complete screenshots are **not byte-exact** across live/cache processes: Garage comparisons have 27–28 changed channels, maximum 58/255, in sparse edge pixels within `[296,255,1254,442]`; live-repeat has one changed channel of 1/255. Rivalry cache/live has three channels of 1/255 difference within `[129,275,196,292]`, while live-repeat is exact. These are retained as measured differences, not masked or represented as exactness passes. The earlier dedicated same-target image/composite tests remain exact; this journey's captures are independent full renders. No appearance acceptance claim follows from this investigation.

Reproduce after reserving a quiet native slot:

```powershell
python docs/evidence/loading-half-2026-11-06/graphics/run_garage_tradeoff.py --base build/loading-half-20261106/frozen-1794003010490398500/game --label <new-unique-label>
python docs/evidence/loading-half-2026-11-06/graphics/analyze_garage_tradeoff.py --label <same-label>
```

`garage-tradeoff-final-1-project.json` identifies the base and seven owned instrumented sources; the task-only project is `build/loading-half-20261106/frozen-1794004590122395400/game`. `garage-tradeoff-final-1-summary.json` retains all raw events and results; `garage-tradeoff-final-1-analysis.json` retains individual values, means, comparisons and image paths. Each sibling run directory retains its command, complete source hashes, raw log and captures.

The overlays add logging without adding yields or draws. The one control adaptation sets the native renderer's `reuse_picture` to the same cache-enabled flag, so disabled-cache controls do not issue an unused raw-image readback. Both modes use identical source files. An independent read-only review found no new heavy dependency edge or prepared-geometry identity change from the instrumentation. Phase timestamps include ordinary scheduling/yields; they are not exclusive CPU/GPU durations. The post-entry diagnostic context occurs after screenshots, so the report uses the explicit ready/phase boundaries for timings. Logging overhead is present; these are attribution measurements, not replacement uninstrumented benchmarks.

This follow-up changed only evidence and owned frozen copies. It did not change shipping runtime sources, Garage presentation, quality settings, renderer, saved cosmetics, devices, owner saves, live/backend data, deployment or the main Git index.

After review, root authorized rejection cleanup. The ten prototype UI/test sources were verified against their recorded hashes and archived exactly under `rejected-candidate/game/`; the two original Rivalry integration files were restored to their before bytes, and the seven new cache scripts/adapters were removed from shipping. The independent profile lazy dependency remains. `rejected-candidate-cleanup.json` records the exact scope and hashes; no additional timing run was performed during cleanup. The reproduction command explicitly targets the historical candidate base because current shipping sources no longer contain the prototype.
