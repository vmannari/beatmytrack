# Store offers on first entry — 2026-10-28

The Store built its offer cards only after `/store/products` and then
`/me/entitlements` completed. A first visit therefore showed empty offer groups.
The page now builds the five existing offer descriptions immediately, with price
ellipsis and disabled checkout. Confirmed catalog prices arrive independently of
account access; only the existing confirmed debug entitlement enables simulation.

## Requirements and changes

- SFI01: `game/ui/store_page.gd` prepares the existing offers in `_ready`, including
  passive swipe neighbors. No new products, prices, free allowances or access are
  invented. A successful service subset or empty catalog replaces the initial
  presentation. Initial offline entry keeps descriptions with unavailable actions
  and no numeric price. Unconfirmed cards do not count as product impressions.
- SFI02: `game/backend/store_access_cache.gd` publishes a validated, scoped catalog
  before waiting for entitlements. A page joining an in-flight access refresh can
  display that catalog immediately. Existing four-scope bound, TTL, passive reads,
  request coalescing and account fences remain.
- SFI03: refresh clears ownership and redraws disabled purchase/gift buttons before
  yielding. Old-account replies cannot present new catalog data or grant access.
  Billing remains disconnected; enabled debug actions retain simulation labels.
- Q01: `game/tests/test_store_first_entry.gd` holds catalog and account responses
  independently and tests first-frame cards, authoritative prices, coalescing,
  refresh, offline, subset/empty catalogs, account changes and the actual first
  Store-tab entry in an isolated App. All services are in-process fixtures.

## Actual verification

Pinned engine: `4.7.2.stable.official.ed1daf0bf`, using
`C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe` from the workspace root.
Final commands use `--path game`, an absolute workspace `--log-file`, and these
arguments (logs are under `docs/evidence/store-first-entry-2026-10-28/`):

| Command arguments | Actual outcome | Log |
| --- | --- | --- |
| `--headless --script res://../docs/evidence/store-first-entry-2026-10-28/baseline_first_entry.gd` | Task-start sources: 27 checks, 10 failures | `baseline-final.log` |
| `--headless --script res://tests/test_store_first_entry.gd` | 27 checks, 0 failures | `first-entry-final.log` |
| `--rendering-method gl_compatibility --script res://tests/test_store_first_entry.gd` | 34 checks, 0 failures; seven screenshots | `compatibility-final.log` |
| `--rendering-method mobile --script res://tests/test_store_first_entry.gd` | 34 checks, 0 failures; seven screenshots, desktop Vulkan | `mobile-final.log` |
| `--headless --script res://tests/test_store_cache_reference.gd` | 9 checks, 0 failures | `cache.log` |
| `--headless --script res://tests/test_store_reference.gd` | 131 checks, 0 failures | `reference.log` |
| `--headless --script res://tests/test_script_parse.gd` | 1356 scripts, 0 failures | `parser.log` |

The reference suite uses `BMT_STORE_EVIDENCE_DIR` pointing to the `reference`
subdirectory of this task's evidence. Native reference results are recorded in
`report.json`. Native screenshots include actual App first-tab loading and
catalog-before-access states in `gl_compatibility/` and `mobile/`.

The existing `test_product_store_telemetry.gd` reports 15 checks / 1 failure:
“scrolling establishes an actually visible last publishing offer.” Exact
task-start runtime sources reproduce the same failure in both headless and native
Compatibility runs (`baseline-telemetry.log`, `baseline-telemetry-native.log`).
The original assertion and fixture are unchanged. The independent Store reference
suite's scrolling/impression checks pass. No all-green regression claim is made.

Initial first-entry reproduction was 22 checks / 8 failures before actual App
coverage was added; final reproduction keeps all earlier assertions. Initial log
paths encountered sandbox user-log/relative-path diagnostics. Later commands use
absolute workspace log paths. The sandbox certificate-store diagnostic remains
in engine output; fixture requests do not use TLS or a real backend.

## Evidence and remaining acceptance

`evidence/store-first-entry-2026-10-28/report.json` records outcomes, source hashes,
captures and limitations. `task.patch` contains only these two runtime changes,
the new regression test and this document, relative to the exact task-start files.
Its isolated `git apply --check`, apply and resulting file hashes are recorded.
Existing unrelated work in the main working tree is excluded.

Reload the current client to use the fix. Network pricing/access latency and owner
appearance/input acceptance remain. No physical-device attachment check or device
test, APK, real authentication/payment, owner-save/live backend mutation,
deployment, owner-process restart or main-index staging/commit/merge was performed.
