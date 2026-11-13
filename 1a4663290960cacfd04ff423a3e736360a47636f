# Track of the Day icon

2026-10-28. Requirements TDI01 / R01 / Q01.

TDI01 replaces the sun/play symbol with an original calendar containing a
checkered race flag. The calendar communicates a daily event and the flag
communicates racing. The shared `game/ui/race_mode_icons.gd` is the only runtime
file changed. Its existing `sun` key and `Mode_sun` button identity are retained
so every existing page and stationary transition rail receives the new artwork
without changing navigation or the feature's behavior. The existing cached SVG
rasterization, mipmaps, tinting, 38-unit icon size and touch targets remain.

R01 retains existing input behavior. Q01 provides matched native before/after
views at 1280x720, 960x540 and 844x390, an inactive Free Race view and a separate
selected/inactive rail preview. The capture helper is
`game/tests/capture_track_of_day_icon.gd`; existing tests are unchanged.

Actual commands, using the pinned 4.7.2 engine through `scripts/dev.ps1`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/track-of-day-icon-2026-10-28/run.ps1 -Phase before
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/track-of-day-icon-2026-10-28/run.ps1 -Phase after
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/track-of-day-icon-2026-10-28/run.ps1 -Headless -ScriptPath res://tests/test_race_mode_input.gd
```

The final Compatibility capture exits 0 with `APP_READY` and five saved views.
The existing headless Race-mode input suite exits 0: **57 checks, 0 failures**.
The actual Track of the Day button is pressed by the capture helper. With the
backend deliberately disabled, its normal unavailable page is expected; these
captures make no assertion about today's online track selection.

The first capture helper called the two-argument `MenuStyle.box` with three
arguments; that helper error was corrected. The restricted engine then failed
to read the Windows certificate store; the same offline command succeeded with
local access. The shell initially rejected the script under its default
execution policy, so the commands above explicitly use process-local Bypass.
The first replacement used an oval circuit inside the calendar; native review
found it ambiguous and the final artwork uses a checkered flag. Those trial
captures remain under `initial-oval/`. The first isolated rail sheet inherited
the project canvas scale and displayed too small; the final helper explicitly
sets its preview canvas size. The full-page before/after captures use the same
project scale.

The runner isolates APPDATA/LOCALAPPDATA inside the workspace. It restores only
its own generated build identity/version when still current, preserving
concurrent source changes and newer generated identities. Logs, build receipts,
source hashes and a task-only review patch are in
`docs/evidence/track-of-day-icon-2026-10-28/`. The patch includes the runtime
change and new capture helper; documentation is supplied alongside it. No main
Git index staging or commit was performed.

[Final selected/inactive preview](evidence/track-of-day-icon-2026-10-28/after/gl_compatibility/rail-actual-size.png).
[Before](evidence/track-of-day-icon-2026-10-28/before/gl_compatibility/daily-1280x720.png)
and [after](evidence/track-of-day-icon-2026-10-28/after/gl_compatibility/daily-1280x720.png).

Reload/rebuild and owner acceptance of the symbol remain. No phone/tablet
attachment query or physical-device test, APK export, live/backend write,
deployment, real-account authentication, purchase, owner-save change or owner
process restart was performed. Desktop Compatibility is the renderer reviewed;
this is not an Android appearance or performance claim.
