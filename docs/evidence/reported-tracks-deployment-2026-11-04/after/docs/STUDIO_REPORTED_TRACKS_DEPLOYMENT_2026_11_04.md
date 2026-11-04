# Reported tracks deployed to Studio

4 November 2026. STRD01 deploys the owner's explicitly approved [reported-track view and deletion controls](STUDIO_REPORTED_TRACKS_2026_11_04.md). STRD02 verifies availability, private access and preservation without deleting or seeding any live track/report.

The existing private `bmt-stg-e7a444ab-studio` service now serves revision **bmt-stg-e7a444ab-studio-00038-xat**, using immutable image `backend@sha256:cebd7f7b8a5653513632d0880c0f61905c490dd9c6d076f3070af179789e9fad`. Refresh the existing Studio browser tab and choose **Reported tracks**.

The image overlays only the ten reviewed runtime files on the exact previous Studio image, `backend@sha256:e4caf9d0ac2887c9bb75253da2a9563fa6b46a7ff1d4120900c7f5e0d99a55bf`. The configured OCI index was checked against its actual serving platform-manifest digest before building. Reviewed workspace hashes match the frozen image sources. Existing credentials, IAM boundary, workload role, resource limits, environment settings and probes were preserved.

Only private Studio was updated. The public game API, worker, jobs and website preview retain their previous images and routes. Existing public quarantine enforcement already removes explicitly deleted tracks from public access, so this feature requires no public API/client change, schema migration or new database grant. Main backend release receipts remain intact; a separate `studio-reported-tracks.json` receipt records this Studio image.

The final deployment image passed **30 tests, 8 deselected**, including grouped report reads, state/revision fences, owner-only idempotent deletion, old archived-link compatibility, historical-result preservation, retained catalogue/community/race admission, and actual PostgreSQL17 restricted Studio-role/named MFA fixture operations. PostgreSQL testing used a labelled task-owned local container/network, removed after the run. Earlier implementation browser acceptance remains **9 checks** with seven reviewed captures; no UI source changed during deployment.

Before promotion, the private canary passed health/readiness checks, served the exact new JavaScript assets, and exposed the reported-track endpoint only behind application staff authentication. An IAM-authenticated request without a staff token receives401/403; the public game API returns404 for that administrative endpoint. The main Studio HTML references the new script. After promotion the same checks passed on the normal Studio URL. Temporary canary tagging and the owned deployment lock were removed.

Actual live report queries ran inside **read-only database transactions** using the frozen read implementation; they exported aggregate counts only, without names, report texts or player identifiers. They currently find **zero eligible reported tracks**. Therefore no live detail sample was available; detail reads and deletion behavior were verified against owned fixtures, including the exact deployed image. No fake live report or live delete command was sent. Readiness performs its existing operational probes; this is not a claim of zero operational housekeeping writes.

Before/after aggregate snapshots match exactly:

| Retained data | Before | After |
| --- | ---: | ---: |
| Tracks | 41 | 41 |
| Track versions | 435 | 435 |
| Runs | 20561 | 20561 |
| Personal bests | 7362 | 7362 |
| Lap personal bests | 7365 | 7365 |
| Support cases | 24 | 24 |
| Case events | 24 | 24 |
| Quarantines | 0 | 0 |
| Hidden tracks | 0 | 0 |
| Archived tracks | 5 | 5 |
| Track deletion decisions | 0 | 0 |

Schema remains **0073_publication_publisher_check**, and the complete competitive manifest compares exactly with its pre-deployment value. These are aggregate preservation checks, not an export or byte-level comparison of private historical rows. No migration, result rescore/reset, publication retry or actual track deletion occurred in this deployment.

Actual commands, using `.tools/backend-secure-venv/Scripts/python.exe` from the repository root:

```text
build/reported-tracks-deploy-2026-11-04/deploy.py inspect
build/reported-tracks-deploy-2026-11-04/deploy.py prepare
build/reported-tracks-deploy-2026-11-04/deploy.py build
build/reported-tracks-deploy-2026-11-04/deploy.py test
build/reported-tracks-deploy-2026-11-04/deploy.py push
build/reported-tracks-deploy-2026-11-04/deploy.py rollout
build/reported-tracks-deploy-2026-11-04/deploy.py verify
```

The initial inspection's exact image-reference comparison stopped on OCI index/platform-manifest differences. Verification of index membership established that both references describe the same serving build; no source or data gate was weakened. Docker retains its default-ARG lint warning despite the explicitly pinned build argument. Existing test deprecation/reflection/isolated-marker warnings remain. Cloud CLI/WSL access used approved escalation and the existing verified CA bundle; short-lived credentials were kept out of logs and output.

The [deployment evidence directory](evidence/reported-tracks-deployment-2026-11-04/) retains frozen source hashes, exact-image JUnit/logs, sanitized read-only snapshots and acceptance receipt, rollout source and documentation checkpoint. Private resource dumps, credential configuration and raw cloud-command logs stay in the ignored build directory.

Deployment is complete. Refresh and real owner staff/UI acceptance remain; no real provider sign-in, live destructive test, physical-device query/test, APK/export, local owner-save/process change, PC-backend replacement or main-index write was performed. Concurrent work was preserved.
