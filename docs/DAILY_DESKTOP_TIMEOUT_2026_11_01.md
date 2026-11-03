# Desktop daily-race timeout — 1 November 2026

The desktop game could time out at **Preparing track** when Track of the Day
was opened before the Free Race browser. The actual desktop log showed
`_prepare_metadata_race` calling `remember_track` on a null `track_catalog`;
the coroutine stopped and its loading deadline subsequently fired. The live
daily feed and limits returned successfully for all five selectable cars.

The metadata race start now initializes the catalogue before retaining its
compiled track. The analogous completed background-preparation path does the
same, so a missing catalogue cannot strand its pending state. Existing changes
to `game/core/app.gd` were retained.

`game/tests/test_daily_metadata_catalog.gd` starts a metadata-only daily track
through the actual App and Game with an isolated profile, no server writes and
fixture lap limits. It also exercises completed background preparation with a
missing catalogue. The original code reproduced the owner-log exception and
failed two assertions. With the fix, the final regression passed **6 checks,
0 failures** both headless and with the desktop Compatibility renderer. The
retained Daily App test passed **15 checks, 0 failures**, and the race-start
feedback test passed **21 checks, 0 failures** headless. `git diff --check`
passed for the touched source.

During test development, an early assertion inspected the Game before its
preparation finished, and the completed-job fixture initially lacked the real
job's nullable result and cancellation interface. Those fixture issues were
corrected before the final runs. Tests used the process-tree crash-dialog
wrapper and disposable profile directories. No owner save or running game was
changed. Restart the desktop game to load the script change; the owner's
in-game retry and physical-device behavior remain unverified.
