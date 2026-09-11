# API contract sketch — v1 design, not implemented endpoints

All online calls use HTTPS, bounded JSON and authenticated player context where required. Public reads must never expose private drafts, purchases or account email. Server time is UTC; times used for scoring are integer milliseconds. A UUID operation key is required on writes; repeat keys with different payloads are a conflict. The service enforces its own limits regardless of client validation.

| Method / path | Purpose | Essential response / failure |
|---|---|---|
| GET /v1/bootstrap | Compatibility, rules versions, server time, current season | supported versions, minimum client, no secrets |
| GET /v1/me/garage | Canonical credits, vehicle XP, owned parts and revision | revision, pending claim IDs, entitlements |
| POST /v1/me/upgrades | Install an earned part atomically | expected revision, part ID; insufficient XP/credits/class conflict |
| POST /v1/run-tickets | Authorize a pinned practice/league challenge | run ID, manifest hash, expiry, signed opaque ticket |
| POST /v1/uploads | Scoped bounded replay/track upload | content hash, byte limit, expiry, opaque upload location |
| POST /v1/runs | Submit ticket and replay evidence | 202 verifying or existing identical result; never accept client rewards |
| GET /v1/runs/{id} | Fetch verification/reward status | pending / verified / rejected + reason + ledger revision |
| GET /v1/boards/{key}/distribution | Global PB histogram/rank | population, bins, edges, own rank, snapshot ID, generated time |
| GET /v1/boards/{key}/neighbours | Nearby faster/slower racers | ordered best results, ties, ghost availability, own row |
| POST /v1/tracks | Create hosted track identity | free/purchased quota enforced atomically |
| POST /v1/tracks/{id}/versions | Publish immutable bounded geometry | hash, validation job, creator completion proof; unsupported schema |
| PATCH /v1/tracks/{id} | Metadata/archive visibility | ownership and moderation check; preserves pinned active versions |
| POST /v1/challenges | Pin rules, track and target ghost | challenge code and share path; no invented guarantee of deferred install routing |
| GET /v1/challenges/{code} | Recipient preview and eligible manifest | available / removed / blocked / incompatible / expired |
| GET /v1/leagues/current | Events/cohort/standing | event manifests, server deadline, provisional/settling flag |
| POST /v1/purchases/verify | Validate native Play purchase | pending / verified / invalid; server-derived entitlement |
| POST /v1/reports | Report track/name/player content | private case ID; abuse/rate limits |
| POST /v1/blocks | Block a player | suppress owned content/social exposure according to policy |
| POST /v1/account/deletion | Request deletion with confirmation | receipt, scope and retained legal/security exceptions explained |

## Write envelope

`operation_id`, `schema_version`, `expected_revision` where applicable, and a specific typed payload. Never put an arbitrary command name into a generic admin executor. Return request correlation ID, a stable machine-readable error code and a localizable message key. Do not return stack traces or service credentials.

## Error families

400 INVALID_INPUT; 401 AUTH_REQUIRED; 403 NOT_OWNER / NOT_ELIGIBLE; 404 NOT_FOUND; 409 REVISION_CONFLICT / IDEMPOTENCY_CONFLICT; 410 REMOVED_OR_EXPIRED; 413 PAYLOAD_TOO_LARGE; 422 INVALID_TRACK / REPLAY_REJECTED; 429 RETRY_LATER; 503 TEMPORARILY_UNAVAILABLE. Distinguish a retryable verification delay from a rejected race.

## Distribution response semantics

`population` counts one verified PB per unique player under this exact key. `bin_edges_ms` has one more element than `counts`; totals equal population. Include tie-aware `strictly_faster`, `rank`, current PB and sample snapshot. Small populations (<20 proposed) return ordered samples rather than a misleading smooth histogram. Current unsuccessful attempts do not replace PBs. Friends is a filtered PB population, not a separate scoring rule.

## Security and retention

Object names use opaque IDs/content hashes, not email or display names. Scoped signed URLs expire. Server verifies ownership before issuing URLs, MIME/type and decompressed bounds before ingestion, and the actual data hash after upload. Enforce storage/query quotas and row-level access. Purchase tokens require server verification and reconciliation (S15). No open-ended user-controlled SQL, filesystem paths or scripts. Retention and deletion implementation must be approved before release; this sketch is not a legal policy.
