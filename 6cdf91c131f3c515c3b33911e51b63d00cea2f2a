# Daily car dropdown removed

DCD01 removes the car dropdown immediately above the daily Race/Race again button. The result card now ends with its primary action. The shared header remains the car-selection control. Header changes refresh the daily card, nearby standings and weekly medals; the existing View all car selector still updates the selected car.

Runtime files: `game/ui/daily_result_card.gd` removes the picker, its signal and refresh synchronization; `game/ui/track_of_day_page.gd` removes the obsolete picker connection/lookup; `game/core/app.gd` replaces the old dropdown synchronization with daily-page activation after header selection. All other source edits are preserved.

Four existing fixtures now use header selection instead of the removed picker: `test_daily_medal_page.gd`, `test_daily_week_fit.gd`, `test_track_of_day_presentation.gd` and the service-backed `test_track_of_day.gd`. No new suite is added. The medal-page and presentation fixtures assert that the dropdown is absent. The service-backed fixture was adapted but not run because this change was checked offline.

Actual commands:

```powershell
python docs/evidence/daily-car-dropdown-2026-11-02/run_native.py test_daily_medal_page --graphical
python docs/evidence/daily-car-dropdown-2026-11-02/run_native.py test_track_of_day_presentation
python docs/evidence/daily-car-dropdown-2026-11-02/run_native.py test_daily_week_fit
git diff --check -- game/core/app.gd game/ui/daily_result_card.gd game/ui/track_of_day_page.gd game/tests/test_daily_medal_page.gd game/tests/test_track_of_day.gd game/tests/test_track_of_day_presentation.gd
python docs/evidence/daily-car-dropdown-2026-11-02/checkpoint.py
```

Results: native Compatibility medal page **124 checks, 0 failures**; retained daily presentation **63 checks, 0 failures**; week fit **87 checks, 0 failures**. Native coverage includes four landscape sizes, six portrait component locales, all medal states, header car changes, saved results, country flags and the existing View all selector. [Updated native view](evidence/daily-car-dropdown-2026-11-02/gl_compatibility/silver-1280x720.png). Fourteen captures and raw logs are in the evidence folder. The existing isolated Windows root-certificate-store warning remains; processes exit successfully. Whitespace checks pass, with Git's existing CRLF-to-LF notice for App.

Tests use pinned Godot 4.7.2 through `scripts/run_no_crash_dialog.py`, isolated storage and an empty service origin. The task-start patch passes forward/reverse application and normalized text-content checks in an owned temporary repository. Shared-document baselines are captured immediately before this task's additions.

Reload and owner appearance/touch acceptance remain. No physical-device query/test, second desktop renderer test for this follow-up, APK, live/backend access or mutation, deployment, owner-save/process change, main-index staging, commit or merge was performed.
