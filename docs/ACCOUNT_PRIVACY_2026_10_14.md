# Account privacy and retained public history — 2026-10-14

Owner finding 5: implement account removal, privacy information and optional analytics controls. The owner requires tracks and historical standings to remain with the name **Removed account**, and explicitly requests placeholder developer/contact details until official ones exist. This is source implementation and local acceptance; no production deployment or real account deletion was performed.

## Result and data boundaries

The API closes sign-in immediately, removes provider identity links and every session credential, releases the old racing name, clears country/creation metadata and disables optional analytics. The remaining player row is a non-authenticating historical identity. Administrative suspension is separate; deletion never reverses an existing content restriction. New Google/development sign-in creates a separate player and cannot reclaim the removed account.

Published versions, track IDs, authored track titles, boards, PB/lap times, rivalry/challenge membership/results and histogram frequencies remain. Published document creator metadata and stored competition identity labels are redacted. Download/source hashes change; original pinned manifests and score identities do not. The client checks the exact redacted compiled hash before applying the retained canonical hash. Compact discovery provides both hashes without a second manifest request; the prepared cache includes both, preventing identical redacted documents from borrowing different historical contracts. The real pinned compiler/verifier confirms unchanged cells, routes, hazards and prepared race geometry. Existing build-compatibility rules remain in force.

A versioned, resumable worker erases private run/ghost evidence, publication recovery/proofs, resume balances/receipts/grants, entitlements, retry journals, individual ratings, artificial-profile identity data, raw/account-linked product facts and diagnostic receipts. Individual rating removal adjusts its aggregate. It preserves historical timing rows while removing their evidence hashes. Private cleanup runs before public source redaction, so an unavailable old track does not hold up private-data removal. Blob deletion follows the existing pin lock and current reference checks; another account's shared objects and active leases survive. Support/audit payloads are stripped of the removed person's detail. Minimal purchase token digests/transactions expire after the configured 365-day default. Expired deletion receipt credentials are cleared after 90 days; the minimal historical erasure identity remains.

Each worker iteration processes at most 100 private/snapshot rows, one track redaction or one blob deletion. Ordinary racing runs first; continuous foreground work gives cleanup one step after sixteen completed jobs, and idle turns drain cleanup. `python -m bmt_backend.privacy --cleanup-once` also supports a separately scheduled maintenance process. Completion requires all phases; unknown plan versions, storage failure or live leases cannot be reported as complete.

Requests require an exact `DELETE` confirmation and UUIDv4 operation. A receipt binds the operation to the initiating credential, allowing the same request after revocation/lost acknowledgement without granting access. Writes are owner-locked and rechecked at commit, including after external IO releases SQL. Claimed runs/publications are fenced. Encrypted native recovery stores the original operation/credential before delivery, recovers expired access only after an explicit rejection, checks the returned player ID, preserves a newer saved login in another instance, and suspends normal authenticated/optional operations while deletion is pending. The confirmation binds the displayed player/origin and focuses **Keep account** initially.

## Interfaces and privacy choice

| Surface | Behavior |
| --- | --- |
| `POST /v1/privacy/account-deletion` | Authenticated native deletion; returns a durable 202 receipt after the independent journal is written. |
| `POST /v1/privacy/preferences` | Explicit boolean account-wide optional analytics preference. New and migrated accounts default off. |
| `/privacy` | Public, escaped policy with visible pre-release contact placeholders and actual data/retention/provider disclosures. |
| `/account-deletion` | Public Google-verification/confirmation flow usable without the installed game. It verifies an existing identity and never creates an account. |
| `/v1/privacy/web-session`, `/v1/privacy/web-delete` | Short-lived existing Google browser handoff; strict token/operation confirmation and idempotent receipt. No game bearer credentials, cookies or browser token storage. |
| Game Settings → Privacy | Optional sharing choice, policy link and account management. Successful local preference saving precedes its application. Off stops collection/uploads, joins pending bounded IO and clears the device outbox/RAM. |
| Manage account → Delete account | Menu-styled consequences/confirmation, durable restart recovery and sign-out. Only hashed account recovery roots are removed; local authored records/cosmetics remain on disk. |
| Studio | Removed state/filter, read-only removed support state and refusal to restore a tombstone. Existing all-player totals remain inclusive. |

The privacy preference covers first-party product/quality/network observations, not essential verification or a provider's SDK processing. The backend rejects opted-out ingestion, skips optional server events and prevents later racing on retained tracks from recreating a removed creator's product facts. Provider ads remain the existing development-only Google Mobile Ads 25.5.0 integration; production ad consent/monetisation enablement is outside this slice.

Google Play requires an in-app deletion path and an external request resource, including for external sign-in and apps with guest access. [Account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en). Its privacy/Data Safety requirements include accurate SDK and retention disclosures. [User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en). Google's current disclosure for the installed ads SDK describes identifier, network, interaction and diagnostic processing; the policy links it explicitly. [Google Mobile Ads data disclosure](https://developers.google.com/admob/android/privacy/play-data-disclosure).

## Independent erasure journal and backup restoration

A successful deletion acknowledgement requires an immutable, minimal journal record containing only schema, opaque player ID and request time. Journal failure returns a retryable error after immediately closing the account; the same credential/operation receipt and worker can finish journaling. No SQL connection is held during external journal IO.

Local storage uses a sibling `<object_dir>-erasure` directory. GCS/S3 use the same existing provider, under a separate `bmt-erasure-v1/<sha256(original object prefix)>` namespace. Ordinary blob GC and restoring the ordinary data namespace do not overwrite that journal. No new provider, SDK or paid service was added. Keep it durable, private and separately replicated; never restore it to an earlier snapshot along with the ordinary database/data. Provider permissions must include the journal prefix.

For an offline restore, with APIs/workers stopped and writes frozen:

```powershell
# Export from the independent journal even if the primary DB is unavailable.
python -m bmt_backend.privacy --export-journal-ledger erasure.jsonl
# Optional additional export from a healthy primary before a planned restore.
python -m bmt_backend.privacy --export-ledger erasure-primary.jsonl
# Restore ordinary DB/data, run matching migrations, then reapply before exposure.
python -m bmt_backend.privacy --reapply-ledger erasure.jsonl --offline
python -m bmt_backend.privacy --cleanup-once
```

Reapplying revokes/removes restored identities and restarts erasure without restoring ownership or deleting retained standings. Do not reopen a restored service without a complete, trusted journal/ledger. Enforce backup expiry using `BMT_PRIVACY_BACKUP_DAYS` (default 30) in infrastructure; changing this setting alone does not configure provider backup lifecycle. Job age/journal completion and repeated cleanup errors need operational monitoring. Phase ordering is persistent erasure-plan version 1 and must not be silently reordered in a later release. Migration downgrade is refused after an erasure record exists.

## Release facts and acceptance

Configure `BMT_PRIVACY_DEVELOPER_NAME` and `BMT_PRIVACY_CONTACT_EMAIL`; the owner approved placeholders for now. Confirm actual hosting/provider names, backup/log retention, legal purchase retention and target audience against the final product. Submit matching Play Data Safety declarations including account/user/install IDs, published user content, interactions, diagnostics and any included provider SDK's processing. The implementation does not submit Play Console forms or certify legal compliance. Public-content terms/licensing, moderation and future production-ad consent remain separate launch work.

Roll out migration **0034** after the existing **0033**, matching API/worker source/dependencies and a rebuilt Android client. Preserve the independent journal through rollback/restore. Verify real Google sign-in, Android Godot/JNI credential restoration and the app/web deletion flow in the rollout environment before public acceptance. The Windows fixture uses actual DPAPI; Android platform encryption already had separate physical Keystore fixture evidence in `COMMUNICATION_M1_M6_2026_10_13.md`. No Android app export/install, real Google deletion, physical-phone flow, production migration, deployment or live storage write is claimed here.

Actual commands, final counts, screenshots, fixture corrections and the task-only source checkpoint are recorded in [review.json](evidence/account-privacy-2026-10-14/review.json). Fixtures use invented identities and disposable databases/files. Concurrent garage/terrain/livery/loading/security work is preserved and excluded from the checkpoint; generated client build stamps are validation receipts, not part of this feature patch.
