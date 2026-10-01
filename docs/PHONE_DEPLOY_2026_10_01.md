# Phone deployment - 2026-10-01

Requirements R01/Q01. Owner requested deployment of the current workspace to the connected phone. Used pinned Godot 4.7.2 and matching Android templates via:

`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 DeployAndroid -QuickValidation -DeviceSerial PRQKU4U4PREQNRWG`

Initial startup smoke exited after eight frames before online session restoration completed. Added `game/tests/test_startup_smoke.gd` to wait for actual readiness, with a 45-second failure deadline, and updated the two startup invocations in `scripts/dev.ps1`. Next attempt exposed obsolete paging calls in `game/tests/test_catalog.gd`; replaced those with bounded-carousel and 5000th-track reachability assertions. No production behavior was altered for these fixes.

Final import and APP_READY passed; driving **62**, catalog **18**, menu **44** checks passed. Fresh debug APK exported to `build/android/circuit01-debug.apk`; install returned Success, launch Status ok (cold launch 930 ms), process running and device log emitted APP_READY. Existing data retained via adb install -r. Full regression suite was not run. Build-tools 35.0.1 fallback and three driving-test ObjectDB leaks were warnings, not failed checks.

Restored `adb reverse tcp:18181 tcp:18181` for local development backend access; PC /readyz returned HTTP 200. Issued a retry-connection tap. Final [phone screenshot](evidence/phone-deploy-2026-10-01/phone.png) shows the game running during a race; this is observation, not a completed gameplay validation. Owner gameplay, menu interaction and performance acceptance remain separate.

Evidence contains actual startup/check/install/launch logs. Changed files: startup smoke, catalog smoke, dev entry point, this report, status/phase notes and evidence. Scoped staged whitespace check passed. The APK includes all current authorized workspace changes, including parallel local work, rather than only the latest menu commit.
