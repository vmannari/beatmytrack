# Applied Google staging evidence

See [requirements, changes, commands, actual outcomes and acceptance](../../BACKEND_GCP_DEPLOYMENT_2026_10_05.md).

- `deployment.json`, `cloud-status.json`, `http-smoke.json`: actual service/image/conditions and cloud HTTP proof. Provider environment flags named production select secure behavior; this is disposable staging.
- `worker-health.json`: actual matching worker build, fresh heartbeat and empty queue from the restricted app-role diagnostic.
- `first-environment-cleanup.json`: successful deletion of the previous owned environment's 12 resources.
- `pricing-review.json`, `plan.json`: current EUR SKU review and prepared plan. Budget alerts and local lease checks are not provider spending caps.
- `certificate.json`, `proposed-debug-ca.json`: verified local TLS issuer and exported public-root metadata; game trust remains unapplied pending owner approval.
- `cleanup-task.json`: actual limited-user fallback settings/deadline; the main Python watcher was confirmed running. `linux-client.log`, `native-recovery.log` and `windows-client-tls-failure.log` retain the observed native outcomes.
- XML: `staging-cli.xml` 22 pass, `cloud-paths.xml` retained 40 pass/one liveness failure, `cloud-paths-final.xml` 41 pass, `staging-final.xml` 24 pass, `auth-regression.xml` 44 pass, `storage-setup-regression.xml` 20 pass/six explicitly unavailable local integrations. Batches overlap.
- `before-*`: task baselines, including earlier concurrent work. `scoped-change.patch` and source hashes capture only this deployment slice; no broad staging of the shared dirty tree.

No passwords, billing account IDs, service-account key files, game refresh/access credentials or private player data belong in this evidence. Ignored operator receipts retain private account/budget details. The cloud smoke used attached ADC and actual private GCS/Cloud SQL; the Windows client TLS attempt failed, while the corrected Linux game client passed 21 checks with standard trust. Real interactive Google/Windows/device acceptance remains explicitly pending.
