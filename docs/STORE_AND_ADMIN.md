# Store and purchase administration — 2026-10-07

The owner requested a Store tab for the five approved products, per-player purchase inspection, testing controls for available items, and access to the backend UI. This implements that local slice without Google Play integration or actual payments.

## Use it

```powershell
# Launch the game against the persistent local purchase lab.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/purchase_lab.ps1 -Action Run
# Open the local backend UI and copy its separate administrator key.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/purchase_lab.ps1 -Action Admin
```

Close an older running game before relaunching. Sign in with **Development**, then open **Store** beside Race/Create/Garage. The page shows publishing capacity, ad-free access and all five prices. Eligible debug accounts use clearly labelled **Simulate** checkout; choose Approved/Pending/Declined/Cancelled. Pending test payments can be resolved in Store. Refresh/recover and the saved-checkout retry preserve purchase identity after connection loss. Real billing remains unavailable; no simulated checkout is offered to real Google identities or release clients.

Admin opens **http://127.0.0.1:18182/admin#economy**. Paste the copied key into the password field and press **Connect**. The key is generated under ignored `build/purchase-lab/admin-owner.key`, independently of `development.key`; it is never embedded in the game, logged or placed in a URL. Console credentials stay in browser-tab memory; Lock/reload clears them. `-Action Admin -NoBrowser` verifies access setup and reports the URL/key-file path without opening a window or altering the clipboard. Settings → Development also offers **Open backend console**, which opens the same configured backend's `/admin` page without credentials.

Under **Economy & purchases**, inspect records filtered by exact player ID, provider and state. Under **Players**, search/open a player and use **Inspect this player's purchases**; their current real/simulated entitlements are shown separately. Inspectors do not materialize wallets or create grants. Analyst access is read only. Owner availability changes require a recorded reason and acknowledgement and are permitted only in development/test environments.

## Rules and contracts

| ID | Implemented behavior |
|---|---|
| STORE01 | Fourth Store tab, existing navy/yellow menu style, responsive scrolling and the five owner-approved products. Race/Create/Garage and canonical driving are retained. |
| STORE02 | Public bounded catalog and authenticated entitlement display; simulation-only checkout for eligible debug development identities. No real store SDK or fake shipping purchase success. |
| STORE03 | Publishing slots, stacked one-time monthly access, permanent access and three-rewind limits use the existing authoritative entitlement/receipt rules. Double-click/retry cannot grant twice; pending grants nothing. |
| STORE04 | Per-player purchase inspection with provider/state/timestamps, explicit simulation/adjustment labels and redacted account context. No raw provider subjects/session/store tokens or invented revenue. |
| STORE05 | Persisted product availability, owner-only testing controls, optimistic revision checks and append-only idempotent command audits. Disabling blocks new checkout at the backend; owned access and already accepted pending purchases remain valid. |
| STORE06 | Separate generated local admin key, browser/clipboard launcher and a credential-free debug menu link. Existing game/cloud session and backend configuration remain separate. |
| STORE07 | Catalog bounded to five known SKU rows; purchase inspection uses keyset pagination (25 default, 100 maximum), with no whole-history count/offset scan and a matching purchase-history index. |

These extend PUR01–PUR08, B01–B07, RW05–RW07 and Q01. Migration **0017_product_controls** creates five initially enabled controls and the history index. API/worker/schema require a matching backed-up rollout elsewhere; only the owned local lab was migrated/restarted. Catalog preparation also refreshed its immutable heads for the already-approved current physics0.51/rules19 build; older versions and player data remain intact.

New API surfaces: `GET /v1/store/products`, `GET /v1/admin/products`, owner `POST /v1/admin/products/{sku}`, and `GET /v1/admin/purchases` with scoped opaque cursors. The public contract is [store-products-v1.schema.json](../backend/schemas/store-products-v1.schema.json). Product checks occur inside the serialized purchase transaction. Accepted purchase replay and pending settlement continue after a toggle; config changes do not revoke purchased access or mint/refund slots.

## Actual verification

- Final affected backend suite: **66 passed, 3 skipped**, using SQLite and an owned disposable PostgreSQL17 container on loopback25441 with isolated schemas. It includes eight concurrent deliveries of the same admin command, conflicting revisions, disabled checkout, pending fulfillment, permanent ownership preservation, persistence, cursor bounds/filter binding, redaction and production/read-only mutation denial.
- Actual Store in the pinned native graphical game: **17 checks / zero failures**. All five actions fit 1280×720; 960×540 logical layout was also checked. Real loopback simulation verified one grant after a double press, pending approval and monthly free-rewind entitlement. Screenshots inspected: [desktop Store](evidence/store-admin-2026-10-07/store-1280x720.png), [compact Store](evidence/store-admin-2026-10-07/store-960x540.png).
- Actual installed Edge through the existing Playwright environment: **7 checks / zero failures**. Browser owner login, per-player filter, disable/enable confirmation, rejected new checkout, accepted pending settlement, player entitlement display and Lock were exercised. Original availability was restored. [Purchase console](evidence/store-admin-2026-10-07/admin-purchases.png), [player inspection](evidence/store-admin-2026-10-07/admin-player.png) visually inspected.
- Existing pinned App regression: **99 checks / zero failures**. New/changed Python passes Ruff; both admin JavaScript files passed syntax checks with the existing Playwright-bundled Node executable. Godot checked/compiled the changed Store/UI graph.
- Owned PostgreSQL test container was verified, stopped and removed. Local interactive API/worker remain available; all five products are enabled. No cloud deployment, actual payment, Android export, phone attachment check/device test or full Validate is claimed.

Actual commands (backend directory for pytest; otherwise project root):

```powershell
..\.tools\backend-venv\Scripts\python.exe -m pytest tests/test_store_admin.py tests/test_admin.py tests/test_commerce.py tests/test_purchase_lab_catalog.py -q --disable-warnings --tb=short
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://ui/store_page.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_store_page.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
.\.tools\backend-venv\Scripts\python.exe scripts/test_store_console.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/purchase_lab.ps1 -Action Admin -NoBrowser
.\.tools\backend-venv\Lib\site-packages\playwright\driver\node.exe --check backend/bmt_backend/admin_ui/app.js
.\.tools\backend-venv\Lib\site-packages\playwright\driver\node.exe --check backend/bmt_backend/admin_ui/commerce.js
```

`BMT_TEST_DATABASE_URL` targeted only the disposable container. Native acceptance used an isolated profile/cache and private loopback development credential. Browser acceptance used explicitly labelled isolated development buyers, never real Google players. During iteration the production-denial fixture needed synchronous validation disabled; the first native fixture looked for navigation before leaving Account; the first browser assertion used the raw field name rather than its human-readable label. Default Node/Playwright browser executables were absent, so existing bundled Node and installed Edge were used without installing dependencies. Assertions/production guards were retained. Store card height was reduced after inspecting clipped lower actions; the final test asserts every desktop checkout action fits. The local history index was explicitly verified after the uncommitted migration gained that index during development.

Changed files: `game/ui/store_page.gd`, App/Settings navigation, simulator availability display, native Store acceptance; backend product model/migration, commerce catalog/admission, admin commerce/read projections and static console scripts, bootstrap capabilities and private local admin setup; launcher, backend/browser tests, schema, docs/status/evidence. Review checkpoint preserves the active checkout/shared staging index and isolates this task from concurrent physics/audio work.

Still outstanding: real Google Play products/billing/provider verification and consumption, provider notifications/refunds policy, signed production ad rewards, production admin SSO/MFA and mobile/store-device acceptance. The current dedicated key console is an existing local operational interface, not a claim that production identity access has been deployed.
