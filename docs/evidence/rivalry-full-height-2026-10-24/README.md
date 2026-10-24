# Weekly Rivalry full-height layout trial — 2026-10-24

WRH01: Replace the Weekly Rivalry winter illustration with a plain dark surface.
WRH02: Remove the active overview podium and its loading placeholder so standings fill the body height. Preserve Circuit presentation and the completed-week ceremony. Score refresh tolerates the absent podium.

Changed runtime: game/ui/weekly_rivalry_page.gd. Updated existing layout expectations in game/tests/test_weekly_rivalry.gd; added native preview harness game/tests/capture_rivalry_full_height.gd.

Validation: pinned Godot 4.7.2, Windows Compatibility. Native isolated preview: three sizes, zero failures. Full Weekly Rivalry suite: 1133 checks, zero failures, including details/results/finale and score updates. Actual App previews copied beside this note as overview-1280x720.png, overview-960x540.png and overview-1600x720.png.

Commands: scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_weekly_rivalry.gd -Graphical -RenderingMethod gl_compatibility (via powershell -ExecutionPolicy Bypass). Strict runner interrupted by sandbox certificate diagnostic; initial default userdata access also failed. Successful offline runs used workspace APPDATA build/rivalry-layout-userdata and the exact pinned engine directly:

    & 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path game --script res://tests/capture_rivalry_full_height.gd --rendering-method gl_compatibility --audio-driver Dummy --log-file '<workspace>/docs/evidence/rivalry-full-height-2026-10-24/capture.log'
    & 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path game --script res://tests/test_weekly_rivalry.gd --rendering-method gl_compatibility --audio-driver Dummy --log-file '<workspace>/docs/evidence/rivalry-full-height-2026-10-24/regression.log'

Certificate-store diagnostic remains in both successful offline logs. Owner appearance acceptance remains; reload client to see changes. No phone/tablet attachment check or physical-device test performed. No APK, deployment or live mutation. Concurrent changes preserved; no shared-worktree commit created.
