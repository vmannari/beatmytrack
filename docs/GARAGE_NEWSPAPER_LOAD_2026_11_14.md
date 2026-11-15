# Garage newspaper loading — 2026-11-14

The owner rejects the small spinner on the newspaper rail icon and requests faster loading. The ordinary selected News icon now provides the same feedback as the other Garage destinations. This supersedes the pending indicator in [the previous transition pass](GARAGE_NEWSPAPER_TRANSITION_2026_11_14.md).

NLO01: `game/ui/garage_page.gd` no longer creates `NewsWaiting`; its spinner script and generated UID sidecar are removed. The existing selected highlight, current-page retention while an edition is read, and account/navigation cancellation remain.

NLO02: `game/ui/garage_news_menu.gd` loads World Ranking only when that tab is opened. A story with a valid live appearance no longer imports the hidden stock illustration or its unused shader. The newspaper lays out and draws before importing/constructing its actual car photograph. Construction starts in idle processing after the paper entrance finishes, so it cannot interrupt that animation. The photo still uses the same vehicle, livery, fitted parts, reduced geometry, camera, lighting and four-millisecond procedural budget. The existing preparation message occupies its reserved frame until the actual car is ready; no stock car is substituted.

NLO03: One pending photograph is tied to the article epoch, receiving pane, visibility and account/server scope. Rebuilding the article supersedes its queued job; leaving before construction does no photo work. Hiding retains the current request without starting it, and showing refreshes its scope/content before resuming. Once construction starts, the existing car widget retains its cancellation behavior. No transport, feed-cache lifetime, race authority or vehicle source was changed.

NLO04: The new `test_garage_news_load.gd` opens the actual App without importing the newspaper through its fixtures. It checks first draw, synchronous construction, animation isolation, three visits, optional Ranking imports, rapid leave, latest paint, hide/show, identity cancellation, and real photographs. Existing livery and transition fixtures now account for deferred preparation. The livery fixture supplies its fake receiving Garage's actual section/tools and awaits the deferred job; its appearance assertions are unchanged. The transition fixture now checks that no photograph exists during entrance and retains its separate twenty-second readiness assertion. Its previous requirement for a ready photograph *during* entrance is superseded by NLO02; the original 38/1 result is retained.

Actual results:

| Check | Result |
| --- | --- |
| Initial synchronous Compatibility control | 14 checks / 4 failures |
| Final actual-App load, Compatibility | 26 / 0 |
| Final actual-App load, headless | 24 / 0 |
| Final actual-App load, desktop Mobile/Vulkan | 26 / 1; first photograph not ready within twenty seconds |
| Final Compatibility transition, including 400 ms delta and thirteen native captures | 38 / 0 |
| Existing no-flash/navigation entry, headless | 20 / 0 |
| Earlier first-load behavior, headless | 17 / 0 |
| Existing feed behavior, headless | 86 / 0 |
| Featured/local livery fixture, headless | 17 / 0 |
| World Ranking navigation, headless | 54 / 0 |
| Production script compilation | 573 / 0 |

The initial control constructs each photo synchronously and starts an unused photo on immediate departure. A preliminary deferred candidate passes 14/0. Later candidates remove the Ranking import and unused illustration work. The initial livery fixture reports 17/1 because its unmounted fake Garage has the default Cars section and no receiving tools; the corrected fixture supplies that identity and keeps the original assertion. Intermediate logs are retained, including the old transition expectation's 38/1 result.

Desktop timing samples, in milliseconds:

| Compatibility sample | First entry call | First lead draw | Repeat entry calls | Repeat lead draws |
| --- | ---: | ---: | --- | --- |
| Original synchronous control | 345.021 | 455.517 | 100.046, 77.079 | 136.166, 122.375 |
| Final | 145.684 | 171.813 | 14.465, 13.468 | 26.189, 24.379 |

These are the synchronous navigation call and first visible lead, not time to a fully rendered 3D photograph or a network latency guarantee. They are separate desktop processes with fixture transport. Concurrent Garage statistics and vehicle-budget work changed surrounding inputs between samples, so these are observations rather than a controlled percentage improvement. The final regression proves that photo construction and Ranking imports are absent from the first navigation call, with one current photo per visit. The previous no-flash behavior remains covered.

Vulkan remains qualified only for the completed checks. Its final first page drew in 286.884 ms; repeat draws were 32.931 and 50.749 ms. The first car was still building at the twenty-second deadline; later visits and cancellation/paint/identity checks passed. A read-only prepared-source probe confirms that the Compact scene's key and source guards reject current concurrent `car_visual.gd`, `car_budget_reduction.gd`, `racing_car_models.gd` and dependency-manifest inputs. The photo therefore uses the ordinary procedural fallback. This establishes a cache miss, not the precise cause of every long Vulkan frame. No stale scene was accepted, key restamped or concurrent model output replaced. A fresh qualification after that model pass publishes matching assets remains outstanding.

Two earlier Vulkan attempts were stopped after repeated readiness failures, by matching and terminating only their own game command lines. A one-visit diagnostic also exits with a readiness failure. Moving construction out of the draw callback did not eliminate those stalls; no render-thread root-cause claim is made. The final Vulkan run completed naturally, reporting two ObjectDB instances/one resource still in use on console teardown. Its stdout/stderr receipt is retained. No whole-suite, device, universal smoothness or complete first-photo latency claim is made.

All final invocations use the pinned Godot 4.7.2 console through `scripts/run_no_crash_dialog.py`, isolated build-local `APPDATA`/`LOCALAPPDATA`, an empty `BMT_API_URL` and Dummy audio. The runnable [helper](evidence/garage-newspaper-load-2026-11-14/run_check.py) and exact command/environment JSON receipts retain the paths and arguments. Actual final commands include:

```powershell
python build/news-load-20261114/run_check.py release-gl res://tests/test_garage_news_load.gd gl_compatibility
python build/news-load-20261114/run_check.py load-headless res://tests/test_garage_news_load.gd headless
python build/news-load-20261114/run_check.py entrance-mobile res://tests/test_garage_news_load.gd mobile
python build/news-load-20261114/run_check.py transition-final-gl res://tests/test_garage_news_transition.gd gl_compatibility --capture-motion
```

Other executed scripts are `test_garage_news.gd`, `test_garage_news_entry.gd`, `test_garage_news_first_load.gd`, `test_garage_news_livery.gd`, `test_ranking_newspaper.gd`, `check_model_refinement_parse.gd` and the retained read-only `probe_sources.gd`, all headless. The first run's standard Windows audio and the later Dummy-audio runs are not compared as a controlled benchmark.

[The completed paper](evidence/garage-newspaper-load-2026-11-14/final-gl_compatibility-windows/loaded-paper.png), [latest paint](evidence/garage-newspaper-load-2026-11-14/final-gl_compatibility-windows/latest-appearance.png) and [pending entry without a spinner](evidence/garage-newspaper-load-2026-11-14/transition/pending-feedback.png) retain native views. Selected animation frames show the unchanged short fade; they are manually stepped captures, not a frame-pacing recording. Other [evidence](evidence/garage-newspaper-load-2026-11-14/) includes raw failures, final logs, measurements and the source checkpoint.

The six-source incremental checkpoint applies/reverses exactly after UTF-8/LF normalization and passes a live reverse check. Both Garage-page checkpoint sides include the concurrent performance-panel changes identically; only the spinner removal belongs to this task. `rivalry_victory_car.gd` remains exact against the starting copy. Generated UID sidecars are excluded from the source patch. No main-index staging or commit was performed. All six owned source states still match after cleanup. Standard retention (`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply`) completed: 28.95 → 28.95 GiB, zero eligible entries, with recent/protected/locked outputs above the target. Its [receipt](evidence/garage-newspaper-load-2026-11-14/build-cleanup.json) is retained. Build-local profiles and shader caches remain disposable under that policy; no new pin was created.

Reload the client to see the change. Owner appearance/input acceptance and physical-device testing remain. No phone/tablet query or test, APK/export, real backend request/deployment, owner-save modification or owner-process action was performed.
