# Daily timer without leading zeros

DTF02 changes the duration to **4 hours 31 minutes**, including unpadded minutes (for example **4 hours 5 minutes**). The width remains reserved for two-digit values using the existing tabular font. Minute updates and rollover are unchanged.

Runtime: two format strings in `game/ui/track_of_day_page.gd`. The existing presentation fixture and the twelve authored translations use the unpadded format. No backend or gameplay rules change.

Validation command:

```powershell
python docs/evidence/daily-timer-unpadded-2026-11-01/run_native.py test_daily_fixed_presentation --graphical
```

Native presentation assertions: **307 checks, 0 failures**; twelve scoped catalogue checks pass. The isolated process also emitted the existing certificate-store warning and cleanup warnings for four ObjectDB instances/one resource; no memory-cleanliness claim is made for this run. The screenshot, raw log, exact source hashes and forward/reverse checkpoint checks are recorded in `docs/evidence/daily-timer-unpadded-2026-11-01/`. The runner uses the pinned engine through the crash-dialog wrapper and isolated test storage. No phone test, deployment, owner-save mutation, owner-process restart or main-index write was performed. Reload and owner appearance acceptance remain.
