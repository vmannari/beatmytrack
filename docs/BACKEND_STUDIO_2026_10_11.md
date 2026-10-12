# Backend Studio inventory and first evidence slice, 2026-10-11

The new Studio specification is reconciled against the existing backend instead
of replacing the working support console. All 92 workbook requirements have an
evidence map. The first additive implementation connects player activity to the
exact submitted race, its pinned track/car/rules, accepted timing, authorized
resume receipts and a redacted JSON evidence bundle. The Studio shell adds a
coverage workspace identifying the services and observations still absent.

Requirements addressed in this bounded slice: **BMT-001, BMT-003, BMT-006,
BMT-019, BMT-020, BMT-030, BMT-034, BMT-050, BMT-051, BMT-052, BMT-081,
BMT-085, BMT-097, BMT-100, BMT-101, BMT-102, BMT-103 and BMT-104**. Broad
requirements remain Partial where additional domains or acceptance are missing;
this is not completion of the whole 92-row platform.

## Requirements and resolved policies

The [readable inventory](BACKEND_STUDIO_REQUIREMENTS_2026_10_11.md) and
[complete evidence map](backend-studio-requirements-2026-10-11.json) preserve exact
workbook IDs, priorities, source wording and criteria, with code/endpoint
evidence, proposed ownership, migration risk and remaining acceptance for each
row. The original four supplied files are unchanged. Their hashes are recorded
in the JSON. The referenced `contracts/`, `qa/` and `IMPLEMENTATION_PROMPT.md`
are absent from the supplied directory. No claim about their schemas or tests is
adopted as implementation evidence.

The three policy questions raised during the initial inventory were resolved by
the owner on 2026-10-11. **BMT-014:** all Studio totals include all players,
including artificial drivers; an admin-only Real/Artificial flag uses the server's
`Player.is_test_driver`, and development authentication does not imply Artificial.
**BMT-045:** each account receives one INITIAL free publishing slot; monthly
rewards are a possible later idea, without authorization to implement.
**BMT-046:** one month means a UTC calendar month on the matching day
(September 12 → October 12), with the existing short-month clamping and
active-expiry extension. None of these three choices remains pending. Existing
consumed-slot evidence, resume rules and five product prices are retained.
The [policy follow-up](BACKEND_STUDIO_POLICIES_2026_10_11.md) records flag and
calendar/initial-allowance tests; the exact supplied workbook remains unchanged,
with explicit owner overrides recorded separately in the evidence map.

Behavioural sessions, retention, onboarding/exposure funnels, device diagnostics,
verified provider revenue, remote configuration, experiments, privacy cases and
individual staff identity require new data or services. Submission records cannot
reconstruct missing foreground activity or historical impressions. Those future
features need separately bounded domain/instrumentation slices; this work adds
no vendor dependency or speculative live values.

## Implemented behaviour and boundaries

`/admin` retains its same-origin deployment, in-memory owner/analyst credentials,
support and commerce controls, global search, date windows and existing hashes.
Navigation groups available workflows under Learn, Operate and Control.
`#studio` shows actual source coverage; `#races/{run_id}` opens the new inspector.
Player activity, the inspector and exact track-version links preserve supported
UTC scope. Charts include a keyboard-accessible daily evidence table.

New read-only routes:

- `GET /v1/admin/studio/capabilities`: implementation coverage and missing-source
  explanations, actual configured environment and authenticated role. It does
  not claim to probe provider health or complete a missing feature.
- `GET /v1/admin/studio/races/{run_id}`: versioned evidence from one coherent
  database snapshot; `download=true` returns an attachment. Both roles can read;
  game credentials cannot. No mutation verb exists for these routes.

The race bundle includes redacted run/player/ticket IDs, the original immutable
track/version/content hash, board/car identity, known scalar pinned manifest
fields, accepted-only ticks/laps, current PB membership, lifecycle timestamps,
up to 100 linked resume receipts, observation time, coverage and SHA-256 checksum.
The checksum is canonical JSON over all fields except `checksum`, using the
existing `digest` function. It detects changed bytes; it is not a signature or
tamper-proof audit. Every request produces its own observed snapshot, not a
persisted global analytics snapshot.

PostgreSQL uses a READ ONLY / REPEATABLE READ transaction. SQLite explicitly
begins its read snapshot. Inspection does not fetch blobs, invoke the verifier,
initialize wallets/access or change game records. Provider subjects, session
credentials, worker leases and arbitrary manifest metadata are excluded.

Seconds are derived only from a valid pinned `tick_rate`. Missing/invalid rates
remain unavailable; live defaults are never substituted. Unverified submissions
do not expose provisional ticks as accepted results. Ticket issuance is not a
recorded client race start; `Run.finished_at` is identified as terminal server
verification time, not the driving finish. PB membership means current pinned
PB, not necessarily a historical improvement at submission time.

Per-attempt validator history, request trace correlation, client sessions,
build/device/ABI diagnostics and remote-config exposure are not persisted for
these runs. The download therefore remains an evidence bundle with missing
reproduction context. It is not a complete verified reproduction/full replay.
Downloaded local copies have no enforced expiry. Full canonical replay remains
an explicitly invoked offline diagnostic and never an automatic race-acceptance
fallback. Five ordinary laps, trajectory acceptance, normal results first,
best-only scoring and public/artificial isolation remain untouched.

Obsolete read requests are canceled on navigation/Lock, and page/auth/dialog
generations fence late responses. Support previews, exports and command
callbacks cannot reopen or change a subsequent dialog after Lock/navigation.
Mutation retry UUIDs and payloads remain stable. A 401 clears credentials,
sensitive caches and pending dialogs. Native dialog close/Escape restores focus;
loading, error, restricted-access and Retry states carry readable labels.

## Files

- Runtime: `backend/bmt_backend/studio.py`; router registration in `app.py` and
  asset allowlist in `admin.py`.
- UI: `backend/bmt_backend/admin_ui/{index.html,app.js,style.css,studio.js}`;
  minimal callback guards/scope preservation in `support.js` and `commerce.js`.
- Verification: `backend/tests/test_studio.py`,
  `scripts/test_backend_studio_console.py`,
  `scripts/test_backend_studio_postgres.py`; optional `--output` argument in the
  existing `scripts/test_admin_support_console.py` preserves historical evidence.
- Documentation: this report, the two inventory files, `BACKEND_UI.md`,
  `DEVELOPMENT_STATUS.md`, `PHASE_0_PLAN.md` and the dated evidence directory.

No database migration, game implementation, engine/template, provider SDK,
shipping product, remote environment or actual player data changed. Existing
unrelated dirty files were preserved; the review checkpoint is based on snapshots
taken before this task's edits rather than the repository's older HEAD.

## Actual verification

| Command/check | Actual outcome |
|---|---|
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_admin.py backend/tests/test_admin_support.py backend/tests/test_store_admin.py -q -m 'not postgres' -k 'not postgres'` | Baseline: **27 passed, 2 skipped, 23 deselected**, 15.58s. PostgreSQL selection was explicitly excluded after the pre-existing configured database was unavailable. |
| `.tools/backend-venv/Scripts/python.exe scripts/test_backend_studio_postgres.py` | **66 passed, 2 skipped**, 40.58s, across SQLite plus one newly owned PostgreSQL17 container. All 16 new Studio cases pass, including actual PG read-only/repeatable-read state coherence when a worker commits acceptance/PB between inspector queries. Both skips are duplicate SQLite row-lock cases; their PG counterparts run. Ownership label checked; only the owned container removed. [Log](evidence/backend-studio-2026-10-11/postgres.log). |
| `.tools/backend-venv/Scripts/python.exe scripts/test_backend_studio_console.py` | Final **11 browser checks, zero failures/JavaScript exceptions** against a newly owned loopback SQLite fixture in installed Edge. Tests exact player/race/version linkage, accepted pinned time, redacted download, 1440/960/390px containment, coverage, focus return, late canceled responses, Lock during pending support preview, analyst controls and error/Retry. [Receipt](evidence/backend-studio-2026-10-11/browser-receipt.json). |
| `.tools/backend-venv/Scripts/python.exe scripts/test_admin_support_console.py --output docs/evidence/backend-studio-2026-10-11/support-regression` | **10 inherited browser workflow checks, zero failures**: pending purchase/approval/retry, simulated slot/access/expiry/reset, pagination/export, 90-day reporting, missing capacity, analyst controls and responsive containment. Fixture server stopped. A parallel duplicate agent run covered the same checks and is not added to the count. |
| `.tools/backend-venv/Scripts/python.exe -m ruff check --config backend/pyproject.toml backend/bmt_backend/studio.py backend/bmt_backend/admin.py backend/bmt_backend/app.py backend/tests/test_studio.py scripts/test_backend_studio_console.py scripts/test_backend_studio_postgres.py scripts/test_admin_support_console.py` | Passed. Two tooling-only import-order differences under the explicit backend configuration were corrected. Python compile checks pass. |
| `.tools/backend-venv/Lib/site-packages/playwright/driver/node.exe --check` for `app.js`, `studio.js`, `support.js`, `commerce.js` | All four passed. |
| Scoped `git diff --check`; task patch reverse applicability; workbook/source/path inventory checks | Passed; source wording and all four supplied hashes unchanged. Review checkpoint contains only this task's baseline-to-final edits. |

New backend tests also cover absent/game credentials, invalid UUIDs, unavailable
links, cross-account corrupted ticket links, accepted-only timing, no live rate
fallback, secret redaction, bounded history, no object/verifier reads, checksum
integrity and no hidden resource creation. Browser fixtures seed illustrative
five-lap records; they do not claim those races were driven/canonically verified.
One existing Starlette/httpx deprecation warning remains.

Initial unrestricted baseline selection attempted the unavailable configured
PostgreSQL fixture; it was not accepted as a passing run. Read-only sandbox WSL
inspection was denied; the authorized local test adapter subsequently ran with
the approved sandbox override. An early browser attempt caught an interim nav
attribute mismatch while files were being edited; the final nav builder fixes
it. Initial screenshots caught a download-button/viewport transition; final
captures wait for enabled controls and settled navigation and scroll to the top.
No invariant or acceptance assertion was removed to obtain the final results.

## Evidence and remaining acceptance

Final captures inspected: [desktop race](evidence/backend-studio-2026-10-11/race-1440.png),
[compact race](evidence/backend-studio-2026-10-11/race-960.png),
[narrow race](evidence/backend-studio-2026-10-11/race-390.png),
[coverage](evidence/backend-studio-2026-10-11/coverage-1440.png), and preserved
[support regression](evidence/backend-studio-2026-10-11/support-regression/player-1440.png).
The [example redacted bundle](evidence/backend-studio-2026-10-11/race-evidence-fixture.json)
contains only newly seeded local fixture records, never real player data.

Review patch and file hashes are retained under
`docs/evidence/backend-studio-2026-10-11/checkpoint/`. No merge or deployment is
performed. Live asset/data parity, production read/privacy/access policy,
individually identified staff, provider configuration, larger-data query budgets,
the remaining workbook criteria and broader future-feature decisions remain open.
The owner choices for all-player Studio totals, the initial-only free slot and
matching-day calendar-month duration are resolved; the policy follow-up records
the admin player flag and final local regression evidence.
Exact 1280x800/1440x900/200% browser-zoom acceptance remains separate from the
three recorded width checks. No phone attachment check, physical-device test,
Android export/install or full game regression was performed; this task changes
the backend console only. Deployment requires explicit owner authorization.


## Authorized Studio staging deployment, 2026-10-11

The owner subsequently authorized deployment. The reviewed nine-file Studio overlay is now live on the existing retained staging service, with fresh backup, zero-traffic canary, unchanged schema/game/commerce and preserved configuration. Exact-image47 tests and live API/asset/flag/browser/native-worker checks passed. Earlier no-deployment statements describe their original local tasks. See [the actual deployment report](BACKEND_STUDIO_DEPLOY_2026_10_11.md) for commands, evidence, image/revision and remaining boundaries.
