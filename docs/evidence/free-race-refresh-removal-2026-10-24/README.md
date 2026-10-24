FRR01 — Remove Free Race manual refresh (2026-10-24)

Changed game/ui/track_browser.gd: removed RefreshTracks creation, forced-query callback, member and disabled-state update. Internal view refresh and automatic discovery remain. Updated game/tests/test_challenge_cards.gd to expect the remaining shared controls and absence of RefreshTracks.

Commands run:
- Godot_v4.7.2-stable_win64_console.exe --path game --rendering-method gl_compatibility --script res://tests/test_free_race_list.gd -- --evidence-root=res://../docs/evidence/free-race-refresh-removal-2026-10-24
- Godot_v4.7.2-stable_win64_console.exe --headless --path game --check-only --script res://ui/track_browser.gd

Parser check exited 0 (default user-log access errors). Rendered test reached APP_READY and saved screenshots, including list-1280x720.png, visually inspected with Random track, Filters and Search and no refresh button. Full test did not pass: score_action_checks line 112 encountered a missing score action and run line 248 a freed instance; test was stopped through its own session. Certificate-store diagnostic also appeared. These unrelated checks were not changed. No full regression pass is claimed.

Remaining acceptance: owner appearance after client reload. No physical-device test, device attachment check, APK or deployment performed. Existing concurrent changes preserved.
