# Studio population and entitlement decisions, 2026-10-11

The owner resolved all three choices from the new Studio specification. Studio
counts include everyone, including artificial drivers. Administrative player
records expose their stored real/artificial flag. Accounts receive one initial
free publishing slot; monthly rewards are a possible future decision. Ad-free
months are calendar months: a purchase on September 12 expires on October 12
at the same time, rather than after a fixed 30-day duration.

Requirements: **BMT-014, BMT-045, BMT-046, BMT-050, BMT-051, BMT-052,
BMT-100, BMT-104; PUR01, PUR04, PUR05; Q01**. These owner-approved decisions
supersede the supplied workbook's population/monthly-slot/30-day proposals. The
original workbook wording and four supplied artifact hashes are preserved in
the [requirements map](backend-studio-requirements-2026-10-11.json). Its decision
register and [readable inventory](BACKEND_STUDIO_REQUIREMENTS_2026_10_11.md) now
record the resolutions; no answer remains pending among these three choices.

## Implemented data and presentation

`Player.is_test_driver` already exists in the database. It is now included in
the authenticated administrative player list, entity detail, support projection
and Studio race evidence bundle. The Players table has a **Player type** column;
the support profile shows **Real** or **Artificial**. Missing/nonboolean data is
shown as Unavailable, not assumed real. Development authentication alone does
not imply that a player is artificial: the stored server classification is the
authority. No new column or migration is required.

Administrative totals, queries and population remain inclusive. No population
switch or automatic exclusion was added. These administrative decisions do not
alter public competition, ratings or eligibility isolation, and no classification
label is added to the game screens. Existing support command/idempotency and
race snapshot contracts remain intact.

The commerce runtime already implements the confirmed policies and is unchanged.
The initial slot is not refilled when a month changes. A monthly ad-free purchase
extends from the later of the approval time or existing expiry, preserves the
UTC time of day and clamps only when the target month lacks the starting day
(January 31 becomes February 28, or February 29 in a leap year). Another purchase
during active access extends the existing expiry by another calendar month.
Existing permanent access, rewarded-resume treatment, banked/daily resumes and
approved products/prices remain unchanged. Possible future monthly rewards do
not authorize a recurring grant today.

## Changed files

- `backend/bmt_backend/admin.py`: additive administrative player boolean.
- `backend/bmt_backend/studio.py`: same boolean in redacted race player data.
- `backend/bmt_backend/admin_ui/{app.js,support.js}`: Players column and profile.
- `backend/tests/{test_admin.py,test_admin_support.py,test_studio.py}`: actual
  classifications, inclusive counts and preservation of read-only projections.
- `backend/tests/test_commerce.py`: owner date example, preserved UTC time,
  active-access extension and consumed-slot retention across future months.
- `scripts/test_backend_studio_console.py`: real/development and artificial
  fixture records, totals/flag/profile/export checks and new captures.
- `scripts/test_backend_studio_postgres.py`: optional output directory preserves
  the first slice's evidence when running this follow-up.
- Requirement inventory/generator, `AGENTS.md`, the existing Studio report,
  `BACKEND_UI.md`, status/phase records, this report and dated evidence/checkpoint.

## Actual verification

| Command/check | Outcome |
|---|---|
| `.tools/backend-venv/Scripts/python.exe scripts/test_backend_studio_postgres.py --output docs/evidence/backend-studio-policy-2026-10-11` | **72 passed, 2 skipped**, 43.64s, SQLite plus a newly owned PostgreSQL17 container. Both skips are duplicate SQLite row-lock cases; PG counterparts run. Container ownership checked and only that container removed. [Log](evidence/backend-studio-policy-2026-10-11/postgres.log). |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_commerce.py -q -k '(initial_allowance or calendar_month or monthly_stacks) and not postgres' --disable-warnings --tb=short` | **11 passed, 42 deselected**, 1.62s. September 12 10:23:45 UTC ends October 12 10:23:45 UTC; a September 20 repeat extends to November 12. Month-end/leap/year transitions preserve time. A consumed initial slot stays zero on October 12 and January 12, with no purchase/refill and the original publication retained. |
| `.tools/backend-venv/Scripts/python.exe scripts/test_backend_studio_console.py --output docs/evidence/backend-studio-policy-2026-10-11` | **13 checks, zero failures/JavaScript exceptions** in real Edge against a newly owned loopback SQLite fixture. Both classes remain in totals; a development-login real player stays Real. List/profile and redacted export expose the flag, with exact-version linkage, error/Retry, stale-read/Lock fences and responsive containment retained. [Receipt](evidence/backend-studio-policy-2026-10-11/browser-receipt.json). |
| Ruff on changed runtime/tests/tooling; bundled Node `--check` on `app.js` and `support.js`; scoped whitespace and task-patch checks | Passed. The existing Starlette/httpx deprecation warning remains. |

An initial policy-test selection failed to exclude PostgreSQL fixture
parametrizations and encountered the unavailable pre-existing DB configuration.
That attempt was stopped; the corrected selected SQLite run above passed. The
separate full API regression used a new owned database, not that configuration.
No assertion or isolation requirement was weakened.

Screenshots inspected: [Players](evidence/backend-studio-policy-2026-10-11/players-1440.png),
[Artificial profile](evidence/backend-studio-policy-2026-10-11/artificial-player-1440.png)
and the retained responsive race captures in the same directory. These contain
only freshly seeded local fixture data. Reviewable before-to-final patch and
hash manifest are under `evidence/backend-studio-policy-2026-10-11/checkpoint/`;
the existing dirty workspace and first-slice checkpoint are preserved.

No live reads/writes, deployment, schema migration, recurring grants, provider
transaction, gameplay/physics change, Android export/install or physical-device
test occurred. Phone attachment was not checked. Deployment parity and owner
review of the visible Studio remain open; broader telemetry/provider/staff/privacy
requirements retain their independently documented gaps. A deployment still
requires explicit owner authorization.


## Authorized Studio staging deployment, 2026-10-11

The owner subsequently authorized deployment. The reviewed nine-file Studio overlay is now live on the existing retained staging service, with fresh backup, zero-traffic canary, unchanged schema/game/commerce and preserved configuration. Exact-image47 tests and live API/asset/flag/browser/native-worker checks passed. Earlier no-deployment statements describe their original local tasks. See [the actual deployment report](BACKEND_STUDIO_DEPLOY_2026_10_11.md) for commands, evidence, image/revision and remaining boundaries.
