# Daily result highlight, flags and grouped actions

DRR01: The fastest completed flying lap now has a solid menu-yellow card, dark condensed timing figures, dark lap number and a trophy marker. Other successful laps keep their normal cards/checks. If the fastest lap is also the failed lap, its failure cross remains red and visible against the highlight. The existing first-fastest tie choice and exclusion of the opening lap are unchanged.

DRR02: Country flags appear beside driver names in the inline result standings and full standings dialog, including its pinned own row. Artwork and unset-country behavior reuse PlayerCountry. The inline attempt uses the signed-in profile's country; guests and absent/invalid country codes use the existing neutral marker. Country is never inferred from a driver name.

The flying-lap endpoint now includes existing Player.country_code metadata for every returned driver and the own-player record. Both small-snapshot and indexed-PB branches select it in their existing queries; no additional query, schema migration or grant change is introduced. This is an additive response field. The client accepts older responses and shows neutral markers until a matching backend rollout supplies countries.

DRR03: The footer groups Back immediately to the left of Race again with the standard 12px gap, aligned to the right. The label is Back at every width and uses its existing translations. Both signals and destination behavior are retained.

## Sources and commands

Runtime files: game/ui/daily_elimination_results.gd, game/ui/daily_results_standings.gd, game/ui/daily_standings.gd, backend/bmt_backend/daily_lap_standings.py. Retained client regression and backend tests now cover response countries, own-profile country, neutral guest state, flags in the full dialog and adjacent Back at five viewport sizes.

From the repository root:

```powershell
python docs/evidence/daily-results-refinement-2026-11-02/run_native.py --graphical
python docs/evidence/daily-results-refinement-2026-11-02/run_native.py --graphical --mobile
python docs/evidence/daily-results-refinement-2026-11-02/run_native.py test_daily_standings
.tools/backend-secure-venv/Scripts/python.exe -m ruff check backend/bmt_backend/daily_lap_standings.py backend/tests/test_daily_lap_standings.py
python docs/evidence/daily-results-refinement-2026-11-02/checkpoint.py
```

From backend:

```powershell
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_daily_lap_standings.py -k 'not postgres' -q --disable-warnings --tb=short --basetemp=../build/daily-results-flags-pytest
```

Final native design checks: **184 checks, 0 failures on each desktop renderer**. These include twelve captures, all twelve languages at three widths, five result viewport sizes, opening-lap exclusion, the completed-attempt comparison, exact self milliseconds, scope/account/day fences, guest handling and action signals. Existing full standings regression: **38 checks, 0 failures**. Focused backend: **3 passed, 3 deselected**, including country metadata on both population paths, paging, public/own/nearby records and retained candidate/cursor rules. Scoped Ruff passes. An initial pytest command from the repository root failed to import bmt_backend; the corrected backend working-directory command passed.

Review: [updated result](evidence/daily-results-refinement-2026-11-02/elite-1280x720.png), [full standings flags](evidence/daily-results-refinement-2026-11-02/full-standings-flags.png), [portrait](evidence/daily-results-refinement-2026-11-02/elite-390x844.png), [native Mobile renderer](evidence/daily-results-refinement-2026-11-02/mobile/elite-1280x720.png). Captures use explicit synthetic response fixtures, not live account data.

All automated Godot launches use the pinned engine, isolated profile paths, no service origin and process-scoped crash-dialog suppression. Logs retain the existing root-certificate-store warning. No physical phone/device test was performed. Reload, matching backend rollout and owner visual/touch acceptance remain. No backend deployment/live mutation, APK, owner-save/process change, or main-index staging/commit/merge was performed. Concurrent changes to result/self styles and other work are retained; the scoped checkpoint is relative to this refinement's starting sources.
