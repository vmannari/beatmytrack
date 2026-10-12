# Challenge creation page and attempt limits ? 2026-10-09

The owner supplied a two-column Create challenge draft and requested optional limits on tries. Creation now occupies the main menu below its existing navigation, with settings on the left and the original scenic art, actual route and live summary on the right. Back/Cancel and Create & share stay outside the cards. All six setting rows fit the default desktop, compact and wide landscape layouts; opening track search or the tries explanation uses the bounded settings scroll.

## Requirements

| ID | Implemented behavior |
| --- | --- |
| CH14 / V03?V05 / R01 | Embedded two-column creation page replaces the centered CanvasLayer sheet. Existing original scenery, vehicle artwork, typography and yellow controls are reused; car/share glyphs extend the original vector icon set. |
| CH15 / B01?B07 | Optional 1, 3, 5 or unlimited tries per driver; unlimited remains the default. Server ticket issuance atomically reserves a try. Abandoned/restarted/rejected races consume their reserved tries; reconnect/upload retries do not reserve another. Exhausted participants can inspect/share results, but cannot start another challenge race. |
| CH16 / Q01 | Additive schema0021 keeps old challenges unlimited, backfills their starts/source finishes and preserves standings. Existing default creation idempotency hashes are retained. Parallel same-key starts share one ticket; competing requests cannot exceed the limit. Explicit rematches retain the chosen limit and create fresh counters. |
| CH09?CH11 / CH02?CH04 | Post-race creation still fixes the exact completed ticket, track and car, including a slower-than-PB finish. Pending/error states never substitute a PB or offer another drive. Cancel restores the same normal summary. Source-race return retains duration and tries. A seeded creator finish counts as one try; a Group created without a source starts at zero. |
| R01 / R05 / TD06?TD08 | Five pinned laps, normal results first, best-only standings, free ordinary racing, internal authentication gates and artificial/public isolation remain. |

No unverified custom target, public/community visibility, 14-day duration or new social feature was inferred from the illustrative draft. Existing verified targets and 24-hour/3-day/7-day durations remain. General creation keeps track/car selection and optional track/creator search; finished-result creation keeps those values fixed.

## Changed files

- `game/ui/challenge_create.gd`: page layout, preview/summary, tries choices and help, selected-limit submission.
- `game/core/app.gd`: menu integration, completed-summary retention/return and source-race settings.
- `game/ui/challenges_page.gd`, `game/backend/challenges_client.gd`: remaining tries, exhausted race gate, response validation and ticket counter updates.
- `game/ui/menu_icon.gd`: original car/share SVG glyphs.
- `backend/bmt_backend/challenges.py`, `challenge_models.py`, `migrations/versions/0021_challenge_attempts.py`: optional contract, atomic reservations, snapshots, rematches, browser invitation and additive migration.
- `game/tests/test_challenges.gd`, `test_challenges_http.gd`, `backend/tests/test_challenges.py`: native layouts, actual HTTP races, attempt/idempotency/concurrency/migration coverage.
- `docs/schemas/challenge-create-v1.schema.json`, `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, this document and task evidence.

## Actual verification

All native checks use `scripts/dev.ps1` and pinned Godot4.7.2.stable.official.ed1daf0bf. Actual HTTP runs use an isolated local service, test identities and recorded five-lap races, rather than retained player data.

| Actual command | Outcome |
| --- | --- |
| `scripts/dev.ps1 CheckScript -ScriptPath res://core/app.gd` | Passed. First restricted attempt could not open the Windows user log; local-access parser passed. |
| `scripts/dev.ps1 TestScript -ScriptPath res://tests/test_challenges.gd -Graphical` | 140 checks, zero failures at1280?720,960?540,1600?720; 18 captures. Exact result/pending/service-error behavior, page integration, all default rows visible and exhausted race controls covered. |
| `scripts/dev.ps1 TestApp` | 99 checks, zero failures. |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_challenges_http.py -q -s --tb=short` with `BMT_CAPTURE_CLOUD` | Final two native flows pass48/49 checks. A real faster PB is verified before the slower source finish; Cancel restores the same summary; exact source, race-first duration/tries, guest try, recipient ghost/race, normal results, retry, rematch and group scoring pass. |
| `.tools/backend-venv/Scripts/python.exe .tools/challenge_page_postgres.py` | Owned disposable SQLite/PostgreSQL runner; final receipt below. Row concurrency and actual schema0020?0021 over existing standings included; the owned container is removed. |
| `scripts/dev.ps1 Doctor` | OnePlus Pad2 OPD2403/f0ba474a attached and authorized. No change-specific Android test/install/export was performed. |

[Menu checks](evidence/challenge-page-2026-10-09/menus.log), [application checks](evidence/challenge-page-2026-10-09/app.log), [native HTTP log](evidence/challenge-page-2026-10-09/http-final.log), [database log](evidence/challenge-page-2026-10-09/postgres.log) and [device receipt](evidence/challenge-page-2026-10-09/doctor.log) retain actual outcomes.

Initial test-only issues were corrected without relaxing assertions: wrong `steer` argument (fixture uses `steering`), a statically impossible type check, duplicate default page content, early layout assertions before the engine's layout pass and the browser preview's missing tries text. An earlier native flow passed while its historical inputs-only prior-PB upload was rejected by concurrent verifier work; the final fixture records and verifies an actual app PB before asserting the slower finish. Concurrent optional-ghost storage work briefly caused two broader database fixture failures, then its own fixture correction restored the full suite. Earlier database failure evidence is retained. A later concurrent `NightAmbience` class required an importer refresh; final parser/test receipt below. Driving physics/verifier behavior and unrelated work were preserved.

## Evidence and acceptance

- [General creation page, desktop](evidence/challenge-page-2026-10-09/screenshots/menu-create-1280x720.png)
- [General creation page, compact](evidence/challenge-page-2026-10-09/screenshots/menu-create-960x540.png)
- [Exact completed-result creation](evidence/challenge-page-2026-10-09/http-final/create-from-results.png)
- [Race-first creation return](evidence/challenge-page-2026-10-09/http-final/create-after-seed.png)

Fixture names/times are test evidence only. The approved original scenic art is reused; the supplied draft is not a shipping asset. Desktop image inspection does not establish phone touch, safe-area or performance acceptance.

Remaining acceptance: owner presentation/feel, tablet touch/search/help/keyboard, actual authenticated finite-try races on the intended development service, and migration/API/worker rollout together. No retained backend/production deployment, player-data reset, purchase, physics merge, full Validate or APK export/install occurred. At the server boundary a try is reserved when a start ticket is granted; a subsequently failed local start remains reserved. Ordinary Free Race stays unlimited.

The task-only Git checkpoint receipt is recorded below. It preserves the existing branch/index and concurrent work; it is a review checkpoint, not a deployment or merge.


Final receipts: owned SQLite/PostgreSQL **58 passed, two SQLite row-concurrency skips**, including migration preservation, final-start races, same-key concurrency and old default creation keys. The final pinned importer completed and headless challenge recheck passed **122** checks; the graphical140-check captures remain unchanged. [Final headless log](evidence/challenge-page-2026-10-09/menus-final-headless.log). No required acceptance invariant was removed.

Review checkpoint: `refs/codex/challenge-page-2026-10-09`; inspect with `git diff refs/codex/challenge-page-2026-10-09^ refs/codex/challenge-page-2026-10-09`. The scoped snapshot parent includes concurrent ghost-storage changes, so this diff concerns creation/tries only. Receipt: `docs/evidence/challenge-page-2026-10-09/checkpoint.json`.
