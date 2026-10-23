# Studio implementation — 2026-10-16

The owner approved implementation of the [backend product review](BACKEND_PRODUCT_REVIEW_2026_10_16.md).
This change implements the local analytical and operational platform and replaces the main navigation
with eight workspaces. It is not a production deployment or evidence that external data feeds are connected.

## What changed

| Workspace | Result |
| --- | --- |
| Overview | Incident-first response links, verification backlog, data age and explicit source gaps. |
| Player behaviour | Activity, exact UTC D1/D7/D30 cohorts, mature first-race journey, observed session engagement; build/platform/mode/population filters; scoped CSV and saved views. Small or immature cohorts do not become optimisation claims. |
| Game quality | Candidate/baseline comparison, completion and weighted frame totals, affected reporting players, device segments and existing track/device/network diagnostics. Release decisions have an audited registry. |
| Monetisation | Provider money grouped by currency and accounting basis; purchase delivery separately; atomic noncash Coin opening/earn/spend entries. Missing revenue and LTV are explicit. |
| Content & competitions | Existing catalogue/publication evidence; readable event context, active/ended filters, search and competition paging. Existing immutable scoring inspectors remain available. |
| Operations & alarms | Continuous incident occurrences, acknowledgement, assignment, notification suppression, recovery and owner closure; history, signed notification outbox, exhausted-delivery retry/dismissal and every worker queue. On-demand checks remain a separate view. |
| Player support | Existing private case/evidence workflow plus owner, priority, due date, linked incident and revision-fenced commands. Player and race inspectors remain linked. |
| Administration | Metric registry/coverage, named staff gate, saved views, release and experiment registries, audit history. Legacy deep links still work. |

The original all-player totals are unchanged. Separately labelled real/artificial analysis is implemented
behind `BMT_STUDIO_BUSINESS_COHORTS=false`; it remains disabled until the population choice is made.
No private guest linking, retrospective device inference, fake financial values or canonical race changes
were introduced.

## Evidence and correctness

Migration `0040_studio_platform` adds17 Studio tables after the shared0037–0039 changes. New analytical
facts are projected in the existing deduplicated product transaction, in the existing bounded500-event
worker batch. They do not run on telemetry ingestion or during driving. First-observed means observed
activity, not installation or a newly registered account. Collection starts with this projection; old
processed events are not silently reconstructed into a new historical cohort.

Calendar-day requests expose their effective boundaries. Return cohorts wait for a complete target day
and the processor watermark, remain provisional during the seven-day late-arrival window, and do not
report expired fact coverage as a zero return. Foreground duration is reported intervals, including its
missing-exit/concurrent-device limitations. Account erasure removes new private facts in bounded batches
without renumbering the original persistent erasure plan; counts can consequently restate.

Diagnostic headline race, frame, rendering-context and network totals now aggregate the entire filtered
SQL scope, using64-bit extraction for large daily network/frame aggregates, including tested values above2^32.
Selector, heatmap, segment and detail caps are labelled separately. The quality track selector uses a small
projection rather than downloading full catalogue documents. Reliability failure links use
an exact failure-code filter; rejected proofs and infrastructure failures have separate counters. Studio
context includes schema identity. Queue records and incident occurrences use stable cursors; competition
lists have real filtered paging. Reports read consistent SQL snapshots.

The incident ledger records opening, escalation and recovery even between operator visits. Unknown
evidence preserves the last firing condition and remains visibly unknown. A recovered occurrence must
be reviewed before closure; recurrence receives a new occurrence. Writes require owner access, a reason,
an idempotent command ID and the expected revision/attempt count. Named actors are retained in audits.

An independent watchdog can retain and notify an outage while the game API/database is offline.
Signed webhooks have stable delivery IDs, short leases, bounded retries and dead-letter handling.
External notification authority is explicit so the watchdog and API cannot both send the same source's
notification. Suppression instructions are cached on the independent host. The API notification consumer
runs separately from race verification. The log collector retains aggregate server counts, never request
IDs, paths, player identities, payloads or credentials. Multi-window error-budget checks require a
declared-complete export and sufficient samples; sparse/incomplete evidence is unknown.

Google Play verification reuses the existing account-binding/proof validation and bounded provider
reader. Only a completed, live, correctly bound, supported single-quantity purchase can reach the existing
atomic grant function. Replays cannot double grant. Consumption/acknowledgement happens after SQL commit;
a completion failure requires a client retry with the same token. Tokens are not stored. Verification
does not infer a cash amount. AdMob imports append immutable deltas for provider restatements, reject
partial/stale snapshots and keep estimated earnings in their provider currency/calendar basis.

Presentation experiments exclude physics, scoring, purchase authority and arbitrary scripts/URLs.
They have stable assignment, explicit applied-setting exposure, one active experiment, pause/stop,
fixed follow-up, minimum sample size and sample-ratio checks. Assignments are not exposures. Scorecards
show expired follow-up coverage as unavailable, rather than turning missing retained returns into zero.
They declare no automatic winner, particularly while crash-free and attributable-revenue guardrails are absent.
No game client setting was activated by this change.

## Validation

Actual commands, hashes, completed counts, initial failures and limits are in
[report.json](evidence/studio-platform-2026-10-16/report.json).
The final focused rerun passes39 checks; the larger regression selection passes249 with3 skips and one
capability-status assertion that was then corrected and covered by that final rerun. Unconfigured provider
adapters remain unavailable in the capability response. PostgreSQL passes42 with one fixture skip.
The [browser run](evidence/studio-platform-2026-10-16/browser.json) covers80 desktop/390px checks with
no JavaScript errors, failed reads or page-wide horizontal overflow. It exercises incident acknowledgement,
recovery/closure, saved views, case priority, dead-letter dismissal and analyst restrictions. Captures use
an owned local service with explicitly seeded data; they are not live player/revenue evidence or a phone test.

Actual PostgreSQL checks include concurrent incident creation/acknowledgement, queue paging, receipt
deduplication, financial restatements, named audit identity, erasure and the500-event SQL budget. The
disposable container is ownership-checked and removed. The prepared analytical projection adds work:
the measured batch timing and SQL count are reported, not described as a speed improvement over the
smaller previous projection. No production load, soak, screen-reader, physical-phone or financial-provider
certification is claimed.

A broader1553-test selection was started and interrupted after its first144 results; it is not a full-suite
pass. One unrelated publication/deletion fixture reached the project's current community-consent gate
before its storage pause. It now explicitly accepts the current terms and its targeted fencing check passes.
Earlier PostgreSQL quality fixtures likewise needed explicit analytics opt-in; production consent was not
weakened. Initial harness/CSP/token-fixture issues and their corrections are retained in the report.
Accepted client timestamps remain observations; device clock uncertainty can affect observed day cohorts.

## Activation and remaining dependencies

Use the [activation runbook](STUDIO_PLATFORM_ACTIVATION.md). The source is locally implemented and tested;
the last verified staging snapshot is schema0036/revision59. No rollout was performed by this task.
This task did not publish a backend image, run a live schema migration, send a real notification, charge a
purchase, change historical records or build/install an APK.

The approved seven-step roadmap now has implemented local services and views across all seven steps;
its production/product acceptance is not complete. These dependencies remain:

* Independent watchdog hosting, a supervised notification consumer, log export scheduling and an actual
  receiver/source credential configuration; externally hosted outbox delivery evidence remains on that host.
* Play package/product/account ownership, live Billing SDK use and token retry/completion testing; RTDN,
  refund/reversal policy and settled financial reconciliation. AdMob account access and scheduled imports;
  impression-level/cohort attribution, FX, player LTV and causal monetisation decisions remain unavailable.
* Staff identity audiences/allowlist and an identity setup that supplies the required signed MFA evidence.
  The current UI accepts a staff identity token; a polished browser SSO flow and actual provider MFA acceptance
  are not claimed. A Google token without the required MFA claim fails closed.
* Actual client adoption of presentation assignments and applied-setting exposures, A/A validation with real
  eligible traffic, complete guardrails and an owner-approved rollout decision. The native game is unchanged.
* Mature real traffic, user acceptance of hierarchy/thresholds, operational load/soak and restore acceptance.

These are explicit connection/policy/acceptance dependencies, not populated demo metrics. The UI retains
unavailable states until evidence exists. Concurrent game, economy, News, community and canonical-contract
work is preserved; the checkpoint is scoped to this task.
