# Beat My Track — concrete task list toward 10/10 in all ten areas

Date: **26 October 2026**. Planning only; no implementation, device test, provider transaction or rollout is performed by this task. Source: the [technical audit](COMPREHENSIVE_MOBILE_AUDIT_2026_10_26.md) and newer accepted Storm, Rivalry, Garage and electric corrections. The [CSV backlog](QUALITY_10_OF_10_TASKS_2026_10_26.csv) contains the same tasks for tracking/import.

There are **55 tasks**: 53 area tasks, one current-baseline task and one final acceptance task. Each has a concrete output, pass condition, dependencies, primary discipline and effort range. All are open planning items; an already satisfied item can close with current evidence. The old audit scores and failures are historical, not assertions that subsequent work has failed.

**10/10 means all agreed category requirements are demonstrated on the supported release, with no known material gap.** It is a demanding review bar, not a promise of perfect or permanently bug-free software. Closing the original 13 findings alone is insufficient. Missing Android/provider/operational evidence keeps the corresponding score provisional.

## Execution order

1. **Establish the current baseline (Q00), measure on target devices (PERF01), and decide competitive trust (SEC01).** The current Forklift news image check returns missing; verify and fix active asset/startup blockers before benchmarking. Decide the supported 60-FPS/content envelope, commerce launch scope and operational recovery targets. Keeping the full stated product scope is the assumption in this list.
2. **Make the gate trustworthy and fix immediate quality issues:** TEST01–TEST03, REL01, UX01–UX02, PERF02–PERF03, AND01, MAINT01–MAINT02. Dependencies in the detailed list determine the precise order. Preserve each newly accepted layout/handling/track contract.
3. **Close trust and provider gaps:** SEC02–SEC03 and AND02–AND03, using owned fixtures and provider sandboxes. These are the largest release dependencies and should not wait until the final week.
4. **Finish measured optimization and reliability:** compact evidence/memory budgets, race/editor/persistence/concurrency cases, narrow App lifecycle extraction, all-screen/input review and actionable diagnostics.
5. **Verify a release candidate:** physical-device soak, independent security and UX reviews, signed-artifact/upgrade checks, incident/restore drills and a representative beta. Then Q99 assigns fresh scores.

These streams may overlap across engineers once dependencies pass; this document does not authorize implementation or delegate work. It does not authorize changing the prior lightweight-verification policy, production deployment, a purchase or owner data. SEC01 is the explicit decision point before changing protected score acceptance.

## Proposed measurable acceptance budgets

These are **planning proposals**, not previously approved product invariants or measurements. PERF01 establishes the actual supported-device/content baseline and confirms or explicitly revises them with the owner. Record CPU/GPU, presented frames, loading and memory separately; no cherry-picked fast scenes or lowered visual-quality defaults.

| Area | Proposed acceptance target / evidence |
|---|---|
| Nord 2 race smoothness | 60 Hz target: steady-play presented intervals p95 ≤18 ms, p99 ≤25 ms and >33.3 ms ≤0.1%; CPU and GPU stage p95 each ≤12 ms where measurable. Include all seven cars/five biomes, representative heavy valid content and a 60-minute thermal run. Record interruptions and first-use/load spikes separately; do not discard gameplay hitches. |
| Usable startup | Cold process launch to usable local Account/Race ≤3 s; warm return ≤1 s. Readiness means a usable action surface, not a splash over unfinished required work. Slow network cannot block local entry. |
| Local interaction/loading | Visible response p95 ≤100 ms; built-in race preparation ≤3 s cold / ≤1 s warm. Establish a separate maximum-valid-UGC loading budget from measured complexity; its loading UI must always remain responsive and cancellable. |
| Memory plateau | After a defined cache warm-up, comparable states after 50 cycles stay within max(10 MiB, 5%) of the established baseline and show no sustained upward retention trend. Extend to 200 cycles in automation. Establish absolute PSS/graphics budgets per supported device/state before claiming efficiency. |
| Input evidence | Proposed ≤2 MiB retained input component for 216,000 canonical input frames, excluding separately budgeted proof/ghost data. Valid rewinds/launch markers and pending legacy records remain exact. |
| UI | No clipped/unreachable required action at supported sizes; proposed primary target minimum 48 logical units; no duplicate action on drag/double-tap; all twelve shipping language choices have current reviewed display copy. |
| Reliability/security | Zero open reproducible P0/P1 defects or protected-score/reward fabrication cases; required fault/concurrency/compatibility suites pass. Acknowledged data and entitlements survive interruption exactly once. Known accepted limitations are stated, not scored away. |
| Operations | Proposed alert within five minutes; proposed RPO ≤15 minutes and RTO ≤60 minutes, demonstrated by a restore rehearsal including erasure replay. Accept storage/cost/staffing implications before committing to these service objectives. |
| Release observation | At least a proposed fourteen-day representative beta plus the scripted device/soak matrix. Report actual users/sessions/device-hours and statistical limits; a small beta cannot establish a precise 99.9% reliability rate. Ongoing quality owners remain after release. |

## Work by category and evidence required for 10/10

| Category | Audit score | Tasks | Evidence required before 10/10 |
|---|---:|---|---|
| Runtime performance | 6/10 provisional | PERF01, PERF02, PERF03, PERF04, PERF05, PERF06 | Stable target-device frame pacing and responsive startup/loading for the supported content envelope; measured CPU/GPU/thermal evidence, with approved appearance preserved. |
| Memory efficiency | 7/10 provisional | MEM01, MEM02, MEM03, MEM04, MEM05 | Compact evidence, bounded active/replacement/retained memory, demonstrated transition plateau and safe pressure/process-death behavior. |
| UI/UX implementation quality | 7/10 provisional | UX01, UX02, UX03, UX04, UX05 | All screens and states fit and respond consistently across supported devices/languages/input methods, with owner and observed-player acceptance. |
| Correctness and reliability | 7/10 provisional | REL01, REL02, REL03, REL04, REL05, REL06 | Race/editor/save/network/progression invariants survive normal operation, failures, duplicates, interruption and real PostgreSQL concurrency. |
| Software architecture | 6/10 | ARC01, ARC02, ARC03, ARC04 | Owned lifecycles, narrow typed contracts and enforced domain boundaries allow feature work and meaningful tests without constructing the entire App. |
| Maintainability | 6/10 | MAINT01, MAINT02, MAINT03, MAINT04, MAINT05 | Reproducible development, current contracts/docs, clean enforced checks and only verified removals; a new engineer can make a bounded change safely. |
| Security | 6/10 provisional | SEC01, SEC02, SEC03, SEC04, SEC05, SEC06 | Fabricated protected scores/rewards and public authorization/abuse cases are addressed; resolved artifacts/configuration and independent adversarial review pass. |
| Testing | 6/10 | TEST01, TEST02, TEST03, TEST04, TEST05, TEST06 | Maintained isolated suites run in enforced gates, cover critical failure paths and cannot be green through missing fixtures, optional private baselines or ignored runtime errors. |
| Observability | 6/10 | OBS01, OBS02, OBS03, OBS04 | A real slow frame, crash, failed transaction or outage is diagnosable by exact build/context; coverage and consent are explicit; alerts and recovery are rehearsed. |
| Android production readiness | 4/10 | AND01, AND02, AND03, AND04, AND05, AND06 | Actual signed distribution, production provider sandbox flows, lifecycle/device compatibility, upgrade preservation and final release disclosures/notices are evidenced. |

## Shared baseline

### [ ] Q00 — Establish a current, complete baseline

**Priority:** First. **Phase:** 0. **Effort:** 0.5–1.5 engineer-days. **Primary discipline:** Client + QA. **Dependencies:** None. **Trace:** MA03; new Rivalry composition status.

**Do:** Freeze a source/build inventory for the slice, check imported/exported asset closure, and resolve active startup blockers. Verify the currently missing game/assets/news/vehicles/forklift.png and every reference to it. Classify each old failure as an active defect, environment problem, or explicitly superseded expectation.

**Done when:** A clean isolated checkout imports and opens Account, Race, Garage, Settings, Store and Creator; current source hashes and an error-free startup log are attached. The original audit remains historical evidence.

## Runtime performance

### [ ] PERF01 — Record target-device performance baselines

**Priority:** First. **Phase:** 0. **Effort:** 1–2 engineer-days. **Primary discipline:** Performance + QA. **Dependencies:** Q00. **Trace:** MA04 MA05 MA13.

**Do:** Profile a release-equivalent build on the Nord 2 and representative Adreno/Mali devices. Measure cold/warm startup, each screen, all seven cars/five biomes, maximum valid creator complexity, loading, GPU passes, presented frames, thermals and power.

**Done when:** Repeatable traces and scene/build/device/settings identities exist; bottlenecks are ranked by measured cost and the proposed budgets are accepted or explicitly revised before optimization.

### [ ] PERF02 — Remove the mandatory full-Garage startup barrier

**Priority:** High. **Phase:** 1. **Effort:** 3–6 engineer-days. **Primary discipline:** Client + rendering. **Dependencies:** PERF01, TEST01. **Trace:** MA13.

**Do:** Prepare the selected model and essential view first; schedule remaining native previews in bounded idle slices, sharing immutable resources where beneficial. Keep cached previews, cancellation and account ownership correct; retain the accepted visual quality and fast Garage return.

**Done when:** Meet the accepted cold/warm usable-screen targets on Nord 2; all seven previews become ready without a first-tap hitch, stale account state or changed matched images. Report the longest unyielded preparation stage.

### [ ] PERF03 — Separate Garage and reflection invalidation

**Priority:** High. **Phase:** 1. **Effort:** 1–3 engineer-days. **Primary discipline:** Rendering. **Dependencies:** PERF01, TEST01. **Trace:** MA04.

**Do:** Give main, room and car reflection captures independent dirty state. Vinyl animation must not redraw the unchanged car-only reflection; hidden views remain inactive and visible animation is retained.

**Done when:** The existing unmuted/muted callback reproduction shows no unnecessary car-only captures; orbit, washing, snow melt, car change and resize update correctly. Device GPU/power improvement and matched images are recorded.

### [ ] PERF04 — Bound CPU work and loading stages

**Priority:** High. **Phase:** 2. **Effort:** 2–4 engineer-days. **Primary discipline:** Client + geometry. **Dependencies:** PERF01, TEST02. **Trace:** MA13; audit performance table.

**Do:** Attribute remaining expensive Star/large-track builds, cache packing, per-frame queries and UI rebuilds. Cache or slice only the measured hot work; keep worker ownership and deterministic simulation intact.

**Done when:** Main-thread stage costs meet the accepted budget; ordinary loading and selection remain interactive/cancellable; warm large-track behavior improves measurably with identical geometry and race results.

### [ ] PERF05 — Optimize measured GPU and overdraw costs

**Priority:** High. **Phase:** 2. **Effort:** 2–4 engineer-days. **Primary discipline:** Rendering. **Dependencies:** PERF01, PERF03. **Trace:** Audit GPU/static candidates.

**Do:** Profile Night fire, Storm glass/reflections, shadows, transparency, shaders, materials, spatial batches and texture residency. Remove redundant passes/work and prewarm necessary variants where measurements justify it.

**Done when:** Accepted frame budgets pass for normal and agreed worst-case content on both GPU families; screenshots preserve approved appearance. No blanket detail, resolution or car-quality reduction is used to obtain green.

### [ ] PERF06 — Pass sustained frame-pacing and thermal acceptance

**Priority:** Required gate. **Phase:** 3. **Effort:** 2–4 engineer-days. **Primary discipline:** Performance + device QA. **Dependencies:** PERF02, PERF04, PERF05, MEM04, AND04. **Trace:** Android performance gap.

**Do:** Run a 60-minute gameplay/transition trace at the selected refresh-rate target. Check first shader use, audio, input latency, background return and sustained throttling; adjust pacing/integration only where the trace shows a defect.

**Done when:** Presented-frame, CPU/GPU headroom, input feedback and thermal budgets pass after warm-up and at the end of the session; cold/first-use spikes are separately reported rather than hidden.

**Category exit:** Stable target-device frame pacing and responsive startup/loading for the supported content envelope; measured CPU/GPU/thermal evidence, with approved appearance preserved.

## Memory efficiency

### [ ] MEM01 — Choose and implement a compact versioned evidence representation

**Priority:** High. **Phase:** 2. **Effort:** 2–4 engineer-days. **Primary discipline:** Client + persistence. **Dependencies:** SEC01, TEST02. **Trace:** MA05; depends on MA01 policy.

**Do:** After the score-trust decision, replace nested per-tick control Arrays with packed input bytes where inputs are needed. Use an explicit count for modes that genuinely need no control contents; retain launch markers, handbrake, rewind offsets and legacy journal decoding.

**Done when:** A 216,000-frame control recording uses at most the proposed 2 MiB input-component budget; replay/rewind identity is exact and all prior pending uploads remain recoverable.

### [ ] MEM02 — Apply byte budgets and backpressure to queued work

**Priority:** High. **Phase:** 2. **Effort:** 1–3 engineer-days. **Primary discipline:** Client + persistence. **Dependencies:** MEM01, REL03. **Trace:** MA05; result_save_queue.

**Do:** Measure complete pending inputs/proofs/ghosts/encoder buffers, not only frame counts. Define byte-based limits for result saves, publication work and caches; spill safely to durable storage and preserve unrestricted legitimate offline racing.

**Done when:** Maximum pending cases stay inside a documented device-safe budget; full queues and disk-full states give recoverable feedback and never duplicate or silently discard acknowledged work.

### [ ] MEM03 — Coordinate retained resources and low-memory response

**Priority:** High. **Phase:** 2. **Effort:** 1–3 engineer-days. **Primary discipline:** Client + rendering. **Dependencies:** PERF01, ARC03. **Trace:** Audit retention and low-memory gaps.

**Do:** Inventory active/replacement/retained memory across Garage, editor, race, textures and audio. Give discretionary caches clear owners and pressure trimming. Reclaim hidden GPU views and work safely without blocking input on thread joins.

**Done when:** Per-state Android PSS/graphics budgets are documented and pass; forced pressure releases discretionary memory, preserves required saves and returns correctly to the prior screen.

### [ ] MEM04 — Prove transition memory reaches a plateau

**Priority:** Required gate. **Phase:** 3. **Effort:** 2–4 engineer-days. **Primary discipline:** Device QA + client. **Dependencies:** MEM02, MEM03, REL02. **Trace:** Audit nine-scene sample is insufficient.

**Do:** Run at least 50 complete Garage/race/results/editor/practice/settings cycles, then extend to 200 in automation. Include account changes, cancellation, all cars and repeated different tracks.

**Done when:** After controlled cache warm-up, comparable states show no growing live-object leak and PSS growth is within the proposed max(10 MiB, 5%) tolerance without a sustained rising trend. Retained high-water marks and GPU allocations are explained.

### [ ] MEM05 — Verify long attempts and effect/history bounds

**Priority:** Required gate. **Phase:** 3. **Effort:** 1–3 engineer-days. **Primary discipline:** Client + QA. **Dependencies:** MEM01, MEM02, TEST04. **Trace:** MA05; bounded history/effect verification.

**Do:** Exercise the 30-minute evidence cap, repeated rewinds, long ghost/telemetry capture, tyre marks, particles, audio voices and interrupted recording persistence. Remove allocations/retention only when measurements show value.

**Done when:** All structures have proven limits and exact overflow behavior; no foreground memory termination, lost acknowledged result or unbounded resource growth occurs in the agreed supported cases.

**Category exit:** Compact evidence, bounded active/replacement/retained memory, demonstrated transition plateau and safe pressure/process-death behavior.

## UI/UX implementation quality

### [ ] UX01 — Fix Store offer hierarchy and fit

**Priority:** High. **Phase:** 1. **Effort:** 1–2 engineer-days. **Primary discipline:** UI. **Dependencies:** Q00, TEST01. **Trace:** MA07.

**Do:** Recover visible space for the three slot-pack actions while retaining gifting, five products, prices, recovery controls, readable copy and minimum targets. Preserve scrolling on genuinely compact layouts.

**Done when:** The six audited initial-view assertions pass at 1280x720 and 960x540; compact landscape/portrait layouts remain usable, scroll reachability is intact and dragging over checkout never purchases.

### [ ] UX02 — Complete and validate all shipping localization

**Priority:** High. **Phase:** 1. **Effort:** 2–5 engineer-days. **Primary discipline:** Localization + UI. **Dependencies:** Q00, MAINT02. **Trace:** MA08; GLF new copy.

**Do:** Reconcile the source catalogue, exclude code/route false positives, author/review missing strings across English plus the eleven requested languages, and include the new live Parts descriptions. Preserve exact legal bodies and intentional proper names.

**Done when:** Strict extraction, plural/placeholder and authored-language checks pass; no unapproved English fallback remains in the shipping flow; long and CJK text fits current layouts with in-place language switching.

### [ ] UX03 — Review every major screen and state at target sizes

**Priority:** High. **Phase:** 2. **Effort:** 3–6 engineer-days. **Primary discipline:** UI + QA. **Dependencies:** UX01, UX02, REL01. **Trace:** MA07 MA08; latest RFC/GLF acceptance.

**Do:** Use a screen/state matrix covering discovery/detail/leaderboards, Garage/compare/wash, Creator, HUD/pause/results, Rivalry/ranking, Challenges, profiles/friends, Store, settings, sign-in and onboarding. Check loading/empty/error/offline/expired states and the separate compact World Ranking page.

**Done when:** No clipped required content, inaccessible action, misleading state or unowned layout exception remains at 1280x720, 960x540, 844x390, tablet/cutout and supported portrait dialogs. Approved Rivalry composition and live Parts rows remain unchanged.

### [ ] UX04 — Make touch, navigation and feedback consistent

**Priority:** High. **Phase:** 2. **Effort:** 2–4 engineer-days. **Primary discipline:** UI + device QA. **Dependencies:** UX03, REL04, AND04. **Trace:** Audit interaction gaps; preserve controls.

**Do:** Verify back/modal behavior, multi-finger ownership, gestures, momentary compare, focus loss, keyboard/controller navigation, confirmations, double-trigger protection and immediate action feedback. Review contrast, font scaling and applicable platform accessibility behavior.

**Done when:** Primary tap targets are at least the proposed 48 logical units; gesture routes, visual feedback and focus/back behavior pass physical-device checks; no duplicate charge/action or stuck input occurs.

### [ ] UX05 — Run an owner and independent-player polish pass

**Priority:** Required gate. **Phase:** 3. **Effort:** 2–4 engineer-days. **Primary discipline:** Owner + UX + QA. **Dependencies:** UX04, PERF06, AND02, AND03. **Trace:** Premium-quality acceptance gap.

**Do:** Observe representative first-time players using the complete flow without coaching. Review comprehension, perceived latency, error recovery, onboarding, art consistency and audio balance; resolve observed material problems without redesigning accepted art for style alone.

**Done when:** Owner approval and a recorded small usability round cover every core task; no unresolved blocking/confusing interaction or material readability/visual defect remains. This is human acceptance, not an automated screenshot score.

**Category exit:** All screens and states fit and respond consistently across supported devices/languages/input methods, with owner and observed-player acceptance.

## Correctness and reliability

### [ ] REL01 — Fix pause-row callback lifetime

**Priority:** High. **Phase:** 1. **Effort:** 0.5–1 engineer-days. **Primary discipline:** Client/UI. **Dependencies:** Q00, TEST01. **Trace:** MA06.

**Do:** Reproduce the deferred fit callback against current source and make layout scheduling node-owned or weak-reference guarded if still affected. Preserve content-derived row sizing.

**Done when:** Immediate/queued disposal, main/settings/help rebuilds, translation and resize cases produce no freed capture or Nil access, while all current tablet label-fit assertions pass.

### [ ] REL02 — Verify races, timing, restart, rewind and ghost invariants

**Priority:** High. **Phase:** 2. **Effort:** 2–4 engineer-days. **Primary discipline:** Gameplay + backend. **Dependencies:** Q00, TEST02. **Trace:** Race/timing and replay gaps.

**Do:** Run versioned golden input fixtures and independent timing/gate checks for all seven vehicles and five biomes. Cover bridge layers, finish crossings, duplicate/lost inputs, pause/restart and three rewinds; compare ghost/result/PB handling.

**Done when:** Same pinned inputs yield identical canonical outputs; no early/duplicate finish, wrong PB, changed scored time or ghost ownership is observed. Accepted electric handling and physical/camera contracts remain intact.

### [ ] REL03 — Prove saves and journals survive interruption

**Priority:** High. **Phase:** 2. **Effort:** 2–4 engineer-days. **Primary discipline:** Persistence. **Dependencies:** TEST02. **Trace:** Audit persistence fault gap.

**Do:** Inject failed writes/flushes/renames, ENOSPC and process death before and between durable journal phases. Exercise primary/backup recovery, old schemas, pending results, creator WIP and cosmetics.

**Done when:** Acknowledged saves and results are not lost; uncommitted work is clearly identified; restart recovers safely and exactly once without overwriting a good backup or changing account ownership.

### [ ] REL04 — Close asynchronous network and account race cases

**Priority:** High. **Phase:** 2. **Effort:** 2–4 engineer-days. **Primary discipline:** Client/backend. **Dependencies:** TEST02, ARC03. **Trace:** MA03; cross-module state risks.

**Do:** Use owned fixtures to reorder/delay/duplicate replies and change navigation, car, selected track, account or origin during each request. Cover refresh-token ambiguity, offline reconnect and server-time transitions.

**Done when:** Old replies cannot mutate current state, retries remain idempotent, valid sessions survive known non-delivery, ambiguous operations recover correctly and every wait has a recoverable timeout/cancel path.

### [ ] REL05 — Protect Creator round trips and all shipped tracks

**Priority:** High. **Phase:** 2. **Effort:** 3–5 engineer-days. **Primary discipline:** Creator + backend. **Dependencies:** Q00, TEST02. **Trace:** RP01-RP04 and audit creator coverage.

**Do:** Test normal road-part import/edit/undo/redo/save/load/test/publish, invalid/malicious documents and cost limits. Include all five corrected Storm tracks and legacy files only under the supported migration policy.

**Done when:** Valid tracks round-trip unchanged through UI/storage/compiler/verifier; malformed tracks fail safely; corrected Storm road parts/routes/start lines/207 objects remain; no validator assertion is weakened.

### [ ] REL06 — Prove progression and entitlement transactions once

**Priority:** High. **Phase:** 2. **Effort:** 2–4 engineer-days. **Primary discipline:** Economy/backend + QA. **Dependencies:** SEC03, TEST02, AND02, AND03. **Trace:** MA01 MA02; progression/concurrency gap.

**Do:** Test rewards, achievements, cosmetic purchases, publishing slots/gifts, challenge tries, ad resumes, restoration and UTC day/week changes under duplicates, concurrent delivery, account deletion and worker restart.

**Done when:** Independent ledgers reconcile; no duplicate/missing grant or overspend appears; sorted gift locks and immutable buyer/recipient are retained; actual PostgreSQL concurrency and provider fixtures pass.

**Category exit:** Race/editor/save/network/progression invariants survive normal operation, failures, duplicates, interruption and real PostgreSQL concurrency.

## Software architecture

### [ ] ARC01 — Extract race-entry and race-return ownership

**Priority:** Medium. **Phase:** 2. **Effort:** 3–6 engineer-days. **Primary discipline:** Client architecture. **Dependencies:** TEST01, REL01. **Trace:** MA09.

**Do:** Move preparation, cancellation, ticket/result handoff and return-state behavior into a narrow lifecycle component with explicit context and outcomes. Keep App as composition root and preserve all existing fences.

**Done when:** Race entry/return can be tested without constructing the whole menu/App; cancellation, account/car/track changes, exact return camera and results-first behavior remain correct.

### [ ] ARC02 — Extract the Creator session lifecycle

**Priority:** Medium. **Phase:** 2. **Effort:** 3–6 engineer-days. **Primary discipline:** Client architecture. **Dependencies:** TEST01, REL03. **Trace:** MA09.

**Do:** Give one component ownership of current document, history, commit/write queues, unsaved departure and preview work. Keep native UI adapters separate from document and transaction rules.

**Done when:** Creator save/undo/departure/failure scenarios run through an isolated contract; screen rebuilding cannot silently own or drop pending writes; current editor behavior and old files remain compatible.

### [ ] ARC03 — Make account and asynchronous operation ownership explicit

**Priority:** Medium. **Phase:** 2. **Effort:** 2–4 engineer-days. **Primary discipline:** Client/backend architecture. **Dependencies:** TEST02. **Trace:** MA09; account fence duplication.

**Do:** Provide a small typed account/origin/navigation context and operation lifetime contract for domain adapters. Centralize repeated scope rules only where it removes a proven source of inconsistency; avoid a generic event bus or extra global managers.

**Done when:** Ownership/cancellation rules have a single documented contract, captured work remains immutable and the stale-reply corpus passes across all adapters without hidden global-state dependence.

### [ ] ARC04 — Enforce domain boundaries and resource ownership

**Priority:** Medium. **Phase:** 2. **Effort:** 1–2 engineer-days. **Primary discipline:** Architecture. **Dependencies:** ARC01, ARC02, ARC03. **Trace:** MA09; literal-load graph.

**Do:** Add lightweight dependency/ownership checks for simulation, presentation, UI, platform, persistence and backend domains. Review the recorded load cycles and break only harmful coupling; document cache/thread owners.

**Done when:** Canonical simulation has no UI/network/filesystem/wall-clock dependencies; platform SDKs remain behind adapters; domain tests isolate real behavior; every intentional dependency cycle has a reason and no eager-load failure.

**Category exit:** Owned lifecycles, narrow typed contracts and enforced domain boundaries allow feature work and meaningful tests without constructing the entire App.

## Maintainability

### [ ] MAINT01 — Make local development reproducible

**Priority:** Medium. **Phase:** 1. **Effort:** 2–4 engineer-days. **Primary discipline:** Tooling. **Dependencies:** Q00, TEST01. **Trace:** MA03; build tooling.

**Do:** Provide one documented bootstrap/doctor path for exact engine/templates, native binaries and backend test dependencies; keep credentials external and support isolated data/output directories.

**Done when:** A fresh machine/checkout can run the documented fast and integration gates without private ignored build snapshots, owner saves or undocumented manual setup.

### [ ] MAINT02 — Make schemas and shared data definitions coherent

**Priority:** Medium. **Phase:** 1. **Effort:** 1–3 engineer-days. **Primary discipline:** Tooling/client/backend. **Dependencies:** Q00. **Trace:** MA08 MA09; avoid blind helper consolidation.

**Do:** Inventory client/server wire schemas, limits, enums and localization source extraction. Consolidate or generate only definitions with shared semantics; keep differing persistence backup/validation contracts explicit.

**Done when:** A schema/limit change has one authoritative definition or an enforced compatibility check; translations/extractors exclude code keys; client/server contract drift is caught before merge.

### [ ] MAINT03 — Remove only proven obsolete code and resources

**Priority:** Medium. **Phase:** 2. **Effort:** 1–3 engineer-days. **Primary discipline:** Client/backend. **Dependencies:** TEST01, ARC04. **Trace:** Audit legacy review.

**Do:** Build a reference/export/tool/fixture inventory and remove genuinely unreachable production artifacts, duplicated implementations and deprecated paths. Archive historical replay/provenance evidence rather than deleting its context.

**Done when:** Every deletion has a negative-use/reference check plus export/runtime verification; HandlingSelection and historical rules are retained where still used; no saved-data compatibility disappears accidentally.

### [ ] MAINT04 — Maintain a concise current system and change guide

**Priority:** Medium. **Phase:** 2. **Effort:** 2–3 engineer-days. **Primary discipline:** Engineering. **Dependencies:** ARC04, MAINT01. **Trace:** Audit documentation and change cost.

**Do:** Document actual seven-car/current-track architecture, source of truth, state/ownership boundaries, build/release steps and critical compatibility policies. Record relevant design decisions beside the code and link historical evidence.

**Done when:** A developer unfamiliar with this chat can locate/change a feature and run its relevant checks without reconstructing dated status files; no undocumented contract or obsolete release claim remains.

### [ ] MAINT05 — Set durable code-health and review checks

**Priority:** Medium. **Phase:** 2. **Effort:** 1–3 engineer-days. **Primary discipline:** Engineering. **Dependencies:** TEST03, ARC04. **Trace:** MA03 MA09.

**Do:** Resolve real typing/error-handling issues and the audited lint failures; establish narrow reviewed changes and code ownership for high-risk domains. Avoid file-size/abstraction targets without an actual maintenance benefit.

**Done when:** Lint/type/contract checks pass and are enforced; failed invariants need an explicit accepted requirement change; critical behavior and error contracts are documented and reviewed.

**Category exit:** Reproducible development, current contracts/docs, clean enforced checks and only verified removals; a new engineer can make a bounded change safely.

## Security

### [ ] SEC01 — Decide protected competition trust and cost policy

**Priority:** First. **Phase:** 0. **Effort:** 1–2 engineer-days. **Primary discipline:** Owner + backend/security. **Dependencies:** Q00. **Trace:** MA01; prior approved trajectory policy.

**Do:** Choose what server-proven legitimacy rankings and valuable rewards require, a verifier capacity/cost budget, and a versioned migration policy. Preserve the existing lightweight policy until an explicit owner decision authorizes a change.

**Done when:** A written decision defines protected modes, evidence schema, legacy cohorts, acceptable latency/cost and enforcement. Simply accepting the demonstrated fabrication risk does not count as closing it for a 10/10 security claim.

### [ ] SEC02 — Make protected score acceptance resistant to fabricated drives

**Priority:** High. **Phase:** 1. **Effort:** 5–10 engineer-days. **Primary discipline:** Backend/gameplay/security. **Dependencies:** SEC01, TEST02, REL02. **Trace:** MA01.

**Do:** Implement the selected server-verifiable acceptance design using existing canonical replay capability where appropriate; make untrusted evidence, rewinds/layers and worker admission explicit. Load-test the protected path.

**Done when:** The fabricated Ellipse/instant acceleration/illegal curvature/layer/sample-density corpus cannot earn protected verified scores; legitimate pinned drives still pass; no client hash/attestation claim substitutes for actual authority. Sample-only detection is documented as partial if unverified scores remain.

### [ ] SEC03 — Remove unproved authority from valuable rewards

**Priority:** High. **Phase:** 1. **Effort:** 2–4 engineer-days. **Primary discipline:** Backend/economy. **Dependencies:** SEC01, TEST02. **Trace:** MA01 clean-race bonus.

**Do:** Require adequate server evidence for clean-race and other authoritative achievements/rewards, or change their classification/value under the accepted policy. Retain atomic grants, wallet locks and idempotency.

**Done when:** Changing client collision/off-track flags alone cannot obtain an authoritative clean reward; duplicate/forged claims and concurrent delivery have no extra financial/progression effect.

### [ ] SEC04 — Review every public trust and authorization boundary

**Priority:** High. **Phase:** 2. **Effort:** 1–3 engineer-days. **Primary discipline:** Security/backend. **Dependencies:** SEC02, SEC03, TEST02. **Trace:** Audit trust boundaries; preserve existing protections.

**Do:** Exercise authentication expiry/rotation, cross-account reads/writes, UGC/resource exhaustion, replay, gifts, publication, discovery work limits, private moderation, Studio MFA/roles, remote config and restore/erasure boundaries with adversarial requests.

**Done when:** No unauthorized data/action or unbounded work is found in the maintained corpus; rate/capacity decisions have tested failure responses; named production staff access and credential isolation remain intact.

### [ ] SEC05 — Scan resolved dependencies and protect release secrets/privacy

**Priority:** High. **Phase:** 2. **Effort:** 2–4 engineer-days. **Primary discipline:** Security + release. **Dependencies:** AND01, TEST06. **Trace:** MA11 MA12.

**Do:** Generate client/native/backend resolved SBOMs and advisory results, inspect actual permissions/exported components and secret handling, and preflight completed developer/contact/provider/privacy configuration.

**Done when:** No unmitigated applicable critical/high dependency or secret exposure remains; the actual package and infrastructure configuration match the intended permissions and disclosures; rejected production defaults fail safely.

### [ ] SEC06 — Obtain an independent adversarial review

**Priority:** Required gate. **Phase:** 3. **Effort:** 3–5 engineer-days. **Primary discipline:** Independent security reviewer. **Dependencies:** SEC04, SEC05, AND02, AND03. **Trace:** Security final acceptance.

**Do:** Have a reviewer outside the implementation exercise competition, money, UGC, identity, privacy and administrative paths against a frozen disposable release environment; resolve verified findings and retain the abuse corpus.

**Done when:** No open release-blocking/high-severity exploit remains; medium issues have explicit owner-approved disposition, regression evidence and monitoring. Review covers the final contracts rather than the old audited build.

**Category exit:** Fabricated protected scores/rewards and public authorization/abuse cases are addressed; resolved artifacts/configuration and independent adversarial review pass.

## Testing

### [ ] TEST01 — Create a maintained test manifest and read-only harness

**Priority:** First. **Phase:** 1. **Effort:** 2–3 engineer-days. **Primary discipline:** Tooling + QA. **Dependencies:** Q00. **Trace:** MA03; nested build helper side effect.

**Do:** Classify fast/native/local-HTTP/PostgreSQL/canonical/device/historical/capture jobs; declare inputs and outputs, isolate data, prevent implicit live endpoints and add a mode that does not regenerate source identity.

**Done when:** The selected release suites are explicit and reproducible; missing critical prerequisites fail clearly, developer-only cases skip with a reason, and read-only checks do not touch production source or old evidence.

### [ ] TEST02 — Provision owned integration and fault fixtures

**Priority:** High. **Phase:** 1. **Effort:** 2–4 engineer-days. **Primary discipline:** Backend/tooling + QA. **Dependencies:** TEST01. **Trace:** MA03.

**Do:** Create disposable PostgreSQL, local HTTP, provider fake responses, clock/fault controls and deterministic content fixtures. Make teardown recoverable and remove dependency on owner services or ignored baseline source.

**Done when:** Concurrency/timeout/expiry/provider failure tests run locally and in CI with no live credentials; clean and developer checkouts execute the same assertions.

### [ ] TEST03 — Triage and repair the full current regression result

**Priority:** High. **Phase:** 1. **Effort:** 2–5 engineer-days. **Primary discipline:** QA + owning engineers. **Dependencies:** TEST01, TEST02. **Trace:** MA03; latest owner overrides.

**Do:** Re-run against the current snapshot; classify all old failures and repair active bugs, stale doubles, planner/log assumptions and rollback fixtures. Map explicitly superseded visual assertions to the new accepted requirements while retaining authority/invariant tests.

**Done when:** Required suites pass with zero unexplained failure/runtime error; historical failures remain recorded; unsupported environment checks are not reported as passes. Current Storm/Rivalry/Garage/electric suites are selected.

### [ ] TEST04 — Fill critical cross-system failure coverage

**Priority:** High. **Phase:** 2. **Effort:** 3–6 engineer-days. **Primary discipline:** QA + domain owners. **Dependencies:** TEST02, REL02, REL03, REL04, REL05, REL06. **Trace:** Audit verification gaps.

**Do:** Add meaningful scenarios for race timing, save interruption, creator round trips, progression, account/origin changes, worker retries, purchases/ads and scene transitions, using independent expected outcomes rather than mirroring implementation.

**Done when:** Every critical player/data/money invariant has normal and recovery-path coverage; observed regressions become retained tests; requirements-to-test mapping is reviewable.

### [ ] TEST05 — Add bounded differential and adversarial corpus checks

**Priority:** Medium. **Phase:** 2. **Effort:** 2–4 engineer-days. **Primary discipline:** Gameplay/backend + QA. **Dependencies:** TEST02, SEC02, REL05. **Trace:** Fairness, parser and persistence robustness.

**Do:** Fuzz valid/invalid track documents and wire input; compare canonical recordings/serialization across supported builds and exercise seeded score/transaction abuse cases. Bound run time and retain failing seeds.

**Done when:** A documented seed/corpus budget runs reproducibly, catches deliberately introduced boundary violations and reports minimized failing cases without worker/resource exhaustion.

### [ ] TEST06 — Enforce build, integration and release gates

**Priority:** High. **Phase:** 2. **Effort:** 2–4 engineer-days. **Primary discipline:** Release/tooling. **Dependencies:** TEST01, TEST02, TEST03. **Trace:** MA03 MA11.

**Do:** Add CI or an equivalent enforced pipeline for fast checks, native layout, PostgreSQL, replay/contracts, localization, dependency/secret checks and signed-artifact validation. Capture error logs and baseline comparisons as artifacts.

**Done when:** A bad script/logged runtime error/contract mismatch reliably blocks promotion even with exit code zero; required platform gates have actual evidence and no silent skip; identical source/toolchain gives an explainable build identity.

**Category exit:** Maintained isolated suites run in enforced gates, cover critical failure paths and cannot be green through missing fixtures, optional private baselines or ignored runtime errors.

## Observability

### [ ] OBS01 — Retain symbols and prove crash/ANR diagnosis

**Priority:** High. **Phase:** 2. **Effort:** 1–3 engineer-days. **Primary discipline:** Release/operations. **Dependencies:** AND01, SEC05. **Trace:** MA10.

**Do:** Store build/native symbol mappings, correlate safe failure identifiers and integrate an appropriate Play vitals/ANR investigation workflow. Preserve optional telemetry consent and clearly separate guest/opt-out coverage.

**Done when:** A deliberate crash/ANR in a disposable release is attributable to its exact build and useful script/native location; no token, private body or unapproved optional collection appears in output.

### [ ] OBS02 — Make performance and network observations actionable

**Priority:** High. **Phase:** 2. **Effort:** 2–4 engineer-days. **Primary discipline:** Client/backend operations. **Dependencies:** PERF01, TEST03. **Trace:** MA10; request-trace test mismatch.

**Do:** Attach bounded release/device/renderer/track/configuration context and relevant request IDs to existing slow-frame, loading, failure and queue metrics. Fix dashboard/test confusion between individual events and summaries.

**Done when:** A reproduced slow scene or failed transaction can be traced from device evidence to the matching server outcome; dashboards state coverage, sampling and data age without implying unobserved guests or verified incidents.

### [ ] OBS03 — Exercise alerts and monitoring independently of the API

**Priority:** High. **Phase:** 3. **Effort:** 1–3 engineer-days. **Primary discipline:** Operations. **Dependencies:** OBS02, SEC05. **Trace:** MA10; existing monitoring needs deployment evidence.

**Do:** Configure and test the existing watchdog/incident paths for API/storage/database failure, stuck queues, verification mismatch, deletion lag and provider fulfillment trouble, with named operational ownership and controlled alert noise.

**Done when:** A staged outage produces an actionable alert within the proposed five-minute window even if the game API is down; recovery resolves correctly and a missing monitoring source itself becomes visible.

### [ ] OBS04 — Rehearse recovery and observe a release candidate

**Priority:** Required gate. **Phase:** 3. **Effort:** 2–3 engineer-days. **Primary discipline:** Operations + QA. **Dependencies:** OBS01, OBS03, AND05, AND06. **Trace:** Operational readiness; ongoing after launch.

**Do:** Write short diagnosis/rollback/restore/provider/deletion runbooks, rehearse representative incidents on disposable infrastructure and observe a representative beta for at least the proposed fourteen days.

**Done when:** Restore/rollback/erasure replay are demonstrated within accepted RPO/RTO; no unresolved material incident remains; enough real exposure exists to interpret reliability rates, rather than claiming 99.9% from a tiny test sample.

**Category exit:** A real slow frame, crash, failed transaction or outage is diagnosable by exact build/context; coverage and consent are explicit; alerts and recovery are rehearsed.

## Android production readiness

### [ ] AND01 — Define the reproducible signed release variant

**Priority:** High. **Phase:** 1. **Effort:** 1–2 engineer-days. **Primary discipline:** Android/release. **Dependencies:** Q00, TEST01. **Trace:** MA11.

**Do:** Create reviewed release configuration, increasing version codes, correct visible branding, intended ABIs, pinned toolchain, secure signing references and final merged-manifest/ELF/ZIP/debug-component checks. Preserve the installed application identity/data.

**Done when:** A reproducible signed test artifact passes native/package checks, excludes demo adapters/diagnostic CA and unsupported debug flows, and has retained symbols, resolved dependency inventory and exact build provenance.

### [ ] AND02 — Complete real Play Billing and restoration

**Priority:** High. **Phase:** 1. **Effort:** 5–8 engineer-days. **Primary discipline:** Android + commerce/backend. **Dependencies:** SEC01, SEC03, AND01, TEST02. **Trace:** MA02.

**Do:** Implement the platform checkout adapter with localized provider products/prices, account binding, pending state, durable server verification, acknowledgment/consumption, resume recovery, restoration, immutable gifts and refund/revoke reconciliation.

**Done when:** Licensed sandbox purchase/pending/cancel/retry/process-death/account-switch/gift/restore/refund cases pass end to end with exactly-once entitlements. No simulated receipt or UI completion grants paid access.

### [ ] AND03 — Complete production ads, privacy choices and SSV

**Priority:** High. **Phase:** 1. **Effort:** 2–5 engineer-days. **Primary discipline:** Android + backend. **Dependencies:** AND01, SEC03, TEST02. **Trace:** MA02; provider consent and reward boundary.

**Do:** Integrate production placements behind the existing policy, appropriate privacy-choice flow and signed server reward verification/recovery. Preserve ad-free ownership and banked/daily resume precedence, and handle no-fill/close/background/late callbacks.

**Done when:** Test geography/consent/opt-out and provider callback fixtures pass; no request bypasses the relevant privacy state; one ad receipt grants at most one valid benefit and failure never consumes a resume incorrectly.

### [ ] AND04 — Pass lifecycle and physical-device compatibility

**Priority:** High. **Phase:** 2. **Effort:** 2–5 engineer-days. **Primary discipline:** Android + device QA. **Dependencies:** AND01, REL02, REL03, REL04. **Trace:** Audit Android verification gap.

**Do:** Execute the device matrix: Nord 2, representative Adreno/Mali phone, constrained supported API device, tablet/cutout, 4-KiB and 16-KiB environments. Include Home/screen lock/call/audio focus/sign-in/ad/Billing activity/app links/process death/network handover.

**Done when:** No stuck control, unexpected resume, lost acknowledged data, duplicate transaction, rendering fault or unsupported native dependency remains. Keyboard/controller behavior and tablet gestures also pass where supported.

### [ ] AND05 — Reconcile final notices, disclosures and release policy

**Priority:** High. **Phase:** 2. **Effort:** 2–4 engineer-days. **Primary discipline:** Release + owner/privacy. **Dependencies:** AND01, AND02, AND03, SEC05. **Trace:** MA11 MA12; licence review outstanding artifact work.

**Do:** Reconcile exact final Gradle/native/assets against licences/provenance, developer/contact identity, consent, Data safety and account-deletion behavior. Validate backup retention and restored deletion replay. Obtain the appropriate owner/legal sign-off on unresolved policy questions.

**Done when:** No placeholder identity/contact or unresolved release provenance/notice discrepancy remains; the actual package/service matches its disclosures and technical deletion/retention tests; sign-off is recorded without treating this plan as legal advice.

### [ ] AND06 — Verify distribution, upgrade, rollback and beta release

**Priority:** Required gate. **Phase:** 3. **Effort:** 2–3 engineer-days. **Primary discipline:** Release + operations + QA. **Dependencies:** AND02, AND03, AND04, AND05, TEST06, SEC06. **Trace:** Final production readiness.

**Do:** Exercise the intended test-distribution path, upgrade from supported installed versions with existing saves, offline first run, signed app links, provider configuration and client/API/worker migration compatibility. Stage rollout with measurable stop/rollback criteria.

**Done when:** The distributed artifact, not only a local debug build, passes updates and full device/transaction smoke checks. Backend backup/restore and rollout order are rehearsed; no production action is implied until separately authorized.

**Category exit:** Actual signed distribution, production provider sandbox flows, lifecycle/device compatibility, upgrade preservation and final release disclosures/notices are evidenced.

## Final acceptance

### [ ] Q99 — Re-audit the frozen release and assign final scores

**Priority:** Final. **Phase:** 4. **Effort:** 0.5–1 engineer-days. **Primary discipline:** Independent review + owner. **Dependencies:** PERF06, MEM04, MEM05, UX05, REL06, ARC04, MAINT03, MAINT04, MAINT05, SEC06, TEST04, TEST05, TEST06, OBS04, AND06. **Trace:** All ten audit categories.

**Do:** Review every category against its agreed exit criteria using the frozen artifact and actual results; verify independent security/UX acceptance, current device traces, full gates, recovery and beta observations. Record remaining limitations and ongoing owners.

**Done when:** Every required task has evidence, every category exit criterion passes and no known material defect or unmeasured requirement is relabeled 10/10. Any area lacking device/provider/operational evidence stays provisional.

## Effort, sequencing and dependencies

The estimates include focused implementation and its verification, not a second full rewrite/testing allocation. Cross-area tasks reference the same work rather than duplicating it: for example, UI relies on REL01 for pause lifetime, security and memory share SEC01's evidence decision, and every provider flow shares TEST02's fixtures.

| Workstream | Engineer-days | Key dependencies / uncertainty |
|---|---:|---|
| Runtime performance | 11–23 | See task dependencies; rebaseline may close work already completed. |
| Memory efficiency | 7–17 | See task dependencies; rebaseline may close work already completed. |
| UI/UX implementation quality | 10–21 | See task dependencies; rebaseline may close work already completed. |
| Correctness and reliability | 11.5–22 | See task dependencies; rebaseline may close work already completed. |
| Software architecture | 9–18 | See task dependencies; rebaseline may close work already completed. |
| Maintainability | 7–16 | See task dependencies; rebaseline may close work already completed. |
| Security | 14–28 | See task dependencies; rebaseline may close work already completed. |
| Testing | 13–26 | See task dependencies; rebaseline may close work already completed. |
| Observability | 6–13 | See task dependencies; rebaseline may close work already completed. |
| Android production readiness | 14–27 | See task dependencies; rebaseline may close work already completed. |
| Shared baseline and final review | 1–2.5 | Frozen snapshot and complete evidence. |
| **Total planning range** | **103.5–213.5 engineer-days (20.7–42.7 engineer-weeks)** | Provider/platform approval, device access and additional discovered defects can extend the range. |

This is an initial bottom-up planning range, not a quote. One full-time engineer needs roughly the stated engineer-weeks of hands-on work before calendar overhead; two or three engineers can overlap client/performance, backend/commerce/security and QA/release work, but cannot simply divide every dependency by team size. Device procurement/access, multilingual human review, independent review, provider setup and the beta/observation period require separate calendar planning. Re-estimate after Q00, PERF01 and TEST03.

The main dependency paths are:

- Current baseline → owned fixtures → trustworthy gates → safe implementation and final regression.
- Competitive trust decision → protected acceptance and reward authority → compact compatible evidence → security review.
- Device baseline → startup/render changes and memory ownership → thermal/transition soak → performance acceptance.
- Release variant → Billing/ads → transaction recovery + privacy/notices → distribution/upgrade verification → observed release candidate.
- Existing contracts and tests → narrow lifecycle extraction → boundary and change-cost verification.

## Changes that must remain protected

- The corrected five Storm circuits use normal editor road parts, generated routes and placed start lines; retain all 207 intentional objects and original editor/compiler/physics guards.
- The latest Rivalry finale composition, full list/player reveal, five detail actions, fixed outer page and standings-only scrolling are accepted. Do not reintroduce superseded subtitle/highlight/badge layouts to satisfy old tests.
- The live Garage Parts list, single main preview, projected callout, momentary compare and authoritative economy/account/save fences remain. Translate its new copy rather than reverting its design.
- Electric-12's consistent finite-rate keyboard/controller handling, 190 km/h cap, release braking, other-car isolation and versioned contracts remain. Performance work does not tune physics or camera behavior.
- Unlimited legitimate racing, local drafts, earned progression and authority/idempotency boundaries remain. Never make a gate pass by weakening an invariant or hiding an untested platform.

## Primary technical references checked for this plan

Use Godot's current 3D optimization guidance to investigate culling, batching and transparency costs before altering artwork; it does not justify changing the accepted game scene without measured benefit. [Godot 3D optimization](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html).

Use presented-frame/thermal evidence alongside engine CPU timings; Android identifies GPU/CPU load, heat and display pacing as distinct causes of slow game sessions. [Android slow sessions](https://developer.android.com/games/optimize/vitals/slow-session), [Android performance issues](https://developer.android.com/topic/performance/issues).

Billing must distinguish pending from purchased state and recover purchases when the app resumes; complete the provider verification and acknowledgment/consumption lifecycle rather than treating a client callback as fulfillment. [Google Play Billing integration](https://developer.android.com/google/play/billing/integrate).

Production ad requests and privacy choices require the applicable consent-state handling; signed SSV protects rewarded-ad fulfillment against forged client callbacks. [AdMob UMP integration](https://developers.google.com/admob/android/privacy), [AdMob SSV](https://developers.google.com/admob/android/ssv).

Provider versions and distribution requirements should be rechecked against the actual release date. The numerical quality budgets above are proposed project targets, not Google or Godot certification rules.

## Scope and tracking

This deliverable adds only the task document and CSV. It does not implement any fix, alter the historical audit, run regression/device tests, build an APK/AAB, sign in, charge a purchase, change owner data or deploy a service. The missing-image observation is a read-only source check, not a fresh application regression diagnosis. Close a task only with dated source/artifact identity, actual commands, results and required owner/device acceptance. Record validated existing work as completed; do not rebuild it merely because it appears in this plan.
