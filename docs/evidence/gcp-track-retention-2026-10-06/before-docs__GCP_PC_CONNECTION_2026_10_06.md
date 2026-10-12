# PC app connected to Google Cloud — 2026-10-06

Requirements B01–B07/B19/B20/B23/Q01. The owner added the exact staging hostname to Avast exceptions and requested switching the app to Google Cloud. The installed Windows configuration now points to `https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app` in project `beat-my-track`, region `europe-west1`.

The real PC configuration at `%APPDATA%/Circuit01Lab/backend.cfg` was backed up privately to ignored `.tools/gcp-staging/pc-backend.before-cloud-20261006.cfg`, then replaced atomically. Its development key was removed from the cloud configuration; the backup retains the original local settings. No app CA/unsafe TLS option was installed. Existing WSL services and player data were not imported, modified or deleted. Restart the app or reopen Sign in to reload its configuration. Google is the configured provider; cloud Development sign-in remains disabled.

## Actual checks

- `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_cloud_staging.gd`, with the exact origin supplied in `BMT_STAGING_API_URL`: the pinned Windows engine passed **21 checks, zero failures**. This is the previously failing Windows TLS path, now using normal Godot trust. Health/readiness/bootstrap, discovery, private-profile rejection, Development-login rejection and Google start/prepare/pending/cancel passed.
- `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_cloud_configuration.gd`, with no `BMT_API_URL` override: **8 checks, zero failures**. The real account controller read the installed app configuration, connected over HTTPS, exposed Google, hid Development and reported no retry/connection error. This diagnostic uses no saved player-session path and creates no authenticated identity.
- Verified certificate inspection now reports **Google Trust Services / WE2**, replacing the earlier Avast issuer. Certificate and hostname validation remained enabled; the public CA export proposed in the prior turn was not applied.
- Cloud API describe confirmed Ready and the expected ownership before the switch. Actual cleanup task execution was tested in its desktop-user context with a read-only ownership/API check: result **0**, owned service verified, mutations **zero**. The action was then restored to actual expiry-guarded cleanup; its final configuration has no `--check` argument.
- After all nine owned expiry labels were renewed, API/worker remained Ready, SQL was RUNNABLE and all four compute consumers retained the original immutable digest. The real app configuration diagnostic was repeated after those metadata updates and again passed **8 checks**; these runs overlap and are not additional coverage counts.

The existing image/dataset was retained: `sha256:bec69858e2a6d2494d96a0169076f8e2f497c84f9d36e0ebb5dd02a8c0fdbca0`. No backend rebuild, contract/schema change or production rollout was performed. The added `game/tests/test_cloud_configuration.gd` is opt-in and excluded by the established `tests/*` export filter.

## Renewed test window and cleanup

The previous deadline passed overnight, but read-only inspection showed the service still running, the old watcher no longer active and the old scheduled task had never run. The renewed explicit test lease ends **October 6, 15:36:57 Helsinki / 12:36:57 UTC**. This eight-hour renewal uses the existing €40 review guard and €1/hour conservative estimate; the existing €10 project budget alert remains an alert rather than a spending cap.

The owned expiry labels and ignored/frozen cleanup configurations were renewed for the same owner and resource names. SQL CLI did not recognize `--update-labels`; its label update uses a version-fenced settings PATCH preserving existing labels. Other resource labels use their SDK update interfaces. API/worker/jobs retain their immutable image. A hidden watcher was restarted. The limited-user scheduled cleanup fallback is assigned to the actual desktop user and runs at **15:41:57 Helsinki**, with WakeToRun, StartWhenAvailable and three five-minute retries. Its successful read-only launch/authentication was proven through Task Scheduler, rather than inferred from task registration. Keep the PC on and connected through cleanup; neither local mechanism is a cloud-enforced spending cap.

## Changed files, commands and evidence

Application configuration and credential-preserving rollback are ignored private files. Ignored helpers updated: `.tools/gcp-staging/{connect-pc.py,cleanup-backup.py,renew-labels.py}` and associated lease/watch receipts. Source: `game/tests/test_cloud_configuration.gd`; documentation: this report, the prior deployment report/runbook, `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`.

Actual additional commands:

```powershell
& .tools/backend-venv/Scripts/python.exe .tools/gcp-staging/connect-pc.py
& .tools/backend-venv/Scripts/python.exe .tools/gcp-staging/start-watch.py
& .tools/backend-venv/Scripts/python.exe .tools/gcp-staging/renew-labels.py
& .tools/backend-venv/Scripts/python.exe .tools/gcp-staging/certificate-check.py
```

The exact project/region were passed to all SDK calls. `Register-ScheduledTask`, `Start-ScheduledTask`, `Get-ScheduledTaskInfo` and `Set-ScheduledTask` registered/tested/restored the limited-user task. Public receipts/logs/task settings and the scoped source/docs checkpoint are in [evidence](evidence/gcp-pc-connection-2026-10-06/README.md); passwords, old development keys and saved account credentials are excluded. The old certificate driver reused its original output path; the new observation was copied into this evidence and the exact earlier Avast observation restored to the historical evidence.

## Remaining acceptance

Real interactive Google login remains untested. If it has not already been saved, register the exact staging origin under the existing Web OAuth client's Authorized JavaScript origins in [Google Auth Platform](https://console.cloud.google.com/auth/clients?project=beat-my-track). Keep localhost origins. A successful browser handoff/Google availability flag does not prove that registration or a valid Google ID token.

This config change covers the Windows PC app. No Android export/install/device exercise was performed; phone attachment was not checked. No visible UI design changed, player data import, NAS migration, capacity measurement or production acceptance is claimed. Staging remains disposable and does not inherit WSL accounts/tracks/PBs. The backed-up local config is available for an explicit return to WSL; there is no silent network-target fallback.
