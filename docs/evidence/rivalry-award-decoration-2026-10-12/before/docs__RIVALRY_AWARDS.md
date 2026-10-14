# Weekly Rivalry awards ceremony, 2026-10-12

The owner's supplied championship reference supersedes the old completed-week podium/track-list presentation. The completed Overview now becomes an awards ceremony; the active hub, track detail, normal race results and single-press next-week transition remain separate.

## Requirements and delivered behavior

AR01–AR10 / WR01/WR03/WR08 / WC01–WC04 / B05/B07 / R01 / V03–V05 / Q01:

| ID | Behavior |
| --- | --- |
| AR01 | Large gold Weekly Champion title, crown, original vector laurels and trophy icon. Tied overall winners explicitly receive **Joint Weekly Champion**. |
| AR02 | Existing cleared scenic rivalry landscape with a transparent render of the actual pinned car, its local livery/condition, warm menu lights and wheel-contact shadows. Champions receive a bounded six-second confetti flourish; perfect winners receive more confetti. Podium finishes use restrained laurels; other finishes use a quiet Week Complete view. |
| AR03 | Prominent final position/field size, actual total points and track-victory cards. Unranked remains unranked; a solo field cannot manufacture competitive victories. |
| AR04 | Five track rows show the player's actual rank, time, signed gap to the second finisher and earned points. Missing times/gaps remain dashes. The same gap column is used for all positions: positive is slower than the second finisher; negative is faster. Track rows open the existing completed detail with racing disabled. |
| AR05 | Each thumbnail combines the existing original biome scenery with that track's actual saved route outline and start marker. They are decorative Controls inside the full-width track buttons, with no separate favorite/action overlay. |
| AR06 | Compact five-row final field includes the leader, player and nearest competitors. The player retains the yellow highlight; signed points gaps are relative to the player. The active hub's full scrolling field remains unchanged. |
| AR07 | Facts generate highlights: track wins, winning margin/shared championship/podium, five completed tracks, and distinct verified PB tracks. Unsupported clean-driving and historical PB claims are omitted. |
| AR08 | Perfect Week requires five **outright** competitive track victories and the completed championship. Tied track wins do not earn Perfect Week. This is a finale badge; no permanent profile trophy or reward ledger was added. |
| AR09 | Share Results uses the existing Android native text share sheet. Desktop copies the actual week, vehicle, final place/points/victories and each track's rank/time/points, with a confirmation. It does not send a message automatically or generate a public results URL/image. Account/car scope, cached snapshot and busy guards apply. |
| AR10 | Equal-width Share/Continue actions sit outside the cards. Continue uses the existing tested acknowledgement/current-week enrollment flow; both actions disable during the transition, and an actionable failure stays on the ceremony. |

The attached image guides composition only. Its player identities, track names, race times, rank/points, population and stated achievements are not inserted into live data. All new artwork is original repo-native vector drawing; no reference raster was shipped. The landscape, font, biome imagery, car meshes, local cosmetics and contact-shadow assets reuse their existing provenance.

## Evidence and data limits

`WeeklyRivalry.finale_summary()` is a read-only projection of the downloaded final field. It neither simulates nor rewrites races. Ties use canonical ticks when available. Competitive victories require another recorded finisher; a missing race never borrows the leader's time.

The backend now records optional `personal_best` in the existing verified ticket outcome **before** updating the pinned board's PB. It is true for a first PB or a strictly faster result, false for ties/slower attempts. Complete snapshots expose at most five distinct `personal_best_slots` for that player and group. The query is bounded to five output slots and uses existing ticket/run indexes. It adds no tables/migrations or scoring writes. Real/development board contracts remain isolated.

Old outcomes without that field cannot establish a PB achievement and are not backfilled. Older deployed servers remain usable: the client treats the optional field as absent and displays the other verified highlights. The PB addition requires separate server rollout and subsequently verified races. Historical retention may remove underlying evidence; permanent trophy history would need its own approved storage policy.

Trajectory-only verification does not establish collision-free driving. The old result `clean` flag means an eligible completed timing attempt, not collision-free driving; it is deliberately not reused for an achievement. No unsupported “clean driving” highlight or source/diagnostic caption is shown in ordinary UI. A reliable collision-evidence contract and permanent account trophies remain future work.

The player car is rendered once per preparation/resize/visibility change in a transparent 2× MSAA viewport. It has no orbit controls, washing writes or live simulation. Confetti redraws are reserved for champions and stop at six seconds; no display-time effect changes canonical driving or score eligibility. Desktop renderer checks do not establish phone performance or AAA acceptance.

## Changed files

- `game/ui/weekly_rivalry_finale.gd`, `rivalry_award_art.gd`, `rivalry_victory_car.gd` and generated UIDs — ceremony layout, original vector effects and actual car render.
- `game/ui/weekly_rivalry_page.gd`, `game/core/app.gd` — completed-state mounting, local cosmetics, track/Continue wiring and platform sharing.
- `game/race/weekly_rivalry.gd`, `game/backend/weekly_rivalry_client.gd` — facts/share projection, optional PB slots and strict integral JSON validation.
- `backend/bmt_backend/rivalry.py`, `docs/schemas/weekly-rivalry-v1.schema.json` — verified PB fact and optional snapshot contract.
- `game/tests/test_rivalry_awards.gd` and UID, `backend/tests/test_rivalry_awards.py`, `scripts/test_rivalry_awards_postgres.py` — earned celebration, layout/action/car/cosmetic/sharing checks and real SQLite/PostgreSQL route regressions.
- `game/tests/test_weekly_rivalry.gd` — replace only the superseded finale-podium assertion with the new ceremony assertion; retain touch targets, bounds, active hub/detail, scoring and completed-race guards.
- This document, AGENTS override, status/plan entries and scoped evidence/checkpoint.

## Actual commands and outcomes

Godot used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, pinned **4.7.2.stable.official.ed1daf0bf** and matching templates. Python used `.tools/backend-venv/Scripts/python.exe`.

| Actual command/arguments | Result |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_rivalry_awards.gd -Graphical -CommandTimeoutSeconds 180` | **1,706 checks / 0 failures**. Covers perfect/champion/podium/midfield/unranked/tied and solo fields, JSON/PB contracts, bounded effects, actual four-width layout and all five cars, clipboard/share scope, local settings and action guards. **33 captures**. |
| Same with `-RenderingMethod mobile -RenderingDriver vulkan` | **1,706 checks / 0 failures / 33 captures**; desktop Vulkan only. |
| `-m pytest backend/tests/test_rivalry_awards.py backend/tests/test_rivalry_week_completion.py backend/tests/test_rivalry.py -k 'not postgres' -q --tb=short --show-capture=no` | **14 passed / 13 deselected**. |
| `scripts/test_rivalry_awards_postgres.py` | **13 passed / 14 deselected**. Newly owned PostgreSQL 17 with isolated schemas; container removed after verification. [Log](evidence/rivalry-awards-2026-10-12/postgres-regression.log). |
| `-Action TestScript -ScriptPath res://tests/test_weekly_rivalry.gd -CommandTimeoutSeconds 120` | **1,115 checks / 0 failures**. Active podium/scrolling field, completed details and all real button touch targets retained. |
| `-Action TestScript -ScriptPath res://tests/test_rivalry_week_completion.gd -CommandTimeoutSeconds 120` | **38 checks / 0 failures** on the new ceremony, including delayed/repeated Continue and account/result fences. |
| `-Action TestApp -CommandTimeoutSeconds 120` | **99 checks / 0 failures**. |
| `-Action TestScript -ScriptPath res://tests/test_rivalry_entry.gd -CommandTimeoutSeconds 90` | **66 checks / 0 failures**. |
| `-Action TestScript -ScriptPath res://tests/test_automatic_rivalry_flow.gd -CommandTimeoutSeconds 60` | **7 checks / 0 failures**. |
| `-Action Import -CommandTimeoutSeconds 120` | Passed; registered new scripts/UIDs and the concurrently added Garage helper. |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 90` | **559 scripts / 0 failures**. |
| Ruff on changed backend/new Python tests/runner | Passed. |
| `-Action Doctor` | Pinned prerequisites found; **empty ADB device list**. |

Initial native checks found short-screen footer overflow, default gallery-thumbnail minima/action overlays, a champion fixture whose fifth-track points actually lost the championship, and Windows clipboard CRLF normalization. Corrected layout/thumbnail controls, made the fixture's score truthful and normalized only platform line endings in the exact-text check. A temporary duplicate vector-art local variable caused a parse error and was fixed. Concurrent workspace Garage changes needed a Godot class-registry Import; unrelated Garage/creator work was preserved. No touch-target, scoring, race-completion or bounds assertion was weakened. FastAPI/httpx deprecation warnings remain.

Native captures are synthetic fixtures at 1280×720, 960×540, 1536×1024 and 1600×720, with all five actual car models and pending/error actions. They are not the owner's live account. Inspect [perfect week](evidence/rivalry-awards-2026-10-12/ui/perfect-1536x1024.png), [short-screen ceremony](evidence/rivalry-awards-2026-10-12/ui/perfect-960x540.png), [midfield finish](evidence/rivalry-awards-2026-10-12/ui/middle-960x540.png), and [shared championship](evidence/rivalry-awards-2026-10-12/ui/tied-1280x720.png). Vulkan captures live under the evidence `ui/mobile/` directory. Test logs and the task-only checkpoint accompany this document.

No phone was attached. No physical-device rendering/performance or Android share-sheet test, Android export/install, full physics regression, production deployment, live account/race write or permanent trophy grant was performed. Remaining acceptance: owner review of the ceremony/wording, phone readability and native sharing, actual account week rollover, and authorized server rollout for PB facts. Restart/rebuild the client to see the ceremony.

The [task-only checkpoint](evidence/rivalry-awards-2026-10-12/scoped-change.patch) preserves unrelated work, including concurrent creator changes in `app.gd` and other status entries. Its [manifest](evidence/rivalry-awards-2026-10-12/checkpoint.json) records the exact before/after content hashes. Reverse applicability and whitespace checks are part of the recorded final validation; no mixed working-tree commit was created.
