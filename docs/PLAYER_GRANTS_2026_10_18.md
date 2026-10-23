# Player inspection and support grants — 2026-10-18

The owner requested a web tool to inspect a selected player and grant track slots, customisation kits and other purchases. Studio now provides **Player support → Player directory → selected player → Purchases & grants**. The subsequent [full backend deployment](FULL_BACKEND_DEPLOY_2026_10_18.md) publishes this tool to the retained cloud and PC services, including PostgreSQL checks and66 live desktop/390px views. No live player grant is issued during verification. The original local implementation evidence follows.

## Requirements and behavior

| ID | Delivered behavior |
| --- | --- |
| PGR01 | Reuse the searchable player directory and canonical selected-player profile. Show remaining slots, owned customisations, banked resumes, Coins, ad-free access and links to purchase records. |
| PGR02 | Owner grants 1–1000 track slots or banked resumes, any of five existing store products, any of 39 existing Compact kits or 48 liveries. Existing server catalogues supply item IDs. Cosmetics are permanent and grantable once; store packs and ad-free products use quantity one. |
| PGR03 | Show the selected name and canonical ID, product, quantity and before/after values before confirmation. Require a reason and acknowledgement. Audits record actor, target, product, quantity, reason, request ID and state. Analysts inspect without grant controls. |
| PGR04 | Grants reach the existing game entitlement, resume and cosmetic APIs. They persist independently of development simulation, add access without billing or deducting Coins, and remain separate from paid purchase records. |
| G01 / R01 | Keep existing purchase verification, simulation balances, free-resume day, racing, wallet prices and earned Coins. Reject restricted/removed accounts, unknown products, invalid quantities, duplicate cosmetic ownership, stale previews and over-capacity balances. |
| Q01 | Actual local backend checks and real Edge desktop/390px workflows, captures and a source-only checkpoint. PostgreSQL, deployment and owner acceptance remain explicit. |

Owner access uses the existing administrator authentication, including named staff audit attribution. No provider integration, credential, new dependency, database table, migration or game-client change is introduced. Disabled store checkout does not prevent an owner issuing a support award. This is an additive grant tool; refunds, revocation and transferring account ownership are outside this slice.

## Implementation and contracts

- `backend/bmt_backend/admin_player_grants.py`: allowlisted catalogue, read-only inventory projection and `POST /v1/admin/players/{player_id}/grants/preview` plus `/grants/commands`.
- `backend/bmt_backend/app.py`: register the grant router alongside the retained administration routers.
- `backend/bmt_backend/admin_support.py` and `studio_catalogue.py`: include grant permissions, supported products, owned cosmetics and current Coins in both player inspection projections. Reads do not initialize wallets or entitlements.
- `backend/bmt_backend/admin_ui/catalogue.js`, `support.js` and `catalogue.css`: Purchases & grants tab, sidebar link, searchable grouped product picker, quantities, confirmation, owned inventory and filtered grant audit history. Existing access labels now include support-granted access.
- `backend/schemas/admin-player-grant-v1.schema.json`: documented command contract.
- `backend/tests/test_admin_player_grants.py` and `scripts/test_player_grants_console.py`: focused API, concurrency, rollback and actual browser coverage.

Execute obtains the same Player lock used by the existing commerce/economy writers; SQLite reserves its writer before reading state. A five-minute preview digest binds player, command, item, quantity, timestamp and before/after state. A committed `AdminAudit.command_id` is the permanent replay identity. Retrying the same request returns its original audit without awarding again, including after preview expiry. Reusing an ID with different content fails.

Entitlement changes and audit commit together. Cosmetics use `CosmeticUnlock(price=0)` and increment the existing wallet revision without changing its balance. Resume awards use the existing durable `ResumeGrant` ledger. Support awards do not create `Purchase` rows and therefore do not masquerade as paid sales. The browser retains the exact submitted command for an ambiguous network retry. Page, selected-player, dialog and authentication generations fence abandoned responses.

## Actual validation

Commands were run from the repository root with the existing local environment:

```powershell
& .tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_admin_player_grants.py backend/tests/test_admin_support.py backend/tests/test_studio_catalogue.py backend/tests/test_store_admin.py -k 'not postgres' -q --tb=short
& .tools/backend-venv/Scripts/python.exe -X utf8 scripts/test_player_grants_console.py
& .tools/backend-venv/Scripts/python.exe -m ruff check backend/bmt_backend/admin_player_grants.py backend/tests/test_admin_player_grants.py scripts/test_player_grants_console.py
git diff --check -- backend/bmt_backend/app.py backend/bmt_backend/admin_support.py backend/bmt_backend/studio_catalogue.py backend/bmt_backend/admin_ui/catalogue.js backend/bmt_backend/admin_ui/support.js backend/bmt_backend/admin_ui/catalogue.css
```

The final backend outcome is **43 passed, 2 skipped, 38 deselected** in 32.71 seconds, with the existing Starlette/httpx deprecation warning, recorded in [backend-tests.txt](evidence/player-grants-2026-10-18/backend-tests.txt). The new tests cover actual game API delivery, no billing/coin charge, read-only previews, permission/eligibility/quantity validation, account binding, stale/expired previews, durable replay, competing commands and atomic rollback. File-backed SQLite duplicate-delivery checks exercise two and eight simultaneous requests. Two existing PostgreSQL-only concurrency checks remain skipped under SQLite; PostgreSQL variants are deselected because the configured disposable service at `localhost:55439` is unavailable.

Real Edge passed **11 workflows** at 1440×1050 and 390×844 with **zero JavaScript errors**, using an owned disposable loopback service with production-mode purchase simulation disabled. Checks include selected-player search, preview/cancel, a seven-slot award, free kit ownership retaining 1250 Coins, a server-committed/lost-response retry, ad-free and resume grants, audit inspection, stale-state rejection, narrow comparison visibility, changing players during preview, locking during preview and analyst inspection. [Browser receipt](evidence/player-grants-2026-10-18/browser.json) and [command output](evidence/player-grants-2026-10-18/browser-tests.txt) retain actual results. The JSON schema parses; scoped Ruff and whitespace checks pass.

### Captures

- [Desktop player inventory](evidence/player-grants-2026-10-18/player-grants-desktop.png)
- [Desktop confirmation](evidence/player-grants-2026-10-18/grant-preview-desktop.png)
- [Grant audit](evidence/player-grants-2026-10-18/grant-audit-desktop.png)
- [390px player inventory](evidence/player-grants-2026-10-18/player-grants-mobile.png)
- [390px confirmation with all before/after columns visible](evidence/player-grants-2026-10-18/grant-preview-mobile.png)

## Initial attempts and corrections

The first unfiltered backend invocations attempted the preconfigured, unavailable PostgreSQL fixture; those runs were stopped and local SQLite variants run explicitly. A production-mode API test initially retained the fixture's synchronous-development-validation flag; the test configuration was corrected to disable it. The injected audit failure initially expected an exception to escape; the existing request boundary correctly converts it to HTTP 500, and the corrected test asserts that response plus complete database rollback.

The original concurrency fixture used a single in-memory SQLite connection. An initial on-disk endpoint-factory substitution still left the request boundary on its original in-memory factory and produced intermittent 503 responses. The final fixture constructs a complete app, middleware and pool against an owned on-disk copy, preserving the simultaneous-success and single-award assertions. It exercises the actual deployed transaction boundary without weakening the invariant.

The first narrow capture exposed the shared table's 650px minimum hiding the comparison values behind horizontal scrolling. A grant-scoped responsive table and actual inner-overflow assertion correct it. Earlier full-page captures placed the fixed header at the current scroll offset; final desktop captures start at the top and modal captures use the viewport. Initial import-format findings were corrected with the existing Ruff tool. No runtime invariant was weakened.

## Checkpoint and remaining acceptance

`docs/evidence/player-grants-2026-10-18/before/` records versions captured before this task edited each existing file. `task-only.patch` compares this task's changes to those pre-edit sources, preserving the pre-existing shared workspace work. `checkpoint.json` records final file hashes. This is a reviewable source checkpoint, not a commit of the large unrelated working tree.

Owner visual/workflow acceptance remains. PostgreSQL validation and matching backend/UI deployment are completed in the subsequent [full release](FULL_BACKEND_DEPLOY_2026_10_18.md). The original local task performed no live player grant, real charge, publication, backend deployment, APK/export/install, phone attachment check or physical-device test. No phone or performance claim is made.
