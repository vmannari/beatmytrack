# Stable results comparisons — 2026-10-08

Requirements: R01/R03, V03/V05, RR05/RR06, B05, TD06/TD08 and Q01. The owner rejects the jumping comparison, the rank from a different population, stacked marker captions and the local four-lap fallback. The latest request supersedes the presentation in [RESULTS_HISTOGRAMS.md](RESULTS_HISTOGRAMS.md).

## Cause and final behavior

The previous refresh serially assigned the public race distribution, fetched its around-me rank, then replaced only the race chart with development data. Every upload/rating sync could briefly draw the public distribution again. The unshipped `best_lap` API left the lap chart displaying only this race's four flying laps. The public rank could say `RANK 1 OF 1` beside 100 development-driver bars.

Results now uses **one authenticated endpoint and one selected population** for both metrics. The client validates board/scope/metric/edges/counts for the entire response before committing either chart synchronously. Equal responses do not redraw or reframe the plots. Pending reads, failures and malformed/mixed responses preserve the last complete comparison. Sync bursts are debounced and a refresh arriving during an outstanding read gets a bounded follow-up. A population is selected when the page opens; upload refreshes do not silently switch between public and development data.

The main race time and fastest flying lap remain prominent. The PB is a compact time on that same row. A single small race-triangle/PB-circle legend shares the existing title row. There are **no stacked THIS RACE/YOUR BEST caption rows and no flying-lap/sample footer**. Bars have restrained rounded tops, narrower gaps and faint reference grid lines. The population's central time domain stays independent of personal outliers; chevrons identify a personal time outside that domain. Close markers use the top triangle for this result and bottom circle for PB, while the exact times remain readable above. Original rendering for chart callers without Results markers is retained.

Each metric shows **POSITION 1 through POSITION 10**, then **TOP N%**. These are exact comparisons against the same field as its histogram, computed from server tick frequencies rather than estimated from bins. The completed race is compared with drivers' race PBs; this race's best flying lap is compared with each driver's shortest verified flying lap across comparable attempts. The player's old contribution is replaced when calculating placement, preventing a slower race from counting the same player twice. Ties use competition position. Percentages round upward to the smallest whole top-percent threshold; a position outside ten can be TOP 1% in a sufficiently large field. With no opponents, there is no position/percentile and the chart shows no peer comparison.

There is no local current/previous-race or four-lap distribution fallback. Before the first successful response, an honest loading/unavailable/empty comparison state retains the two actual result times and known PBs. This prevents a missing older backend from masquerading as the requested player comparison.

## Backend contract

`GET /v1/track-versions/{version_id}/results-comparison?vehicle_id=compact&bins=8&test_population=true|false&race_ticks=...&lap_ticks=...` returns `board_id`, `population_scope`, `stats_revision`, `race` and `best_lap`. Both histograms carry their exact bins, metric, field population, `own_best_ticks`, `opponent_count` and nullable `comparison` (`position`, comparison `population`, `top_percent`, `candidate_ticks`). The display-only candidate parameters are bounded canonical tick values; they never create or modify a verified score. Existing publication, vehicle, rules, disabled-player, development-session and test-population gates apply. Public comparisons exclude artificial identities.

All metrics and placements execute within the existing PostgreSQL repeatable-read boundary (one SQLite request transaction in local tests). Lap aggregation retains standing-start exclusion, active PB membership, non-PB verified attempts and the applicable development-record reset boundary. Real PBs can update the personal marker from another device. The development field may compare a real player with its artificial entrants without exposing those identities in public rankings. No migration, physics/replay change, dependency or player-file rewrite was introduced.

Schemas: [results-comparison-v1.schema.json](schemas/results-comparison-v1.schema.json), [time-histogram-v1.schema.json](schemas/time-histogram-v1.schema.json).

## Changed files and actual checks

Source: `game/ui/race_complete.gd`, `game/ui/track_distribution.gd`, `backend/bmt_backend/runs.py`. Tests: `game/tests/test_race_results.gd`, `test_results_histograms.gd`; `backend/tests/test_domains.py`, `test_test_drivers.py`. Schemas, these two comparison documents, development status/phase plan and dated evidence complete the review package.

Commands used pinned Godot **4.7.2 stable ed1daf0bf** through `scripts/dev.ps1`, with `APPDATA=build/stable-results-user` for isolated records. The graphical run also set `BMT_RESULTS_EVIDENCE` to the dated evidence directory. Runtime checks used approved Windows certificate access.

| Actual command | Actual result |
| --- | --- |
| `TestScript -ScriptPath res://tests/test_results_histograms.gd -Graphical` | **48 checks, zero failures**, final; verifies pending/identical/failed refresh stability, one endpoint, both metrics, mixed-board/scope/count rejection, exact markers, top-ten/percentile/solo behavior and five captures. |
| `TestApp` | **99 checks, zero failures**. |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` | **355 scripts, zero failures**. |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_domains.py backend/tests/test_test_drivers.py -q -k 'histogram or results_comparison' --tb=short --show-capture=no --junitxml=docs/evidence/stable-results-histograms-2026-10-08/backend-tests.xml` | **11 passed, 1 skipped, 59 deselected**, SQLite and owned PostgreSQL 17. [Actual XML](evidence/stable-results-histograms-2026-10-08/backend-tests.xml). |
| `ruff check` for the changed backend source/tests; scoped `git diff --check` | Passed. An unused local test variable found on the first lint pass was corrected. |

The PostgreSQL fixture was the task-owned, labeled, loopback-only container on port 55448 (one CPU, 512 MiB), removed afterward. Existing local services/databases were preserved. The earlier broad results fixture and baseline rules-upgrade 409 failures remain documented in the preceding report; they were not weakened or reported passing. Full physics regression/full `Validate` was not run for this presentation/read-only API change.

## Evidence and acceptance

[Desktop](evidence/stable-results-histograms-2026-10-08/comparison-1280x720.png), [compact](evidence/stable-results-histograms-2026-10-08/comparison-960x540.png), [wide](evidence/stable-results-histograms-2026-10-08/comparison-1600x720.png), [coincident PB](evidence/stable-results-histograms-2026-10-08/new-personal-best-1280x720.png) and [percentile state](evidence/stable-results-histograms-2026-10-08/percentile-1280x720.png) were captured and inspected. All 100 comparison-driver times/laps come from the actual retained Silmukka reseed CSV. Player times are isolated illustrative fixtures; the percentile fixture uses a recorded field time and an exact count over the unbinned driver values. No screenshot fixture was uploaded. The empty isolated catalog accounts for absent recommendation cards.

[Task-only patch](evidence/stable-results-histograms-2026-10-08/stable-results-comparison.patch) records the current correction against turn-start snapshots while preserving unrelated working-tree changes. No mixed-workspace commit was made.

**The matching development backend rollout still needs the owner's explicit approval.** The previous automatic approval review rejected building/pushing repository code to the existing Artifact Registry destination. This correction does not reinterpret the user's UI feedback as approval or retry that rejected upload. The unbuilt two-module overlay was refreshed **locally, with no network calls**, to include the new atomic endpoint and exact-placement functions. [Prepared overlay receipt](evidence/stable-results-histograms-2026-10-08/development-overlay-prepared.json). It retains exact source/image/ownership guards, requires unchanged packaged canonical files and a fresh successful SQL backup, and performs no migration or reseed. No cloud image/service/record changed in this turn.

Until the approved update reaches the existing development API/worker, the new endpoint is unavailable and the client shows its truthful comparison-unavailable state instead of alternating charts or using four local laps. After approval: build/prove/backup/deploy/smoke and verify the live field. Owner visual acceptance is pending. Phone attachment was not checked; no physical-device test or Android export/install was performed.
