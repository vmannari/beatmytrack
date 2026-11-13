# Straight player-row accent

DPA01 follows the owner's supplied reference: the Daily player's yellow highlight is a straight three-unit vertical bar, inset from the top/bottom, alongside the rounded navy row. An independent noninteractive ColorRect replaces the rounded style-box border. Row geometry, content spacing and input behavior are retained.

Runtime: `game/ui/daily_result_card.gd`. The existing style assertion in `game/tests/test_daily_standings_entry.gd` now checks the navy fill and independent accent. No new test suite was added.

Actual commands:

```powershell
python docs/evidence/daily-player-accent-2026-11-04/run.py test_daily_standings_entry
python docs/evidence/daily-player-accent-2026-11-04/run.py --graphical
git diff --check -- game/ui/daily_result_card.gd game/tests/test_daily_standings_entry.gd
python docs/evidence/daily-player-accent-2026-11-04/checkpoint.py
```

Entry/cache checks **14/0**; actual-App Compatibility checks **237/0**, including four landscape sizes, twelve locales, earned/unearned awards and portrait layouts. The native screenshot was inspected to confirm the bar is straight. [Native preview](evidence/daily-player-accent-2026-11-04/native/gl_compatibility/unplayed-1280x720.png). Runs use the pinned engine, isolated test storage and crash-dialog wrapper. The existing Windows certificate-store error remains in the successful logs.

The task patch is relative to the archived sources immediately before this correction, preserving the earlier redesign and concurrent work. Forward/reverse application and content checks use an owned temporary repository; the main index is not written. No physical-device query/test, owner-save/process change, backend change, live access or deployment was performed. Reload and owner appearance acceptance remain.

DPA02 follows the owner's further correction on November 4: the straight bar now spans the complete row height, reaching both corners, and left content padding increases from 6 to 12 units so the rank/dash clears the marker. Marker offsets compensate for the panel's content margins rather than shortening the line. Runtime change remains confined to `game/ui/daily_result_card.gd`.

Actual follow-up command: `python docs/evidence/daily-player-accent-corners-2026-11-04/run.py --graphical` passes **237/0**; scoped `git diff --check` passes. The updated native image was inspected for the full-height line and increased dash spacing. [Corrected preview](evidence/daily-player-accent-corners-2026-11-04/native/gl_compatibility/unplayed-1280x720.png). The immediately preceding source is archived separately in that evidence folder. The certificate-store error remains; no device test, live access or deployment was performed.
