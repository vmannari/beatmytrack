# Achievement notification timing — 2026-11-03

AT01: Resume an authoritative achievement update deferred during driving or loading when results/menu work becomes eligible. AT02: Retain the existing driving guard, account fences and notification deduplication.

The owner reported a Desert race achievement appearing after the following Grass race. Signed-in race medals come from the server collection, after race verification; local progress cannot grant them. `refresh_after_activity()` retains a receipt when the App's driving/loading policy closes, but its timer stops. Ordinary and Daily results restore the menu through `_race_menu_visible(true)`, bypassing `_show_screen()` and its `achievements.resume_pending()`. The shared lifecycle wake previously resumed snapshots and Garage preparation only. Consequently a pending achievement collection could remain asleep until another receipt or navigation. This reproduces a real missed wake; no production account or server timeline was inspected to attribute that particular occurrence conclusively.

`game/core/app.gd` now resumes pending achievement activity from `_wake_optional_work()` when the existing background-work policy permits it. The wake is already called by results/menu restoration, loading completion and foreground lifecycle changes. Existing coalescing remains bounded to roughly 0.35–1 second after a receipt/wake. No collection polling, race-time optional HTTP, achievement criteria, save format, backend or visual layout changes.

`game/tests/test_achievement_timing.gd` exercises the actual App lifecycle methods and actual achievement client with a synthetic verified Desert milestone. Startup and transport are replaced with isolated fixtures. It checks the deferred activity during driving, results wake without another race receipt/navigation, authoritative family/tier, duplicate wakeups and loading-completion wakeup.

| Verification | Actual result |
| --- | --- |
| New regression against task-start App | 9 checks, 5 failures |
| New regression after fix, headless | 9 checks, 0 failures; exit 0 |
| New regression after fix, native Compatibility | 9 checks, 0 failures; exit 0 |
| Existing achievement notification suite, headless | 291 checks, 0 failures; exit 0 |

The retained suite includes real App startup, race entry/results, successfully saved local grants, authoritative account snapshots, identity fencing, notification deduplication and presentation/input checks. Headless execution is not rendered-image evidence. No visual layout changed, so no new screenshot was required.

All engine commands use pinned `4.7.2.stable.official.ed1daf0bf`, Dummy audio, empty `BMT_API_URL` and separate `APPDATA` folders under `build/achievement-timing-2026-11-03/`. Each engine launch uses the crash-dialog wrapper. Logs retain the environment's `Failed to read the root certificate store` engine error; fixtures use no real network, tests completed and this error is not reported as resolved. Raw output: [evidence directory](evidence/achievement-timing-2026-11-03/).

```powershell
# APPDATA suffixes: baseline-user, final-user, native-user, retained-user.
$env:APPDATA = Join-Path $PWD 'build/achievement-timing-2026-11-03/final-user'
$env:BMT_API_URL = ''
python scripts/run_no_crash_dialog.py -- 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --audio-driver Dummy --script res://tests/test_achievement_timing.gd
# Native focused run substitutes --rendering-method gl_compatibility for --headless.
# Retained suite:
python scripts/run_no_crash_dialog.py -- 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --audio-driver Dummy --script res://tests/test_achievement_notification.gd -- --evidence=res://../docs/evidence/achievement-timing-2026-11-03/retained-headless
git diff --check -- game/core/app.gd
```

The source checkpoint compares the preserved task-start App against the final App, excluding its pre-existing changes. It includes the new regression and this report plus the small status/plan additions. Forward/reverse application and text equality are checked in an isolated temporary repository; the main index is untouched. See `task-only.patch` and `checkpoint.json` in the evidence directory.

Server verification and offline/service waits can still delay signed-in medals. An award verified only after another race starts waits for eligible menu/results work. Instant finish-line grants are not claimed. Reload/rebuild and the owner's Desert→Grass sequence remain acceptance checks. No physical-device query/test, APK, owner-save/process change, real backend request, deployment, staging, commit or merge was performed. Concurrent work is preserved.
