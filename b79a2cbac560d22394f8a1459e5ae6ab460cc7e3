<!-- STUDIO-USAGE-DEPLOY-20261027 -->
**Deployment update:** Usage & costs is now live in private Studio. Monitoring, Ville binding and the owner-enabled billing destination are connected; the first provider billing table/data is pending. [Actual rollout and validation](STUDIO_USAGE_DEPLOY_2026_10_27.md). The implementation report below is retained as written before the subsequent deployment authorization.
<!-- /STUDIO-USAGE-DEPLOY-20261027 -->

# Studio Usage & costs — 27 October 2026

The private Studio now has a local **Usage & costs** workspace at `/admin#usage`.
It puts resource headroom ahead of costs, preserves the original global Studio
populations, and restricts the cost-per-active-player figure to **Ville**. The
implementation is ready for a private Studio rollout; it has **not been deployed**.

[Desktop view](evidence/studio-usage-costs-2026-10-27/usage-desktop.png),
[390px browser view](evidence/studio-usage-costs-2026-10-27/usage-narrow.png), and
[missing-source view](evidence/studio-usage-costs-2026-10-27/usage-unavailable.png)
use an explicitly synthetic local fixture. They are not bills or device tests.

## Requirements and behavior

- **UC01:** a private, read-only usage endpoint and integrated Studio navigation,
  dates, manual refresh, saved locations, staff access and lock/cancellation behavior.
  The existing public workload gate remains in force.
- **UC02:** Ville is the only eligible player in the cost denominator. An explicit
  configured stable UUID is preferred; otherwise the server resolves the unique
  claimed username `Ville`. Artificial, disabled, unclaimed and removed accounts
  are ineligible. No other account substitutes when Ville is absent. Identity is
  rechecked on every request; analytical facts use the existing reporting reader
  and erasure fence. Original all-player totals and policies remain unchanged.
- **UC03:** current usage, hourly sampled peaks or conservative histogram bounds,
  limit, remaining capacity, observation time and source are shown for configured
  resources. Initial warning/critical thresholds are **75% / 90%**. Missing, stale,
  ambiguous, truncated and unmeasured inputs stay unknown. The threshold can flag
  a conservative bound; it is not certified sustainable throughput.
- **UC04:** bounded Google Monitoring, Cloud Run/Cloud SQL configuration, aggregate
  application request summaries, and an optional detailed Billing export feed the
  view. No individual request bodies, credentials or private player rows are
  collected by the cloud reader. No new library or analytics vendor is added.
- **UC05:** meaningful SQLite/PostgreSQL, source-failure and real-browser checks,
  read-only live preflight, original failed attempts and a task-only review patch
  are retained alongside a machine-readable report.

## Resource coverage

The view covers CPU/memory utilization, service scaling ceilings and concurrency,
configured job CPU/memory, manual worker allocation, current SQL disk allocation
and any observed growth ceiling, PostgreSQL connection slots, this Studio
process's actual connection-pool bound, shared verification reservations,
telemetry intake credits, Ville's reserved per-minute read/write budgets, and
provider-published allocation/rate quota series with matching dimensions.

Limits come from the relevant source. A running worker count of one against a
manual allocation of one does **not** establish saturation; CPU, memory and queues
provide that evidence. A missing service-wide cap during a revision split stays
unknown. Per-minute rate leases represent reserved quota, not exact call counts.
The deployed API's policy must be verified during rollout; Ville's reserved
usage is shown, but its remaining rate headroom stays unknown in this version.
This avoids presenting a different Studio policy as an API limit. Local application rows are current snapshots,
not an invented hour of peak history.

Quota usage is joined to its exact provider metric, location and named window.
An allocation series without a limit name is usable only when the matching
provider limit is unique. Legacy rate counters are not compared with arbitrary
daily quotas. At most 200 quota limits are presented. Missing publication of a
quota/usage series does not mean unlimited capacity. Unconfigured resources,
tier-dependent limits and every provider limit are not exhaustively measured.
Warnings appear when the workspace is queried; this adds no continuous alarm
delivery or independent availability monitor.

## Cost interpretation

The detailed-export query filters to the configured backend project and effective
UTC calendar dates, includes credits, and keeps currencies separate. The table is
an explicit validated setting; browser parameters cannot supply SQL or a table.
Each query has a **100 MB maximum bytes billed**, 3-second initial wait, and a
500-row completeness cap. A pending, oversized or incomplete response is
unavailable. Cloud collection is cached and rate limited to one collection per
process per minute; changing dates cannot bypass that interval.

Ville's figure is a **partial API allocation estimate**. It requires fresh
signed-in request reporting covering the entire selected window, actual Ville activity, identifiable detailed-export
API resources, and verified request-based billing. Eligible API CPU, memory and
request charges are allocated by Ville's share of observed client requests.
Idle/minimum-instance, worker, database, storage and unidentified charges remain
unallocated. Different requests can consume different resources; this is not an
exact measurement of Ville's CPU or full lifetime cost. Missing/inactive/stale
activity produces no cost-per-active-player number. Billing exports lag and can
be restated; no final-invoice or production-scale forecast is invented.

Endpoint tables read only the existing `http_cost_summary` aggregate log events.
They show requests, compressed bytes and elapsed time, ordered by elapsed work.
Elapsed time includes waiting and overlaps between concurrent requests; it is
not CPU time. Periodic/unflushed summaries and window boundaries can differ from
the provider's totals. Individual success-log sampling does not sample the
all-request counters in these summaries.

## Live read-only preflight

An existing operator identity read the current API, private Studio, worker and
database configurations and Monitoring aggregates. The final recorded read also
obtained **37 endpoint/status rows** from aggregate logs with no provider errors.
The artifact's `captured_at` and individual observation times define its scope;
it is a dated snapshot, not a continuing health claim.

The recorded snapshot showed roughly **68% worker memory**, **1 / 2 API instances**,
and **4.4% of currently allocated SQL disk**, below the initial pressure thresholds.
Several Studio/quotas series were unavailable and remain unknown. An operator
metadata-only lookup found **zero detailed billing export tables in this project**.
No billing rows were queried, export created, IAM policy changed or live player
database accessed. Operator access does not prove that the deployed Studio
service identity has all the required read permissions.

## Actual validation and corrections

- Owned PostgreSQL17 fixture: **88 passed, 1 deselected**. The legacy selected
  snapshot test constructs a public-only generic auth fixture and initially
  returned404. Its **unchanged read-only/snapshot assertions** also run and pass
  through the new explicit private-admin fixture. No production access guard or
  snapshot assertion was relaxed. Shared reporting deadline, privilege,
  concurrency and erasure tests execute against the disposable PostgreSQL server.
- Final focused selection: **31 passed, 2 PostgreSQL cases deselected**; those
  PostgreSQL cases are included in the 88-pass run. Subsequent saved-location/date
  checks: **2 passed**. The additional provider-selector/job-template check passes.
- Final PostgreSQL coverage/connection/snapshot/shared-reader recheck: **20 passed**.
  The newly owned container was removed after both successful PostgreSQL runs.
- Actual Edge browser: **9 checks**, zero page errors, at1440px and390px widths.
  Checks include thresholds, Ville's denominator, manual refresh, missing sources,
  stale readings, details, navigation and removal of data on lock.
- Ruff passes for the new implementation/test tools and modified admin/configuration integrations. `app.py` retains the same task-start I001 import-order finding; its existing import order is preserved. The review patch is checked separately against captured
  pre-edit files and in reverse against the resulting workspace.

Earlier attempts remain in the evidence: ordinary float equality in an estimate
fixture, a reused browser database, a disconnected historical local PostgreSQL
configuration, the missing explicit admin fixture, and PostgreSQL's numeric SUM
returning Decimal before the integer conversion fix. The live preflight also
exposed invalid Monitoring resource-type OR selectors and omitted protobuf-zero
fields; corrected selectors and histogram handling are tested. The sandbox
could not use the operator credentials; the permitted read-only preflight ran
with the existing identity outside that restriction.

A broadened native download test reports a canonical engine error. The same test
fails with task-start copies of all touched runtime sources in an isolated
package; no workspace rollback or game changes were used. Its XML is retained.
This view is not a game/verifier repair or whole-repository test certification.

## Configuration and rollout awaiting authorization

Set these only on the existing private Studio workload, preserving its current
identity, named MFA, SQL/reporting credentials, sizing and traffic policy:

```text
BMT_STUDIO_USAGE_PROJECT=beat-my-track
BMT_STUDIO_USAGE_REGION=europe-west1
BMT_STUDIO_USAGE_RESOURCES={"services":["bmt-stg-e7a444ab-api","bmt-stg-e7a444ab-studio"],"workerPools":["bmt-stg-e7a444ab-worker"],"instances":["bmt-stg-e7a444ab-db"]}
BMT_STUDIO_USAGE_PLAYER_ID=<optional stable UUID for Ville; never commit player data>
BMT_STUDIO_USAGE_BILLING_TABLE=<project.dataset.detailed_export_table>
BMT_STUDIO_USAGE_BILLING_LOCATION=EU
```

`jobs` is another supported inventory key; the total explicit inventory is capped
at12 resources. Only add the actual job names intended for monitoring.

The existing Studio service identity needs resource metadata and Monitoring
read access, plus aggregate log read access. Review existing grants first; the
corresponding standard roles are `roles/run.viewer`, `roles/cloudsql.viewer`,
`roles/monitoring.viewer` and `roles/logging.viewer`. The BigQuery reader needs
data-view access to the selected export dataset and query-job creation in its
query project. Do not copy operator credentials into Studio.

The proposed new export destination is an **EU** dataset named
`bmt_usage_billing` in the existing project, with **detailed usage cost export**
from the existing billing account. The provider creates its export table; bind
that actual table afterward. Dataset storage and bounded query jobs can incur
charges. The runtime query remains restricted to this backend project. Dataset,
export and service-identity grants have not been created.

Before promotion, check the private image with the existing workload identity,
verify resource observations and an actual Ville binding, then check the first
arriving billing data and partial attribution labels. No schema migration or
API/worker/game rollout is required for this workspace. No APK/device attachment
check or physical-device test, production deployment, owner-process restart,
main-index staging, commit or merge was performed. Concurrent work is preserved.

## Commands and sources

```text
.tools/backend-venv/Scripts/python.exe scripts/test_studio_usage_postgres.py
.tools/backend-venv/Scripts/python.exe scripts/test_studio_usage_postgres.py --focused
.tools/backend-venv/Scripts/python.exe scripts/test_studio_usage_console.py
# From backend/:
../.tools/backend-venv/Scripts/python.exe -m pytest tests/test_studio_usage.py -m "not postgres" -q --disable-warnings
../.tools/backend-venv/Scripts/python.exe -m pytest tests/test_studio_usage.py::test_usage_view_can_be_saved_without_expanding_other_saved_routes tests/test_studio_usage.py::test_access_dates_and_assets -q --disable-warnings
# Existing operator, read-only resource/summary/metadata preview:
.tools/backend-venv/Scripts/python.exe scripts/studio_usage_cloud_preview.py --config .tools/gcp-staging/config.json --prefix bmt-stg-e7a444ab --inspect-billing --output docs/evidence/studio-usage-costs-2026-10-27/cloud-preview.json
```

Runtime sources: `studio_usage.py`, `studio_usage_cloud.py`, `admin_ui/usage.js`
and `usage.css`, with small routing/configuration/asset/saved-view integrations.
No canonical simulation or client source changes belong to this task.

Provider contracts:
[Monitoring metrics](https://docs.cloud.google.com/monitoring/api/metrics_gcp_p_z),
[Cloud Run configuration](https://docs.cloud.google.com/run/docs/reference/rest/v2/projects.locations.services),
[worker scaling](https://docs.cloud.google.com/run/docs/reference/rest/v2/projects.locations.workerPools),
[billing export](https://docs.cloud.google.com/billing/docs/how-to/export-data-bigquery),
[billing settings](https://docs.cloud.google.com/run/docs/configuring/billing-settings).
