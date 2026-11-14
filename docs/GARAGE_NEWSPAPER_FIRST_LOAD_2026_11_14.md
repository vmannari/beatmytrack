# Garage newspaper first load — 2026-11-14

The newspaper previously printed a local example story before its deferred account read started. The first account response then replaced that story. Rendering also marked the briefly displayed example as read.

NPL01: `game/backend/news_client.gd` now tracks whether the current account/server has supplied a usable first edition. Existing stories become readable before a slow daily refresh request finishes. An initially empty edition stays pending while its daily generation is active; the existing bounded polling settles it. Completed empty editions and errors release the ordinary local fallback. Identity changes reset readiness, and existing epoch checks reject old responses.

NPL02: `game/ui/garage_news_menu.gd` distinguishes pending account data from an empty edition. It retains the paper, masthead, tabs and existing updating status until stories are ready. It prints no temporary story, read marker or enabled story navigation. Cached stories, guests and unsupported servers retain their immediate presentation. Subsequent real feed updates retain the selected story when that story is still present.

NPL03: `game/tests/test_garage_news_first_load.gd` covers the deferred first request, delayed reads, slow daily requests, pending generation, confirmed empty feeds, errors, stale account replies, cached refreshes, guest/unsupported editions and selected-story retention. The existing `test_garage_news.gd` synthetic feed restoration explicitly marks its injected snapshot loaded; its existing assertions remain.

Actual verification:

| Check | Result |
| --- | --- |
| New regression against original production sources | 17 checks / 7 failures |
| New regression, fixed, headless | 17 / 0 |
| New regression, desktop Compatibility | 19 / 0 |
| New regression, desktop Mobile/Vulkan | 19 / 0 |
| Existing client/newspaper behavior | 86 / 0 |
| Existing scroll/read-state behavior | 41 / 0 |
| Production script compilation | 562 / 0 |
| Broader native newspaper suite, Compatibility | 966 / 2; not a pass |

The broader native suite expects the action slot visible after returning to Appearance and Parts. Current `garage_page.gd` explicitly hides it for both sections. That source and those assertions were not changed. No baseline reproduction was run for those two findings.

The older headless race suite produced hash, frozen-countdown and cancellation failures before reaching its seeded newspaper interaction, then continued running races. The share suite stopped at a null browser access (`test_publication_share.gd:212`). Both were terminated by their verified task-specific process IDs; neither is counted as passed or used to claim end-to-end race/share qualification. Their logs are retained. The first-load fix does not edit race, sharing, Garage layout, handling, asset producers or backend code.

Runs used the pinned `4.7.2.stable.official.ed1daf0bf` executable through `scripts/run_no_crash_dialog.py`, with separate `APPDATA`/`LOCALAPPDATA` directories inside `build/news-first-load-20261114`. Direct invocation avoided the development wrapper's shared build-identity rewrite. Example command, with the log path made absolute:

```powershell
python scripts/run_no_crash_dialog.py -- 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/test_garage_news_first_load.gd --log-file $newsLog
```

The other actual script arguments were `res://tests/test_garage_news.gd`, `res://tests/test_garage_news_scroll.gd`, `res://tests/check_model_refinement_parse.gd`, `res://tests/test_garage_news_native.gd`, `res://tests/test_garage_news_race.gd`, and `res://tests/test_publication_share.gd`. Native regression runs omitted `--headless` and used `--rendering-method gl_compatibility` or `--rendering-method mobile --rendering-driver vulkan`. The share run passed `-- --evidence=res://../build/news-first-load-20261114/share`. The broad native run used its historical default output directory and refreshed its 98 comparison PNGs; these generated files are outside the source checkpoint. The baseline invocation's relative log path produced Windows reserved-path diagnostics; the regression still completed with its 17/7 result. Subsequent log paths were absolute.

[Receipts and source patch](evidence/garage-newspaper-first-load-2026-11-14/) include native pending/ready captures from both desktop renderers. The loading shell and account story were visually inspected. These are desktop checks with fixture transport, not a live account or device test. New live stories may still arrive through normal feed updates; the fix prevents the temporary first-load fallback.

Reload the client to use the change. Owner appearance and Android acceptance remain. No device query/test, APK/export, live backend request/deployment, owner-save change, owner-process restart or Git staging was performed. Automatic approval review rejected the combined checkpoint/profile-removal command with “blocked by policy” before execution. The checkpoint was then created separately. Profiles remain in the disposable task build directory; no removal workaround was attempted. The prescribed `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply` completed successfully: 22.42 → 22.42 GiB, zero eligible entries, with recent/protected/locked output above the 20 GiB target. Its receipt is retained. Runtime/test diffs pass whitespace checks; the shared status document has an inherited trailing-blank-line finding outside the inserted task note.
