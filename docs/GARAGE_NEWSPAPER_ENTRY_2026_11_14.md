# Garage newspaper entry follow-up — 2026-11-14

The owner still saw another story briefly on first entry after the earlier empty-feed fix. This pass reproduces a separate path in the actual Garage: an expired cached story, or a previously empty cached edition, was painted before the entry read returned.

NPE01: `game/backend/news_client.gd` adds `prepare_entry()`. It synchronizes account/server scope, reuses the existing sixty-second cache and waits for an expired or already-running feed read. The accepted GET response releases entry before a slow daily POST finishes. The read-phase flag distinguishes those two stages even when the previous cache is recent. Existing GET/POST endpoints, cache duration, generation polling and account epoch checks remain. An expired entry resets edition readiness so a previous empty result cannot briefly print local stories during renewed generation.

NPE02: `game/ui/garage_page.gd` keeps the current Garage section visible until that initial read is ready, then performs its normal newspaper transition. A navigation serial rejects superseded entries. Hiding the Garage cancels a pending entry even if it is shown again before the reply. Account/server changes and a replaced service reject old replies. Fresh caches, guests and unsupported servers open immediately. Concurrent car-preview feedback changes in the same file were preserved; this task's checkpoint includes only the newspaper additions relative to that source snapshot.

NPE03: `game/tests/test_garage_news_entry.gd` exercises the real App/Garage navigation and observes story identities on actual post-draw frames. Delayed fixture transport holds each pending response long enough to inspect it. It also covers a slow daily POST, reuse of in-flight reads, rapid repeated taps, a recent cache with an in-flight poll, navigation/hide/account cancellation and immediate cached/guest/unsupported entry.

| Check | Actual result |
| --- | --- |
| Original production entry, native Compatibility | 14 checks / 5 failures |
| Entry bypass control, native Compatibility | 22 / 7, expected rejection |
| Final actual Garage entry, Compatibility | 24 / 0 |
| Final actual Garage entry, desktop Mobile/Vulkan | 24 / 0 |
| Earlier first-load regression, headless | 17 / 0 |
| Existing feed/newspaper behavior, headless | 86 / 0 |
| Final production compilation | 568 / 0 |

The observed original/control sequences were `stale-story → actual-story` and `local-new-track → actual-story`. Both final renderers record only `actual-story` in each case. Pending and ready captures show the retained Garage followed by the refreshed edition. The bypass control changes only the test service's entry preparation; all assertions remain. An initial harness attempt omitted the draw observer and was corrected before the 14/5 baseline was counted.

Commands used the pinned engine through Windows crash-dialog suppression, isolated `APPDATA`/`LOCALAPPDATA` under `build/news-entry-20261114`, and `BMT_API_URL` set to the empty string. All feed transport came from the fixture backend. Native commands:

```powershell
python scripts/run_no_crash_dialog.py -- 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path game --rendering-method gl_compatibility --script res://tests/test_garage_news_entry.gd --log-file $newsLog
python scripts/run_no_crash_dialog.py -- 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path game --rendering-method mobile --rendering-driver vulkan --script res://tests/test_garage_news_entry.gd --log-file $newsLog
```

`$newsLog` was an absolute path in the task build directory. The bypass control appended `-- --ungated-control`. Headless commands used `--headless --path game --script` with `res://tests/test_garage_news_first_load.gd`, `res://tests/test_garage_news.gd` and `res://tests/check_model_refinement_parse.gd`. Direct invocation avoided changing shared build identity. `git diff --check` passed for both runtime sources.

[Evidence](evidence/garage-newspaper-entry-2026-11-14/) contains logs, original/control and final story observations, selected native captures, the task-only source patch and its checks. Broad historical race/share/layout fixtures were not repeated; their previous limitations remain in the [earlier report](GARAGE_NEWSPAPER_FIRST_LOAD_2026_11_14.md).

Reload the client for the change. An uncached/expired edition now waits for its normal feed request while the existing Garage remains visible. Later feed updates and explicit story browsing still work normally. Owner appearance and device acceptance remain; no device query/test, APK/export, live backend request/deployment, owner-save/process change or Git staging was performed. The task-only checkpoint applies and reverses with exact normalized source comparisons. The prescribed build-retention cleaner completed: 24.32 → 24.32 GiB, zero eligible entries; recent/protected/locked output remains above the target. Its receipt is retained. No new active-work pin was created.
