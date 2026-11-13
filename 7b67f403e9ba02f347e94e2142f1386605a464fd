# Histogram and track-detail request reuse

Free Race now reuses a fresh, matching personal comparison instead of downloading it again. The server supplies the durable histogram's generation time and absolute expiry. That expiry follows the existing population-dependent worker cadence: about five minutes at 100 drivers, fifteen at 1,000 and forty-seven at 10,000, capped at an hour. Receiving the same old snapshot again cannot restart its deadline.

| Requirement | Resulting behavior |
| --- | --- |
| SRR01 histogram freshness | The private cache matches the track revision, car/configuration, rules/compiler/engine contract, actual backend/account/population scope, candidate times and both personal bests. Fresh matching race/lap PBs need no histogram request. Expiry, race PB improvement and flying-lap PB improvement independently trigger refresh. Legacy servers keep a bounded ten-minute fallback. |
| SRR02 result positions | A slower result still has its own position. With unchanged PBs and a fresh retained frame, the request sends its exact histogram key; the server returns current candidate positions and metadata without repeating the bins. A changed generation/frame returns a full response. The client validates the merged pair atomically and retries a corrupt omission once without the optional hint. |
| SRR03 leaderboard size | The preloader and direct detail path request `limit=3`, matching the three visible standings. The full paginated High scores list is fetched only on explicit opening. Refreshed previews are shared; their separate ten-minute lifetime does not renew histogram age. |
| SRR04 unused speculation | Departure, preview demotion, list return and browser cleanup clear queued speculative jobs. Startup/account/car events on other screens no longer start unused Free Race statistics. Already-started shared reads can finish; explicit foreground consumers remain usable. The retained two-track/three-active-job bounds remain. |
| R01 preservation | Keep the 650-ms selected-track preparation, exact document/ghost caches, accepted two-viewport discovery reserve, geometry, rendering, personal-best/race validation, competitive standings, rewards and account transaction fences. |
| Q01 evidence | Retain focused native/HTTP checks, both desktop renderers, old-source controls, source hashes and a task-only patch. No device test, deployment, owner-process restart, staging or commit. |

## Implementation

`backend/bmt_backend/histogram_snapshots.py` exposes existing snapshot timestamps through an optional metadata output, retaining the previous three-part return contract. `runs.py` adds optional `freshness` and `histogram_key` fields and accepts `known_histogram`. Only an exact board/generation/grid identity omits both bin arrays; candidate tick positions still use the existing checker and large-population approximation rules. Full replies remain compatible with older clients. Schemas are [full comparison](schemas/results-comparison-v1.schema.json) and [position-only comparison](schemas/results-comparison-overlay-v1.schema.json).

`histogram_http.py` compresses negotiated compact replies when beneficial, including replies below the global 1-KiB threshold. Otherwise a shorter decoded response could use more wire bytes than the already-compressed full response. These representations use private weak validators and consistent `Vary` metadata. Identity-only clients receive ordinary JSON; `gzip;q=0` is respected for these compact responses.

`comparison_reuse.gd` centralizes freshness, PB matching, frame hints and omission merging. `comparison_preloader.gd` owns bounded persisted packets, coalesced foreground comparison reads and queue cancellation. Its disk envelope binds the actual service/account/population identity as well as the caller's scope. Earlier envelopes miss once under the stronger namespace; player saves and downloaded track documents need no migration. Receipt timestamps remain unchanged when only leaderboard data changes. Failed, future-clock, expired, malformed and wrong-account values cannot count as fresh comparison hits.

`track_browser.gd` consumes the shared packet and preserves local/verified PB alignment. `race_complete.gd` uses the same cache supplied by App: it retains the bars for a non-improving race while displaying that race's own position and marker. Account changes fence cached hits and in-flight replies even before the main identity callback reconfigures the views. Existing scene construction, chart resolution, labels and layout remain.

## Measured result

The disposable two-driver HTTP fixture returned **2,430 decoded / 600 compressed body bytes** for a complete comparison and **869 decoded / 373 compressed body bytes** for the matching position-only reply: **37.8% fewer body bytes** in that fixture. These numbers exclude HTTP headers and do not forecast player-day traffic or provider bills. The largest request reduction is a fresh matching PB: the fixture's initial histogram read is reused by later detail consumers, with zero additional comparison reads until a relevant change or expiry.

The native fixture also verifies actual result-page marker/position binding, independent race/lap PB changes, restart persistence, same-caller-scope account changes, clock/expiry boundaries, corrupt omission fallback, frame changes, repeated leaderboard consumers and cancellation followed by a valid foreground read. The final per-suite counts and source hashes are recorded in [report.json](evidence/statistics-request-reuse-2026-10-26/report.json). Actual mock browser captures are [Compatibility](evidence/statistics-request-reuse-2026-10-26/cache-detail-gl_compatibility.png) and [desktop Mobile](evidence/statistics-request-reuse-2026-10-26/cache-detail-mobile.png); their fixture names and standings are not live player records.

## Validation and controls

All native commands use the pinned Godot 4.7.2 through `scripts/dev.ps1` with isolated `APPDATA`. The focused script is `res://tests/test_statistics_request_reuse.gd`; it was also run with `-Graphical -RenderingMethod gl_compatibility` and `mobile`. Retained checks cover instant/personal/carousel/startup histograms, results histograms, download caches, App and script parsing. Logs contain the actual commands' build identities and outcomes.

The backend command runs `test_statistics_request_reuse.py`, `test_histogram_snapshots.py`, `test_histogram_followup.py`, `test_compact_histograms.py` and `test_population_batch.py` with `-k 'not postgres and not test_migration_backfills_snapshots_without_rewriting_results' -m 'not godot'`. The real local five-lap verifier case was run separately with isolated app data and permitted native engine access. The protocol fixture additionally checks conditional replies, compression negotiation and exact full/omitted-grid equivalence.

The original carousel test expected six queued targets despite the task-start production cap already being two. Its original 20-check/one-failure result reproduces with the exact task-start preloader loaded separately. Only that superseded count is updated to two; target replacement, foreground priority and other guards remain. The backend migration test still fails at the existing `0054` downgrade guard, identically with task-start modules executed only in memory. Both original failures and controls remain in evidence.

Initial native findings included an unconfigured mock adapter and a freed-service callback; those lifetime/configuration guards were corrected. A sandboxed verifier initialization failed, then passed with isolated native access. A later concurrent Rivalry edit briefly referenced an undeclared polling callback; that file was preserved and its concurrent declaration resolved the parse error before final checks. PostgreSQL calibration was unavailable; no database service was started or changed.

## Remaining acceptance

Reload/rebuild the client and roll out the matching API to use server-directed expiry and smaller position replies. Older APIs retain bounded full-response behavior. This task performs no deployment. Owner/device navigation, touch, slow-network and loading-performance acceptance remain; desktop renderer checks do not establish phone latency or production request frequency. No attachment check, physical-device test, APK/AAB, real authentication/purchase, live account/backend mutation, owner-process restart, staging or commit was performed.

The scoped patch excludes concurrent App/profile and other independent work. Generated development build identities are command artifacts, not feature changes.
