# Studio platform activation

Current backend rollout: the retained API and matching worker are at schema42, including Achievements and Challenge Club discovery. Apply the existing migration command through `0042_achievements` for this image. The platform-only baseline instructions below describe schema40. [Current deployment evidence](ACHIEVEMENTS_BACKEND_DEPLOY_2026_10_17.md) records the pinned game contract and preserved Studio data.

Deployment status: the core API/UI is now live on the retained service at schema40. [Actual rollout and checks](STUDIO_PLATFORM_DEPLOY_2026_10_16.md) preserve the current client/verifier contract. The independent watchdog, log collector, external accounts and notification delivery described below remain unconfigured; this rollout does not establish continuous monitoring or live provider integration.

This runbook prepares the implementation for review. It does not authorize a new deployment or create
external accounts. All secrets belong in the existing secret configuration, never in repository files.

## Database and matching runtime

Back up the target database using its existing procedure and verify restore evidence. Apply the existing
migration command through head `0040_studio_platform` before starting this API/worker code. It includes
the shared0037 earned-Coins,0038 News and0039 friend-publication migrations. Review those changes with
their matching client/verifier contracts; the current shared tree has newer canonical work than staging.
Do not replace pinned historical manifests or copy a fixture database into a real service.

The API and product processor must use the same source/schema. New analysis starts at activation; wait
for a received client observation and a progressing projection watermark. Existing historical totals are
still available separately. Keep `BMT_STUDIO_BUSINESS_COHORTS=false` until the population policy decision.

## Independent monitoring

Configure the API with `BMT_STUDIO_MONITOR_SOURCE_TOKENS`, a JSON object mapping each stable source name
to its separate random credential of at least32 characters. Use distinct names for the watchdog and server-log
collector. These tokens grant neither administrator nor game access.

Run `python -m bmt_backend.studio_watchdog` under a supervised service on an independent host/store:

| Setting | Meaning |
| --- | --- |
| `STUDIO_WATCHDOG_URL` | Explicit HTTPS origin of the game API. |
| `STUDIO_WATCHDOG_DB` | Its own durable SQL store, e.g. an absolute SQLite path on that host. Must differ from the API database. |
| `STUDIO_WATCHDOG_SOURCE` / `STUDIO_WATCHDOG_TOKEN` | Matching dedicated API source identity. |
| `STUDIO_WATCHDOG_ADMIN_TOKEN` | Optional read-only analyst credential for worker health; readiness works independently. |
| `BMT_STUDIO_MONITOR_POLL_SECONDS` |10–300; default30. Work/timeouts also affect actual detection delay. |
| `BMT_STUDIO_MONITOR_WEBHOOK_URL` / `BMT_STUDIO_MONITOR_WEBHOOK_KEY` | Explicit HTTPS receiver and signing key for independent outage notifications. |

The watchdog uses `Settings.from_env`, so its ordinary base configuration still needs a syntactically valid
PostgreSQL `BMT_DATABASE_URL`; it never opens that database. Its actual store is `STUDIO_WATCHDOG_DB`.
Supervise the host/process and disk capacity independently; a stopped watchdog cannot notify about itself.

For a watchdog that sends its own notifications, configure its source in the API's
`BMT_STUDIO_MONITOR_EXTERNAL_NOTIFIERS` comma-separated list. The API rejects an authority mismatch rather
than double delivering. Its source token must also be in the API source mapping. Other sources use the API
outbox and require a separately supervised `python -m bmt_backend.studio_delivery_service` with API database
and webhook settings. No notification IO occupies a canonical race verifier.

Receivers verify HMAC-SHA256 over `X-BMT-Timestamp + '.' + exact request body`, check timestamp age and dedupe
`Idempotency-Key`. A2xx response acknowledges delivery. Redirects are refused. Retry history, stable IDs,
pending leases,12-attempt exhaustion and owner retry/dismiss actions are visible for the API outbox.
Independent-host delivery receipts remain in that host's durable outbox.

Export complete structured game-API request logs with their Cloud Logging timestamps. Schedule:
`python -m bmt_backend.studio_http_metrics --jsonl PATH --complete-six-hour-export` using
`STUDIO_HTTP_URL`, `STUDIO_HTTP_SOURCE`, `STUDIO_HTTP_TOKEN`. The file must be at most64MiB and the collector
caps100,000 unique requests. Incomplete/invalid exports remain unknown. It uses closed minute boundaries,
5-minute/1-hour/6-hour windows,99.9% server-response and99% under1-second objectives,14.4x/6x burn checks
and at least100 requests per window. Review these initial objectives against real player impact before
production acceptance. No event IDs or log bodies are sent to Studio.

Accept by stopping an owned test API/dependency, observing independent delivery, restoring it, verifying
retained occurrence/recovery and closing the incident. Also test collector failure, stale evidence,
suppression, restart dedupe, receiver timeout, retry exhaustion and supervisor recovery. Fixture tests
already cover local outage/retry logic; a real hosting/receiver acceptance still needs the chosen accounts.

## Provider money and purchase delivery

`BMT_STUDIO_PLAY_PACKAGE` enables the backend verification adapter. Use existing Application Default
Credentials with explicitly granted Android Publisher access. The client first gets `/v1/billing/account`,
uses its obfuscated account ID in the actual Play billing flow, then posts product ID/token to
`/v1/billing/google-play/verify`. Retry a completion failure with the same token. The backend does not store
tokens. A missing retry can leave an acknowledged/consumed completion pending at Play even after the
idempotent server grant, so do not activate the client billing flow before testing that lifecycle and its
provider notification/refund reconciliation policy. Test purchases cannot enter the live entitlement path.

Set `BMT_STUDIO_ADMOB_ACCOUNT=accounts/pub-…` and grant AdMob report access to the configured ADC identity.
Schedule `python -m bmt_backend.studio_providers --since YYYY-MM-DD --through YYYY-MM-DD --currency EUR`.
The import covers1–31 provider calendar days, caps1,000 rows, rejects an incomplete report and appends
restatement deltas. AdMob network earnings are estimates in `America/Los_Angeles` report dates; they are
neither settled receipts nor player LTV. Use a supervised schedule and inspect latest-import age.
No owner-supplied screenshot, catalogue price or client request becomes verified monetary revenue.
Coin movement history starts with this migration. Existing balances receive a labelled opening snapshot
on their next wallet access; previous earning/spending history is not invented or backfilled.

Primary contracts:
[Play product proof](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.productsv2),
[Play acknowledgement](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.products/acknowledge),
[Play consumption](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.products/consume),
[AdMob reporting](https://developers.google.com/admob/api/reference/rest/v1/accounts.networkReport/generate),
[AdMob metrics](https://developers.google.com/admob/api/v1/report-metrics-dimensions).

## Staff and controlled presentation changes

Configure separate `BMT_STUDIO_STAFF_AUDIENCES` and `BMT_STUDIO_STAFF_SUBJECTS`, a JSON subject mapping to
`{"name":"…","role":"owner"}` or analyst. Staff audiences must not overlap game sign-in audiences.
`BMT_STUDIO_STAFF_REQUIRE_MFA=true` requires signed `amr` evidence containing `mfa` or `otp`; ordinary
Google ID tokens may not supply it. Choose and validate the identity policy before claiming staff MFA
works. Current sign-in accepts the resulting identity token in the tab; a dedicated browser SSO flow
remains future integration work. Allowlist removal revokes access immediately. Disable legacy keys with
`BMT_STUDIO_LEGACY_KEYS_ENABLED=false` only after the replacement access path has been tested.

Create a draft presentation experiment under Administration. Its immutable variants use only the allowed
onboarding message, offer-layout or store-order registry. Activation does not deploy or change native UI.
Clients must call `POST /v1/experiments/assignments`, apply a supported setting, then record its actual
exposure. Never record assignment retrieval as exposure. Pause/stop removes active delivery. Existing
assignments stay stable. Start with an A/A test; inspect sample ratios, consent, maturity and complete
quality/revenue guardrails before any optimisation decision. Scorecards do not automatically pick a winner.
