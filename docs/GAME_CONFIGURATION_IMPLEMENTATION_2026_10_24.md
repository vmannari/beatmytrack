# Game Configuration implementation

2026-10-24. Local implementation of RGC01–RGC11 from the [interface specification](GAME_CONFIGURATION_INTERFACE_SPEC_2026_10_24.md), following the owner's subsequent instruction to implement the app, backend and Studio controls. A/B testing is included in this implementation.

Open **Studio → Administration → Game Configuration**, or **Administration → A/B testing**. The routes are `/admin#studio?tab=config` and `/admin#studio?tab=experiments` on the configured Studio service. Production Studio retains the separate private service and named staff/MFA requirements from the concurrent security changes.

## Controls available now

| Area | Implemented controls |
| --- | --- |
| Advertising | Master permission, automatic ads, completed-race and active-time thresholds, OR/AND trigger, first-ad delay, minimum races/time between ads, cooldown after actual rewarded presentation, session cap, rewarded Resume availability. |
| Menus | New challenge creation and new Weekly Rivalry entry availability, menu notice and expiry. Existing entered competitions and promised resumes retain their contracts. These are client entry controls, not replacements for domain authorization. |
| Store | Ordering of the five existing offers, with typed Move up/down controls. Prices, ownership and purchase fulfillment remain with their existing authorities. |
| Audiences | Platform sets, exact compatible build IDs, required client capabilities, signed-in/guest state, server-read ad-free ownership, explicit internal account IDs, priority and bounded overrides. Equal-priority overlapping changes to the same key are rejected. |
| Releases | Drafts, active-vs-draft comparison, validation, internal/5%/25%/100% nested rollout, UTC scheduling, pause expansion, cancel schedule, history, restore under a new generation, restrictive emergency switches. |
| Inspection | Effective player preview, source of each value, ad eligibility and local session timeline, last reported applied groups, redacted policy download, audit history. Real-player previews are audited. |
| Experiments | A/B, A/A and A/B/n with 2–4 arms; editable allocations, enrollment, audience, hypothesis, fixed follow-up, minimum mature sample, ads/menu/Store settings; start, pause, complete, scorecard and promotion into a reviewable draft. |

The built-in cadence remains **3 completed ordinary races OR 10 active foreground minutes**. Master and automatic remote ad permission default off. The alternative **4 races AND 6 minutes** can be saved as a draft; it was exercised only in isolated fixtures. No policy was published to an existing service.

Completed-race counts exclude practice and creator test finishes. Background, pause, result-screen and fullscreen-ad time do not contribute to active play. An unavailable/failed show retains the due counters. Only an actual interstitial show resets spacing and consumes the session cap; changing policy never resets consumed usage. Rewarded cooldown starts at presentation independently of earning a reward. The cooldown has its own bounded elapsed clock, so it can expire even after the session clock reaches its saturation bound.

## Delivery and authority

`GET /v1/game-config` supplies a complete schema-1 policy resolved from the immutable release, matching audiences, committed account assignments, ownership protections and emergency restrictions. Unsupported capabilities receive safe defaults. Signed-in cohorts are deterministic and nested; guests receive the baseline/fallback without an invented persistent experiment identity. Invalid bearer credentials return an authentication error instead of silently becoming guests.

`GET /v1/game-config/emergency` supplies a small restrictive permission lease. The app fetches full policy on startup/foreground and approximately every 30 minutes with jitter, and renews the emergency lease approximately every 110 seconds in safe states. Requests are bounded to 64 KiB and three seconds. Ordinary configuration transport is cancelled/deferred during loading and driving. At a result after a long race, the app can renew the expired emergency lease before its ad decision, then rechecks that the same result remains visible. An explicitly requested paused rewarded offer can also renew this small lease. Neither path applies a new race policy during driving.

The cache uses the existing atomic storage helper on an owned low-priority thread. Origin, account and measurement-consent scope fence cached data and late replies. A complete valid non-experiment cache can restore without a reachable configuration service for at most seven days. Cache restoration does not renew ad permission. New ad settings apply at an ordinary race result; menu settings at entry, and Store exposure after offers become visible. Expired/corrupt/unsupported data retains the valid group or returns to built-in defaults. Older servers without this negotiated protocol retain the existing development-ad path; a negotiated remote policy requires fresh permission.

This adds no code, SQL, URL, physics, car handling, race-rule or reward expression field. Valuable actions still use their original server transactions and receipts. Banked/free resumes and in-flight recovery are not revoked by hiding a rewarded offer. Existing paid ad-free ownership suppresses automatic ads. Production provider IDs, consent and signed reward fulfillment are still separate prerequisites: the existing AdMob bridge remains debug/demo only.

The backend uses `0060_game_configuration` for four bounded-purpose tables and additive experiment metadata/counters. The migration contains frozen DDL. Subsequent concurrent migrations `0061`/`0062` remain in the chain. Draft/publication/experiment commands share a serialized control lock, compare revisions and audit command IDs. Configuration command retries return their recorded result. Reads use coherent database snapshots. A bounded worker check activates due schedules and revalidates base generation and experiment conflicts; changed prerequisites mark a schedule blocked. The restricted worker updates existing administrative control metadata and does not create it.

Public configuration and experiment-assignment routes remain on the gameplay API, while administration routes and assets remain on the private production Studio workload. The concurrent database-role grants include the configuration tables and limited scheduler updates. This task did not change production role enforcement.

## Experiment behavior

Assignments use the existing experiment service and signed-in account identity. They remain stable across supported devices, and allocation does not change after registration. Enrollment requires both server measurement eligibility and client measurement opt-in. One active experiment occupies each exclusive layer, `ads` or `presentation`. Each experiment uses one actual application boundary; mixed menu/Store bundles are rejected.

Creating an experiment pins its baseline generation, common policy and protected keys. A partial release or intersecting audience override blocks activation; changing a protected baseline while an experiment is active requires pausing it. The master advertising permission is never an experiment variable. This prevents a control/treatment comparison from quietly changing its common conditions.

Fetching or assigning does not record exposure. The client records exposure when the applied policy can affect the relevant decision. Ad controls, including a no-automatic-ad control, are exposed at the same eligible result before variant-dependent frequency, delay or cap checks. Shared entitlement, native support and emergency gates precede this exposure. Menu and Store experiments use their actual visible boundaries. Optional product observations carry the policy generation/resolution and already exposed variant. Configuration delivery and ad decisions use the existing bounded, consent-gated telemetry queue and owned projection transaction.

Scorecards show assigned, exposed, mature and returned accounts, return rate, absolute difference, relative lift, family-wise 95% Bonferroni-adjusted Wilson rate intervals, assignment/exposure ratio diagnostics and ad-decision counts. The return metric follows the existing target UTC-day definition, rather than a new rolling retention definition. Missing verified revenue and crash guardrails are explicitly unavailable. There is no automatic winner or automatic promotion. Promotion pauses delivery and copies the selected settings into a draft; publication still requires a separate reviewed command.

Delivery totals describe the latest observation from signed-in reporting accounts over the past 24 hours. They do not estimate all eligible installs or guest/offline coverage. Operational observations are not reward proof or billing revenue.

## Requirement and use-case coverage

| Requirement | Evidence and practical coverage |
| --- | --- |
| RGC01 | Actual owner/analyst browser flows, typed fields, 390px containment, Studio screenshots; native notices at three landscape/portrait sizes. |
| RGC02 | Server registry, matching client validator and JSON schema; bounds, capabilities and boundaries; unknown keys rejected. |
| RGC03 | OR/AND, delay, minima, rewarded cooldown, cap, failed show, counter continuity; existing actual App ad flow and long-race lease renewal. |
| RGC04 | Priority/conflict tests, private preview, stable account buckets, nested rollout, multi-platform/capability edits preserved. |
| RGC05 | Immutable snapshots, edit conflicts, exact configuration command replay, schedule revalidation, real PostgreSQL concurrent writers/readers. |
| RGC06 | Restriction wins, stale permission suppresses, explicit renewal at safe result, restore retains restrictions. |
| RGC07 | Four-arm and opt-out backend tests; three-arm browser creation; real native HTTP assignment/exposure/projection; scorecards and reviewed promotion. |
| RGC08 | Pending/safe-boundary application, cache/account/origin/consent fences, late response rejection, conditional HTTP reuse and invalid-data checks. |
| RGC09 | Entitlement read does not create balances; paid suppression; existing ad/Store/App/driving regressions; competition/economy fields excluded. |
| RGC10 | Separate assignment, application, exposure and decision observations; scope/coverage disclosures and unavailable guardrails. |
| RGC11 | Existing private staff access, owner/analyst controls, reasons, CAS, audit, command replay, redacted export and erasure projection. |

The controls support ad tuning and cadence comparisons, internal feature trials, notices, Store-order comparisons, staged/scheduled publication, incident restriction, restore, player support and manual experiment decisions. Future reward amounts/multipliers, recurring monthly publishing allowances, changing product prices, new task/event formats, localized message catalogs, region/account-age targeting and automatic winners remain outside the registered policy. The interface explains the unapproved economy categories rather than activating them. The original design remains the broader use-case inventory; implementation of this slice does not mark those future domains shipped.

## Actual verification

| Check | Final result |
| --- | --- |
| Configuration + existing Studio platform + product backend | 60 passed; 1 PostgreSQL case deselected here and run in the owned PostgreSQL fixture below. |
| Owned PostgreSQL 17 | 4 passed: duplicate commands, stale edits, coherent policy reads, existing duplicate-ingestion/concurrent-projection check. Final migration chain applied. |
| Native configuration | 40 checks, 0 failures. |
| Native real App configuration | 13 headless; 16 Compatibility and 16 desktop Mobile-renderer checks, 0 failures. The later permission-only fix also passed the headless App check. |
| Actual native HTTP | 17 checks, 0 failures, including long-race lease renewal and product-event attribution. |
| Browser with native HTTP | 12 workflows, zero page errors, actual configuration/experiment mutations only in the fixture's temporary SQLite service. |
| Existing regressions | Race ads 57, AdMob adapter 44, product telemetry 55, Store telemetry 15, Store reference 104, App 141 and driving 72: 0 failures. |
| Parser | 1,058 scripts, 0 failures. |
| Java | Existing offline `compileStandardDebugJavaWithJavac`: BUILD SUCCESSFUL, 16 tasks. No APK/export. |
| Static checks | Focused Ruff, changed JavaScript parsing and both JSON schema parsing passed. |

Commands, actual receipts, source hashes and checkpoint details are in [report.json](evidence/game-configuration-2026-10-24/report.json). Typical reproducible commands are:

```powershell
# From backend/ with the existing project venv
..\.tools\backend-venv\Scripts\python.exe -m pytest tests/test_game_config.py tests/test_studio_platform.py tests/test_product_analytics.py -k 'not postgres' -q
# From repository root; owned disposable fixtures only
.\.tools\backend-venv\Scripts\python.exe scripts/test_game_configuration_postgres.py --include-product
.\.tools\backend-venv\Scripts\python.exe scripts/test_game_configuration_console.py --output docs/evidence/game-configuration-2026-10-24/final-acceptance --native
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_game_configuration.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_script_parse.gd
```

Native tests used separate task APPDATA paths. Browser/PostgreSQL helpers use owned temporary services and clean up their own processes/labelled container. Windows native startup needed the sandbox exception for certificate-store reads. No SDK/network dependency was installed for this task.

Initial fixture issues included the explicit development Studio-key flag, JSON-number conversion, freeing a node during a callback, browser selectors/scroll position, and a generic PostgreSQL fixture pointing at a stopped shared endpoint. These were corrected in fixtures; the final PostgreSQL runs used an owned loopback database. A product telemetry 24-hour-expiry assertion failed once during a parallel run. The preserved original-source control and repeated unchanged-current run both passed; no invariant or production pruning behavior was weakened. One empty-script `CheckScript` invocation started the isolated main scene; only its verified task-owned child was stopped, then the correct project parser passed. Browser review corrected emergency wording and retained multi-platform/capability selections. Final review also corrected long-race permission renewal before ad presentation.

Actual previews:

- [Studio settings](evidence/game-configuration-2026-10-24/final-acceptance/settings-desktop.png)
- [A/B/n results](evidence/game-configuration-2026-10-24/final-acceptance/experiments-desktop.png)
- [Narrow Studio overview](evidence/game-configuration-2026-10-24/final-acceptance/overview-narrow.png)
- [Native landscape notice](evidence/game-configuration-2026-10-24/native-compatibility/notice-1280x720.png)
- [Native portrait notice](evidence/game-configuration-2026-10-24/native-mobile/notice-540x960.png)

## Rollout and remaining acceptance

Release matching migrations, gameplay API, private Studio UI/API, workers and client together. Keep the concurrent separate workload credentials and production staff controls. Confirm the production reporting reader and measurement setting before starting experiments; the code does not enable collection or configure missing commercial feeds. Old clients cannot acquire this new configuration capability without an update. The Java presentation signal needs a rebuilt debug client to report its exact callback; the existing debug callback fallback remains supported.

Owner review, sustained device behavior, production calibration, paid-provider/consent prerequisites and production experiment sample/guardrail coverage remain. The graphical Mobile checks ran on the desktop GPU and are not device tests. No phone/tablet attachment check or physical-device test was performed. No APK, install, account mutation on an existing backend, live policy publication, purchase, deployment or owner game/editor restart was performed. Concurrent repository work remains preserved.
