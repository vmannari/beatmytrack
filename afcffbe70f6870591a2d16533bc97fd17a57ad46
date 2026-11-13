# Usage & costs deployed to private Studio — 27 October 2026

The owner-approved Usage & costs workspace is live on the existing private Studio,
revision **bmt-stg-e7a444ab-studio-00015-gax**, with normal traffic. Open Studio
through its usual launcher/proxy, reload, sign in with the existing Google/MFA
flow and select **Usage & costs**. The invoker policy and named-staff gate remain.

Requirements: **UCD01** use the latest deployed compatibility image and isolate the
feature; **UCD02** test the exact candidate; **UCD03** connect monitoring and billing
with the existing Studio identity; **UCD04** validate live reports, private access
and a canary before promotion; **UCD05/R01/Q01** preserve other services, retain
actual attempts/evidence and state remaining acceptance boundaries.

## Release and preservation

Image:
`europe-west1-docker.pkg.dev/beat-my-track/bmt-stg-e7a444ab-images/studio@sha256:77d75aab74b345084fd50e4ab339a19917e5cd4260c2a2a5763cbd5bcc55b332`.

The parent is the current compatibility release
`backend@sha256:a0cc1c441187714e77d97bca694e64cc26b8f8e9b132d83829d15804eebb7f86`.
Only the validated feature delta is applied to its package: **seven existing
files change, four runtime files are added, and331 original files remain exact**.
The resulting342 package-file hashes are checked. The deployment-only read-only
probe is outside the runtime package and is never mounted as an HTTP route.

All **164 canonical game files** and the pinned seven-car manifest compare exactly
between parent and candidate. Physics0.75/rules23/electric18 and schema0070 remain.
The game API, single worker and all seven existing job definitions are verified
unchanged. No schema migration, player mutation, private-record/hash export,
resource resize, PC-backend change or owner-game restart belongs to this rollout.

## What is connected

The existing `bmt-stg-e7a444ab-staff` service identity now has resource/Monitoring/
aggregate-log read access and BigQuery query-job creation. Existing IAM bindings
are retained with an etag-protected policy update. Added roles are
`roles/run.viewer`, `roles/cloudsql.viewer`, `roles/monitoring.viewer`,
`roles/logging.viewer` and `roles/bigquery.jobUser`. SQL/secret authority is not
broadened. The private Studio's invoker IAM policy is unchanged.

The explicit inventory contains the API, Studio, worker, SQL instance and seven
existing jobs. It stays within the12-resource bound. Current CPU/memory, sampled
hourly peaks/bounds, scaling/concurrency, database/pool/queue and published quota
observations retain their source and freshness. Missing series, inactive jobs,
unverified per-player rate ceilings and manual-worker throughput remain unknown.

A live read-only operator job uses the exact candidate image, Studio service
identity, existing SQL/reporting credentials and Cloud SQL bindings. It confirms
the real, unique claimed **Ville** account without exporting its ID or records.
Reports retain the existing limited-reader/erasure/deadline protections. The
one-day validation window has zero observed client activity; it is correctly
ineligible for a cost-per-active-player number, rather than producing a zero-cost
claim. The ordinary workspace defaults to its selected reporting dates.

The final live probe returns **58 resource rows and45 endpoint/status rows** from
the existing aggregate request summaries. Its snapshot flags the worker:

| Resource | Latest reported observation | Interpretation |
| --- | --- | --- |
| Worker CPU | About109.8% of nominal allocation | Critical utilization indicator; provider samples can exceed nominal allocation. |
| Worker memory | About95.9% of allocation | Critical; the hourly histogram upper bound is99%. |
| Studio instance count |1 of configured maximum1 | The configured scaling ceiling is reached; CPU/memory are separate indicators. |

These are dated observations in `live-probe.json`, not an assurance about every
future frame or request. Resource settings were preserved. Unknown quota/idle-job
series are not reclassified as safe capacity. No automatic scaling or continuous
notification service is introduced.

## Billing export

The **EU** dataset `beat-my-track.bmt_usage_billing` is created with the Studio
reader and existing project-owner access. The owner completed the detailed-export
console step during this deployment. Google then added its managed
`billing-export-bigquery@system.gserviceaccount.com` writer, which is verified.
Studio is configured for that account's detailed export destination, EU location,
backend-project filter and100MB query ceiling.

At final inspection, the provider had **not yet created the first detailed export
table**. Currency totals and Ville's partial allocation therefore remain
unavailable until provider delivery. No table or billing rows were fabricated,
and the managed table was not manually created or altered. Existing cost-query
completeness, freshness, currency and attribution guards remain intact. No
provider billing rows were read during this rollout.

Google documents initial export latency and possible retroactive backfill:
[Cloud Billing export setup](https://docs.cloud.google.com/billing/docs/how-to/export-data-bigquery-setup).
When the provider table arrives, verify its identity/schema and the first totals
before using them for cost forecasts. Different request types still cost
different amounts; Ville's figure is a partial identifiable API allocation, with
worker/database/storage/idle/unidentified charges unallocated. Original global
Studio populations remain unchanged.

## Actual validation

- Exact Linux candidate plus an owned, internal-network PostgreSQL17 fixture:
  **91 passed, 1 deselected**,286 existing warnings. The legacy selected snapshot
  test uses a public-only auth fixture; its unchanged assertions run and pass
  through the explicit private-admin wrapper. No invariant/access guard is
  removed. Disposable database and network are removed after the run.
- Parent/candidate canonical comparison: **164 exact files**, matching complete
  seven-car contract. Package proof:338 original files become342, with exactly
  the reviewed seven modifications/four additions.
- Actual live reporting functions, same production identity and bounded reader:
  resource measurements, SQL slots, Ville binding and45 endpoint rows pass. This
  directly invokes read-only functions in an operator job; it mints no owner HTTP
  credential and makes no authenticated-browser data-page claim. The exact owned
  probe job is deleted after successful validation.
- Canary and final HTTP checks: health/readiness/shell/new assets/auth config200;
  missing staff credentials401; game-auth route404; anonymous IAM edge403.
  Existing Google/MFA and seven-day limited reporting policy remain.
- Fresh real Edge on the actual live private origin at1440px and390px: navigation,
  Google sign-in, absence of legacy key, required staff authentication, width and
  zero page errors pass. Invoker headers are forwarded only to that exact origin.
  No owner credentials are entered; any email hint is masked in captures.

[Live desktop shell](evidence/studio-usage-deploy-2026-10-27/live-shell-desktop.png)
and [narrow shell](evidence/studio-usage-deploy-2026-10-27/live-shell-narrow.png)
show the genuine deployed sign-in/navigation. The separate
[implementation views](STUDIO_USAGE_COSTS_2026_10_27.md) retain synthetic feature
and failure-state browser evidence. The optional local8182 proxy check timed out;
the live service is independently verified. No owner process was restarted to
address that check. Use the existing Studio launcher as usual.

## Retained attempts and operational limits

The first probe result was not immediately visible in Cloud Logging. After
ingestion it showed aggregate endpoint logs temporarily unavailable. A same-
identity, read-only diagnostic obtained HTTP200 and44 endpoint rows. Re-running
the original probe with its normal settings then returns45 rows and passes; the
runtime implementation was not changed or its source gate relaxed. The precise
cause of the first source failure is not established. Initial/diagnostic/final
receipts remain separate. A diagnostic update using an unsupported Jobs PATCH
`updateMask` was rejected400 before mutation; the documented Job update format
corrects it. Normal traffic stayed on the old Studio revision through validation.

The temporary canary tag, owned probe job and deployment lock are removed. The
new dataset and intended read grants remain. There is no APK, physical-device
attachment check/test, purchase, owner save change, main-index staging/commit/
merge, public-admin exposure or API/worker restart by this task. Final owner/MFA
workflow acceptance, real billing delivery/calibration, representative load and
the independently observed worker pressure remain operational follow-up.

## Actual commands and evidence

Entry point:

```text
.tools/backend-secure-venv/Scripts/python.exe -X utf8 build/studio-usage-deploy-2026-10-27/deploy.py <stage>
```

Stages executed: `inspect`, `build`, `test`, `connections`, `push`, `canary`,
`probe`, `probe-result`, `billing-check`, `promote`, `finish`. The completed probe
job was also used for a source-only diagnostic and an original-program recheck;
these do not add application endpoints or change its ordinary authorization.
Offline canonical comparison and
`build/studio-usage-deploy-2026-10-27/check_live_browser.py` provide the additional
image/browser receipts. Actual source programs are retained as audit copies;
private resource/environment/state files remain only in ignored build storage.

The machine-readable [report](evidence/studio-usage-deploy-2026-10-27/report.json)
records hashes, checks, limitations and the binary-inclusive task-only checkpoint.
Source changes for implementation remain covered by the original usage feature's
checkpoint; this deployment adds orchestration, receipts and current status only.
