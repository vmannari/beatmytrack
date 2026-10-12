# Player countries and standings flags — 2026-10-07

The owner requests a country for each player and its flag beside the player in every standing. Requirements: **CTRY01** persisted player country; **CTRY02** account selection; **CTRY03** standings coverage; **CTRY04** migration, asset provenance and validation. This extends B01/B07, WR01/WR09, R01, V03–V05 and Q01 without changing driving or scoring.

Players choose a country under **Manage account**, also reachable from Settings → Account. New Google players choose their country alongside their racing name. The picker searches country names or two-letter codes and provides 48-logical-pixel rows and keyboard selection. Existing authenticated players save their country independently of their name; the development account keeps its fixed racing name.

`country_code` is a self-selected ISO 3166-1 alpha-2 country/territory code, normalized to uppercase against the shared 249-entry offline allowlist. The backend persists it and returns it in sign-in, session refresh and `/me`. `PATCH /me` accepts a country, name, or both; invalid fields reject the complete update. Country-only updates preserve unfinished username selection. No location, Google-name, email or timezone inference occurs. Existing real accounts migrate to an empty code and show a neutral globe until they choose. The API can clear a country with an empty string; the current picker offers the country list.

Flags appear in the Weekly Rivalry Overview/Standings tables, podium, track-detail nearby rows, named next rival, and named result rows using that same renderer. They also appear in Free Race's high-score preview, the paginated full high-score dialog and Around me. A player mapped to “You” retains the server country. Older cached responses without the field remain readable using the neutral icon. The results distribution contains no named player rows to decorate.

Migration `0018_player_country` adds a non-null two-character field without changing real identities, names, sessions or scores. It gives explicitly artificial development drivers stable fictional countries; both automatic fields and operator-created fleets assign them to newly created artificial profiles. Public-population isolation and development gates remain intact. Country metadata never enters replay, handling, rules keys, matching or points calculation.

The original 4:3 SVGs are vendored from [flag-icons v7.3.2](https://github.com/lipis/flag-icons/tree/v7.3.2), under its retained MIT license. The neutral SVG is original project artwork. [Provenance and archive hash](../game/assets/countries/PROVENANCE.md) and the reproducible download script are retained. Godot import settings cap images at 64 pixels with mipmaps; the actual complete catalog uses **4,078,620 bytes** of texture image data. Android export filters explicitly include the country catalog and license. Backend package data also includes the catalog and its license. There are no runtime asset requests or added dependencies.

Changed files:

- Backend: `identity_models.py`, `auth.py`, `runs.py`, `rivalry.py`, `automatic_test_drivers.py`, `test_drivers.py`, new `countries.py`/catalog/license, migration `0018_player_country.py`, `pyproject.toml`, [profile schema](../backend/schemas/player-profile-v1.schema.json), and country tests.
- Native: `ui/player_country.gd`, `ui/country_picker.gd`, `ui/account_panel.gd`, `backend/account_controller.gd`, `ui/weekly_rivalry_page.gd`, `race/weekly_rivalry.gd`, `ui/cloud_leaderboard.gd`, `ui/track_browser.gd`, `ui/settings_page.gd`, `core/app.gd`, `export_presets.cfg`, country assets/imports, and country/account tests.
- Contracts/documentation: `docs/schemas/weekly-rivalry-v1.schema.json`, this record, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`; tooling: `scripts/vendor_country_flags.py`.

Actual verification uses `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`. Final commands and outcomes:

```powershell
python scripts/vendor_country_flags.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_player_countries.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_weekly_rivalry.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_player_countries.py backend/tests/test_auth.py backend/tests/test_browser_auth.py backend/tests/test_rivalry.py backend/tests/test_test_drivers.py backend/tests/test_automatic_test_drivers.py -q -k 'not postgres' -m 'not godot' --junitxml=docs/evidence/player-countries-2026-10-07/affected-final.xml
.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_account_client.py backend/tests/test_automatic_test_drivers.py -q -m godot --junitxml=docs/evidence/player-countries-2026-10-07/http-final.xml
.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_domains.py::test_recorded_practice_through_real_publish_worker -q -k 'not postgres' --junitxml=docs/evidence/player-countries-2026-10-07/practice.xml
```

- Graphical countries: **656 checks, zero failures**, at 1280×720, 960×540 and 1600×720. Loads every country image and checks its size/total memory, actual flags next to “You”, score-column separation, missing-country fallback, literal player names, Around me and picker search/choice/touch-row geometry.
- Rivalry regression: **1070 checks, zero failures**; app navigation: **99 checks, zero failures**; parser: **347 scripts, zero failures**.
- Affected backend suite: **86 passed, 11 deselected** (PostgreSQL and separately run native integration). Covers account persistence, validation, country migration/retry, profile authorization, public/neighbourhood/weekly country propagation and retained authentication/test-driver behavior.
- Real disposable HTTP/native integration: **2 passed**. Country/account UI checks pass; actual country saving, country selection with username onboarding, session restoration, separation between identities and automatic canonical-driver verification are exercised. Google uses the existing test identity verifier, not real Google credentials. Graphical account captures use `BMT_CAPTURE_ACCOUNT=docs/evidence/player-countries-2026-10-07/account-final`.
- Recorded-practice verification: **1 passed, 1 PostgreSQL deselected** after running outside the sandbox.
- Ruff on changed backend source/new tooling and scoped whitespace checks passed.

Failures and limits are retained honestly. Initial Windows Python lacked pytest; verification used the existing `.tools/backend-venv`. Sandboxed asset networking and Godot certificate-store access were denied; public asset download and native checks succeeded after approved tool escalation. No approval rejection occurred. Early test fixtures omitted publishing/creator PBs and measured picker rows before layout; corrected fixtures passed. The final picker evidence sends the same text-change signal as user input because assigning `LineEdit.text` programmatically does not emit it.

A broader backend/domain run gave **104 passed, 2 failed, 41 deselected**. Recorded practice subsequently passed outside the sandbox. The remaining `test_checkpoint_rules_upgrade_keeps_track_and_historical_board` fails with a 409 verifier-build mismatch and also fails using the task-start `runs.py` in an isolated package copy; [baseline report](evidence/player-countries-2026-10-07/baseline-rules.xml). Its fixture still uses the older rules transition; country work does not alter that contract or weaken its assertion. There is no claim that the full regression suite is green.

Inspected actual native screenshots: [compact overview](evidence/player-countries-2026-10-07/ui/overview-960x540.png), [standings](evidence/player-countries-2026-10-07/ui/standings-1280x720.png), [high scores](evidence/player-countries-2026-10-07/ui/high-scores-960x540.png), [country picker](evidence/player-countries-2026-10-07/ui/country-picker-960x540.png), [saved account](evidence/player-countries-2026-10-07/account-final/country-developer.png), [new-player country step](evidence/player-countries-2026-10-07/account-final/choose-name-960.png). Rivalry/high-score captures use isolated presentation fixtures, never invented live results. Scoped patch, source hashes, initial status and logs are retained under `docs/evidence/player-countries-2026-10-07` so unrelated workspace work stays separate.

Remaining acceptance: owner visual review, real Google sign-in and country persistence against the retained service, mobile keyboard/touch behavior and phone rendering. **No phone attachment check, device test, Android export/install, full Validate, live account write, NAS/cloud migration or production deployment was performed.** This is a local implementation. Live use requires backing up the target database, applying `0018_player_country` and deploying matching API/worker source; production deployment still requires owner authorization. The release client must also include these changes. Existing player files remain intact.
