# Weekly Rivalry card and header layout — 2026-10-24

RCL01: Equal 184-unit podium cards, equal widths, consistent centered rank/icon sizes and points, aligned vehicle/name baselines. Retains medal colors, personal car appearance and player profile actions.
RCL02: Remove Small Tracks. Big Thrills. and its loading placeholder; weekly tracks occupy the full body height.
RCL03: Owner follow-up moves week/countdown to the header right edge beside the title, reclaiming their former second row for standings.

Changed files: game/ui/weekly_rivalry_page.gd, game/tests/test_weekly_rivalry.gd. Tests adapt the earlier taller-winner requirement to the newly requested equal height and check the full-height tracks and header alignment.

Validation command (APPDATA=<workspace>/build/rivalry-layout-userdata):

    & 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path game --script res://tests/test_weekly_rivalry.gd --rendering-method gl_compatibility --audio-driver Dummy --log-file '<workspace>/docs/evidence/rivalry-card-layout-2026-10-24/header-regression.log'

Initial card layout suite: 1142 checks, zero failures, exit 0 (regression.log). Final header suite results in header-regression.log. Native screenshots at 1280x720, 960x540, 1600x720 are copied from the actual App suite. Offline fixtures retain the sandbox certificate-store diagnostic and known shutdown ObjectDB/resource warnings. No phone/tablet attachment check or physical-device test, APK, live mutation or deployment. Owner visual acceptance and client reload remain. Concurrent work preserved.

Final result: 1145 checks, zero failures, exit 0. Standings viewport grows from 216 to 246 logical units at all three tested sizes. Native 1280x720 screenshot visually inspected; equal podium cards, full-height tracks, removed slogan and header-right clock confirmed. git diff --check passes for runtime and suite.
