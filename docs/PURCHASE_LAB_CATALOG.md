# Purchase-lab Race catalog correction — 2026-10-07

PUR03/PUR06/PUR08/B01–B07/R01/Q01. The owner reported an empty Race menu after using the purchase launcher. The isolated lab database had no published tracks; Race correctly reads the backend catalog, but the launcher omitted its initialization.

Fixed: `scripts/purchase_lab.ps1` prepares the approved catalog before starting a new local API and also checks catalog setup when reusing a running lab. The developer receives the normal initial publishing allowance; administrative catalog setup does not consume it. Existing simulated purchases, banked credits and creator tracks remain intact. Namespace `lab_catalog_` keeps seeded authoring identities separate from ordinary creator drafts.

The bundled `backend/bmt_backend/lab_tracks.json` contains only the **27 latest public track documents** from the owner-approved official corpus, sourced from the previously verified public export `.tools/gcp-track-transfer/source-catalog.json`, SHA256 `f3040a3cc045100b8ecc742836d6a8e978b3613042f63d3bf0e37ba7f03e1e63`. Original Beat my track authorship is retained. No source accounts, authentication, racing histories, ratings, rewards or purchases are included. It adds 210,507 bytes and works without the ignored source export. Backend package data includes this development catalog.

Every document is prepared by the real pinned canonical verifier. A build/source fingerprint caches completed setup; changing the build produces new immutable catalog revisions while retaining old links and manifests. Seeding is restricted to the explicitly enabled **development SQLite purchase lab**; it cannot apply to the PostgreSQL cloud backend. It introduces no invented creator runs or leaderboard times.

## Actual commands and results

```powershell
# Project root; only owned local lab processes were restarted.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/purchase_lab.ps1 -Action Stop
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/purchase_lab.ps1 -Action Start
# Repeat Start proved idempotence: 27 existing, zero new revisions.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/purchase_lab.ps1 -Action Start
# Backend directory:
..\.tools\backend-venv\Scripts\python.exe -m pytest tests/test_purchase_lab_catalog.py tests/test_official_tracks.py tests/test_commerce.py -q --disable-warnings --tb=short -k 'not postgres'
..\.tools\backend-venv\Scripts\python.exe -m ruff check bmt_backend/purchase_lab_catalog.py bmt_backend/purchase_lab.py tests/test_purchase_lab_catalog.py
# Project root; child environment supplied the loopback URL and private development key.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_purchase_lab_catalog.gd -Graphical
```

- Initial setup: **27 published tracks**. Repeated startup: **27 reused, zero new revisions**.
- Focused backend suite: **30 passed, 2 skipped, 20 deselected**. Tests cover discovery after setup, slot preservation, no invented runs/PBs, restart reuse, build changes retaining immutable revisions, player draft/entitlement preservation and rejecting non-lab backends. PostgreSQL cases were deliberately excluded; production PostgreSQL is not involved in this SQLite-only tool.
- Pinned graphical game: **115 checks, zero failures**, including all 27 actual downloads/compilations, native/backend geometry hashes, current rules/compiler, real Race menu cards, enabled Race action and a compatible race ticket. No race was completed or submitted. [Actual screenshot](evidence/purchase-catalog-2026-10-07/race-menu.png) was visually inspected.
- Ruff passes. No physics/compiler/gameplay or menu-layout change, store payment, cloud deployment, phone attachment check/device test, Android export or full Validate occurred.

Changed: `backend/bmt_backend/purchase_lab_catalog.py`, `lab_tracks.json`, `purchase_lab.py`, `backend/pyproject.toml`, `scripts/purchase_lab.ps1`, focused backend/native tests, purchase docs/status. Review checkpoint and scoped patch accompany the slice; existing checkout and shared index remain unchanged. Restart the existing game with the purchase launcher to refresh the menu against the populated lab.
