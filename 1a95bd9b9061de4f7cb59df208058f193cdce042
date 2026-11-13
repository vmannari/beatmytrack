# Daily standings regression review — 7 November 2026

DSR01: A small flying-lap snapshot can precede an authenticated driver's newly verified ordinary PB. Read the driver's eligible durable PB with a player-scoped query and overlay it in a private population; preserve the shared snapshot. The snapshot generation includes the resulting population so paging cannot continue across changed standings. Implementation is in `backend/bmt_backend/daily_lap_standings.py` alongside concurrent Daily-specific score integration.

DSR02: Add `backend/tests/test_daily_standings_verified_overlay.py`: improved PB before refresh, previously absent driver without double counting, immutable public snapshot, and a partial Daily attempt passing ticket/admission/worker/projection into standings without creating an ordinary race PB. The last case uses a stub evidence verifier and does not prove native evidence acceptance. During verification, worker finalization referenced `daily_laps` from another function's scope; deriving it from the pinned manifest fixes that NameError in `backend/bmt_backend/worker.py`.

DSR03: Review concurrent results/standings UI changes in the native Compatibility renderer. Captures show the completed lap, comparison rank, country flags, highlighted player, persistent actions, nine-stage medal rail and flying-lap grid. These are native fixture views, not device captures or live account results. AAA remains an owner/device acceptance target.

Commands executed from the repository root unless stated otherwise:

```powershell
# Working directory: backend
& '..\.tools\backend-secure-venv\Scripts\python.exe' -m pytest tests/test_daily_lap_standings.py tests/test_daily_standings_verified_overlay.py -q --tb=short --disable-warnings
# 8 passed, 8 skipped (PostgreSQL not requested), 41 warnings.

# Isolated APPDATA under build/standings-review-user, empty BMT_API_URL;
# explicit log/output paths under build/standings-review-captures.
python scripts/run_no_crash_dialog.py -- 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path game --log-file 'C:/Codes/Godot/Beat my track/build/standings-review-captures/headless.log' --script res://tests/test_daily_results_design.gd
# 179 checks, 0 failures.
# Same command without --headless, native.log: 191 checks, 0 failures.
# Headless test_daily_standings.gd, standings.log: 42 checks, 0 failures.
```

Inspected captures: `build/standings-review-captures/elite-1280x720.png` and `full-standings-flags.png`; the native test also captures 1920×1080, 960×540, 844×390 and 390×844 views. Logs retain the existing Windows certificate-store diagnostic. Initial system Python lacked pytest; using the repository secure environment resolved it. Initial dev.ps1 execution-policy and user-log access failures are not passes; dev.ps1 was attempted with process-scoped ExecutionPolicy Bypass, then the pinned engine was launched through the required crash-dialog wrapper with an isolated explicit log path. Initial fixture import and test hint errors were corrected. Concurrent worker/UI/backend edits were present throughout; these results are scoped checks, not a frozen release qualification.

No device test, APK export/install, live account request, backend rollout, owner-save change or main-index write was performed. Matching client/backend deployment and real-device upload/appearance acceptance remain.
