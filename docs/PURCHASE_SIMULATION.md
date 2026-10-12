# Purchases and free pretesting — 2026-10-06

The owner approved five products and authorized implementation without a real store. This slice implements server entitlements and an isolated development purchase simulator. No Google Play billing SDK, payment, production deployment or cloud data change occurred.

## Try it

From the project directory in PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/purchase_lab.ps1 -Action Run
```

The launcher starts an API and canonical verification worker on **127.0.0.1:18182**, then opens the pinned game. Sign in with **Development**, open **Settings → Development**, and scroll to **Purchase simulator — no payment**.

The 2026-10-07 correction also automatically prepares **27 approved public tracks** for the lab's Race menu. An existing running game should be closed and relaunched with the command above. Catalog setup preserves simulator purchases and creator drafts, does not consume publishing slots, and reuses existing catalog revisions on subsequent starts. [Actual catalog checks and screenshot](PURCHASE_LAB_CATALOG.md).

Choose Approved, Pending, Declined or Cancelled, then press a product button. Pending purchases grant nothing until approved using their pending row. Declined/cancelled purchases grant nothing. **Refresh / recover** reloads server state; **Retry saved purchase** resolves a lost response using the same durable purchase identity. **Expire month** and **Reset ad-free** change simulated access only, without refunding slots or erasing purchase history. These actions take effect immediately; Apply is for ad/settings preferences.

The Store tab now offers the same five products and pending-payment recovery. Use `scripts/purchase_lab.ps1 -Action Admin` to open the separately authenticated console, inspect player purchases and enable/disable items for testing. See [Store and administration](STORE_AND_ADMIN.md) for commands, guards and actual verification.

```powershell
# Start just the backend; Run sets the game's connection automatically.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/purchase_lab.ps1 -Action Start
# Stop both owned processes, preserving test data.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/purchase_lab.ps1 -Action Stop
```

Requires the existing `.tools/backend-venv` and pinned Godot 4.7.2 executable. The launcher uses private generated development credentials and a SQLite database under ignored `build/purchase-lab/`. It sets connection variables only for the launched game and uses a separate `purchase_lab_session.cfg`, preserving the ordinary saved account session and backend configuration. Existing WSL/cloud services are untouched. Android connection/setup and device acceptance are not part of this Windows launcher.

The pretest database is retained separately under ignored `build/purchase-lab-pretest-20261006/`. The running default lab is fresh: one initial slot, ads enabled and zero purchases. The disposable PostgreSQL test container was stopped and removed after the checks.

## Approved rules and implementation

| ID | Implemented requirement |
|---|---|
| PUR01 | One initial publishing slot per account, without recurring rewards. Local drafting/export and recipients' racing remain free. |
| PUR02 | `creator_slot_1` €0.99; `creator_slots_5` €3.49; `creator_slots_10` €5.99. Each approved transaction grants one pack. Repeat purchases use new identities. |
| PUR03 | Successful publication consumes one slot in the same transaction as the immutable publication. New published revisions consume a new slot. Same-version retries consume none; failed/unverified publication consumes none. Hiding a track does not restore capacity. |
| PUR04 | `ad_free_month` €3.49 is repeatable and never automatically renews. UTC calendar-month extension starts at the later of approval/purchase time or existing expiry; month-end days clamp to the target month's last day. |
| PUR05 | `ad_free_forever` €9.99 takes precedence permanently. Active ad-free access bypasses rewarded ads and preserves banked/daily resumes. Server and client retain the maximum three rewinds per race. A previously pending monthly purchase still fulfills once if approved after forever access. |
| PUR06 | Simulation defaults off. It requires development environment, development authentication, the explicit simulation flag, and a development identity. Real Google identities cannot claim it. Simulated slots/monthly/forever fields are separate and ignored when simulation is disabled. Debug controls and transport reject release usage. |
| PUR07 | Permanent purchase identity, owner/product binding, account locks, atomic ledger/grant writes and an atomic client journal protect retries and concurrent replicas. Uncertain ad-free rewind recovery cannot mint a credit. |
| PUR08 | Deterministic date/expiry tests, payment-state controls, canonical native HTTP integration and bounded replay load tooling support pretesting without payment. |

These also implement the relevant B01–B07, RW05–RW07 and Q01 boundaries. Ordinary racing/handling/physics remain unchanged. Official authored catalog content retains its existing capacity exemption; the development purchase simulator deliberately exercises slot limits even for its official-marked developer tracks.

Migration **0016_commerce** adds entitlement, purchase and publication ledgers. Existing publications are grandfathered intact; prior non-official publishers have already used their initial allowance, and older excess publications create no debt. Other accounts receive one initial slot. Migrations remain explicit and require a backed-up, matching API/worker rollout outside this local lab.

`GET /v1/me/entitlements` follows [entitlements-v1.schema.json](../backend/schemas/entitlements-v1.schema.json). Simulation uses `/v1/development/purchases`, its `/{id}/resolve` endpoint, and `/v1/development/entitlements/adjust`. Product count is five; history returns at most twenty pending and twenty recent settled entries. At most twenty unresolved simulated purchases may exist per account. Compound indexes support pending recovery without scanning every player's history. No client-facing endpoint accepts a claimed real purchase proof.

## Actual verification

- Backend regression: **568 passed, 25 skipped, 29 deselected** (`pytest -m 'not godot'`), before the final focused changes; no aggregate claim across overlapping batches.
- Final affected backend/recovery batch: **113 passed, 6 skipped**. Final commerce/index/legacy-migration batch: **44 passed, 2 skipped**. Both used a disposable PostgreSQL 17 container and isolated schemas in addition to SQLite. Skips include SQLite-only exclusions for production row-lock tests and optional provider checks.
- Native graphical simulator: **30 checks, zero failures**, including actual loopback sign-in, pending resolution, duplicate delivery, a double UI click, journal recovery and creator-quota recovery. [Screenshot](evidence/purchases-2026-10-06/purchase-simulator.png) visually inspected; all five products fit the scrolled Settings viewport.
- Native existing regressions: AdMob development **44**, backend exception recovery **28**, App **99** checks, all zero failures. Final native HTTP/account batch **3 tests passed**, including canonical racing, actual rewind verification and **40** lifecycle assertions after the explicit second-slot purchase.
- Ruff passes for new commerce modules/migration/tests. The native tests compile the changed client/UI graph; no full project Validate or Android export is claimed.

Actual commands, from repository root unless noted:

```powershell
# Backend working directory; BMT_TEST_DATABASE_URL targeted only the owned temporary PG container.
..\.tools\backend-venv\Scripts\python.exe -m pytest -m 'not godot' -q --disable-warnings --tb=short
..\.tools\backend-venv\Scripts\python.exe -m pytest tests/test_commerce.py tests/test_resumes.py tests/test_track_lifecycle.py tests/test_exception_recovery.py -q --disable-warnings --tb=short
..\.tools\backend-venv\Scripts\python.exe -m pytest tests/test_commerce.py -q --disable-warnings --tb=short
..\.tools\backend-venv\Scripts\python.exe -m pytest tests/test_cloud_client.py tests/test_account_client.py -q --disable-warnings --tb=short
# Root; graphical test additionally used BMT_PURCHASE_TEST_URL and the private lab key.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_purchase_simulation.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_admob_development.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_backend_exception_recovery.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
.\.tools\backend-venv\Scripts\python.exe -m bmt_backend.commerce_loadtest --key-file build/purchase-lab/development.key --requests 100 --concurrency 8 --output docs/evidence/purchases-2026-10-06/purchase-replay-load.json
```

The last load command replays one payment 100 times with eight busy clients: **100 HTTP 200 responses, exactly one slot grant, maximum 411 response bytes**, 56.25 requests/s, p95 399.48 ms, maximum 1254.13 ms. This measures the SQLite development server's single-account contention, not cloud capacity or concurrent-player limits. The tool refuses non-loopback URLs. See [actual result](evidence/purchases-2026-10-06/purchase-replay-load.json).

Initial failures were preserved/repaired: unprivileged native user-log access, the stale configured PostgreSQL port (replaced with an owned disposable container), developer official-content bypass during quota testing, the lab's normal 90-writes/minute budget during a 100-request replay (only the lab now uses a higher budget), and the old native fixture's unfunded second publication. The latter fixture now explicitly simulates a slot purchase and retains all original immutable-link/cache/account-recovery assertions. A subsequent native run encountered audio assets being added by concurrent work; refreshing the Godot import cache resolved their loading errors without changing audio source or weakening assertions. [Initial native HTTP failure](evidence/purchases-2026-10-06/native-http.log), [audio-import failure](evidence/purchases-2026-10-06/native-http-final.log), [passing final run](evidence/purchases-2026-10-06/native-http-imported.log), [affected backend log](evidence/purchases-2026-10-06/backend-tests.log), [final commerce log](evidence/purchases-2026-10-06/commerce-final.log), [native simulator log](evidence/purchases-2026-10-06/native-purchases.log).

## Changed files and remaining acceptance

Backend: `commerce.py`, `commerce_models.py`, `purchase_lab.py`, `commerce_loadtest.py`, migration `0016_commerce.py`, `app.py`, `config.py`, `migrations/env.py`, `tracks.py`, `resumes.py`, entitlement schema, `test_commerce.py` and the native HTTP fixture configuration. Client: `platform/purchase_simulator.gd`, `ui/purchase_simulator_panel.gd`, Settings/App wiring, resume-credit/ad gating, HUD/panel resource displays, typed wallet validation, creator publication recovery and native purchase/lifecycle tests. Docs/status and scoped Git evidence accompany the slice; concurrent work and the shared Git index are preserved.

Review branch: `purchases-simulation-2026-10-06`. Its purchase commit follows a separate snapshot of pre-existing workspace dependencies. The scoped delta is also retained in `docs/evidence/purchases-2026-10-06/scoped-change.patch`; `checkpoint.json` records the commit, baseline and unchanged active HEAD/index.

Still required for real purchases: Google Play catalog/localized prices and billing adapter, provider proof verification/account binding, durable consumption/acknowledgement retries, notifications/reconciliation, a refund policy for already-used slots/access, and store sandbox/device acceptance. Development expiry/reset is an audited simulation adjustment, not a refund implementation. Production ad reward SSV also remains unconfigured. No phone attachment check, phone test, actual payment, production deployment or modification of cloud player data was performed.
