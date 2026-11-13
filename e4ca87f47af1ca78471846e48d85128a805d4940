# Usage & costs accuracy and presentation review — 27 October 2026

Requirements: **UCR01** audit the live report and actual billing availability;
**UCR02** reconcile charges and credits, preserve currency and billing provenance,
and distinguish Ville's planning model from measured cost; **UCR03** distinguish
current pressure, historical peaks, histogram bounds and scaling settings;
**UCR04** provide an actionable, readable desktop/narrow report; **UCR05/R01/Q01**
continue the authorized private Studio rollout with scoped evidence and preserved
game/backend behavior.

The revised view is live on private Studio revision **bmt-stg-e7a444ab-studio-00018-kuq**.
[Open Studio](http://127.0.0.1:8182/admin#usage) and reload. Live private asset
hashes and the native Google sign-in shell were checked; the staff/MFA HTTP gate
remains. API, worker, all seven existing jobs, resource settings and invoker IAM
are verified unchanged.

The earlier report was useful but needed qualifications. Client request attempts
are an allocation proxy: retries, failed attempts, missing clients and endpoint
complexity prevent them from proving player CPU consumption. A running instance
at its configured scaling ceiling also does not prove load saturation. The new
view makes these distinctions explicit.

## Financial findings and corrections

The live EU dataset was reachable but contained **zero tables** at the initial
inspection. The owner already enabled detailed export. No actual billing total
or invoice reconciliation could be verified, and no cost was invented. The view
now identifies this as **Waiting for the first billing export**, with separate
states for missing configuration, no rows in selected dates, permission/provider
failures and bounded-query incompleteness.

During candidate validation the configured table appeared, with **zero rows and
zero bytes**. The candidate's real BigQuery query succeeded with no data. An
independent aggregate query for the same backend project and dates, without the
ingestion-partition predicate, also returned no currencies/charges and processed
zero bytes. There was no streaming buffer. Thus no delivered costs were hidden
by the report's partition predicate in this check. The current state is **No
billing rows in these dates**, not an assumed zero bill. Real nonempty billing
totals and later export coverage still require reconciliation after delivery.

The query uses `NUMERIC` for costs and correlated credit sums; application
aggregation uses decimal arithmetic before converting final display values.
Charges, credits and net reconcile across currency, service, resource and day.
Currencies never combine. Global resource identifiers complement resource names;
equivalent dash/underscore account suffixes are accepted only within the exact
configured dataset and billing-account binding. Another account is never chosen.
The query retains its project filter and 100 MB scan ceiling, rejects partial
results, and permits at most 2,000 complete aggregate groups.

The last `export_time` and latest selected-row usage end are distinct from the
time a successful query completed. Historical windows are not mislabeled as
current delivery. The totals concern this backend project and UTC usage dates;
other projects and account-only charges are excluded. These totals can differ
from an invoice month and can be restated. The report supplies no unsupported
final-bill forecast.

Ville remains the only eligible real active player. His request-share allocation
is explicitly a **low-confidence partial API planning scenario**, with its
eligible charge base and unallocated remainder. Idle, worker, database, storage,
tax and unidentified charges remain unallocated. Current billing configuration
does not establish its history. Full measured cost per active player is null;
missing/inactive/erased accounts, stale reporting and incomplete collection never
substitute another player. Original global populations remain intact.

## Capacity findings and corrections

The same initial live sample showed worker memory at **97.91% of 768 MiB**, about
**16.03 MiB remaining**, and CPU at **140.46% of the nominal allocation**. These
are provider observations, not a sustained-load diagnosis. Studio's latest
concurrency was zero, but an earlier sampled mean reached its **8/8** setting.
The report retains this genuine earlier high reading.

Scaling allocation now has a distinct configuration assessment, including zero
scale-out room when at its ceiling. Histogram upper bounds alone cannot create
a critical alert; exact observations, lower bounds and sampled means retain a
proven historical floor so a real earlier high reading survives recovery. The
display separates the latest value, peak provenance, current remaining capacity
and the reason for review. Single-container memory headroom also displays bytes.
Stale/missing data remains unknown; inactive job series and unverified quota/rate
limits are not represented as available capacity. Quota coverage is not exhaustive.

The initial interpretation draft downgraded Studio concurrency based only on its
bucket edge. Further inspection found the earlier 8/8 mean; the final guard keeps
that real peak high. Both comparisons and the regression are retained.

## View and validation

The workspace now leads with capacity attention and billing confidence, followed
by recorded charges/credits/net, an interactive daily chart, filterable resource
capacity, Ville's model, ranked workload drivers and expandable source coverage.
Chart days with no exported rows are visibly missing. Negative net credits plot
below zero. Endpoint elapsed time includes waiting and is never labeled CPU time
or money. Worker request totals are not shown as unsupported HTTP metrics.

Actual final test results, screenshots, source hashes and deployment receipts are
in [the evidence report](evidence/studio-usage-review-2026-10-27/report.json).
The final exact-image PostgreSQL/Studio suite passes **108 tests**, with one
legacy public-workload fixture deselected; its original read-only snapshot
assertions run under the explicit private-admin fixture. The first candidate's
107-test pass is retained. The final owned Edge fixture passes **14 checks** at
1440/390 widths with no page errors, including keyboard chart controls, separate
currencies, negative credits, filters, pending/empty/disconnected/stale states,
navigation and locking. Ruff passes on both runtime modules and the focused
tests/browser script.
The exact immutable Studio parent is used with four usage-file replacements;
338 other package files remain exact. The source-only overlay excludes concurrent
game/API compatibility work. No schema migration or resource resize is included.

Desktop Edge tests use an owned synthetic authenticated fixture. The live
read-only operator probe uses the Studio service identity and existing reporting
credentials, emitting only aggregates. It calls report functions directly and
does not mint an owner HTTP credential or bypass the staff/MFA HTTP gate. Live
shell checks do not claim an authenticated owner data-page browser session.
No physical-device test was performed.

Remaining acceptance: first real billing delivery and independent reconciliation
of those actual totals; sustained worker pressure/load diagnosis; owner visual
acceptance. No production pricing or throughput guarantee is inferred from this
report. No player writes, owner-game restart or main-index staging/commit occurs.

Google references: [detailed export schema and update times](https://docs.cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/detailed-usage),
[decimal reconciliation examples](https://docs.cloud.google.com/billing/docs/how-to/bq-examples),
[export setup and delivery](https://docs.cloud.google.com/billing/docs/how-to/export-data-bigquery-setup),
and [Cloud Run scaling ceilings](https://docs.cloud.google.com/run/docs/configuring/max-instances-limits).
