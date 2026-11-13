# Custom car pictures no longer delay the first menu — 2026-11-05

The first menu now opens after account restoration without waiting for a missing equipped-car photograph. A missing picture shows a neutral silhouette of the selected model. Exact cached PNGs load independently. Creating a new photograph waits for a visible, ready Garage showing that car, behind its existing loading-picture presentation.

Two frozen desktop Compatibility samples per version reduce first-menu time with a custom-picture cache miss from 24.501/26.408 seconds to 8.331/8.940 seconds. The medians are 25.454 to 8.635 seconds, a 16.819-second reduction (66.1%) in this sample. This is an offline desktop startup observation, not an Android or cleared-driver-cache result.

## Requirements and implementation

| ID | Result | Sources |
|---|---|---|
| STH01 | Account restoration and the initial destination remain; thumbnail readiness is removed from startup's blocking path. | `game/core/app.gd` |
| STH02 | Cached images can load in eligible foreground menus. Cold native capture requires the same visible Garage owner and car, a ready showroom, no page transition or memory pressure, and no game/loading/background state. The cover must actually draw before loading the native renderer. | `game/core/app.gd`, `game/ui/header_car_appearance_cache.gd` |
| STH03 | Missing images use an existing model silhouette; a saved appearance change immediately removes obsolete paint. Existing appearance/source/renderer/account keys, scoped cancellation, one native world, 14-file/texture bounds and rendering quality remain. Deferred captures do not starve disk reads and retry eligibility at 250 ms intervals instead of every frame. | `game/ui/profile_car.gd`, `game/ui/header_car_appearance_cache.gd` |
| STHQ01 | Frozen before/after probes, actual-App navigation/capture/reload tests, policy boundary checks, all-five-car native references and source receipts verify delivery. | Three new fixtures under `game/tests/`; [evidence and runners](evidence/startup-thumbnail-2026-11-05/) |

The capture uses the same 176×112 target, renderer factory, camera/presentation, cooperative build, graphics receipts, five settling draws, alpha conversion and atomic PNG writer. There is no shader, model, prepared scene, lighting, renderer, backend or physics change. Existing neutral loading art supplies both silhouettes; no new artwork or translation is introduced.

A picture absent from disk and memory can remain a silhouette until the player opens Garage for that car. Saving a customization there schedules its exact saved appearance after the existing debounce. Other saved cars cannot trigger unrelated cold captures. Leaving Garage, changing owners/appearance or closing an eligibility gate cancels preparation and removes its cover. Already admitted image work retains the existing publication gate.

This intentionally supersedes the older startup-photo contract that required the equipped image before the first menu and allowed regeneration on Account. `test_deferred_header.gd` defines the new production contract; older historical startup/equipped-cache fixtures that require immediate capture in ordinary menus are not used as acceptance for this policy. The retained all-car native reference fixture verifies the unchanged capture output independently.

The normal build's broad header-source identity may invalidate old header PNG keys after these UI-source edits. That guard remains intact; misses use the new covered path. Vehicle/prepared-geometry sources and their dependency rules are unchanged. Test runs keep the same frozen build identity for a controlled comparison and do not regenerate shared build metadata.

## Measurements

The owned project copies mutable code and prepared Garage/car/menu content; imported/static directories and native resources retain the documented shared links. Before and after runs use this same project, exact engine, resolution and probe. The three runtime files are restored from byte-exact task-start/candidate snapshots between versions. Each process receives a private offline profile, empty backend URL and Dummy audio. Source hashes are checked around every accepted run. The custom-miss order is original, candidate, candidate, original, each with a fresh profile.

| Case | First menu | Startup / settled header captures | Notes |
|---|---:|---:|---|
| Original custom miss A | 24.501 s | 1 / 1 | One header world |
| Candidate custom miss B | 8.331 s | 0 / 0 | No header world |
| Candidate custom miss B | 8.940 s | 0 / 0 | No header world |
| Original custom miss A | 26.408 s | 1 / 1 | One header world |
| Original stock | 9.189 s | 0 / 0 | Single control sample |
| Candidate stock | 7.659 s | 0 / 0 | Single sample; no separate stock-speedup claim |
| Candidate persisted custom hit | 8.059 s | 0 / 0 | Separate process; one exact-key PNG read after the menu |

Custom initialization falls from 16.912/18.006 seconds to 0.520/0.566 seconds. Resource loading remains roughly 3.1–3.5 seconds in those four runs. All seven startup probes reach the offline Account destination with no optional feature controllers loaded. The first menu metric includes engine time to its first completed draw; it is not full Garage or first-race readiness.

The capture cost has been deferred to an explicit covered Garage opportunity, not removed from the renderer. Native shader compilation can still block a Garage loading frame. This change makes no first-race, steady-FPS, total-session-work, memory/PSS or battery claim. Neither the GPU driver cache nor filesystem caches were cleared.

## Verification

The primary final-runtime checks total **198 assertions, zero failures**:

| Check | Result |
|---|---:|
| Actual-App policy/cache/navigation, headless | 19/0 |
| Actual-App Garage cover, capture, exact PNG reload, save invalidation and navigation cancellation, desktop Compatibility | 43/0 |
| Same actual-App flow, desktop Mobile | 43/0 |
| Retained first-menu dependency closure | 22/0 |
| All five native header images and existing appearance invariant, Compatibility | 26/0 |
| Same all-five reference checks, Mobile, final stable-source repeat | 26/0 |
| Production owner/car/foreground/loading/race/pressure/transition fences and late-draw/held-read boundaries | 19/0 |

An additional verbose candidate shell run passes 22/0; two archived-runtime shell controls pass 22/0 each. The 17 accepted process receipts contain no parser/shader errors, timeouts or source changes. The validator also confirms startup's original one-world versus candidate zero-world contrast, the separate-process disk hit, exact write/reload pixels, final source hashes and captured views.

The reference checks retain the pre-existing `<0.02` appearance-error threshold; no tolerance was relaxed. Separate allocations are not generally pixel-identical, including unchanged archived repeats. Same-target graphics bookkeeping remains pixel-exact, and the actual-App PNG reload is byte-exact. No claim is made that all independently rendered before/after images are byte-identical. Forty native car/reference/control PNGs plus six final actual-App views are retained.

Visible states reviewed include [the menu silhouette](evidence/startup-thumbnail-2026-11-05/frozen-contract-compatibility/menu-silhouette.png), [the drawn Garage cover](evidence/startup-thumbnail-2026-11-05/frozen-contract-compatibility/garage-cover.png), [the finished Compatibility view](evidence/startup-thumbnail-2026-11-05/frozen-contract-compatibility/garage-ready.png) and [the finished desktop Mobile view](evidence/startup-thumbnail-2026-11-05/frozen-contract-mobile/garage-ready.png).

Initial findings remain in the evidence. The first headless fixture omitted its private records directory, failed to save, then reached a nil placeholder and its internal deadline. The corrected fixture passed 19/0. The first native implementation passed 43/0 before the later sleeping-work change. The initial all-car Mobile run passed 26/0 but another test file was copied into the frozen project during the run; it is excluded from the stable-source acceptance total and repeated as `final-header-mobile` without changes. The first patch-format check rejected CRLF in the new helper/JSON files; those task-owned files were normalized to LF and the unchanged whitespace check repeated. None of these receipts is overwritten.

All runs retain the environment's root-certificate-store error. The candidate shell dependency fixture also retains a shutdown warning for two objects and one resource. Its verbose run identifies `AudioStreamMP3`, `AudioStreamPlaybackMP3` and `01-blacktop-thunder.mp3`; the fixture leaves music enabled, unlike the new startup/contract probes. Both task-start shell controls were clean apart from the certificate diagnostic, so this task does not claim a matched reproduction. The same two-object/one-resource warning is documented in the [earlier shell study](STARTUP_SHELL_2026_11_04.md) and its `cold-closure-final.log`. These diagnostics remain explicit; passing assertions do not imply clean whole-app teardown or a memory-soak result.

## Shader decision and remaining acceptance

The concurrent [weathering-linking study](WEATHERING_LINKING_2026_11_05.md) already tested the proposed expensive shader specialization. Broad splits increased the number of programs and whole-car cost; the narrow two-source candidate did not show a dependable complete loading improvement. This task preserves that result and does not enable a speculative shader change. First-use race graphics remain a high-priority unresolved cost.

Reload the local project to see the new behavior. Owner appearance/touch acceptance and Android cold/warm startup, Garage interaction, first-race and memory measurements remain. No device attachment query or device test was performed. No APK/AAB, owner-save modification, owner-process restart, live/backend request, deployment or main-index write was performed. Unrelated concurrent work is preserved.

## Commands and checkpoint

The exact `godot-version.txt` build is `4.7.2.stable.official.ed1daf0bf`. Runners invoke `C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe` directly to avoid the dev wrapper regenerating shared build identity. Every process command, private profile, exit code, diagnostic and source receipt is stored in its `run.json`.

```powershell
python docs/evidence/startup-thumbnail-2026-11-05/freeze_project.py
python docs/evidence/startup-thumbnail-2026-11-05/run_matrix.py
# Additional exact commands are retained in these process receipts:
# final-fences, frozen-before-shell, final-header-mobile,
# final-shell-verbose, baseline-shell-verbose.
python docs/evidence/startup-thumbnail-2026-11-05/validate.py
python docs/evidence/startup-thumbnail-2026-11-05/checkpoint.py
```

The matrix uses fresh named output/profile directories; choose new run names for a repeat rather than overwriting evidence. `freeze_project.py` creates only owned copies/junctions. [validation.json](evidence/startup-thumbnail-2026-11-05/validation.json) records accepted counts, timing arithmetic and delivery hashes. The [task-only patch](evidence/startup-thumbnail-2026-11-05/task.patch) is checked and round-tripped in an isolated repository; the owner's Git index remains untouched. An initial round-trip also exposed inherited Git line-ending conversion; per-command `core.autocrlf=false` in the owned repository preserves exact source bytes without changing owner configuration. Raw image/profile evidence remains alongside that source checkpoint.
