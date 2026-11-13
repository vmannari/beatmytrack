# Daily weekly card fit (2026-11-02)

DWF01: Reserve the weekly panel?s actual combined minimum height instead of assuming 92 logical pixels. Recalculate when its minimum changes, including after progress refresh. The hero yields the required space; stacked result positioning uses the same measured height.

Changed runtime source: `game/ui/track_of_day_page.gd`. Focused fixture: `game/tests/test_daily_week_fit.gd`, derived from the existing medal-page fixture with an additional 2538?1147 viewport and weekly-card containment checks. Existing assertions remain.

Command: `python docs/evidence/daily-week-fit-2026-11-02/run_native.py test_daily_week_fit --graphical`

Two native Compatibility runs: 102 checks, 0 failures each. Final screenshots use isolated synthetic account/feed data. [Screenshot at the reported dimensions](evidence/daily-week-fit-2026-11-02/silver-2538x1147.png) visually reviewed: full bottom border and padding visible. Existing Windows root certificate-store warning remains; no live service request. The first copied capture fixture retained its original output directory and refreshed historical medal-page captures; corrected before the final run, whose images are all in this task?s evidence directory.

Review checkpoint: [task-only patch](evidence/daily-week-fit-2026-11-02/change.patch), relative to the saved task-start source rather than HEAD; concurrent work preserved. No main-index write or commit. No device test, deployment, owner-save change or owner-process restart. Reload and owner/device visual acceptance remain.
