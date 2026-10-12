# Results histogram correction — 2026-10-08

Owner request: use wider race-time bins, clearly show the just-completed race and the player's best, and include all test drivers' best laps in the lap comparison.

Requirements: R01/R03, V03/V05, RR05/RR06, B05, TD06/TD08 and Q01. RR06 is this correction's comparison-data/marker contract.

## Implemented behavior

Results requests **eight bins**, replacing 24 for race time. Local fallback uses at most eight bins and scales its bin count to actual sample size. The race and lap charts preserve exact server bin edges/counts; markers do not create comparison samples.

**THIS RACE** is yellow, with a solid line and triangle; **YOUR BEST** is pale blue, with a dashed line and circle. Each label includes its time. Equal millisecond times share a `THIS RACE / YOUR BEST` marker. The horizontal time domain includes both markers, including races faster/slower than the comparison field; they remain positioned by their actual time. The public verified race PB can update a local PB from another device. Pending uploads retain the current race marker without inventing a verified rank. Development comparison refresh no longer removes the markers.

Both histogram endpoints accept `metric=race|best_lap` (default `race`) and bounded `bins=1..100`. `best_lap` reads canonical verified five-lap splits, excludes the standing start, and contributes **one shortest flying lap per active driver across comparable verified attempts**, including slower races that improved a lap. Drivers must still have a retained PB in that pinned board. Public data excludes artificial identities; development board access remains authenticated/capability-gated. Old raw artificial runs preceding the latest applicable record reset cannot restore retired lap records. Real players are outside that reset. No migration, replay/physics change or player-file rewrite is needed.

Lap queries deliberately do not use the race-PB cache revision: a lap can improve without improving race time. PostgreSQL count aggregates are explicitly converted to integers. Development histogram reads now use the same database snapshot boundary as public boards. The response contract is [time-histogram-v1.schema.json](schemas/time-histogram-v1.schema.json).

An older backend that ignores the new metric must not feed race times into the lap chart: the client requires `metric=best_lap` in the response and keeps its local fallback otherwise. Consequently, live all-driver lap data requires the matching backend update.

## Files and review checkpoint

- `game/ui/race_complete.gd`: wider requests, lap comparison loading, marker retention, local and verified PB handling, development fallback independent of public board availability.
- `game/ui/track_distribution.gd`: separate timed marker rendering, exact bin edges, bounds including both personal times, retained original rendering for other chart callers.
- `backend/bmt_backend/runs.py`, `test_drivers.py`: metric contract, database aggregate, development reset protection and snapshot boundary.
- `game/tests/test_race_results.gd`, new `test_results_histograms.gd`; `backend/tests/test_domains.py`, `test_test_drivers.py`: focused marker, population, SQL-dialect, privacy and reset checks.
- This document, response schema, development status/phase plan and dated evidence.

The working tree already contains extensive unrelated work. [Task-only Git patch](evidence/results-histograms-2026-10-08/results-histograms.patch) records only changes against snapshots taken before this task. No mixed-workspace commit was made. Private capture/overlay preparation helpers remain under `.tools/results-histograms`; they are outside the game/export root and contain no credentials.

## Actual verification

All Godot commands use pinned **4.7.2 stable ed1daf0bf** through `scripts/dev.ps1`. `APPDATA` was redirected to `build/results-histograms-user` for isolated test saves. Windows certificate access required an approved sandbox escalation for runtime checks.

| Command | Actual outcome |
| --- | --- |
| `CheckScript -ScriptPath res://ui/race_complete.gd` | Passed after redirecting the initial denied user-log path. |
| `TestScript -ScriptPath res://tests/test_results_histograms.gd` | Initial focused run: 24 checks, zero failures; final graphical run includes the additional verified-PB assertion. |
| `TestScript -ScriptPath res://tests/test_results_histograms.gd -Graphical`, with `BMT_RESULTS_EVIDENCE` set | **36 checks, zero failures**, final; includes four captures and three measured landscape sizes. |
| `TestApp` | **99 checks, zero failures**. |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` | **351 scripts, zero failures**. |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_domains.py backend/tests/test_test_drivers.py -k histogram -q --tb=short --show-capture=no` | **7 passed, 1 skipped, 59 deselected**, against SQLite and an owned PostgreSQL 17 database. Skip is the PostgreSQL-only snapshot test's SQLite parameter. |
| Same Python; `pytest backend/tests/test_domains.py backend/tests/test_test_drivers.py backend/tests/test_review_reliability.py -q -k 'not godot' --tb=short --show-capture=no --junitxml=docs/evidence/results-histograms-2026-10-08/backend-tests.xml` | **143 passed, 5 skipped, 2 failed**. Both failures are the existing `test_checkpoint_rules_upgrade_keeps_track_and_historical_board` 409, one per SQL dialect. [Actual XML](evidence/results-histograms-2026-10-08/backend-tests.xml). |
| Baseline-copy `pytest backend/tests/test_domains.py -k 'checkpoint_rules_upgrade and not postgres' -q --tb=short --show-capture=no` | Same 409 reproduced using the task-start `runs.py` and `test_drivers.py`; no source changes were reverted in the shared workspace. [Baseline XML](evidence/results-histograms-2026-10-08/baseline-rule-failure.xml). |
| `ruff check` for the four changed backend source/test files; scoped `git diff --check` | Passed. |

The owned PostgreSQL container used a task label, loopback port 55448, one CPU and 512 MiB, and was removed after testing. Existing services/databases were not changed. The first histogram-only Python invocation accidentally selected an unavailable older local PostgreSQL fixture and reported two connection-timeout errors; the owned fixture replaced that unavailable test connection. The first actual PostgreSQL lap test exposed numeric serialization as a string; that was corrected and the final dialect checks pass.

The broad Godot `TestResults` still fails existing rating timing/viewport/touch/recommendation assumptions and stops on its recommendation button index. The recommendation-catalog problem is already recorded in [RESULTS_CONNECTION_NOTICE.md](RESULTS_CONNECTION_NOTICE.md). No assertions or canonical gates were weakened. The first sandboxed attempt also could not read Windows certificates; only its owned blocked engine process was stopped. The focused suite reuses the original distribution/tail assertions and passes, but the broad results suite is **not** reported green.

## Visual evidence and deployment status

[Desktop 1280×720](evidence/results-histograms-2026-10-08/comparison-1280x720.png), [compact 960×540](evidence/results-histograms-2026-10-08/comparison-960x540.png), [wide 1600×720](evidence/results-histograms-2026-10-08/comparison-1600x720.png), and [equal current/PB marker](evidence/results-histograms-2026-10-08/new-personal-best-1280x720.png) were captured and inspected. The comparison field uses all **100 actual verified Silmukka compact-driver records and their lap splits** from the retained reseed CSV. Player times reproduce the owner's screenshot as an explicitly illustrative UI fixture; they are not new submitted/server records. The isolated empty catalog is why these captures have no recommendation cards. [Source/count/bin receipt](evidence/results-histograms-2026-10-08/verified-silmukka-histograms.json).

A two-module development overlay is concretely prepared for the existing retained `beat-my-track` / `europe-west1` backend. It applies only exact-matching histogram functions/imports to the current immutable parent image, and requires a proof that every packaged canonical file is unchanged, a fresh successful SQL backup and the existing ownership/image guards before deployment. It performs no migration or reseed. [Preparation receipt](evidence/results-histograms-2026-10-08/development-rollout.json).

**Cloud build/push/rollout is pending explicit owner approval.** Automatic approval review rejected the attempted image build/push because the current trusted instructions authorize backend implementation but do not explicitly authorize this repository-code egress and rollout destination. No image was built/pushed and no cloud service, record or schema was modified by this task. The exact intended destination is the existing development Artifact Registry repository `europe-west1-docker.pkg.dev/beat-my-track/bmt-stg-e7a444ab-images/backend` and its retained development API/worker, not production.

Remaining acceptance: approve and run the prepared development rollout, verify live lap populations, and review the chart while racing. Phone attachment was not checked; no physical-device UI test, Android export/install or full `Validate` was performed.
