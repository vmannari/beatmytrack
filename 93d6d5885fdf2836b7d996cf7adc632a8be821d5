# Remaining benefits before account deletion

Implemented locally on 25 October 2026. The native account panel and public web deletion page now disclose remaining account benefits before the player confirms permanent deletion. This implements the publisher's selected voluntary-deletion policy; the annual ad-free product and its purchase lifecycle remain separate release work.

| Requirement | Result |
| --- | --- |
| ADW01 Current balances | Authenticated, non-cached `GET /v1/privacy/deletion-preview` and verified web-session response use the same read-only snapshot. It includes publishing slots, coins, banked resumes, online cosmetic unlocks, pending orders and active ad-free expiry. Missing resource rows use existing initial/default values without creating or granting resources. Simulator balances require the existing development eligibility checks. |
| ADW02 Native warning | Lists exact balances, ad-free days/hours and UTC expiry. Clearly states that whole-account deletion permanently loses remaining benefits, including paid benefits, without restoration or transfer to a replacement account. The body scrolls while the Delete/Keep actions stay reachable. Keep account receives initial focus. |
| ADW03 Web warning | The verified page lists the same benefits and requires acknowledgement. Dynamic names and values use DOM text. No credentials or verification tokens are added to URLs, storage or logs. |
| R01 Identity and recovery | Loading, failed/malformed snapshots and wrong-account responses cannot enable confirmation. Native identity/origin/login changes invalidate the disclosure. Existing account-deletion request IDs, authorization, tombstones, response-loss recovery and backup erasure are preserved. Preview is a disclosure, not a new erasure authorization requirement. |
| Q01 Verification | Backend privacy regression, native warning, existing privacy recovery, disposable HTTP account integration, browser flow, application and full script parsing checks completed below. |

Local authored tracks, car condition and local cosmetics remain on the device. Published tracks and historical standings remain under Removed account. The warning preserves mandatory consumer rights and outstanding purchase claims. Pending store payments are explicitly distinguished from deleted account benefits.

Changed runtime files: `backend/bmt_backend/privacy_deletion_preview.py`, `privacy.py`, `privacy_pages.py`, `privacy_ui/deletion.js`; `game/backend/backend_client.gd`, `game/ui/account_panel.gd`, `account_deletion_dialog.gd`, `account_deletion_benefits.gd`. Contract: `backend/schemas/account-deletion-preview-v1.schema.json`. Tests: `backend/tests/test_deletion_preview.py`, `game/tests/test_account_deletion_warning.gd`, `scripts/review_deletion_warning_browser.py`.

Verification used `4.7.2.stable.official.ed1daf0bf`, the existing backend Python and existing local Playwright/Edge installation. Godot used an isolated APPDATA profile; the HTTP integration harness also creates a unique records/session folder and disposable loopback database/server.

| Actual command/check | Actual outcome |
| --- | --- |
| `PYTHONPATH=backend` with backend Python: `-m pytest backend/tests/test_deletion_preview.py backend/tests/test_privacy.py -q --tb=short --disable-warnings --show-capture=no` | 23 passed; 111 existing dependency/reflection warnings. Covers auth, isolation, real balances, zero/expired/legacy access, simulation eligibility, no resource initialization, web parity and deletion retry continuity. |
| `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_account_deletion_warning.gd` | Initial focused pass: 37 checks, 0 failures after short-screen correction. |
| Same focused suite with `-Graphical -RenderingMethod gl_compatibility` after all final source changes | 42 checks, 0 failures, including captures at 1280×720 and 960×540, delayed login replacement, wrong owner, failure/retry and cancellation during loading. |
| Backend Python with `PYTHONPATH=backend;.tools/review/Lib/site-packages`: `scripts/review_deletion_warning_browser.py` | 23 checks, 0 failures; every browser request intercepted, no real Google verification/account mutation. Exercises actual HTML/JS/CSP, safe names, acknowledgement, invalid snapshots, expired/legacy access and identical deletion retries. |
| `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_account_privacy.gd` | 27 checks, 0 failures; existing vault/deletion recovery and public-history invariants. |
| Backend Python: `-m pytest backend/tests/test_account_client.py -q --tb=short --disable-warnings --show-capture=no` | 1 passed with its disposable HTTP server; 6 dependency/reflection warnings. |
| `scripts/dev.ps1 -Action TestApp` | 141 checks, 0 failures. |
| `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd` | 1142 scripts, 0 failures. |
| Ruff over the four changed backend modules/test and browser review script | All checks passed. |

Initial failures are retained as findings: missing PYTHONPATH prevented Python collection; restricted Windows log/certificate access prevented Godot startup until an isolated profile and test escalation were used; the first native short-screen dialog measured 596×606 at 960×540, corrected by sizing its scroll area to both viewport and physical window; the simulation test initially omitted the required fictional development key; the browser harness first attempted an uninitialized database through middleware, then used the actual HTML handler directly; a string-based Playwright wait conflicted with the shipped CSP, corrected with locator waits; Ruff requested import ordering. A direct run of `test_account.gd` lacked its disposable server/credentials and failed authentication/country assertions with a missing `country_code`; the proper HTTP fixture subsequently passed. No failing assertion was removed or weakened.

Evidence: [native 1280×720](evidence/deletion-benefits-warning-2026-10-25/deletion-1280x720.png), [native 960×540](evidence/deletion-benefits-warning-2026-10-25/deletion-960x540.png), [web](evidence/deletion-benefits-warning-2026-10-25/web-deletion-960.png), [report](evidence/deletion-benefits-warning-2026-10-25/report.json). The task-only patch compares shared files with their saved task-start bytes, preserving concurrent work; source hashes identify the reviewed snapshot.

Remaining acceptance: deploy the matching API and web resources, reload/rebuild the client, verify actual account balances/provider states in the release candidate, and review touch/accessibility and complete translations. The snapshot is current when loaded, rather than a reservation against concurrent earning/spending. An older server cannot supply the snapshot, so the new native dialog stays disabled with retry. Older app builds retain their previous warning until updated. Existing no-expiry grants are described truthfully; this task does not convert them into annual grants or implement the new SKU.

No physical-device attachment check or device test, APK, real purchase/Google sign-in, live account deletion, production deployment, schema migration or owner-process restart was performed. Existing shared runtime/UI/localization and vehicle work was preserved.
