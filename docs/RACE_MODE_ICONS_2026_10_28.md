# Clearer Weekly Rivalry and Challenges icons

2026-10-28. Requirements RMI01–RMI03 / R01 / Q01.

Weekly Rivalry now uses three competitors on a stepped winners' podium, showing
ranked competition. Challenges uses crossed checkered race flags, replacing
the abstract target/arrow. The shared Challenges glyph changes with its rail
symbol, including the page's empty state. The ordinary trophy used for awards
elsewhere remains appropriate to that role and is unchanged.

RMI01 is the Rivalry podium, RMI02 is the shared crossed-flags symbol, and RMI03
is consistent selected/inactive presentation at the existing sizes. R01 retains
all navigation identities, native input behavior, caching, SVG raster dimensions
and touch targets. Q01 records native visible review and retained input checks.

Two runtime files change: `game/ui/race_mode_icons.gd` and the shared constant in
`game/ui/menu_icon.gd`. The legacy `trophy` / `target` keys and button names remain
stable. The rail's challenge stroke is adjusted to match the other 64-unit
symbols after scaling the common 24-unit artwork. The new artwork is original
SVG path data; there are no added assets, dependencies or runtime processes.

Actual commands through the pinned 4.7.2 engine's development entry point:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/race-mode-icons-2026-10-28/run.ps1 -Phase before
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/race-mode-icons-2026-10-28/run.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/race-mode-icons-2026-10-28/run.ps1 -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/race-mode-icons-2026-10-28/run.ps1 -Headless -ScriptPath res://tests/test_race_mode_input.gd
```

Compatibility and desktop Mobile each exit 0 with two saved native views:
selected/inactive production rails at their actual 38-unit icon size, smaller
shared glyphs, and the actual Challenges page in an isolated themed shell.
The existing Race-mode input suite passes **57 checks, 0 failures**, including
mouse/touch activation of both destinations and interrupted transitions.
Existing tests are unchanged; `game/tests/capture_race_mode_icons.gd` is a capture
helper. A separate five-check scope audit confirms that Track of the Day, Free
Race and Friends artwork, the rasterizer/cache, and all other MenuIcon code are
exact. No player-facing copy or localization catalogue changes are needed.

The runner isolates local user files and archives logs/build receipts. It
restores only its own generated identity/version while preserving newer
concurrent metadata. The task-only patch is based on the captured task-start
sources, retaining the previously accepted daily icon, and passes reverse
application and whitespace checks. No main Git index staging or commit occurs.

[Before](evidence/race-mode-icons-2026-10-28/before/gl_compatibility/icons-actual-size.png)
→ [new icons](evidence/race-mode-icons-2026-10-28/after/gl_compatibility/icons-actual-size.png).
[Challenges page](evidence/race-mode-icons-2026-10-28/after/gl_compatibility/challenges-page.png).
Logs, hashes and the scoped source patch accompany `report.json` in that folder.

Reload/rebuild and owner acceptance of the symbols remain. No phone/tablet
attachment query or physical-device test, APK, live/backend write, real-account
authentication, purchase, owner-save change, owner-process restart, deployment
or main-index staging/commit/merge was performed. Desktop views do not establish
physical-device appearance or performance; concurrent work is preserved.
