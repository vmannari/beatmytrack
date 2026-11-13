# Daily car standings preparation recovery

DSS01: Switching cars can encounter the backend's explicit HTTP 503 `LAP_STANDINGS_PREPARING` response while the selected car's histogram snapshot is built. Previously `daily_result_card.gd` treated this as a terminal failure immediately. The card now retains its existing loading presentation and retries preparation responses up to three times, respecting `retry_after` within 1–30 seconds (default 5). Limits/event preparation receives the same bounded treatment. Other failures retain the existing error and manual retry behavior. Each response and timer is fenced by refresh serial, account, event and car; changing cars or leaving the page invalidates old work.

Changed files: `game/ui/daily_result_card.gd`, `game/tests/test_daily_standings_preparing.gd`, this document. Existing concurrent changes in the runtime file were preserved. Task-start runtime copy: `build/daily-standings-switch/daily_result_card.before.gd`; scoped patch: `build/daily-standings-switch/change.patch`.

Actual verification (isolated APPDATA/LOCALAPPDATA under `build/daily-standings-switch/profile`, empty `BMT_API_URL`):

```powershell
python scripts/run_no_crash_dialog.py -- 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path game --headless --audio-driver Dummy --script res://tests/test_daily_standings_preparing.gd
python scripts/run_no_crash_dialog.py -- 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path game --headless --audio-driver Dummy --script res://tests/test_daily_standings_entry.gd
git diff --check -- game/ui/daily_result_card.gd game/tests/test_daily_standings_preparing.gd
```

Results: preparation regression 5 checks / 0 failures; retained entry regression 14 checks / 0 failures; whitespace check passed. Both Godot runs emitted the existing root-certificate-store error and exited 0. Coverage includes automatic recovery, cancellation after car switch, bounded persistent preparation, genuine failure behavior, cache and account isolation. Existing loading/error visuals are reused; no layout or artwork changes or new screenshots.

The owner's exact server response was not captured, so this establishes and repairs one concrete failure path, without proving it caused every reported warning. Reload and owner reproduction remain. No device query/test, live service access, backend modification, deployment, owner-save/process change or main-index write.
