# Garage newspaper transition — 2026-11-14

The owner accepts the removed story flash and requests a smoother transition with less delay. The previous flow acknowledged the tap only after the feed read, hid the Garage immediately and slid an opaque newspaper across the full content width. Status-only updates also rebuilt the article.

NTF01: `garage_page.gd` immediately selects News and displays one small pending indicator while its existing feed read is outstanding. `garage_news_wait.gd` draws that indicator and processes only while visible. Cancellation clears it. The previous account/server/navigation fences and the retained Garage while reading remain.

NTF02: The newspaper now enters over the existing Garage with a 24-pixel movement and an eased 0.22-second fade, replacing the 0.32-second full-width slide and delayed handoff. Its first layout receives the final main-area dimensions. A faint first draw prepares the actual paper before starting the clock; the animation advances by at most 1/30 second per frame so an isolated stalled draw cannot skip the visible entrance. The outgoing preview, title and carousel stay in their original positions beneath the paper; the completed transition hides the showroom. Interruption restores opacity, input and ordinary menu layout. No extra viewport or snapshot world is used for this transition.

NTF03: `garage_news_menu.gd` updates only the controls/status when the story data is unchanged. A bounded snapshot includes the current scope, stories, read state, appearance, availability, error and paging cursor. Genuine content changes still render; resizing rebuilds the article only when its editorial breakpoint changes. Busy notifications, the daily POST and ordinary size allocation no longer discard the current article or car photo. A procedural photo build uses four-millisecond cooperative slices instead of twenty-four; synchronous prepared-model restoration is not covered by that slice limit.

NTF04: `news_client.gd` wakes entry preparation on its existing `changed` signal, removing a polling-frame delay while retaining its epoch/scope checks. It adds no requests and retains the existing sixty-second cache. `test_garage_news_transition.gd` observes native frames, construction counts, pending feedback, the correct story, the original Garage resources, title stability, photo readiness and cancellation.

Actual results:

| Check | Result |
| --- | --- |
| Initial native transition baseline, Compatibility | 20 checks / 5 failures |
| Final Compatibility transition, including a 400 ms frame and thirteen animation captures | 38 / 0 |
| Final Mobile/Vulkan transition, including a 400 ms frame | 25 / 0 |
| Final headless transition | 22 / 0 |
| Existing native no-flash/account/navigation entry regression | 24 / 0 |
| Actual mouse/touch/sidebar suite | 4507 / 0 |
| Earlier first-load regression | 17 / 0 |
| Existing feed/story/page-turn behavior | 86 / 0 |
| Existing scroll/read-state behavior | 41 / 0 |
| Native featured-livery behavior | 18 / 0 after caption-fixture correction |
| Production script compilation | 569 / 0 |

The car-photo fixture initially reports 18/1 because it expects the retired caption `Bob · Compact / 01`. Its exact expectation now uses `Bob · Rally`, matching the unchanged current vehicle catalogue and production caption. The other appearance, fitted-part, opacity and fallback assertions remain. No production name or vehicle art was changed.

The final observations count one article through entry/daily status and one article/one actual car during cached entry. The original baseline rejected missing pending feedback, the long opaque slide, the disappearing Garage and the POST-driven rebuild. The original assertions were kept.

Desktop timing samples are limited evidence. The final Compatibility run settled 271.426 ms after the fixture response was released, versus the original 329.214 ms sample; the final Vulkan run sampled 649.025 ms, including a 376.818 ms interval to observe commit. Configured animation duration is 220 ms versus 320 ms, plus the first presentation draw; a preliminary candidate without that draw barrier sampled 229.015 ms. These are separate native runs on a desktop with controlled fixture transport, not phone/network latency or a universal frame-time guarantee. Click-to-settled samples include a deliberately held response and pending screenshot, so are not used as latency comparisons. Cached own-car construction calls ranged from about 36 ms in an isolated candidate run to 102 ms in a contended run. Synchronous prepared restoration, cold shaders and actual network latency remain practical limits; a four-millisecond procedural slice is not a four-millisecond bound for the whole entry.

A late Vulkan run had multi-second intervals (7482.009 ms to observe commit, 11573.174 ms to settle), skipped all visible intermediate fade frames and failed 24/1. A host sample immediately afterward showed 100% CPU and 98% GPU utilization; this does not establish the precise cause. That failure motivated the first-draw barrier and capped animation progress. The fade assertion was tightened to require opacity between 5% and 95%, so the faint preparation frame cannot satisfy it. A separate 400 ms delta regression also checks that the actual paper remains at an intermediate opacity. The failing log remains; this pass does not claim to fix global rendering stalls or resource contention.

Native commands used the pinned engine through scoped crash-dialog suppression, isolated `APPDATA` and `LOCALAPPDATA` inside `build/news-transition-20261114`, and an empty `BMT_API_URL`:

```powershell
python scripts/run_no_crash_dialog.py -- 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path game --rendering-method gl_compatibility --script res://tests/test_garage_news_transition.gd --log-file $newsLog -- --capture-motion
python scripts/run_no_crash_dialog.py -- 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path game --rendering-method mobile --rendering-driver vulkan --script res://tests/test_garage_news_transition.gd --log-file $newsLog
```

`$newsLog` was an absolute task log path. The baseline appended `-- --baseline`. Other actual scripts were `test_garage_news_entry.gd`, `test_garage_news_livery.gd` and `test_garage_sidebar.gd` in native Compatibility, and `test_garage_news.gd`, `test_garage_news_first_load.gd`, `test_garage_news_scroll.gd` and `check_model_refinement_parse.gd` with `--headless`. The sidebar output was redirected with `-- --evidence-root=res://../build/news-transition-20261114/sidebar`. Direct invocation avoided rewriting shared build identity. No real transport was used.

[Animation preview](evidence/garage-newspaper-transition-2026-11-14/entrance.gif) and [receipts](evidence/garage-newspaper-transition-2026-11-14/) retain selected native views, frame observations, logs and the incremental source checkpoint. The preview uses thirteen native frames advanced in 22 ms steps; it illustrates the motion and is not a frame-pacing recording. It was assembled with the existing `.tools/review` Pillow installation. No dependency was installed.

Reload the client to see the change. Owner appearance and physical-device acceptance remain. No phone/tablet query or test, APK/export, live backend request/deployment, owner-save/process change or Git staging was performed. The previous no-flash fix and concurrent car-selection feedback code are retained. The incremental checkpoint applies/reverses with exact normalized comparisons; final runtime/test hashes still match after cleanup. Standard build retention completed: 25.68 → 25.68 GiB, zero eligible entries, with recent/protected/locked output above the target. Its receipt is retained. Temporary profiles, shader output and native frame sequences remain disposable under that policy; no new pin was created.
