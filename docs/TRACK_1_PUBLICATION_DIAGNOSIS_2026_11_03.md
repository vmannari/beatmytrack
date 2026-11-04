# Track#1 publication diagnosis

Follow-up: the owner authorised a backend fix. It is now deployed, and the original request published successfully with the same recording and one slot consumed. See [the repair and live acceptance report](PUBLICATION_BACKEND_FIX_2026_11_03.md). The inspection below is retained as the original diagnosis.

3 November 2026. Diagnostic inspection only.

Requirements: TPD01 identify the failed publication stage and root cause; TPD02 preserve the existing request, track, recording, account and live configuration.

Track#1 (`track_8c32864740d603a8011f7433e92fc72e`) was uploaded successfully. The API accepted publication `e1045945-cad2-46c8-8b29-d296f39b81ab` with HTTP202 at 18:58:54 UTC / 20:58:54 Helsinki. At 18:58:56 UTC the worker reached `_commit_publication`, after track validation, contract checks and creator-trajectory verification, and failed while checking whether the new track should be official.

The database log confirms the exact cause:

```text
2026-11-03 18:58:56.905 UTC db=bmt,user=bmt_worker ERROR: permission denied for table identities
SELECT identities.id FROM identities
WHERE identities.player_id = $1::VARCHAR
AND identities.provider = $2::VARCHAR AND identities.subject = $3::VARCHAR
```

The corresponding worker event is `worker_iteration_failed`, exception `ProgrammingError`, site `bmt_backend.publications:_commit_publication:367`. The worker's policy deliberately excludes authentication tables, while this publication branch still queries `Identity`. This is a backend code/privilege mismatch affecting new-track creation, not a rejected creator lap or an upload failure. Existing-track publication may skip this branch.

The exception occurs outside the verification exception handler. It rolls back publication changes but leaves the earlier committed claim in `verifying` until its lease expires. This explains the continuing successful status polls with no failure detail. The code retries claims and eventually reports generic validator unavailability if attempts are exhausted. Exact deployed lease/attempt settings were not queried.

At the final local inspection (21:03:03 Helsinki), the saved request remained `verifying` with no receipt or failure code. Its embedded track document and separate creator-proof file both remained present. Slot consumption follows the failed identity query within the publication transaction; this attempt did not reach that step. Account balances and database rows were not separately queried.

Read-only checks performed:

- Inspected the owner's matching saved workflow and proof-file existence using Python, without writing the profile or reading session-token values.
- Queried Cloud Logging with the configured Cloud CLI: API/publication events since 15:00 UTC, then worker and Cloud SQL events from 18:58:45 through 19:03:00 UTC. Cloud SQL corroborates the worker failure directly.
- Compared the failing source branch with `backend/bmt_backend/database_privileges.py` and the claim/commit transaction boundaries in `backend/bmt_backend/publications.py`.

Initial sandboxed Cloud CLI access failed because its credential database/log directory was not writable. The same read-only log query succeeded through approved escalation with the existing verified Windows CA bundle. No credential values were printed.

Changed files: this diagnostic report only. No runtime tests were needed for this read-only diagnosis; no tests are claimed as passed. No source/configuration fix, database permission change, deployment, retry, new publication, owner-save/process change, main-index write or physical-device query/test was performed.

Remaining work: correct the worker's official-track classification dependency while preserving the intended authentication-table boundary, validate new-track publication with actual PostgreSQL worker privileges, and obtain deployment authorization before applying a live fix. After correction, verify completion of this existing durable request without duplicating publication or consuming extra capacity.
