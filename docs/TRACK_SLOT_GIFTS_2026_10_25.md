# Track-slot gifting — 2026-10-25

GTS01–GTS04/R01/Q01 implement the owner's request to buy publishing slots for another player. In Store, choose **Gift slots** on the 1-, 5- or 10-slot pack, enter an exact username, find the player, review recipient/quantity/price, and confirm. The purchased pack increases the recipient's remaining publishing capacity. Existing buyer capacity, the one initial free slot, free racing/local drafts and ad-free products retain their rules. There is no transfer of existing slots.

The current game client still has no shipping Billing SDK checkout. Gifts follow its explicitly labelled, debug-only development checkout; both accounts must qualify for simulation, and simulated capacity never becomes real capacity. The existing verified Google Play endpoint also accepts an optional recipient UUID, verifies the buyer's provider proof, and grants real capacity to that recipient. No payment was made and no backend was deployed by this task.

## Requirements and implementation

- **GTS01:** Responsive Store gift actions and a two-step username/confirmation dialog; changed `game/ui/store_page.gd`. English and eleven directly authored translations live in `game/localization/*.po` and `scripts/translations/slot_gifts.tsv`. `scripts/compile_slot_gift_translations.py` appends these rows without regenerating unrelated catalogue entries. A deferred locale-summary callback now checks that its data remains available.
- **GTS02:** `commerce_models.py` and migration `0069_slot_gifts` add a nullable immutable purchase recipient while retaining buyer ownership of the receipt. Existing purchases remain self-purchases. `commerce.py` supplies authenticated indexed exact-name lookup, recipient validation and delivery. Self gifts, ad-free gifts and unavailable/artificial recipients are rejected. Pending/declined/cancelled payments grant nothing; pending approval uses the original recipient.
- **GTS03:** `purchase_simulator.gd` saves recipient with request identity in the account-scoped atomic recovery journal. `studio_finance.py` binds verified receipt identity to buyer, product and recipient. Duplicate callbacks/retries cannot redirect or duplicate delivery. Both account locks are acquired in sorted UUID order, and simulated and real balances remain separate.
- **GTS04:** Administrative purchase records expose recipient UUID. Audited pending approval previews recipient balances, locks both accounts, refreshes the order after locking and checks the delivered result against the preview. Privacy retention explicitly joins purchases to their buyer after adding the second player foreign key. Changes are in `admin_commerce.py`, `admin_purchase_controls.py` and the single join in `privacy.py`; contracts are described by `backend/schemas/slot-gift-purchase-v1.schema.json`.
- **R01/Q01:** New backend/native tests, exact task-start snapshots, logs, screenshots, hashes and task-only review patch are under [evidence](evidence/track-slot-gifts-2026-10-25/). No original assertion or tolerance is weakened.

## Actual validation

Commands use the pinned Godot 4.7.2 through `scripts/dev.ps1`, workspace-local APPDATA and `.tools/backend-venv/Scripts/python.exe`.

| Command/test | Actual outcome |
| --- | --- |
| `python -m pytest backend/tests/test_slot_gifts.py backend/tests/test_commerce.py backend/tests/test_admin_support.py -q -k 'not postgres' --tb=short` | 57 passed, 3 skipped, 51 deselected. Skips are the retained PostgreSQL-only tests. |
| `python -m pytest backend/tests/test_slot_gifts.py -q -k 'not postgres' --tb=short` | 12 passed, including gift receipt binding, rejected recipients, pending approvals, simulation isolation, audited approval and concurrent opposite-direction delivery/retries. |
| `python -m pytest backend/tests/test_studio_platform.py::test_verified_play_purchase_binding_and_replay_never_double_grant backend/tests/test_privacy.py -q --tb=short` | 21 passed. Provider proof is a fixture; no live provider call. |
| `dev.ps1 -Action TestScript -ScriptPath res://tests/test_slot_gifts.gd -Graphical -RenderingMethod gl_compatibility` and `mobile` | Final 64 checks, zero failures in each renderer. Covers 1280×720/960×540, recipient confirmation, rejected lookup, saved recipient/request recovery, account switching, disabled billing and all eleven translations. Desktop Mobile is not a device test. |
| `dev.ps1 -Action CheckScript -ScriptPath res://ui/store_page.gd` | Passed using isolated APPDATA; later complete native tests compile the final script and adapter. |
| Post-lock-refresh admin approval/settlement/state-change checks | 5 passed, 53 deselected. |
| Ruff on changed Python sources; task-only patch reverse-apply check | Passed. |
| Retained `test_store_reference.gd` | Final 131 checks/6 failures. Exact task-start Store reloaded only in isolated process memory reproduces the identical six existing whole-catalogue fit failures. Initial extra two exposure failures from a taller gift row were corrected with responsive shared actions. |
| Retained `test_purchase_simulation.gd` | Two lifecycle assertions fail, then untouched `TrackLifecycle._root` accesses a nil `directory`. Exact task-start purchase adapter in isolated process memory reproduces both failures and the same error. |
| Broader Store admin suite | An existing fixture constructs production Settings with forbidden legacy admin keys. This fails before exercising the endpoint; production configuration checks were not changed. Initial combined run: 43 passed, 3 skipped, two failures (this fixture and the corrected gift-concurrency fixture). |
| PostgreSQL gift tests | Configured localhost:55439 test service timed out, including outside the sandbox. PostgreSQL validation is outstanding. No service was started/restarted. |
| Resource import, two attempts | Fails copying existing `~bmt_track_geometry.windows.x86_64.41dbd9ca28a1.dll`. No owner process was restarted. Actual runtime tests load current translations and extensions successfully. |

Initial direct PowerShell execution-policy and sandbox log/certificate-store failures were resolved with process-local execution policy, isolated APPDATA and approved native test access. Initial in-memory SQLite concurrency failures came from the fixture's single shared connection, including request middleware. The test now uses a temporary WAL database and rebinds the retained sessionmaker so every request component uses independent connections; concurrent grants and original count bounds pass. Initial missing admin fixture key, import-copy failure and deferred locale callback failure remain in the logs.

Native captures: [Store at 960×540](evidence/track-slot-gifts-2026-10-25/gl_compatibility-final/store-960x540.png), [gift confirmation](evidence/track-slot-gifts-2026-10-25/gl_compatibility-final/confirm-960x540.png), [German](evidence/track-slot-gifts-2026-10-25/gl_compatibility-final/confirm-de.png), [Finnish](evidence/track-slot-gifts-2026-10-25/gl_compatibility-final/confirm-fi.png), [Japanese](evidence/track-slot-gifts-2026-10-25/gl_compatibility-final/confirm-ja.png). Matching desktop Mobile captures are retained under `mobile-final/`.

## Remaining acceptance

Apply migration 0069 with a matching client/API rollout when authorized. Owner visual/touch review, physical-device testing, PostgreSQL concurrency validation and resolution of the native import-copy failure remain. Real gifting requires the outstanding shipping Billing integration and its payment/refund lifecycle acceptance; this feature does not implement a new refund policy or claim real payment-provider acceptance. Received capacity appears through the existing entitlement refresh; no notification service or new polling is introduced.

No physical-device attachment check/test, APK, real authentication/purchase, live data mutation, deployment or owner-process restart was performed. Concurrent workspace changes are preserved. `checkpoint.patch` is a reviewable task-only patch against the captured task-start files; no shared index changes or unrelated commit is made.
