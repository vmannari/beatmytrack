# Weekly Rivalry garage backdrop and restored podium — 2026-10-24

RGP01: Owner correction supersedes the full-height trial. Restore the original active Weekly Rivalry podium and its loading placeholder. Original podium layout assertions restored.
RGP02: Remove the Weekly Rivalry page-specific background drawing so the existing shared garage MenuBackdrop shows through, exactly as on other menu pages. Circuit retains its existing winter background.

Runtime change: game/ui/weekly_rivalry_page.gd. Preview harness game/tests/capture_rivalry_full_height.gd follows the revised request. No account/gameplay changes.

Command: with APPDATA=<workspace>/build/rivalry-layout-userdata, run the pinned C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe --path game --script res://tests/test_weekly_rivalry.gd --rendering-method gl_compatibility --audio-driver Dummy --log-file <workspace>/docs/evidence/rivalry-garage-podium-2026-10-24/regression.log.

Native App views copied from the suite beside this note. The sandbox certificate-store diagnostic remains visible in the offline run. No phone/tablet attachment check or physical-device test, APK, deployment or live mutation. Owner appearance acceptance and client reload remain. Concurrent changes preserved.

Result: WEEKLY_RIVALRY_TESTS: 1136 checks, 0 failures; exit 0. Shutdown retains 4 ObjectDB instances/1 resource diagnostic, as recorded in regression.log. Native 1280x720 preview inspected: original podium and shared garage visible.
