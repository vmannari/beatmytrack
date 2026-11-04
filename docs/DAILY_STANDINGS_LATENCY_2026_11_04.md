# Today's standings loading investigation — 4 November 2026

**DSL01–DSL03: evaluation only.** The reproduced delay is the wait for a usable server lap-comparison snapshot, amplified by the card's five-second retry interval. Individual requests are fast. No runtime fix or deployment was requested or performed.

## Measured time

The existing cloud API serves today's **Over and under**, day 20761, version `af60541d-3308-5606-a891-f5b893dda7f5`. At 07:36 Helsinki, all five `/track-of-the-day/limits` responses were ready, but Compact, Forklift, Hovercraft and Kart initially returned **503 `LAP_STANDINGS_PREPARING`, Retry-After: 5** from `/lap-standings`. Electric had already been requested earlier. Every car returned standings on subsequent probes. These are public, unauthenticated GETs; there were no sign-ins, score submissions or administrative writes. As in normal game reads, missing-snapshot GETs can enqueue background refresh interest and warm the snapshot.

| Stage | Actual evidence |
| --- | --- |
| Daily metadata | 314 ms in the retained matrix run; an earlier direct GET took 176 ms |
| Medal limits | 15/15 ready; median 194 ms, range 166–773 ms |
| Successful standings requests | 23/23 successful after excluding seven preparation replies; median 211 ms, range 166–636 ms |
| Preparation replies | Seven across top/nearby probes; median 238 ms, range 175–629 ms |
| Cloud service request latency | 51 logged daily GETs: 42 success responses, median 30.3 ms; nine 503 responses, median 28.4 ms; all service latencies 21.2–61.0 ms |
| Actual card rendering, desktop Compatibility | 4.4–9.1 ms total across three `_render` calls per measured scenario |
| One preparation reply, actual card | 5.422 s total: 403 ms in synthetic requests, **5.019 s in retry/frame waits** |
| Three preparation replies, actual card | 15.831 s total: 820 ms in synthetic requests, **15.011 s in retry/frame waits** |
| Matching card cache | Restored synchronously in 4.4–5.7 ms before the delayed refresh finishes |

The public request measurements include a new curl connection per GET. Successful standings had median component times of 15.2 ms DNS, 20.0 ms additional TCP connection, 63.2 ms TLS, 103.2 ms from TLS completion to first byte, and 0.77 ms body transfer. Component medians are independent and need not sum to the median request time. Cloud latency measures the service request span, not an isolated SQL profile. Neither represents the owner's device network timing.

Most significantly, bounded cloud logs contain a matching sequence **before this investigation's probes**:

| Helsinki time | Electric standings | Cloud latency |
| --- | --- | --- |
| 07:33:06.918 | 503 | 53.6 ms |
| 07:33:07.366 | 503 | 49.9 ms |
| 07:33:12.590 | 200 | 55.5 ms |

The final two requests start **5.223 seconds apart**, matching the client's five-second preparation timer plus request overhead. The first preparation request to the successful request spans 5.672 seconds. Logs do not establish the device/account or why two initial calls occurred; no player identifiers are retained. This sequence directly supports the retry explanation without attributing all latency to an inferred database slowdown.

## Where the wait comes from

1. `game/ui/track_of_day_page.gd::refresh` waits for `/track-of-the-day`, then `_show_track` configures the result card. The standings call is a second request. Cached track metadata can skip the first request; matching card rows can display before the second finishes.
2. `game/ui/daily_result_card.gd::refresh` calls `/track-of-the-day/lap-standings` for the selected car. It keeps the loading state for preparation responses, sleeps for the supplied `Retry-After` (clamped to 1–30 seconds), and makes at most four attempts. Ordinary missing snapshots therefore add **5, 10 or 15 seconds** of timer waits. A `LAP_LIMITS_PREPARING` response can instead request 30 seconds and add up to 90 seconds of waits. The latter was **not observed** here.
3. `backend/bmt_backend/daily_standings.py::flying_standings` first resolves the day's fixed limits, then independently loads a durable histogram/lap snapshot. No generation, invalidation, or an incompatible board fingerprint makes the standings unavailable. It schedules demand and immediately returns 503 with Retry-After 5; it does not synchronously build the standings.
4. `histogram_http.py::schedule_demand` queues bounded background interest after the read transaction. `histogram_snapshots.py::refresh_one(active_only=True)` requires that demand, claims a lease, completes any prerequisite lap-best backfill, and publishes the snapshot. `worker.py` gives this background role turns when idle and reserved turns every sixteen completed foreground jobs. Queue/backfill/build work can extend readiness beyond one retry interval.
5. Daily publication (`track_of_day.py::step`, `daily_fixed_limits.py::prepare`) computes and stores the medal cutoffs separately. It does **not** require all five standings snapshots to be ready or maintain demand for them. Consequently, ready track art/medals do not imply ready standings. All five limits were ready while four cars' standings were unavailable in the live sample.

The selected snapshot was usable for Compact by the next sampled request, 4.72 seconds after its first failed request began. That is a sampled readiness bound, not the exact build duration: probes were interleaved across five cars. Snapshot metadata was not queried directly, so this review does not distinguish never-built versus invalidated versus fingerprint-mismatched rows. The structural dependency and the observed preparation/timer waits are confirmed. No `histogram_refresh_failed` or `histogram_demand_failed` entries were returned by a bounded error-log query from 00:00 UTC to collection time; this is not proof that every worker/background operation was healthy.

The ordinary authenticated GET path goes through `_coalesced_read` and `_authenticated_read` without the mutation `_busy` queue. A 401 can enter session renewal and wait for that queue, but sign-in/session renewal was not exercised. Normal response size was only 1.5–2.3 KB, and rendering and body transfer were small in these measurements.

## Recommended change, in priority order

1. **Warm the featured track's five standings snapshots in background work before players enter.** Add bounded demand for the exact daily version and enabled population during daily publication/maintenance, and retain or renew that interest for the day. Keep the existing invalidation, manifest, moderation and result-isolation fences. This removes the first-view dependency on a player's GET without moving aggregation into requests or scanning the full catalogue.
2. **Shorten preparation retry granularity after measuring worker readiness.** Five-second sleeps impose up to almost five seconds of avoidable delay after a snapshot becomes ready. Adjust the server/client retry contract together, with bounded attempts/deadline and cancellation. Do not simply increase retries or weaken unavailable-snapshot checks.
3. **Add a distinct daily diagnostic category and stage timings.** Existing network health classifies `/track-of-the-day/*` as `other`; the race-load profiler does too. Record snapshot availability/reason, demand-to-claim, build duration, and client retry wait separately without account identities or player-facing diagnostic text.

A separate observation: the deployed candidate/nearby endpoint still returns at most two competitors for the Compact limit-7 probe. The November 3 local card change requests six. This agrees with its documented pending backend rollout; it is not the cause of the loading delay.

## Commands, verification and artifacts

DSL01 traces the metadata → card → snapshot → demand → worker path. DSL02 measures public GETs and bounded service logs. DSL03 profiles the actual card with controlled preparation responses, without network access or owner data.

```powershell
python scripts/profile_daily_standings.py --url https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app --output docs/evidence/daily-standings-latency-2026-11-04/public-timings.json --rounds 3
python docs/evidence/daily-standings-latency-2026-11-04/read_cloud_timings.py
python docs/evidence/daily-standings-latency-2026-11-04/run_native.py
.tools/backend-secure-venv/Scripts/python.exe -m ruff check scripts/profile_daily_standings.py docs/evidence/daily-standings-latency-2026-11-04/read_cloud_timings.py docs/evidence/daily-standings-latency-2026-11-04/run_native.py docs/evidence/daily-standings-latency-2026-11-04/checkpoint.py
python docs/evidence/daily-standings-latency-2026-11-04/checkpoint.py
```

The public matrix retains **46 GETs: 39 HTTP 200, seven expected preparation 503s**. The cloud query retains 51 sanitized request summaries, including the earlier matching sequence. The native runner uses pinned **Godot 4.7.2**, Compatibility on the PC, the required crash-dialog wrapper, Dummy audio and isolated APPDATA/LOCALAPPDATA. All **three scenarios pass with native exit 0**. Synthetic responses nominally wait 200 ms each; the first ready request measures only 53 ms because the first engine frame/timer consumes startup delta. Use the measured request durations; it does not affect the independently measured five/15-second waits. The preceding native run also completed all scenarios; its PowerShell pipeline returned 1 after reporting the existing certificate-store error. The repeat runner records the native return code explicitly and preserves both logs. No failing assertion or timing gate was weakened.

Initial diagnostics are retained as limitations: sandboxed curl could not reach the cloud host, and normal network access was required for public reads; localhost port 18181 returned 404 for the daily endpoint and was not used as evidence about the deployed backend. A first gcloud query failed certificate verification; the existing workspace CA bundle restored verified TLS. A PowerShell invocation then lost filter quoting; the Python SDK argument-list runner succeeded. Initial scoped Ruff found two import-order and two missing explicit subprocess-check findings; these were corrected, and the final scoped check passes. The native Windows certificate-store warning remains in the successful run. `scripts/dev.ps1` was inspected; the isolated direct runner follows the preceding task's documented pinned-engine fallback and avoids regenerating shared build identity. `git diff --check -- AGENTS.md DEVELOPMENT_STATUS.md docs/PHASE_0_PLAN.md` reports an existing extra blank line at the status document's EOF; this task only prepends its marked summary and preserves that concurrent content.

New diagnostic files: `scripts/profile_daily_standings.py`, `game/tests/profile_daily_standings_latency.gd`, this report and its evidence directory. Shared AGENTS/status/plan receive only a task summary. The checked task patch includes these additions and summaries, with an isolated index and exact forward/reverse verification; it excludes unrelated concurrent work. Public GET bodies/player rows are not retained. [Public timings](evidence/daily-standings-latency-2026-11-04/public-timings.json), [cloud summaries](evidence/daily-standings-latency-2026-11-04/cloud-request-timings.json), [native timings](evidence/daily-standings-latency-2026-11-04/native-card-timings-repeat.json), [native log](evidence/daily-standings-latency-2026-11-04/native-card-repeat.log).

No phone/device query or test, APK/AAB, owner-save/process change, real authentication/purchase, deployment, administrative database write or main-index write was performed. Runtime sources and competitive results remain unchanged. Authenticated/device-specific overhead and exact worker queue/build durations remain unmeasured; the recommendation is not an implemented speedup.
