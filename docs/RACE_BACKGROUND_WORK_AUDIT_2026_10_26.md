# Work performed during an active race — 2026-10-26

The current client does **not** satisfy a strict “only race work while racing” policy. The clean-state probe made no network requests from the tested background timers, and the parked Garage and its reflections were disabled. However, prior-run uploads/status checks, old challenge/rivalry results, pending appearance/purchase recovery, and an achievements refresh on focus return can still run during a new race. A retained Garage also keeps the editor memory inventory active every second.

This task checks behavior; it does not change runtime code, deploy the backend, or claim that these paths cause an observed hitch. The only new executable is an isolated audit fixture.

## Findings and recommended treatment

| Priority | Work that can run during racing | Evidence | Recommended treatment |
| --- | --- | --- | --- |
| First | Previous-run outbox scanning, upload/retry and status checks | App's one-second timer calls `cloud.flush_outbox()` without a race guard. A private existing-run journal produced `/runs/status?ids=audit-existing-run` during the active race. Backoff still limits actual requests; this is not one HTTP request every second. | Defer old-run network delivery and status reads until a menu/result boundary. Preserve immediate durable capture of the current result and existing account/idempotency fences. Guard completion callbacks too: the result-save queue and long-poll completion can also start a flush. |
| First | Previous challenge/rivalry result polling | The App's half-second timer produced both `/challenge-results/audit-old-challenge` and `/rivalry/tickets/audit-old-rivalry/result` with an active game. Each client retains its own polling delay/backoff. | Defer remote polling while driving; consume already cached completion receipts locally when needed. Restart due work once on return. |
| First | Pending appearance and coin-purchase recovery | Forcing the existing due timers produced `/me/appearances`, `/economy`, and `/economy/purchases`. Appearance's race guard applies only to clean polling. The economy timer retries pending purchases every 15 seconds when idle. | Schedule background recovery between races. Preserve the original operation keys, pending journals and authoritative server outcomes; do not discard a transaction or interrupt an explicitly requested operation. |
| Small periodic cleanup | Retained Garage/editor memory inventory | `App._process()` calls `editor_memory.tick()` whenever a retained Garage exists. The probe observed natural samples during the race, then timed three forced-due samples. The inventory walks retained resources and may trim caches when over budget. | Skip ordinary inventory while driving. Continue to handle a real memory-pressure notification and avoid joining a live preparation worker. |
| Small periodic cleanup | Empty signed-in outbox checks | The outbox still performs migration/path/pending-directory checks with no jobs. Eight warmed, empty checks were timed before installing the pending-job fixture. | Park this timer's optional work during a race rather than repeatedly checking an empty queue. |
| Small cleanup | Hidden menu processing and focus refresh | Ordinary race entry hides `root_ui` without disabling its processing. TrackBrowser and its search drawer still receive frame callbacks; the browser's preparation-hint path returns when hidden. Focus-in/resume calls achievements refresh without a race guard; the probe reproduced `/achievements`. | Suspend the hidden menu's optional processing with an explicit restore on exit/results. Defer the achievements refresh while driving. Preserve scene cleanup, account-change handling and menu return behavior. |

The hidden menu callbacks observed here mostly return early. Their existence is not evidence of hidden full-frame rendering or a major CPU bottleneck. The tutorial controller, local result-save queue and resume recovery also remain processing: tutorial/rewind assistance, saving a result, and recovering ownership of a charge require more selective treatment than disabling the entire App.

## Work already controlled

- Product telemetry and game-configuration transport are disabled during an active attempt. Telemetry's pump returns before queue persistence/upload; an in-memory heartbeat and bounded quality counters can remain. Configuration's explicitly requested rewarded-ad permission path is separate from ordinary background refresh.
- The retained Garage cannot process. All three inspected SubViewports—the showroom and two reflection views—had `UPDATE_DISABLED` and could not process.
- Creation-slot refresh and publication processing have active-game guards. Normal discovery and clean appearance refresh do not start ordinary race-time fetches on the tested path.
- Ghost playback in the race is local presentation; it is not a per-frame ghost download. Previously started menu/network work may still complete. Bounded speculative comparisons are not a global network barrier: `cancel_speculation()` removes queued speculative jobs, not active requests.
- Vehicle-condition checkpoints use the small, deduplicated condition store and its low-priority writer. This is legitimate persistence rather than a periodic dump of the whole account/save file. Canonical simulation, input evidence, rewind history, driving effects and race HUD/audio updates are required race work.
- Release hitch diagnostics use compact fixed storage on ordinary frames. Detailed dictionary/context collection defaults to debug builds. The probe compared both modes on the same game; there is no finding that release performs the full debug collector by default.

## Reproduction and measurements

Fixture: `game/tests/audit_race_background_work.gd`. It starts the real App, opens and parks a real Garage, starts an offline race on the first installed circuit (Ellipse), then installs a synthetic signed-in client. The fixture supplies only a private in-memory publication identity to pass the normal published-track entry guard; it publishes nothing. Both `request_api` and the lower `_send` boundary are intercepted and return a synthetic 503. Production App callbacks and the service methods being audited run unchanged.

Each invocation uses private `APPDATA`, `LOCALAPPDATA`, records, library, outbox, purchase journal and synthetic session paths under `build/race-background-work-audit-2026-10-26`. No real credentials, account sessions, owner save files or live HTTP endpoints are used. The audit does not restart the owner's App process.

The pending-operation cases explicitly emit each existing timer's timeout once or force a throttle due. They prove that a code path can execute while racing. They do not estimate production request rates, successful response decode costs, storage totals, bills, capacity or mobile frame rates. The fake server's 503 exercises retry preservation rather than inventing successful purchases or verified results.

Headless run, Godot `4.7.2.stable.official.ed1daf0bf`, 60-fps cap:

- **15 checks, zero failures**, process exit 0; 23.26 seconds including App/Garage/world preparation.
- Unpaused simulation advanced 299 ticks over the 2.5-second guest measurement. This first run was stationary; the native follow-up enables the real accelerator input.
- Three forced-due Garage/editor memory inventories: **0.812, 0.881 and 1.122 ms** on this desktop. Estimated retained Garage allocation was 72,871,292 bytes; general retained allocation was 61,013,024 bytes. These are the code's resource estimates, not measured device/GPU allocations. No cache trim occurred.
- Eight warmed empty outbox checks: **0.433–0.824 ms**, median **0.534 ms**. These are total observed callback durations on this machine, not portable per-device guarantees.
- Hitch observer's own callback: detailed **19,228 µs / 90 frames = 0.214 ms/frame**; compact **1,706 µs / 90 frames = 0.019 ms/frame**. This excludes work outside the observer callback, including stage-timing instrumentation, render-signal sampling and any asynchronous writer.
- No synthetic HTTP calls in the clean due-timer probe; each pending/focus case reproduced the paths listed above.
- All 17 audited production source hashes matched between the beginning and end of this run. Each run records its own hashes because concurrent workspace work continues.

Native desktop follow-up, Windows OpenGL Compatibility on NVIDIA GeForce RTX 3090, 60-fps cap:

- **16 checks, zero failures**, process exit 0; 83.08 seconds including preparation. Together the two final runs passed **31 checks**.
- The fixture held the real `accelerate` input. Simulation advanced 298 ticks and the car moved **42.178 metres** during the 2.5-second sampled interval.
- The same clean/pending/focus request observations reproduced. All three parked Garage viewports were disabled.
- Three forced-due memory inventories took **0.843, 0.872 and 1.126 ms**; eight empty outbox checks took **0.352–0.626 ms**.
- Observer callback totals: detailed **11,295 µs / 90 frames = 0.126 ms/frame**; compact **843 µs / 90 frames = 0.009 ms/frame**. These are diagnostic callback measurements, not total race-frame or GPU timings.
- All 17 audited production source hashes matched between the beginning and end of this run as well. Separate start/end hashes are in `runtime-native.json`.

The headless renderer cannot establish GPU cost; the native run confirms the viewport/control behavior with a desktop renderer but is not a full GPU workload profile. Neither run is Android/device acceptance or a five-lap capacity test. Weather/biome variants, every race mode, successful large responses, background OS throttling and sustained low-memory operation remain outside this bounded probe.

Exact commands, isolated environment paths, stdout and stderr are retained under `build/race-background-work-audit-2026-10-26/`; evidence copies and a machine-readable index accompany this report. The native follow-up uses a separate desktop window positioned offscreen. No owner-window input is sent; accelerator injection is internal to the fixture's Godot process.

The initial fixture attempt exited 1 because it lacked the required publication metadata and App correctly declined race entry. Only the fixture was corrected. Its logs and the intermediate 14-check successful run are retained. The successful headless process also emitted Godot's root-certificate-store error during engine initialization; there were no script errors and no real HTTP transport was used.

## Proposed implementation boundary

Use an explicit active-driving policy for optional background work, shared by periodic timers **and** completion-triggered work. Defer old uploads/polls, background wallet/appearance/achievement refreshes and ordinary memory inventory. On results/menu return, release one coalesced due task per service with existing backoff and bounded concurrency. Account changes must invalidate deferred work; original journals and idempotency keys must survive.

Keep current-race durable saves, requested rewind/charge settlement, essential authentication/account safety, actual memory pressure and active tutorial guidance available. Validate race-to-pause/results/menu/retry, focus return, account switching and purchase/upload recovery before shipping that policy. This audit has not implemented or deployed it.
