# Startup record switch — 2026-11-02

SMU01: Start the selected record directly, without briefly decoding the default record. SMU02: Wait for saved sign-in restoration before starting menu music, so Guest preferences cannot play ahead of the active account's preferences.

`game/soundtrack/audio_world.gd` installs record changes immediately when no decoder exists and prevents `show_menu()` from starting an obsolete stream while a change is queued. Changes during existing playback retain their fade transition and cursor preservation. `game/core/app.gd` starts music after `online.start_session()` returns; the initial restoration screen does not start playback. Music can begin during the remaining picture preparation.

`game/tests/test_startup_music.gd` checks all fourteen initial streams, disabled music, invalid-selection fallback, native cursor continuity, live record changes and the shipping App/profile-storage path with different Guest/account records. Account selection uses a fictional in-memory identity and private saved fixtures; no sign-in request is made. The original sources fail **30 of 37 headless checks**. Final results:

| Check | Result |
| --- | --- |
| Startup regression, headless | 37 checks, 0 failures |
| Startup regression, native Compatibility | 69 checks, 0 failures |
| Retained supplied soundtrack, native Compatibility | 43 checks, 0 failures |
| Retained playlist, native Compatibility | 58 checks, 0 failures |

The retained soundtrack check includes real decoded Music-bus output and native end-of-record advancement; playlist checks include saved membership, skipping, playback controls and recovery. Final native logs contain no engine errors. [Raw logs and task-only patch](evidence/startup-music-2026-11-02/).

Commands used the pinned `4.7.2.stable.official.ed1daf0bf` engine. Each child received an isolated `APPDATA` under `build/startup-music-2026-11-02/` and an empty `BMT_API_URL`:

```powershell
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_startup_music.gd -CommandTimeoutSeconds 180

python scripts/run_no_crash_dialog.py -- 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/test_startup_music.gd

# Run separately for test_startup_music, test_supplied_soundtrack and test_record_playlist:
python scripts/run_no_crash_dialog.py -- 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path game --rendering-method gl_compatibility --position -10000,-10000 --resolution 1280x720 --script res://tests/test_startup_music.gd

git diff --check -- game/core/app.gd game/soundtrack/audio_world.gd game/tests/test_startup_music.gd
```

The first sandboxed runner attempt failed at Windows certificate-store/access initialization. Normal-access offline runs completed. An initial native regression passed its assertions but exposed a freed lambda during immediate fixture teardown; the fixture now lets deferred menu work settle before freeing the App, and the final native run is clean. The earlier native log is retained as `after-native.log`; `test_startup_music-native.log` is the final run. The normal dev runner refreshed its existing generated build identity; these generated/concurrent files are excluded from this task's checkpoint.

`task-only.patch` is compared with task-start copies of the two runtime sources and immediate pre-addition copies of the three shared documents. It includes the new regression and this note. Forward/reverse application and normalized text-content equality are checked inside a private temporary Git repository; the main index is untouched.

No visual layout or audio asset changed, so no screenshot is required. No device query/test, APK, owner-save or owner-process change, backend request, deployment, commit or merge was performed. Saved-session network behavior is covered by the existing restoration boundary and a fictional local profile fixture, not a real account login. Reload and listening on the owner's device remain acceptance checks. A slow saved-session check now delays initial music until it completes; it cannot play a temporary Guest track first.
