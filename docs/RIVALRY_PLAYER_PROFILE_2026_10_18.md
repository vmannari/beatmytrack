# Rivalry player profiles — 2026-10-18

RPP01: Selecting another driver from Rivalry standings, the podium, the per-track board or post-race Rivalry results opens a public player profile. It shows their country/name, shared Rivalry car with the actual paint/livery/fitted parts, weekly rank/points, and published created tracks with route outlines, biome and available ratings. Track boards resolve the same account's overall row for its appearance. Missing shared cosmetics are labelled; local Garage dirt is never borrowed.

RPP02: Report player and Block player / Unblock player are inside a 52-by-48-unit ellipsis menu. Reporting opens the existing private report form for the exact account; blocking uses the existing durable account/server-scoped safety adapter. Blocking immediately clears the public track cards and hides identity/car/country. Unblocking reloads the public tracks. Guests can browse and receive the existing sign-in guidance for safety actions. Changing account/server closes the profile.

RPP03: Pointer selection happens on release; keyboard activation remains available. Touch scrolling, cancellation and emulated mouse duplication do not select a driver. The existing custom Rivalry list recognises a stationary touch on a profile name after its scroll gesture completes. A guard on the shared car renderer prevents resize/visibility callbacks accessing a missing viewport while popup styling reparents its content.

The existing `/tracks?creator=...&limit=20&cursor=...` service supplies published metadata. The name is only the catalog search hint: every displayed row must match the exact creator account ID and existing block guard. Each explicit More tracks reads one page; one open profile retains at most 100 matching cards. No document downloads, catalog-wide scans, background polling or new backend endpoint are added. The profile is a read-only showcase; its cards do not start races. Private/local drafts are not public. A renamed creator needs fresh Rivalry data to refresh the search hint. No lifetime statistics or private account fields are inferred.

Changed runtime files: `game/ui/player_profile.gd` and its UID, `weekly_rivalry_page.gd`, `weekly_rivalry_result.gd`, `rivalry_track_standings.gd`, and the viewport-lifecycle guard in `rivalry_victory_car.gd`. The focused fixture is `game/tests/test_rivalry_player_profile.gd`. Project status/plan/agent notes describe the completed slice.

Actual validation used Godot `4.7.2.stable.official.ed1daf0bf` through the repository entry point. Each run set `APPDATA` and `LOCALAPPDATA` to separate subdirectories of `build/rivalry-player-profile-2026-10-18`. Commands from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CheckScript -ScriptPath res://ui/player_profile.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_rivalry_player_profile.gd -CommandTimeoutSeconds 120
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_rivalry_player_profile.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_rivalry_player_profile.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestApp -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_rivalry_result.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_community_safety.gd -CommandTimeoutSeconds 180
git diff --check -- game/ui/weekly_rivalry_page.gd game/ui/weekly_rivalry_result.gd game/ui/rivalry_track_standings.gd game/ui/rivalry_victory_car.gd
```

Final results: profile **49 headless / 54 Compatibility / 54 desktop Mobile**, script parser **869**, app **140**, original Rivalry result **10**, original community safety **23**; all have zero failures. The profile fixture verifies account-ID filtering against another same-name creator, exact encoded cursors, real shared customisations, direct name activation on each board, touch tap versus scrolling, report target, block/unblock, error/retry/empty states, guest guidance, account-change closure, and bounds at 960×540, 1280×720 and 1720×900. Display scaling retains the project's logical viewport; bounds are checked in that coordinate space. Desktop Mobile means the Vulkan renderer on the desktop GPU, not an Android device test.

Initial attempts are retained: direct script invocation hit the host execution policy; the explicit PowerShell command then hit sandboxed user-log access. Redirecting the test data fixed that; executing a full SceneTree test still required approved access to the Windows certificate store. No trust settings were changed. The first native run found oversized content and a null-viewport callback during popup reparenting. Bounding the profile content and guarding the car callback fixed those. Initial appearance/block fixture assertions selected the first sorted standing rather than the intended account; they were corrected to locate the account by ID. An initial bounds assertion compared physical pixels with the stretched logical viewport; final checks use the visible logical rect. Earlier passing 47/52-check versions preceded guest and final gesture coverage.

Reviewed native evidence:

- [Profile at 960×540](evidence/rivalry-player-profile-2026-10-18/gl_compatibility/profile-960x540.png)
- [Profile at 1280×720](evidence/rivalry-player-profile-2026-10-18/gl_compatibility/profile-1280x720.png)
- [Profile at 1720×900](evidence/rivalry-player-profile-2026-10-18/gl_compatibility/profile-1720x900.png)
- [Ellipsis actions](evidence/rivalry-player-profile-2026-10-18/gl_compatibility/player-options.png)
- [Existing report form](evidence/rivalry-player-profile-2026-10-18/gl_compatibility/report-player.png)
- [Desktop Mobile profile](evidence/rivalry-player-profile-2026-10-18/mobile/profile-1280x720.png)

G01/R01/Q01: Owner appearance/workflow acceptance and physical-device behavior remain. No phone attachment check/device test, APK, live report/block, backend mutation/change or deployment was performed. Native profile data and moderation operations were mocked; the original safety persistence regression also passed. Concurrent workspace changes are preserved. Task preimages, available native test logs, final hashes and a task-only review patch are in `evidence/rivalry-player-profile-2026-10-18`; documentation preimages were refreshed immediately before the task's notes were inserted so the patch excludes concurrent status additions.
