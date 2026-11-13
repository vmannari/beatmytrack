# Daily timer unit labels

DTF01: The daily timer now displays zero-padded units, for example **04 hours 31 minutes**. The visible text is the duration itself. The reserved width uses the same translated template and tabular font, preserving stable width while time changes. Minute cadence and exact rollover behavior are unchanged.

Changed runtime source: `game/ui/track_of_day_page.gd` (display and width measurement). The existing presentation fixture now asserts the localized word format and supports a separate evidence destination. `scripts/translations/daily_timer_words.tsv` and twelve scoped PO additions provide the units in each offered language.

Actual command:

```powershell
python docs/evidence/daily-timer-words-2026-11-01/run_native.py test_daily_fixed_presentation --graphical
```

Result: **307 native Compatibility checks, 0 failures**, including fixed width across nine time samples in twelve languages and retained result-view checks. Twelve catalogue entries pass format-token/nonempty checks. The actual App screenshot is `docs/evidence/daily-timer-words-2026-11-01/fixed-hours-minutes.png`.

The runner uses the pinned Godot 4.7.2 build through `scripts/run_no_crash_dialog.py`, isolated test storage and an empty service origin. The existing isolated root-certificate-store warning remains. No phone test, backend change, deployment, owner-save mutation or owner-process restart was performed. Reload and owner appearance acceptance remain. The task-only patch and forward/reverse content checks are recorded in the evidence folder; concurrent work and the main Git index are preserved.
