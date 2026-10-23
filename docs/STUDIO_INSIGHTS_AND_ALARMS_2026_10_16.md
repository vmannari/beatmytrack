# Studio insights and alarm desk, 2026-10-16

Approved follow-up: both earlier approval requests are resolved. The27 matching
catalog revisions and scoped ordinary-payload deletion permission are live;
compiler27/physics0.59 is active. See
[completed follow-up](BACKEND_APPROVED_FOLLOWUP_2026_10_16.md) for preservation and
verification evidence. This supersedes the pending-approval status in the initial
deployment record below.

Deployment follow-up: this implementation is now live on the retained staging
service. [Deployment evidence](BACKEND_LATEST_DEPLOY_2026_10_16.md) records the
exact frozen image, schema36 migration, live browser checks and preserved data.
The local-only statements below describe the initial implementation checkpoint.
The existing racing contract remains active while separate catalog and runtime
deletion-permission approvals remain pending after automatic review rejected
those two proposed mutations. Neither rejected action executed.

The owner requests clearer backend information, direct insights, guidance to the
right evidence, and an explicit view for reacting to and clearing issues. This
local implementation replaces the default Studio pulse with a decision-led
Overview and adds an authenticated Alarms workspace.

Requirements for this slice:

- **BUI01**: lead with the current situation, prioritised issues and relevant metrics.
- **BUI02**: explain findings and link each investigation to its source evidence.
- **BUI03**: provide a searchable alarm queue with severity, area and state filters.
- **BUI04**: share durable, audited acknowledgement and recovery closure between admins.
- **BUI05**: preserve permissions, request fences and usable desktop/narrow layouts.

## Visible behaviour

The Overview starts with a current status statement, highest-priority issues and
the alarm-desk action. Scoped findings identify the largest observed first-race
cohort loss, mature exact-D7 return and retained failed publications when those
sources exist. The first-race finding is descriptive; it does not infer a cause.
Verified terminal outcomes use verified / (verified + rejected + failed), with
the denominator shown. Queued attempts do not inflate that denominator.

Task links guide users to player support, client quality, publication processing
and competition provenance. Activity, source watermarks and population stay
visible. Unavailable sources and immature cohorts are not rendered as zeros or
healthy-service claims. The navigation groups starting points, understanding,
investigation and management; publication processing is directly discoverable.

The alarm queue separates Needs attention, Acknowledged, Ready to clear, Cleared
and All. Critical active conditions remain above warnings after acknowledgement.
Each selected issue explains impact, current evidence and the next action.
The detail stays below the desktop toolbar when scrolling and precedes the
queue on narrow layouts. Resetting issue filters retains the reporting dates.

An owner can acknowledge an active condition with an investigation note. An
acknowledged fault stays active. Once the check recovers, the owner can record
what was fixed and clear it. The backend rechecks immediately before closure;
an active or unavailable condition rejects the decision. A recurrence after
closure returns to Needs action. Escalation from acknowledged warning to critical
also requires renewed attention. Analysts inspect the same shared state without
write controls or write permission. Reasons are escaped and common pasted
credential formats are rejected by the existing case-text guard.

## Checks and state contract

Eight fixed metadata checks run on request. These review defaults are operational
thresholds, not owner-accepted SLOs:

| Check | Condition |
| --- | --- |
| Worker availability | No compatible available verifier; critical when work is pending, warning otherwise |
| Queue delay | Oldest pending work at least 120 s; critical at 600 s |
| Queue capacity | Current depth reaches configured capacity |
| Race verification failures | Any infrastructure failure completed in the last five minutes; rejected proofs are separate |
| Publication failures | Any failed explicit request completed in the last five minutes; capped count of 5,000 |
| Local object capacity | Below 5 GiB free; critical below 1 GiB; remote free space is not inferred |
| Backup marker | An explicitly configured completion marker is missing or unreadable; no restore-success inference |
| Reporting delay | Oldest unprocessed receipt at least 300 s old; critical at 1,800 s |

`GET /v1/admin/alarms` returns current conditions plus previously actioned state,
observation time, available-check count and scope. Reads create no alarm state.
`GET /v1/admin/alarms/{key}` adds the latest 25 decisions, with an explicit
history-truncation flag. Existing Audit history retains earlier decisions.
`POST /v1/admin/alarms/{key}/actions` accepts a UUID `command_id`, nonnegative
`expected_revision`, `acknowledge|clear` action and an 8–500-character reason.
Retries are idempotent; changed revisions or reused command IDs return 409.

The existing `OperationState` store holds at most eight `admin-alarm:` rows;
the existing append-only `AdminAudit` records decisions. A per-signal transaction
lock serialises first creation and later decisions on PostgreSQL; SQLite uses
the existing immediate-write lock. The unique audit command constraint also
fences simultaneous reuse across different alarm keys. No migration is required.
Health observation can reuse the action's database session, avoiding a nested
pool checkout while holding the decision lock. No proof blobs are read or races
replayed by the new publication/reporting projections.

This is **on-demand checking**. There is no background detector, notification
delivery or complete incident-occurrence ledger. Only decisions are persisted;
unacknowledged conditions that recover and faults entirely between checks are
not retained as incidents. Remote storage capacity, unconfigured backups,
crash-free rates, provider revenue and individual staff SSO remain separate
coverage gaps. Broader retained publication failures remain a review queue,
not a permanently firing five-minute alarm.

## Changed files

- Runtime: `studio_alarms.py`, router registration in `app.py`, asset allowlist in
  `admin.py`, optional session reuse in `operations.py`.
- UI: `admin_ui/insights.js`, `insights.css`, `index.html`, and navigation/routing
  in `app.js`.
- Verification: `test_studio_alarms.py`, `test_studio_insights_views.js`,
  `test_studio_insights_console.py`, `test_studio_insights_postgres.py`.
- This report, the backend UI guide, project/status/phase notes and the task-only
  evidence/checkpoint. Concurrent community-safety/backend and game/track edits
  are excluded. The shared `app.py` checkpoint baseline removes only this
  task's two router lines from the final file, preserving the parallel router
  work on both sides of the patch. The unrelated support-case UI edit is excluded.

## Actual verification

Commands run from the repository root, using `.tools/backend-venv/Scripts/python.exe`
and the existing Playwright Node executable:

| Command | Actual result |
| --- | --- |
| `python scripts/test_studio_insights_postgres.py` | **57 passed**, 60.62 s; SQLite plus disposable PostgreSQL17, including 13 new alarm scenarios on both databases, original Studio/admin/case tests and concurrency checks. The labelled owned container was removed. [Log](evidence/studio-insights-2026-10-16/postgres.log). |
| `python -m pytest backend/tests/test_studio_alarms.py backend/tests/test_studio.py backend/tests/test_studio_operations.py backend/tests/test_admin.py -q -m 'not postgres' --disable-warnings --tb=short --junitxml=docs/evidence/studio-insights-2026-10-16/api.xml` | **42 passed, 2 deselected**, 42.34 s in the recorded local run. This overlaps the broader database run; the counts are not additive. [Receipt](evidence/studio-insights-2026-10-16/api.xml). |
| `python -m pytest backend/tests/test_review_reliability.py backend/tests/test_review_followups.py backend/tests/test_worker_lifecycle.py -q -k 'health and not postgres' --disable-warnings --tb=short --junitxml=docs/evidence/studio-insights-2026-10-16/health-regression.xml` | **8 passed, 126 deselected**, 4.22 s; existing health-contract checks. [Receipt](evidence/studio-insights-2026-10-16/health-regression.xml). |
| `python scripts/test_studio_insights_console.py` | **11 browser checks, zero JavaScript exceptions**, real Edge against newly owned loopback SQLite. Cross-tab state, analyst permissions, recovery/clear/reload/recurrence, escaped evidence, source loss during closure, filtering, 390/1024 containment and sticky desktop detail pass. [Receipt](evidence/studio-insights-2026-10-16/browser.json). |
| `python -m pytest backend/tests/test_studio_alarms.py -q -k 'not postgres' --disable-warnings --tb=short --junitxml=docs/evidence/studio-insights-2026-10-16/final-integration.xml` | Final shared-workspace integration: **13 passed, 13 deselected**, 13.49 s, with the concurrently added backend router retained. The browser suite was also rerun successfully in that combined workspace. This overlaps the earlier suite. |
| `node scripts/test_studio_insights_views.js` | **4 presentation checks**: scoped denominators/findings, immature/missing sources, cancellation/escaping and critical priority. |
| Ruff on changed Python; Node syntax on new/changed JS; scoped whitespace and reverse task-patch application | Passed; [static receipt](evidence/studio-insights-2026-10-16/static.json) and [checkpoint](evidence/studio-insights-2026-10-16/checkpoint.json). |

Initial attempts are retained as limitations of the actual process: the browser
fixture first tried inserting a product-state row already created by migrations;
the fixture was corrected to update that row. Initial lint caught a reused
session argument and later an obsolete fixture suppression; both were corrected.
An initial broad health selection included unmarked PostgreSQL parametrisations
that used the old unavailable local configuration; that run was interrupted.
The final health-only SQLite selection and separately owned PostgreSQL suite
above passed. The first sandboxed WSL availability check was denied by the OS;
the approved local test runner then succeeded. No assertion was weakened.
The existing Starlette/httpx deprecation warning remains.

## Visual review and remaining acceptance

These captures contain **seeded local fixture data**, not production incidents
or actual client measurements. Worker-health scenarios and prepared activity
were explicitly seeded; production monitoring has not been exercised.

- [Previous overview](evidence/studio-insights-2026-10-16/overview-before-1440.png)
- [New overview](evidence/studio-insights-2026-10-16/overview-after-1440.png)
- [Active alarm desk](evidence/studio-insights-2026-10-16/alarms-active-1440.png)
- [Recovered issue](evidence/studio-insights-2026-10-16/alarm-recovered-1440.png)
- [Cleared history](evidence/studio-insights-2026-10-16/alarms-cleared-1440.png)
- [Recovered overview](evidence/studio-insights-2026-10-16/overview-healthy-1440.png)
- [Narrow alarm desk](evidence/studio-insights-2026-10-16/alarms-after-390.png)
- [Narrow overview](evidence/studio-insights-2026-10-16/overview-after-390.png)

Owner review of information hierarchy, guidance and review thresholds remains.
No deployment, migration, production write, provider integration, gameplay
change, Android build/install or physical-phone test occurred. Phone attachment
was not checked. Deployment requires the owner's explicit authorisation.
