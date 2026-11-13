# Daily track view cleanup

DVC01 removes the repeated award name, next-medal sentence and medal-name fallback from the daily track result card. The earned/selected medal icons remain, with translated names on hover. A single target-time line remains below them; its tooltip retains the exact improvement or stage-clearance explanation. Elite shows its distinct medal without another text announcement or target line. No medal thresholds, progress, times or standings calculations change.

DVC02 adds the shared `PlayerCountry.flag` artwork between rank and name in the nearby standings. The local candidate row copies country metadata from the current account. Opponents use the existing response metadata; missing/unknown codes use the shared neutral flag. Driver names retain ellipsis and gain a hover tooltip. Self-row highlighting applies only to labels, leaving flag colors intact. The View all dialog already supported flags and needs no runtime change. No backend source changes are required for this presentation change; matching country metadata must be present in the service response to display a selected flag.

Runtime change: `game/ui/daily_result_card.gd`. Existing fixtures `test_daily_medal_page.gd`, `test_daily_fixed_presentation.gd` and `test_daily_week_fit.gd` now inspect the medals/target instead of removed text controls. The medal-page fixture also covers account/opponent flags, View all flags and row containment. Its output directory can be set through `BMT_DAILY_MEDAL_OUTPUT` to preserve historical captures. Concurrent week-strip, results, Rivalry and other source changes are preserved.

Actual commands from the repository root:

```powershell
python docs/evidence/daily-view-cleanup-2026-11-02/run_native.py test_daily_medal_page
python docs/evidence/daily-view-cleanup-2026-11-02/run_native.py test_daily_medal_page --graphical
python docs/evidence/daily-view-cleanup-2026-11-02/run_native.py test_daily_medal_page --graphical --mobile
python docs/evidence/daily-view-cleanup-2026-11-02/run_native.py test_daily_fixed_presentation
python docs/evidence/daily-view-cleanup-2026-11-02/run_native.py test_daily_standings
python docs/evidence/daily-view-cleanup-2026-11-02/run_native.py test_daily_week_fit
python docs/evidence/daily-view-cleanup-2026-11-02/run_native.py test_track_of_day_presentation
python docs/evidence/daily-view-cleanup-2026-11-02/checkpoint.py
```

Results: medal page **109 checks / 0 failures headless**, **123 / 0 each desktop renderer**; fixed presentation **436 / 0**, standings **38 / 0**, week fit **87 / 0**, retained daily presentation **62 / 0**. Checks retain saved progress, car/account scoping, stale replies, translated layout, unlimited retry and the original millisecond lap time. All launches use pinned Godot 4.7.2 through the process-scoped crash-dialog wrapper, isolated test storage and an empty service origin. The existing Windows root-certificate-store warning appears; all test processes exit successfully. During review the shared labels' ignored mouse filter was corrected for target/name tooltips; native checks were repeated after that correction.

Native App captures use synthetic local results and standings. Each renderer has four landscape silver views (1440×900, 1280×720, 960×540 and 844×390), bronze/gold/Elite/no-result states, and six portrait component locales at 390×844. The portrait captures scroll to the result card. [Desktop preview](evidence/daily-view-cleanup-2026-11-02/gl_compatibility/silver-1280x720.png) and [portrait Finnish preview](evidence/daily-view-cleanup-2026-11-02/mobile/portrait-fi.png). These are desktop rendering checks, not physical phone evidence.

The task-only patch is relative to archived task-start source and the shared documents immediately before this task's additions. Forward/reverse application and normalized text content are checked in an owned temporary repository, without writing the main index. Raw logs, captures and hashes are in [the evidence folder](evidence/daily-view-cleanup-2026-11-02/).

Reload/rebuild and owner appearance/touch acceptance remain. No phone/device query or test, APK, live service access, backend mutation, deployment, owner-save mutation, owner-process restart, main-index staging, commit or merge was performed.
