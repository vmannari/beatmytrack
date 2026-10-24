# Security deployment — 2026-10-24

The retained Google Cloud staging API, one worker and all five existing owned job definitions now use the SEC06/SEC07/SEC03/SEC08/SEC04 release at schema `0062_retire_discovery_cache`. API revision **bmt-stg-e7a444ab-api-00099-ret**, worker **bmt-stg-e7a444ab-worker-00040-kvd**. The existing [API](https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app) is healthy and receives 100% of traffic. Private Studio remains disabled because named staff identities and a verified MFA provider have not been configured. The PC backend and running clients remain unchanged.

The immutable image is `europe-west1-docker.pkg.dev/beat-my-track/bmt-stg-e7a444ab-images/backend@sha256:16c22624a9bf5f1995c8315fbf1554d62dc3707826ba6a9217ff0f2d65327c0e`. Frozen source SHA256 is `32239ccce29943b54f95a029f919aa75089fa561825b0f830159e1469b0d26bc`. Godot4.7.2 / compiler27 / physics0.66 / rules23 / five laps remain exact. The snapshot includes migrations0058–0062 and the tested concurrent ranking/configuration/cache-retirement changes; later concurrent schema0063/client changes are outside this artifact.

## Authority and preservation

The API and worker now have separate service accounts, database credentials and scoped secret grants. Runtime database users are nonowners. The migrator alone receives the schema-owner credential; diagnostic/operator jobs use the restricted API database credential. The former shared SQL login is `NOLOGIN`, its old service identity and secret version are disabled, and its storage/Cloud SQL access is removed. Current definitions contain no legacy administrator keys, staff subject lists or monitor credentials. Existing development/test-driver policy is retained explicitly; this is development staging, not a production-mode certification.

Public Studio/admin/monitor paths return404 before database work. Legacy Studio opt-in and temporary ad-preview resumes are explicitly false. The deployment also corrects the development API boundary: administrative routers require an explicit legacy opt-in outside production. Appearance ownership enforcement and the server-stored grandfathering migration are active. Old insecure appearance writers must not be redeployed.

Maintenance ran from **2026-10-24T11:24:16.283440+00:00** to **2026-10-24T11:38:25.077892+00:00**, about **14.1 minutes**. A database-free maintenance revision paused all application routes. Old requests drained, the worker stopped, and accepted race/publication/validation queues were empty. Managed Cloud SQL backup **1792841359801** succeeded without exporting player records. After57→62, all **314,798 original rows across132 compared tables** match their pre-migration fingerprints; no invalid indexes remain. The schema marker and two deliberately retired disposable discovery tables are excluded. Existing cosmetic grants are compared at the original cutoff; legitimate migration grants are additions. Comparisons precede ordinary worker projections/retention.

## Verification

- Working-source authority selection: **70 passed**. Exact frozen image with disposable PostgreSQL17: **258 passed,1 skipped,12 deselected**. These are focused gates, not a full-suite claim.
- Synthetic-only57→62 rehearsal: **131 tables /103,328 original rows exact**, no real player records copied. Measured1.557s is a local rehearsal, not cloud latency/capacity evidence.
- Actual live native replay/schema/GCS smoke: **passed**,12,757 canonical ticks, two temporary diagnostic objects, zero player writes.
- One matching live worker, empty queue and all **16 discovery partitions ready** before public traffic reopened. Public discovery traverses **30 tracks**, with no duplicate IDs.
- Live production-strength API role validation passes even though staging runs development mode. Worker cannot read session tokens/staff or rewrite/delete administrative audit records; API cannot read staff; Studio role cannot read session tokens. Preview resumes/legacy Studio keys are false.
- All seven target images match, existing resource/process settings and worker count are preserved, temporary traffic tags are removed and the owned deployment lock is released. PC container images/configuration/start times remain exact.

Initial failures and corrections are retained in [the machine-readable report](evidence/security-deploy-2026-10-24/report.json): disposable PostgreSQL startup retry, receipt merge, gcloud flags-file spelling, a correctly denied application-role read of the protected staging guard, shell quoting and the initial missing exact-secret grant for retained staging test drivers. None required weakening the runtime database grants or exposing Studio.

## PC approval and remaining acceptance

Automatic approval review rejected the proposed PC database backup copy before execution because the sensitive player records, identities/token hashes and destination were not specifically authorized by “deploy.” The pending request names `C:\Codes\Godot\Beat my track\build\security-deploy-2026-10-24\pc-backup`. No PC backup was copied, no alternative real-data rehearsal bypassed that rejection, and PC containers/data were not changed. Explicit backup approval is required before the PC rollout can continue.

Client restart/install and owner/device acceptance remain. No phone/tablet attachment check, physical-device test, APK/export/install, real provider sign-in, purchase, population execution or reporting replica was performed. Studio activation needs named staff/provider/MFA acceptance; broad reporting retains its separate replica/cost gate. Load/edge calibration and restore exercises remain operational acceptance. Concurrent work and owner processes are preserved; no mixed-tree commit is created.

Operational scripts are private ignored `.tools/`; code-only audit copies, exact image/package hashes, logs and aggregate receipts are in [the evidence folder](evidence/security-deploy-2026-10-24/). Credentials, environment files and raw resource metadata remain in ignored private build storage. Actual entry point:

```text
.tools/backend-secure-venv/Scripts/python.exe -X utf8 .tools/security_deploy_20261024.py <stage>
```

Executed stages: `inspect, freeze, build, preflight, test, plan, provision, push, maintenance, runtime-files, operator-access, transport-check, synthetic-rehearse, quiesce, stop-worker, cutover-data, test-secret-access, canary, promote, smoke, authority, discovery, retire, finish`. The proposed real-PC `rehearse` command was rejected before execution; `synthetic-rehearse` uses invented data and aggregate cardinalities only. The dated [source-fix report](SECURITY_FIXES_2026_10_24.md) describes the implementation and prior tests; [the23October release](LATEST_BACKEND_DEPLOY_2026_10_23.md) remains the PC deployment receipt.
