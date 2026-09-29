# Control Room: backend UI v1

Owner request: 2026-09-29, implement `temp/BMT_Backend_UI_Draft_v1`.
Requirements: **B01–B07, B18, B21, B23, B28, RW01–RW08, V03, Q01**.

## Implemented slice

The live console is served at `/admin` by the existing FastAPI service, with the
reference's dark navigation rail, light workspace, teal actions, eight sections,
responsive cards/tables, global search and explicit confirmation dialogs. The
owner-supplied `source/style.css` is the base stylesheet; layout additions and live
application code are repository-owned. No synthetic prototype records or metrics
are included. No artwork/font downloads, JS framework, analytics SDK or runtime
external dependency was introduced.

- Overview queries real account, track, submission and queue counts. Daily activity
  means **submitted attempts**, not foreground sessions or completed local races.
  Reporting windows are rolling UTC windows; account/track totals and queue are
  lifetime/current, explicitly labelled. Charts show at most 14 calendar days.
- Players: bounded name/UUID search, state filter, pagination, provider names without
  subjects, permanent resume balance and the last 20 submitted races.
- Tracks: version search, publication filters, parent visibility, ratings, hashes,
  creator/proof identities, immutable manifests and a stored-route SVG schematic.
  The schematic is not authoritative road geometry or an elevation preview.
- Races: bounded state/identity search, outcomes, verifier attempts/failure codes,
  tick/lap evidence, replay hash, pinned board/vehicle/track identity and PB status.
- Economy: real resume grant history and balance inspection. No currency grants or
  simulated provider transactions.
- Live operations: current compatibility boundary; no invented activation controls.
- Analytics: real submission counts and outcome distribution; missing client
  telemetry is explicitly unavailable.
- System: current API/database observation, paginated verification jobs, durable
  audit history and owner/analyst capability explanation.

Lists cover all time; the top reporting-window selector affects overview/analytics.
Global search spans players, track versions and races, returning up to eight matches
per domain. Lists are bounded to 100 records/request (UI: 25) with stable ordering.

## Administrative commands and access

`BMT_ADMIN_OWNER_KEY` and `BMT_ADMIN_ANALYST_KEY` are separate, minimum-32-character
credentials. Empty values disable that role. They must differ from each other and
from the development game key. Authorization is checked for every administrative
API request; a game session never implies admin access. Keys stay in tab memory,
not URLs, localStorage or sessionStorage. Reload/Lock clears access. Normal player
sessions and provider subjects are never returned by admin record projections.

Owners can restrict/restore accounts and hide/show tracks. Analysts can inspect but
cannot execute commands. Each command requires a UUID idempotency identity,
expected current state, reason and acknowledgement. State and append-only audit
entry commit together. Identical retries return the original audit result; changed
payloads/revisions conflict. Concurrent identical PostgreSQL commands are tested.
Restrictions revoke existing player session families. Restoration requires a new
login. Hiding retains immutable versions, publication state and race evidence.

Migration **0007_admin_audit** adds durable before/after, reason, role actor,
correlation ID and command identity. There is no endpoint to edit/delete audit rows.
This is application-level append-only history, not a tamper-evident external log.
Credential roles identify audit actors; individual admin SSO/MFA is not implemented.
Use HTTPS and a private administrative network for a hosted deployment. Public/NAS
production deployment was not performed.

## Local use

Run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 BackendStart`.
The existing launcher generates distinct owner/analyst keys in ignored
`.tools/bmt-pc.env`, retains them on later starts, migrates and starts the PC stack.
Open **http://127.0.0.1:18181/admin** and use `BMT_ADMIN_OWNER_KEY` from that local
file, or `BMT_ADMIN_ANALYST_KEY` for read-only inspection. Keys are not printed in
logs or copied into the game configuration. Both Compose definitions pass the
optional keys; production defaults stay disabled.

## Changed files

`backend/bmt_backend/admin.py`, `admin_models.py`, `admin_ui/*`, migration
`0007_admin_audit.py`; router/readiness registration in `app.py`, settings validation
in `config.py`, migration metadata in `migrations/env.py`, static package data in
`backend/pyproject.toml`; both deployment Compose files and `pc_development.py`;
`tests/test_admin.py`, updated schema expectation in `tests/test_auth_postgres.py`;
`deploy/capture_admin.py`; this document and the development/phase status entries.

## Verification and evidence

- `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_admin.py -q`:
  **7 passed**, including actual PostgreSQL concurrent duplicate-command handling.
- Focused initial authentication suite: **34 passed**. Admin + PC launcher checks:
  **11 passed** before adding the PostgreSQL test.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 BackendStart`:
  image built, exact Linux Godot verifier checked, migration completed and PC API
  health/readiness passed. Existing PC player records retained.
- `.tools/backend-venv/Scripts/python.exe backend/deploy/capture_admin.py`:
  **passed** against the actual PC PostgreSQL/API. Eleven routes; owner/analyst
  sign-in, search, inspection, confirmation cancel/Escape, 390px responsive layout,
  mobile navigation, lock/reload. No live player mutations are made by this capture.
- Browser-only Playwright was installed into the developer virtualenv, not server
  runtime dependencies. Initial certificate attempts failed; the existing
  `.tools/backend-ca.pem` trust bundle succeeded without disabling TLS verification.
- Initial full suite: 163 passed / 6 skipped / 12 errors / 1 failure. The disposable
  PostgreSQL container was stopped; started `bmt-backend-test`. A schema assertion
  still expected revision 0006 and was updated to 0007. A clean rerun is recorded
  below. Initial live browser test found a PostgreSQL GROUP BY bind-expression
  mismatch; shared UTC-day expression fixes it, with a PostgreSQL regression test.
- Browser checks also caught and fixed a 5px mobile overflow and inaccessible
  navigation-close path. Production CSP remains enforced during browser checks.

Screenshots from real local data:
[Overview](evidence/backend_ui/overview.png),
[Tracks](evidence/backend_ui/tracks.png),
[Track inspector](evidence/backend_ui/track_inspector.png),
[Confirmation](evidence/backend_ui/confirmation.png),
[Mobile browser width](evidence/backend_ui/mobile.png).

## Remaining acceptance and explicit boundaries

Owner visual/workflow acceptance remains. No Android export or physical-phone test
was performed; responsive browser emulation is not device acceptance. No new game
physics or handling changes belong to this slice.

The draft's broader backend services remain unimplemented: purchase verification /
recovery, currency ledger corrections, privacy export/deletion, live configuration
activation/rollback, retention/device/revenue telemetry, worker heartbeats,
backup/storage-cost monitoring, race invalidation and leaderboard rebuild commands,
job retries, individual staff SSO/MFA, CSV exports, saved views and full ghost playback.
The console does not offer fake executable controls for these services. Future
configuration and commerce services still require their own domain implementation
and approved contracts. Audit history, track visibility and account restriction
are the implemented administrative workflow, not a claim that all 30 prototype
screens are backed by production services.


### Final clean verification

Full rerun: **177 passed / 6 expected SQLite concurrency skips**, 97.87 seconds.
Command: `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests -q --tb=short`
with the existing disposable `BMT_TEST_DATABASE_URL` injected from the ignored test
configuration and its hostname set to `127.0.0.1` (avoids localhost IPv6 connection
timeouts). Output: `.tools/admin-regression.log`. The earlier cloud-client failure
also passed on this clean run. No failing assertion was disabled.

Ruff checks for the new API/models/migration/settings/test/capture files pass.
The final browser capture passes with live PostgreSQL data and enforced CSP;
overview, track inspector, confirmation and mobile captures were visually inspected.
