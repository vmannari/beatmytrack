# Studio player-data simulator, 2026-10-17

The owner requests a populated development Studio using ordinary player data, without a separate test population. The simulator creates 600 ordinary accounts and 60 UTC days of history in the retained backend. All eight Studio workspaces use their existing queries and totals. Existing accounts, recordings and published tracks are retained. The final machine report and populated screenshots are in [the evidence directory](evidence/studio-simulator-2026-10-17/).

The operator CLI defaults to a preview. `--apply` writes normal source records; the existing telemetry validators and worker projectors prepare the reports. It is restricted to development/test environments. Stable receipts and a transactional cursor make interrupted imports resumable and completed imports idempotent. The dataset identifier is operator provenance, with no special Studio filter, separate totals or runtime client behaviour.

## What to inspect

Open the [live Studio](https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app/admin). Use the existing owner sign-in. The default recent window contains activity; select the full 60-day window to inspect mature D30 cohorts.

- **Player behaviour:** new/returning players, weekend variation, early churn, foreground sessions, first-race drop-offs and D1/D7/D30 returns. Tourist, regular, enthusiast and creator tendencies generate different activity, without becoming special account populations.
- **Game quality:** compare candidate `0.59.1` with baseline `0.59.0`. Galaxy A13 has a deliberate slow-frame/completion regression. Compare `0.59.2` with `0.59.1` for recovery. These are telemetry build labels; the canonical race contract remains pinned.
- **Monetisation:** approved/pending/declined development orders, estimated purchase/ad earnings, earned Coins and cosmetic spending. Earnings retain provider `simulation`, currency EUR and accounting basis `estimated`; they are ordinary ledger entries, not external settlements. The Type column distinguishes purchase and ad totals.
- **Operations & alarms:** an open quality issue, acknowledged purchase investigation, recovered score-delivery issue and closed discovery incident. Incident details show the next action, owner and response history; recovered issues expose **Clear recovered issue**. Sample observations are not a continuously running production watchdog.
- **Player support / Administration:** 24 linked support cases with priorities and assignees, three releases, a paused A/A presentation experiment and its scorecard. The two sample staff identities do not grant sign-in access. The exhausted notification example is dead, never queued for delivery.
- **Content & competitions:** existing published circuits and their populated race records. The simulator does not publish new official tracks or manufacture competitions.

## Run and refresh

With the backend installed and `BMT_DATABASE_URL` configured for a development/test database:

```powershell
python -m bmt_backend.studio_simulator --players 600 --days 60 --dataset studio-october
python -m bmt_backend.studio_simulator --players 600 --days 60 --dataset studio-october --apply
python -m bmt_backend.studio_simulator_tick --dataset studio-october --apply
```

The historical import needs existing published boards with accepted five-lap recordings. It reuses those immutable recordings and their exact lap times; it does not generate new driving proofs or run thousands of new physical simulations. Ordinary ticket/run/PB/reward records reference that evidence. Client finishes that cannot fit before the history cutoff become abandoned attempts. Server submission latency excludes driving time.

The live tick adds four validated observations for up to 24 consented ordinary accounts, then runs the normal projection. It refreshes the sample monitor observations while preserving response states. Five-minute receipt buckets prevent duplicate activity; disabled, deleted, opted-out and artificial accounts are excluded. It does not create fresh race results or money.

The deployed job can refresh the data without local database access:

```powershell
gcloud run jobs execute bmt-stg-e7a444ab-studio-simulator --project=beat-my-track --region=europe-west1 --args=-m,bmt_backend.studio_simulator_tick,--dataset,studio-october,--apply --wait
```

No recurring scheduler is created. A completed historical import is not extended by rerunning it; use a live tick for current activity. Use one dataset per development environment: different datasets are not intended as an account-name namespace. Keep the immutable player/day/seed plan when resuming.

## Correctness, rollout and limits

The simulation exposed a real validation error: published UUIDv5 track/version identifiers were rejected by race telemetry. Server-owned references now accept valid UUIDs while client race IDs still require UUIDv4. A real ingestion/projection regression test covers this. Populated money rows also exposed the missing earnings Type column, which is added.

The deployment overlays only the simulator modules, that validation fix and the earnings Type column on the previously tested schema40 image. Compiler27 / physics0.59 / rules20 and the existing catalog remain unchanged. Newer concurrent Godot, achievement, challenge-discovery and schema work is excluded. No migration is needed. The before-import backup is `1792222346511`.

Final results, revision/image, source hashes, original-data fingerprints, test output and desktop/390px browser observations are recorded in [report.json](evidence/studio-simulator-2026-10-17/report.json). Browser checks make GET requests only; action rendering is checked without changing live incidents or sending notifications. This is functional sample-data coverage, not a production load test, restore rehearsal or a physical-phone test.

Retained initial attempts are part of the evidence: PostgreSQL rejected DISTINCT over a JSON board value; source selection now uses EXISTS. The first cloud run stopped on the published UUID validation bug after creating the ordinary accounts; the corrected import resumes the same dataset. A day-boundary fixture prompted coherent race/submission timing. A final refresh check corrected monitor timestamps to use the actual observation time, independently of deduplicated activity buckets. The first browser harness assumed one h1 in the historical totals wrapper; it now inspects the workspace heading. No original data was erased to resolve these attempts.

Before real production traffic, provision/reset the environment to the approved clean baseline, including accounts, dependent event/report/incident/finance rows and their caches. Clearing only a test flag or hiding a population is insufficient because these accounts deliberately use ordinary player semantics. This task does not perform that future destructive reset. Provider connections, continuous watchdog/log schedules and real notification delivery remain separate activation work.

The populated views confirm that missing observations were a major cause of the empty presentation: the first-race funnel, mature cohorts, release difference, money/Coins and incident response now show usable examples. They also expose further presentation work. The release device table still shows long render-context hashes and absolute slow-frame counts; readable renderer/viewport labels and per-device rates would make that comparison clearer. Treat this dataset as a repeatable visual and workflow fixture for that next UI pass, rather than proof that every product-design issue is resolved.

## Completed retained deployment

API revision **bmt-stg-e7a444ab-api-00071-riv**, schema40, image `europe-west1-docker.pkg.dev/beat-my-track/bmt-stg-e7a444ab-images/backend@sha256:74156652dea7c44696f23bec8148eb05dc39fcf57ba8d47511dab782851a6322` is live with the matching worker and existing jobs. Historical execution `bmt-stg-e7a444ab-studio-simulator-d4kjj` completed successfully: **600 ordinary players, 60 days, 8,809 sessions, 221,984 source observations and 14,721 accepted race results**. Live ticks add current observations separately. No original accounts were removed.

Full-window analysis sees 600 observed players; the recent default window sees 369. Candidate completion changes by -6.0 percentage points versus baseline; the recovery comparison changes by 5.4 points. These are intentionally simulated descriptive comparisons, without causal attribution.

`37 passed, 1 warning in 68.08s (0:01:08)` passed on the deployed image using disposable PostgreSQL. 58 final read-only Edge workspace/detail checks passed at 1440px and 390px, including four incident states, response actions and experiment scorecard rendering. No JavaScript errors, failed admin reads, browser mutation requests or global horizontal overflow occurred. The slowest of 9 sampled API reads took 1.178s; the slowest sampled route took 1.104s. These timings are individual functional samples during this session.

All 14,721 new race results match one of 70 retained accepted recording templates exactly. 555 Coin wallets balance against their ledgers; all 12 used boards have matching PB counts, public counters and tick frequencies. Eight original-data table fingerprints remain exact. The raw track-version fingerprint changes because normal database triggers increase verified-finisher totals; subtracting precisely the new accounts' finisher increments reproduces the complete original fingerprint. All other original track fields are unchanged. All 27 official heads/documents/old links pass. Native replay/schema/storage smoke and 19 packaged UI assets pass. Temporary canary tags and the owned rollout lock are removed. Actual checks and screenshots: [machine report](evidence/studio-simulator-2026-10-17/report.json), [populated browser evidence](evidence/studio-simulator-2026-10-17/populated-browser.json), [raw original-data snapshot](evidence/studio-simulator-2026-10-17/original-data-after.json), [track counter explanation](evidence/studio-simulator-2026-10-17/original-track-content-after.json), [data coherence](evidence/studio-simulator-2026-10-17/data-correctness.json), [catalog](evidence/studio-simulator-2026-10-17/catalog-live-http.json).
