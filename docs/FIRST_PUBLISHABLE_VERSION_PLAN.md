# First publishable version and income plan

Prepared 2026-10-02 from the current workspace. The owner selected **free download with optional rewarded ads and purchases**. Launch date, team, budget and Play Console production access are undecided.

Beat my track has enough implemented gameplay and tooling to pursue a first commercial release without another broad feature expansion. The remaining work is to turn the development build into a reliable product: enjoyable phone handling, a good clean-install experience, real repeatable rewards, safe online operation, verified monetization and a tested Google Play release. Revenue capability and a profitable business are separate milestones; neither player demand nor this game's revenue per player has been measured.

This is a proposed release plan, not implementation, permission to deploy or a replacement for the owner overrides in [AGENTS.md](../AGENTS.md). Requirements below refer to the [original inventory](../Android_racing_game_blueprint_v2/planning/Requirements.csv), backend B requirements and rewind RW requirements in the linked implementation documents. Reduced scope and new commercial configurations need an owner decision before their implementation.

## Project assessment

| Area | Evidence in this project | Work before commercial release |
| --- | --- | --- |
| Driving and timing | Five fictional cars; fixed 120 Hz simulation; quantized inputs; ordered road gates; five-lap races; local records; versioned server replay verification. Latest handbrake physics is `arcade-planar-0.49`. | Accept the latest handling on phones, freeze the first shipping rules, and verify client/server replay agreement. Earlier handling approval does not prove acceptance of the new handbrake. |
| Presentation | Illustrated menus, Race discovery, carousel/search/filters, garage, detailed results, adjustable touch layout and five current environment choices already exist. | Finish phone usability and readability, remove misleading placeholders, approve actual shipping assets. Avoid another menu redesign. |
| Creator | Free-form roads, automatic route/start line, bridges, objects/hazards, autosave/undo, local import/export, practice proof and immutable online publication. | Test novice creation, difficult geometry, data recovery and end-to-end publication on phones; provide public-content reporting and moderation. |
| Installed tracks | `game/resources/builtin_tracks.json` lists **one** installed original circuit. The owner's richer collection is stored in player files; four development cloud entries are documented. | Curate and bundle an original starter pack. Development screenshots and copied local saves are not the experience a new customer installs. |
| Backend | FastAPI/PostgreSQL, separate pinned Godot worker, Google browser flow, durable upload outbox, ratings, per-car verified boards, admin restrictions, deployment/backup scripts. | Real Google acceptance, public HTTPS/NAS deployment, service monitoring and restore drill. Admin hide/disable actions are present; player reports, blocks and account deletion are missing from the audited routes/UI. |
| Rewind | Ten-second history, three confirmed resumes per race, daily free allowance, permanent bank, server receipts and replay validation. | Connect real rewarded-ad and purchase providers. Both client and server currently hardcode `TEMPORARY_AD_RESUMES = true`; the temporary `ad_preview` path is not an income mechanism. |
| Rewards and progression | Results explicitly say reward preview/no balance credited. All five cars are currently available with no unlocks or purchases. | Replace preview coins with an actual, useful reward loop. Decide how much of the original progression specification belongs in the first commercial version. |
| Android release | Pinned Godot and templates are installed; debug APK export/deployment exists; an Android 13 DN2103 is connected at this review. | Final package/name/version, signed release AAB, target SDK, native compatibility, production configuration, store testing and listing. Current preset is only `Android Debug`, with Gradle disabled and a handling-lab package identity. |
| Evidence and workflow | Extensive domain tests, replay fixtures, screenshots and some physical-phone measurements. | Establish one reproducible release checkpoint. Existing workspace changes span many files. Full backend failures/stalls and earlier graphical failures are documented; focused passes do not close them. Some README/setup statements still describe retired content and missing tooling. |

Primary project evidence: [handbrake](HANDBRAKE.md), [rewind](REWIND.md), [cloud integration](CLOUD_TRACKS.md), [creator publishing](CREATOR_PUBLISH_FLOW.md), [official development seeding](OFFICIAL_TRACK_SEEDING.md), [account setup](ACCOUNT_SIGN_IN.md), [results rewards](PREMIUM_RACE_COMPLETE.md), [asset provenance](../licenses/ASSETS.md) and [deployment runbook](../backend/deploy/README.md). Later dated corrections take precedence over older passages in these documents.

The architecture is suitable for this release. Keep the simulation, platform adapters and separate verification worker. Concentrate new work in those boundaries instead of replacing the engine/backend or refactoring the entire application. The large composition root is a maintenance risk, but a broad rewrite would postpone launch without proving demand.

## Proposed first commercial product

The promise should be concrete: **short, active races, personal-best improvement, and circuits players can create and share**. Show actual phone gameplay before the editor or shop.

- Android landscape release in English first; Windows remains the development and test platform.
- Retain the five existing cars, freely available. Preserve their distinct handling and the approved overhead camera. No paid performance or paid control advantage.
- Target **8-12 curated original circuits**, including at least three easy tracks and several intermediate/expert tracks. Use existing cleared owner-authored courses where suitable; verify ownership and geometry rather than importing the retired Slicks corpus. Every ordinary race remains five laps. Reference lap duration remains 10-30 seconds; measure the novice experience separately.
- Keep the existing themes where they pass device checks. New art/content beyond this pack is unnecessary. A failing environment must be optimized, or its first-release omission explicitly agreed; do not silently weaken performance acceptance.
- Guest/offline racing, local PBs, immediate full restart, local creator and free file sharing. Google sign-in is optional for ordinary play, required for public publishing, verified competition and the proposed banked ad/purchase rewards.
- Signed-in published-track races, ratings and verified full-race boards with truthful empty/pending states. Best-lap global rankings are not currently implemented and must not be advertised.
- A shareable immutable-track URL with a readable code fallback. Recipients can open a small track preview/store page, then enter the code in the game if automatic opening is unavailable. Test sending and receiving on phones; do not promise post-install automatic deep linking. This supports acquisition without adding a friends/social system. G05/T05.
- A brief first-drive lesson and an optional small creator starter guide. Explain checkpoints, braking, handbrake and rewind when they become relevant. A new player should reach driving before being asked to buy or watch an ad.
- Actual repeated-race rewards and a small earned cosmetic/mastery loop, with durable saves and meaningful garage feedback. Give normal eligible completions a base reward even after PB bonuses are exhausted. Sell neither those credits nor XP.
- One rewarded-ad placement for resumes and two small resume-pack purchase options. Additional cosmetic sales are a follow-up unless existing paint variants can be finished without delaying this release.
- Public-content terms, report/block functions, account deletion, support/privacy pages and an operator responsible for moderation and refunds.

**Scope decision required:** lightweight mastery/earned cosmetics with all five cars free reduces the original G04/E03 performance-upgrade progression; postponing recurring leagues reduces G07. These are proposed deferrals, not superseded requirements. If the owner requires full earned performance upgrades or leagues in the first published version, add explicit work for inventory, tuning/class rules, verification partitions and/or event settlement, then re-estimate. The current schedule excludes them. Preserve unlimited legitimate rewards and play in either choice.

For the small reward loop, define one versioned completion grant and real earnable cosmetic uses; the preview amounts are still provisional. Guest/offline rewards must persist locally without requiring a server ticket or connection. They cannot self-grant an authenticated server balance: define guest-to-account adoption and offline reconciliation explicitly, and label any pending server reward honestly. Use separate grant identities for base completion and one-time milestones, with repeated legitimate racing continuing to earn base rewards. This reconciliation work belongs in Gates 2-3, not a hidden later economy rewrite.

Also defer paid creator capacity, friends/rematches, additional race modes, real-time multiplayer, subscriptions, live economy balancing and new vehicles. Creator capacity needs a retention promise, quotas/archive behavior and entitlements that do not exist today. It is a weaker first bet than monetizing the resume system already used during racing. Disabled friends/mode/race-count placeholders should be hidden or clearly unavailable in the shipping experience; no fabricated activity, rankings or ratings.

## Monetization design

### Rewarded resumes

Use the owner-approved order: **banked resumes first, daily free resume second, then an optional rewarded ad**. Daily free resets at 00:00 UTC without rollover. Purchased/awarded banked resumes never expire. Keep the three-resume race limit and rewind-assisted leaderboard eligibility. A full restart is always free, with no racing limit or mandatory ad.

Proposed initial provider: Google AdMob, with no mediation stack at launch. This is a recommendation pending provider/account approval, not an installed dependency. Use a maintained Godot Android adapter or a small native plugin after a release-build compatibility check; pin its SDKs and provenance.

The server should issue an authenticated reward intent, bind it to a player and nonce, verify the provider's signed callback and deduplicate the transaction before calling the existing `grant_verified` boundary. Exactly one completed verified ad grants one banked resume. Client completion/dismissal callbacks alone cannot mint competitive credits. AdMob documents [server-side callback verification](https://developers.google.com/admob/android/ssv).

Persist pending rewards and reconcile after reconnect or process death. Handle dismissal without completion, duplicate/delayed callbacks, no fill, SDK failure, consent refusal and account changes. Keep the race paused while the player chooses; avoid losing the selected rewind point while waiting. If no verified reward is available, offer cancellation or a free full restart. Do not silently spend another resource or make ordinary racing depend on the ad provider. Unlimited ads per day means no game-imposed daily cap, not guaranteed provider inventory.

Convert the temporary path into explicit development configuration and disable issuance of `ad_preview` in shipping clients and production servers. Reject new preview-based submissions under the shipping contract without deleting existing development history. Preserve the accepted handling/timing logic. Use test ads during development and closed testing; production configuration must not contain test grants or development keys.

For EEA/UK/Swiss personalized advertising, plan Google-certified consent management and a privacy-options entry. Consent refusal must leave ordinary gameplay available; use only ad modes allowed for that consent state. Google's [CMP requirements](https://support.google.com/admob/answer/13554116?hl=en) distinguish personalized and limited/non-personalized eligibility. Complete a data inventory and age/audience decision before SDK integration.

### Purchases

Initial pricing experiments, **not approved prices or forecasts**: 10 resumes for EUR 1.99 and 30 for EUR 4.99, localized through Play product details. Expose a compact menu/garage purchase entry and bank balance; never put a purchase flow between Retry and driving. Do not offer a misleading “remove ads” product when all ads are already voluntary.

Require sign-in before opening a paid flow so the purchase has a durable game-account owner. Document that owner, synchronize bank balance across devices and prevent another game account from claiming the same token. Returning-device recovery of a consumed pack means restoring its server balance/history, never regranting the original quantity.

Verify package, allowlisted product, purchase token, ownership and `PURCHASED` state on the backend; persist an idempotent grant and retry consumption/acknowledgement safely. Pending purchases grant nothing. Add refund/revocation reconciliation, recoverable failed fulfillment and a support procedure for refunds after some resumes have been spent. Preserve legitimate historical PBs; do not invent punitive balance or record-deletion policies. Google's [purchase security guidance](https://developer.android.com/google/play/billing/security) and [billing integration guidance](https://developer.android.com/google/play/billing/integrate) describe verification and acknowledgement/consumption handling, including the three-day acknowledgement window after purchase completion.

Build against supported Play Billing, **8 or later as of this review**, preferably the supported version the chosen adapter has actually tested. Library 7's normal submission deadline passed on 2026-08-31; no extension should be assumed. Recheck [the deprecation schedule](https://developer.android.com/google/play/billing/deprecation-faq.html) at upload.

## Work sequence and completion evidence

Effort estimates assume one experienced developer, five focused development days per week, existing equipment and prompt owner acceptance. They include implementation and verification, not a committed delivery date. Each gate should end with one reviewable Git checkpoint and evidence from its exact build. Obtain required deployment/provider approvals only after the relevant configuration and release candidate are concrete.

| Gate | Estimated development days | Work and relevant requirements | Completion evidence |
| --- | --- | --- | --- |
| 0 Release decisions and feasibility | 2-4 | Confirm reduced progression/league scope, markets/audience, publisher identity, budget and provider/product choices. Inventory current changes and old failing tests. Spike release AAB/API 36/native compatibility before committing to an adapter. Q02/Q03, A04, V06. | Written release scope; named blocker list; Play account/access status; a reproducible release-build feasibility report. No secrets committed. |
| 1 Freeze the driving experience | 4-7 | Accept latest phone handling and touch controls; fix blocking checkpoints/bridges/recovery; resolve full regression failures. Pin shipping physics/rules and verifier. G01-G03, R01-R07, A02, Q01, V01/V04. | Owner approval on a phone; varied-player driving observations; full canonical replay/regression pass including current handbrake/rewind; sustained device traces. No unexplained verification mismatch. |
| 2 Make the installed game complete | 6-10 | Bundle 8-12 cleared tracks; first-drive/creator guidance; real base rewards and small earned cosmetic/mastery loop; results/garage feedback; remove shipping placeholders. G03/G05, E01/E02, R06/R07, T01-T04, V03/V05/V06. | Fresh install without copied saves/backend still has a useful track library; repeated slower races earn correctly; retries/process death cannot double grant; novice first-race and creator flows observed; asset ledger and screenshots/video updated. |
| 3 Make accounts and online sharing launchable | 8-12 | Real Google login; production identity for official content; NAS HTTPS/proxy; share URL/code lookup; account deletion; upload terms; report/block/moderation queue using existing admin restrictions; offline/cache/outbox recovery; alerts, backups/load test. B01-B07/B19, G05/T05, A01/A03/A05, S01/S02. | Two real Google accounts on phones publish/share/download/race/rate; recipient code works without deferred linking; forged runs rejected; delete/block/report flows work; backup restored; worker capacity and queue delay measured; production development sessions rejected. Public deployment needs explicit owner authorization. |
| 4 Enable actual ad and purchase income | 8-12 | Android provider/billing adapters, consent, verified callback/token fulfillment, pending recovery, refund/revocation, wallet UI and shipping preview disablement. RW03-RW07, A01/A04, M01/M02, S02, Q02. Resume sales retain the explicit owner exception to M01. | Provider test ad and Play test purchase grant exactly once, survive retries/restart and account changes; no-fill/cancel/pending/duplicate/refund tests; same leaderboard rules and race cap; release inspection finds no preview/dev credentials. |
| 5 Test and submit the commercial release | 5-8 | Complete device/network/save/thermal matrix; pre-launch reports; clean install/update; store listing, honest screenshots/trailer, support/privacy/deletion pages and disclosures; complete closed testing and review preparation. Q01-Q03, S01/S02, V04/V06. | All release gates below met on the signed candidate; test feedback resolved; listing matches available features; launch/rollback and operator checklist ready. Actual public rollout requires owner authorization. |

Total: **33-53 development days**, or about **40-64 days with a 20% planning reserve**: approximately **8-13 full-time weeks**. Re-estimate after Gate 0 and phone acceptance. Extra features, unresolved native-plugin compatibility, part-time availability and delayed business-account setup can increase this substantially. This estimate is not the time required for the full original product blueprint.

Open Play Console/account verification, domain/provider setup and tester recruitment early. Start required closed testing as soon as a stable policy-complete candidate exists and continue improving it during the observation window. For affected personal accounts created after 2023-11-13, Google requires at least **12 continuously opted-in testers for 14 days**, followed by an application for production access; completing 14 days is not automatic approval. See [official testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en). Review/access delays are additional external uncertainty, not fixed work estimates.

The dependency chain is: scope and release feasibility → accepted driving → complete installed experience → safe online service → verified monetization → tested signed candidate → limited public launch. Store preparation and business setup can proceed alongside development; on a one-person team that does not make engineering effort disappear.

### Implementation priorities in the current repository

- Release tooling: `scripts/dev.ps1`, `game/export_presets.cfg`, `game/project.godot`, native music build/extension and a production-config boundary. Preserve the pinned engine/templates. Add supported release/AAB actions rather than relying on the debug APK path.
- Content/onboarding/rewards: `game/resources/builtin_tracks.json`, `game/resources/tracks/`, `game/ui/track_catalog.gd`, `game/core/app.gd`, `game/ui/race_complete.gd`, `game/ui/race_reward_preview.gd`, persistence and new explicit reward domain/ledger code. Do not convert UI preview totals into trusted server balances.
- Identity/content safety: `game/backend/{account_controller,backend_client,cloud_tracks}.gd`, account/discovery UI, `backend/bmt_backend/{auth,tracks,admin,maintenance}.py`, migrations and deployment scripts. Extend existing boundaries with account deletion and moderation data; do not add a second auth system.
- Monetization: `game/platform/resume_credits.gd`, a new Android ad/billing adapter behind domain interfaces, `backend/bmt_backend/{resumes,resume_models}.py`, provider verification routes/jobs and tests. Maintain banked-before-daily consumption and immutable receipts.
- Regression gate: the current full `Validate` function does not explicitly run the standalone handbrake, rewind, touch-layout/mobile-control, results or backend suites. Add a release-check command that composes the required existing checks and new meaningful integrations. Do not interpret one generic PASS line as coverage of every release requirement.
- Documentation: refresh stale root/backend README claims and current release setup, test manifest, asset/licensing notices and support/runbook documentation. Preserve the original blueprint and player files.

## Production and Google Play gates

As checked on 2026-10-02, new Android app submissions must target **Android 16/API 36**. Explicitly configure and inspect the generated manifest; blank preset SDK fields and a build-tools fallback are not evidence. See [current target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en-EN).

Produce a signed release **Android App Bundle**, enable [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756?hl=en), protect the upload key, and select a permanent package ID before public distribution. Provide a migration/export strategy for existing development saves if the package/user-data identity changes. Inspect the exported archive for test fixtures, legacy tracks, credentials, debug routes/UI and unused native binaries. Verify the active native music library plus engine and SDK native libraries on 16 KB-page devices using Android's [native compatibility guidance](https://developer.android.com/guide/practices/page-sizes); installed NDK r28b alone does not certify the final AAB.

Public sharing requires user/content reports, blocks, terms acceptance and actual moderation, even without chat or uploaded pictures. Track names, profiles and authored shapes are user content. Use the existing admin hide/disable tools as the enforcement end of a real player report workflow. See [Google Play UGC policy](https://support.google.com/googleplay/android-developer/answer/9876937?hl=en-GB). Account creation, including external Google sign-in, requires an in-app deletion path and a functional web deletion request resource; guest access does not exempt the app. Define retained legal/fraud records and treatment of published versions without silently deleting unrelated player files. See [account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en-EN).

Complete Data Safety, privacy policy, target audience/content rating, ads and purchase disclosures, reviewer access instructions, developer verification and merchant/payout setup. Provider SDK data use must match the declarations. Audit music, fonts, Google sign-in assets, generated artwork and the adapted wet-glass shader; include engine/native third-party notices. No runtime AI generation is part of this product. Choose service-fee enrollment and confirm actual territory/account treatment rather than assuming one universal rate. The [published fee schedule](https://support.google.com/googleplay/android-developer/answer/112622?hl=en) includes an enrolled 15% tier for the first USD 1M annual revenue, with other programs/treatments varying.

For production official tracks, replace the operations seeder's dependence on `development/developer` with an explicit production publisher identity and reviewed migration/seeding procedure. Never copy the development database or enable dev auth to create a shipping catalog. Preserve immutable version IDs/hashes when deliberately migrating legitimate content, and do not seed fake scores or ratings.

The DS925+ deployment is a reasonable first small-service target, not a proven public capacity. Measure replay seconds per job, queue arrival rate, timeouts, storage growth and CPU/memory under the actual race mix. If one worker averages 10 seconds per replay, its theoretical throughput is six per minute before overhead and safety headroom; multiply measured average DAU race submissions rather than judging capacity by registered-user count. Add workers or move hosting only after measuring the bottleneck. Rehearse HTTPS/OAuth callback, trusted-proxy limits, external connectivity, restore and rollback. Keep cached ordinary racing available during a service outage. The runbook's nightly backup proposal permits up to 24 hours of lost data and is not a proven recovery objective.

## Release acceptance

These are proposed operating gates unless an existing requirement states otherwise. Record exact build, device, test cohort and pass/fail evidence; no fixture population substitutes for real customers.

| Gate | Required evidence |
| --- | --- |
| Driving | Owner approves current phone handling. At least ten varied first-time players observed; proposed target: eight finish an easy race without coaching and six choose another attempt. Keep feedback even when these thresholds miss. |
| Content and rewards | Installed pack works offline from a clean store-style install; official reference lap durations measured. Eligible repeats continue giving base rewards; no duplicate grants; no preview currency represented as earned/spendable. |
| Timing integrity | Full driving/checkpoint/track/replay/handbrake/rewind checks pass; Windows, Android-captured inputs and Linux verifier agree under the pinned contract; sharp joins, hairpins, bridge junctions and hazards tested. |
| Phone stability | Declared minimum/reference device plus at least another GPU family and a recent Android device; 20-minute thermal session, multitouch stress, keyboard/safe insets, pause/background/ad interruption, low storage, airplane mode and restart/update tested. Existing Q01: p95 frame time ≤20 ms and no persistent >33 ms frames; target 60 FPS. Keep the stricter visual target visible and get a decision if requirements conflict. |
| Online | Real Google recovery, two-account ownership/publication/rating, offline outbox recovery/expiry, report/block/deletion and admin action demonstrated; queued/invalid results never appear as verified. |
| Money | Real provider/Play sandbox flows, exact-once awards, balance recovery, pending/error/duplicate/refund handling, UTC daily boundary and three-use race cap; shipping preview/dev paths rejected. No charge or watched-ad claim before fulfillment proof. |
| Operations | Public production approval; tested backup/restore and rollback; alerts for health, errors, queue age, storage, backup age and callback failures; named moderation/support owner and a cash/time operating cap. |
| Store | Signed AAB accepted by Play internal testing; target/native compatibility and pre-launch report cleared; required closed test/access completed; legal/support URLs and disclosures accurate; screenshots/video from the candidate without debug probe labels. |

Recent Storm measurements are encouraging but limited: a 60-second phone run reports internal p95 24.296 ms, while a separate 26.64-second display trace reports p95 17.013 ms and about 2% missed refreshes. These measure different things; neither is the required 20-minute cross-device thermal pass. See [raw evidence and limits](STORM_MOBILE_OPTIMIZATION.md). Resolve the measurement method and optimize as necessary rather than declaring Q01 passed from the display trace alone.

For the first paid cohort, propose ≥99.5% crash-free users over a meaningful multi-day sample and no reproducible purchase-loss, save-loss or timing bug. This is a project launch target, not a quoted Google policy or evidence of current stability. Full backend/PostgreSQL/integration and graphical release checks remain mandatory; resolve failures individually without weakening invariants.

## How income becomes measurable

Start with internal/closed testing and then a limited public launch in one or two chosen markets. Use test purchases during testing; first actual income requires live monetization, approved distribution and real players. Cash receipt also depends on provider settlement timing. Do not count sandbox purchases or estimated ad impressions as money earned.

Use a small documented measurement set: first race started/completed, voluntary retries, first PB, next-day/seven-day returns, creator test/publish/share/recipient completion, verified replay delay, ad offered/completed/grant confirmed, purchase started/verified/refunded, crash/ANR and support/moderation time. Prefer existing server records and Play/provider dashboards; any new client events need a privacy/retention decision and an adapter outside simulation. Do not add an analytics vendor merely to produce a dashboard. Define D1 as return on the next day and D7 as return on day seven, using only cohorts old enough to be measured, and distinguish guests/account users and acquisition sources.

Follow the original [zero-paid-acquisition sequence](../Android_racing_game_blueprint_v2/planning/Launch_and_live_ops.md): ten driving observations, ten novice creators, 30-50 online testers, then about 300 external first-time players with seven-day follow-up. Invite real testers through permitted racing/indie communities and maker challenges; prepare a short real gameplay clip, store screenshots and clear free-racing language. Recruiting and outreach require owner-led/explicitly authorized communication; this review did not contact anyone.

Proposed initial scale-up gates: ≥80% easy first-race completion, D1 ≥25%, D7 ≥10%, reliable purchases/ads and nonnegative cash contribution under the agreed operating budget. These are decision thresholds, not industry benchmarks or promised results. With 300 users, show counts and uncertainty; do not infer commercial viability from friendly or incentivized testers. Diagnose poor handling/onboarding/retention before adding cars or a larger shop. Do not buy traffic until mature cohorts show a conservative contribution per install and a credible payback window.

### Illustrative income sensitivity

The following is arithmetic, **not a forecast or an ad-market benchmark**. Assume 0.5 completed paid rewarded impressions per daily active user per day, 30 days/month, EUR 5 publisher revenue per 1,000 impressions, monthly active users equal to three times daily active users, 1% monthly buyer conversion, and EUR 2 average net purchase proceeds per buyer after applicable fees/taxes/refunds. These inputs must all be replaced with measured results. Do not apply Play purchase fees again to ad revenue already stated as publisher revenue.

| Daily active users | Monthly rewarded-ad revenue | Monthly net purchase proceeds | Monthly receipts before service/support/labour |
| --- | --- | --- | --- |
| 100 | EUR 7.50 | EUR 6 | EUR 13.50 |
| 1,000 | EUR 75 | EUR 60 | EUR 135 |
| 10,000 | EUR 750 | EUR 600 | EUR 1,350 |

Formula: ads = DAU × 30 × paid rewarded impressions per user/day × publisher eCPM ÷ 1,000. Purchases = monthly unique active users × buyer conversion × average net buyer proceeds. Fill/consent/region/seasonality and sign-in friction can reduce the ad term; repeated purchasers and pack mix change the purchase term. Halving eCPM or completed views halves the ad term. With these inputs, every sustained DAU yields EUR 0.135/month before operating costs: EUR 100 monthly cash costs need roughly 741 DAU; EUR 2,000 founder income plus EUR 100 cash costs needs roughly 15,556 DAU. This is only sensitivity arithmetic, not an acquisition goal justified by evidence.

The preserved financial workbook's base purchase yield of approximately EUR 0.14 per install is also an assumption, predating the resume model. Keep the original workbook unchanged. Build a separate launch worksheet from real cohorts, provider statements, actual Play fees/tax treatment, refunds, hosting and founder time. First income could be small; meaningful founder income requires sustained active players, retention and margins.

Budget is undecided. A provisional planning envelope is EUR 500-1,500 incremental prelaunch cash plus a chosen EUR 50-150 monthly operating cap, excluding labour and new test phones; these are reserves, not vendor quotes or authorized purchases. Price domain/hosting/provider setup and any targeted security/privacy help during Gate 0. Cap spending, monitor NAS/storage/support costs and keep enough reserve for refunds and recovery. Define a maintenance/export path if online operation becomes unaffordable. Do not sell lifetime hosting.

## First actions when development resumes

1. Agree the small-release progression/league decision, target markets/audience, available weekly time, cash cap and Play account status. Freeze the launch checklist before accepting new feature requests into it.
2. Capture a clean release checkpoint from the current mixed workspace; reproduce and triage recorded full-suite failures. Include current standalone handbrake/rewind checks in the release manifest.
3. Run the latest handling on the connected phone and another reference device, then accept/fix it and freeze shipping physics. Test clean-install content independently of the owner's local saves.
4. Prove signed AAB/API 36/native-library/provider compatibility early. Set up Play account verification and recruit the needed testers while completing the starter pack, onboarding and real rewards.
5. Complete production identity/moderation/deletion and server operation, then integrate verified rewarded ads and resume purchases. Finish testing and prepare the concrete release candidate before requesting public deployment/rollout approval.

## Verification performed for this plan

Read the development/Phase 0 history, current agent overrides, launch/requirements/financial interpretation, relevant implementation documents, build/export configuration, simulation/catalog/reward/resume/account/admin/seeder boundaries and test entry points. Inspected existing menu, physical-phone Storm and results screenshots. The viewed menu/results captures include historical fixture/prototype content; they are not proof of the current shipping UI, live populations or new device acceptance. Checked current Google primary policy/SDK sources linked next to their claims.

Actual commands run on 2026-10-02:

| Command | Result |
| --- | --- |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Doctor` | Passed; exact Godot `4.7.2.stable.official.ed1daf0bf`, matching Android templates/tool prerequisites, one authorized DN2103 attached. |
| Same entry point, `TestMenus` | 48 checks, zero failures. |
| Same entry point, `TestCatalog` | 21 checks, zero failures. |
| Same entry point, `TestHandbrake` | 231 checks, zero failures. |
| Same entry point, `TestRewind` | 57 checks, zero failures. |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_resumes.py -q --tb=short -k "(daily_non_stacking or grants_are_idempotent or invalid_or_cross or submission_requires or temporary_ad) and not postgres"` | Five passed, 15 deselected; existing Starlette/httpx deprecation warning. This is a selected wallet/receipt-boundary test, not real provider verification or a PostgreSQL/full backend pass. |
| `git status`, `git log`, scoped `git diff --stat`, `rg --files`, targeted `rg` and file reads | Repository/code/configuration audit completed. Existing changes retained. |
| `git diff --check -- docs/FIRST_PUBLISHABLE_VERSION_PLAN.md DEVELOPMENT_STATUS.md docs/PHASE_0_PLAN.md` | Passed; Git emitted existing CRLF-to-LF conversion notices. |
| Readback and Python document audit | Local source links, heading spacing, required scope statements, trailing whitespace and illustrative income calculations checked. |

No new APK/AAB export, installation, physical-device driving/thermal test, full game/backend/PostgreSQL regression, live Google/ad/purchase test, production deployment, outreach or purchase was performed. Connected-device discovery is not device acceptance. No visible UI changed, so no new screenshot/video is required for this planning task; release gates require new candidate evidence.

Changed deliverables: this plan and concise planning records in `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`. The original specification/workbook, game/backend behavior and player data are unchanged. Keep this document as the reviewable planning checkpoint; no mixed-workspace commit or publication is implied.
