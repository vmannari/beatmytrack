# Backend Studio requirements inventory, 2026-10-11

Local telemetry follow-up: [signed-in telemetry and product analysis](PRODUCT_TELEMETRY_2026_10_11.md) now implements bounded collection, prepared activity, ordered journeys, exact-day retention and exposure/action reporting. Collection is disabled by default and has not been deployed. The review below describes its original snapshot; broader requirements and live coverage remain separately assessed.

The supplied package proposes **92 requirements: 55 P0, 34 P1 and 3 P2**, plus 66 event types, 34 metric definitions and 16 workspaces. The existing console provides substantial authoritative support, content, race, commerce and worker inspection. Behavioural analytics, revenue truth, staff identity, privacy, experiments and remote configuration need new data or domain services; a presentation change cannot supply those records.

This inventory fulfills the discovery work of **BMT-001** and prepares the additive rollout required by **BMT-104**. The [machine-readable evidence map](backend-studio-requirements-2026-10-11.json) preserves every exact workbook ID, priority, requirement, acceptance criterion, dependency and proposed owner under `source`, and records an independent assessment, evidence, endpoints, migration risk and remaining acceptance for every row. The original workbook is unchanged; source artifact hashes are recorded. DOCX/XLSX content was extracted with standard-library ZIP/XML parsing; the 33-page PDF was read with already-installed PyMuPDF and its four prototype screenshot pages were exported as local references. No dependency was installed. This review did not independently verify the vendor/research/legal claims in the package.

Statuses describe implementation coverage, not production acceptance. **Existing** requires the complete stated behaviour; **Partial** identifies implemented portions and gaps; **Missing** means the required service/data contract is absent from the inspected source; **Unknown** would require evidence the repository cannot establish. Conservatively, no broad requirement is declared fully complete just because one domain portion or prototype control exists. Prior test/rollout results in [BACKEND_UI.md](BACKEND_UI.md) remain prior evidence, separate from this task's checks.

## Owner-resolved policy overrides

| Requirement | Current approved contract | Draft proposal | Resolution |
|---|---|---|---|
| BMT-014 | All Studio totals include all players, including artificial drivers; public competition stays isolated. | Exclude server-classified synthetic traffic from production product KPIs by default. | **Resolved 2026-10-11:** retain all-player totals; display per-player Real/Artificial from `Player.is_test_driver`. Development authentication alone does not mean Artificial. |
| BMT-045 | One initial publishing slot/account, no recurring allowance; each new published revision consumes capacity. | One free slot per UTC month without accumulation. | **Resolved 2026-10-11:** one INITIAL slot. Monthly rewards are a possible later idea, without authorization to implement. |
| BMT-046 | UTC calendar-month extension plus permanent ad-free; active access bypasses rewarded resume ads and preserves daily/banked resumes. | Thirty-day benefit and independently defined optional rewarded-ad treatment. | **Resolved 2026-10-11:** matching calendar day (September 12 → October 12), same UTC time; retain short-month clamping and active-expiry extension. |

These three decisions are resolved. Their original workbook wording remains under `source`; explicit owner-approved overrides and effective acceptance are recorded separately in the JSON. The admin-only player flag supersedes the earlier no-classification presentation restriction; no population selector, ordinary game badge or public ranking change follows. See [policy evidence](BACKEND_STUDIO_POLICIES_2026_10_11.md).

The draft's old demo prices are explicitly proposals. The approved five-product catalog remains `creator_slot_1` EUR0.99, `creator_slots_5` EUR3.49, `creator_slots_10` EUR5.99, `ad_free_month` EUR3.49 and `ad_free_forever` EUR9.99. See [PURCHASE_SIMULATION.md](PURCHASE_SIMULATION.md). Prices are catalog values, not verified revenue. No refund/revocation policy or real provider purchase configuration is inferred from this package.

The package references `contracts/`, `qa/` and `IMPLEMENTATION_PROMPT.md`, which were not supplied in `temp/backend-gui`. The standalone HTML is present. Reference schemas and claimed artifact/golden test results therefore cannot be treated as inspected or passed. The workbook supplies event names/property inventories but not all typed ingestion schemas.

## Data coverage and delivery order

1. Preserve existing support/commerce/search/worker workflows and pinned five-lap trajectory verification. The first local slice now implements a read-only player → race → exact immutable track evidence workflow and honest capability coverage, using bounded redacted exports. Local regression passed; production deployment remains unauthorized.
2. Define the minimum governed telemetry/session contract using the owner's all-player Studio population policy, then additive first-party ingress/outbox/read projections. Foreground sessions, first opens, discovery exposure, deliberate abandonment, device frame histograms and music/control/editor observations must begin at a recorded coverage date. Historical submission rows cannot reconstruct them.
3. Build golden-tested activity/funnel/retention/creator metrics with explicit maturity, denominator, late-data and snapshot definitions. The proposed north star (three accepted races across two days in seven) remains a product decision. Analytical load must stay separate from the game writer as measured volume grows.
4. Treat real provider verification, SSV, amount/currency snapshots, refunds/reconciliation, privacy requests, individual staff SSO/MFA, moderation cases, remote-config rollout and experiments as separate bounded domain slices. They require policy/configuration and evidence; unavailable states must remain visible until then.

P0 means mandatory before its associated feature is live; the specification explicitly does not require all advanced domains before the first read-only release. No external analytics/vendor dependency, cloud migration, gameplay change, fake live metric or new production write follows from the reference architecture.

## Implemented local slice and actual evidence

`backend/bmt_backend/studio.py` adds authenticated read-only `GET /v1/admin/studio/capabilities` (`bmt-studio-capabilities-v1`) and `GET /v1/admin/studio/races/{run_id}` (`bmt-studio-race-evidence-v1`). `?download=true` returns the same bounded redacted snapshot as a no-store JSON attachment. The snapshot links original player/ticket/board/track version, projects only known scalar pinned fields, converts accepted ticks only with the pinned rate, includes ownership-matched resume receipts (maximum 100) and carries a canonical-JSON SHA-256 checksum. PostgreSQL repeatable-read/read-only and SQLite explicit read transactions prevent mixed worker-completion state. The actual stored receipt/verification times are labelled accurately; ticket issue does not claim a client start, and verification terminal time does not claim driving finish.

`backend/bmt_backend/admin_ui/studio.js` and the retained shell provide the linked race → original track → evidence download flow and implementation-backed capability gaps. Existing player support, development purchase controls and commerce remain available. The shell preserves supported UTC date context, cancels obsolete reads, fences late reads and pending previews after Lock/re-login, distinguishes denied access, returns dialog focus and supplies a table alternative to the daily chart. The broader requirement rows stay Partial because sessions, device/reproduction capture, metric service, replay UI, staff SSO, provider verification and other domains remain absent.

| Actual command/check | Actual outcome |
|---|---|
| `.tools/backend-venv/Scripts/python.exe scripts/test_backend_studio_postgres.py` | **66 passed, 2 expected skips**, 40.58s. Includes all 16 new Studio tests (15 SQLite plus one actual PostgreSQL coherent read-only snapshot while a worker completes). Also covers existing admin/support/store suites. Owned disposable PostgreSQL17 container removed; [log](evidence/backend-studio-2026-10-11/postgres.log). |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_admin.py backend/tests/test_admin_support.py backend/tests/test_store_admin.py -q -m 'not postgres' -k 'not postgres'` | **27 passed, 2 skipped, 23 deselected**, 15.58s; existing SQLite baseline. Parent tool output retained in the conversation; no separate baseline log. |
| `.tools/backend-venv/Scripts/python.exe scripts/test_backend_studio_console.py` | Final **11 browser checks, zero failures**, against an owned loopback SQLite/FakeVerifier fixture. Actual exact-version link/download, analyst inspection, cancellation/Lock fences, dialog focus, failure/Retry and 1440/960/390 containment; [receipt](evidence/backend-studio-2026-10-11/browser-receipt.json). |
| `.tools/backend-venv/Scripts/python.exe scripts/test_admin_support_console.py --output docs/evidence/backend-studio-2026-10-11/support-regression` | **10 existing support workflow checks, zero failures/JavaScript errors**; [observations](evidence/backend-studio-2026-10-11/support-regression/browser-checks.json) and retained screenshots. |
| Changed Python Ruff and all four served JavaScript syntax checks | Passed, as recorded by the parent implementation task. |

Policy contract follow-up: `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_commerce.py -q -k '(initial_allowance or calendar_month or monthly_stacks) and not postgres' --disable-warnings --tb=short` → **11 passed, 42 deselected, one existing warning**, 1.62s. Added meaningful fixtures confirm consumed initial capacity does not refill after one/several months; September 12 → October 12 preserves UTC time; an additional purchase before expiry extends October 12 → November 12; existing leap/short-month/year and expiry/forever checks remain. Runtime commerce was unchanged. The first calendar-only attempt incorrectly relied on pytest markers, encountered unavailable PostgreSQL setup and was stopped; the final selector explicitly excludes PostgreSQL fixture cases. No assertion was weakened.

After the owner decisions, final policy regression `.tools/backend-venv/Scripts/python.exe scripts/test_backend_studio_postgres.py --output docs/evidence/backend-studio-policy-2026-10-11` passed **72 tests, 2 expected skips**, 43.64s, and removed its owned PostgreSQL container; [log](evidence/backend-studio-policy-2026-10-11/postgres.log). Final policy browser `.tools/backend-venv/Scripts/python.exe scripts/test_backend_studio_console.py --output docs/evidence/backend-studio-policy-2026-10-11` passed **13 checks, zero failures**, including actual real/artificial flags, all-player totals and a real development player's serverflag in the export; [receipt](evidence/backend-studio-policy-2026-10-11/browser-receipt.json). These later reruns overlap the original 66-test/11-check first-slice runs and are not additive counts. [Policy report](BACKEND_STUDIO_POLICIES_2026_10_11.md) retains screenshots and exact final details.

Visible local evidence: [race inspector](evidence/backend-studio-2026-10-11/race-1440.png), [narrow inspector](evidence/backend-studio-2026-10-11/race-390.png), [capabilities](evidence/backend-studio-2026-10-11/coverage-1440.png) and [preserved player support](evidence/backend-studio-2026-10-11/support-regression/player-1440.png). These are isolated fixture/browser observations, not canonical game, actual device or live-cloud acceptance. The [implementation report](BACKEND_STUDIO_2026_10_11.md) records final changes, exact checks, evidence, checkpoint and limitations.

## Requirement evidence map

Rows retain the original priority. Exact source wording, proposed owners, migration risks, acceptance criteria and endpoint lists are in the JSON companion. Linked paths identify implementation evidence or the inspected boundary where the gap was established; a path alone is not acceptance.

### Foundation

| ID | Priority | Coverage | Implemented evidence and remaining gap |
|---|---|---|---|
| BMT-001 — Inventory before replacement | P0 | Partial | This evidence map inventories all 92 rows; deployed parity, volumes, provider SDK configuration and assigned owners still need confirmation. [admin.py](../backend/bmt_backend/admin.py) |
| BMT-002 — Separate environments | P0 | Partial | Separate staff/player keys and development gates exist; no multi-environment console switch or individually scoped staff sessions. [config.py](../backend/bmt_backend/config.py) |
| BMT-003 — Stable entity correlation | P0 | Partial | New read-only race snapshot links original player/ticket/board/track-version/hash and pinned car/rules. Sessions, configs, experiments and persisted request traces are absent. [studio.py](../backend/bmt_backend/studio.py) |
| BMT-004 — Identity resolution | P0 | Missing | No authenticated guest-to-account merge ledger or deterministic cohort identity restatement workflow. [identity_models.py](../backend/bmt_backend/identity_models.py) |
| BMT-005 — Domain event outbox | P0 | Missing | Domain writes are transactional but no authoritative analytics event outbox/relay exists; the client race-upload outbox is a separate concern. [db.py](../backend/bmt_backend/db.py) |
| BMT-006 — One context across tools | P1 | Partial | UTC period/hash context is preserved through Studio navigation, player activity, exact track/race drilldowns and return links; build/cohort/timezone state and saved cohorts are absent. [studio.js](../backend/bmt_backend/admin_ui/studio.js) |
| BMT-007 — Independent analytical load | P0 | Missing | No analytical store or independent behavioural read projection exists; current admin queries the operational database with limits. [admin.py](../backend/bmt_backend/admin.py) |
| BMT-008 — Decision notebook | P1 | Missing | No decision notebook or immutable insight/review record domain. [app.js](../backend/bmt_backend/admin_ui/app.js) |

### Data

| ID | Priority | Coverage | Implemented evidence and remaining gap |
|---|---|---|---|
| BMT-010 — Versioned event contracts | P0 | Missing | Existing game payload schemas do not constitute a governed behavioural event catalog with purpose/retention/sampling contracts. [schemas](../docs/schemas) |
| BMT-011 — Non-blocking mobile collection | P0 | Missing | No product-telemetry collection queue, batch ingress client, eviction counters or measured device enqueue budget. [backend](../game/backend) |
| BMT-012 — Ingestion validation and acknowledgement | P0 | Missing | No durable per-event telemetry ingestion/acknowledgement/quarantine service. [app.py](../backend/bmt_backend/app.py) |
| BMT-013 — Time and session semantics | P0 | Missing | Race ticks and server timestamps exist; no 30-minute activity-session model or foreground/clock-quality observations. [track_models.py](../backend/bmt_backend/track_models.py) |
| BMT-014 — Exclude synthetic traffic | P0 | Partial | Owner override: all Studio totals include all players; per-player Real/Artificial flag comes only from server Player.is_test_driver, not development authentication. Source default-exclusion proposal is superseded; broader QA classification remains incomplete. [identity_models.py](../backend/bmt_backend/identity_models.py) |
| BMT-015 — Data quality cockpit | P0 | Missing | Worker health exists but no event freshness, orphan joins, consent coverage, schema or reconciliation cockpit. [worker_lifecycle.py](../backend/bmt_backend/worker_lifecycle.py) |
| BMT-016 — Lineage and metric registry | P1 | Missing | No persisted/versioned product metric registry, analytical SQL lineage or snapshot query service. [admin.py](../backend/bmt_backend/admin.py) |
| BMT-017 — Late data and restatements | P1 | Missing | No event-time analytical partitions, late-event watermarks or restatement/backfill snapshots. [db.py](../backend/bmt_backend/db.py) |
| BMT-018 — Sampling contracts | P0 | Partial | Authoritative purchases, resumes and accepted results are retained unsampled; no general diagnostic sampling/coverage policy. [commerce_models.py](../backend/bmt_backend/commerce_models.py) |
| BMT-019 — Controlled exports | P1 | Partial | Bounded redacted player-history JSON and checksummed race snapshots exist; governed CSV/Parquet, metric versions, suppression and async export jobs do not. [studio.py](../backend/bmt_backend/studio.py) |

### Analytics

| ID | Priority | Coverage | Implemented evidence and remaining gap |
|---|---|---|---|
| BMT-020 — Studio pulse | P0 | Partial | Studio presents actual operational counts/verification health and an implementation-backed coverage page; eligible activity, activation, retention, revenue and client quality remain unavailable. [app.js](../backend/bmt_backend/admin_ui/app.js) |
| BMT-021 — Behaviour explorer | P1 | Missing | No governed behavioural facts, pre-exposure cohort comparison or build/device/discovery segmentation. [admin.py](../backend/bmt_backend/admin.py) |
| BMT-022 — Onboarding funnel | P0 | Missing | First open/menu ready/race intent/observed start/voluntary retry observations are not captured; submissions cannot reconstruct onboarding. [admin.py](../backend/bmt_backend/admin.py) |
| BMT-023 — Retention and maturity | P1 | Missing | No eligible foreground activity or canonical first-activity cohort exists; registration/submission return is a different metric. [identity_models.py](../backend/bmt_backend/identity_models.py) |
| BMT-024 — Creator journey | P1 | Partial | Server publication and validation records exist; editor/test/save observations and ordered creator journey are absent. [track_models.py](../backend/bmt_backend/track_models.py) |
| BMT-025 — Social and rivalry journey | P1 | Partial | Challenge membership/tries/results and rivalry assignment/results exist; invitation delivery/exposure/foreground return are not recorded. [challenges.py](../backend/bmt_backend/challenges.py) |
| BMT-026 — Preference versus exposure | P1 | Missing | No discovery exposure/position/selection observations; race totals alone cannot establish preference. [tracks.py](../backend/bmt_backend/tracks.py) |
| BMT-027 — Qualitative evidence | P1 | Missing | Track ratings exist but no optional survey invitation/response sampling or support feedback theme domain. [tracks.py](../backend/bmt_backend/tracks.py) |
| BMT-028 — Driving and presentation diagnostics | P1 | Missing | Local game diagnostics do not provide backend control/restart/clean-streak/music/mute exposure analytics. [diagnostics](../game/diagnostics) |
| BMT-029 — Governed AI analysis | P2 | Missing | No governed natural-language/AI analytical query service or analytical metric views; runtime AI remains separately authorized scope. [admin.py](../backend/bmt_backend/admin.py) |

### UGC

| ID | Priority | Coverage | Implemented evidence and remaining gap |
|---|---|---|---|
| BMT-030 — Immutable track inspector | P0 | Partial | Immutable hashes/creator proof/compatibility/route/records exist; Studio race inspector opens the original exact track version rather than its latest head. Reports/cases/spatial analysis remain absent. [studio.py](../backend/bmt_backend/studio.py) |
| BMT-031 — Spatial quality analysis | P1 | Missing | No per-segment traversal/collision/exit/frame telemetry or normalised layer-aware spatial aggregate. [track_models.py](../backend/bmt_backend/track_models.py) |
| BMT-032 — Discovery diagnostics | P1 | Missing | No eligible discovery list impressions, slot positions, recommendation version or selection ledger. [tracks.py](../backend/bmt_backend/tracks.py) |
| BMT-033 — Moderation case workflow | P0 | Partial | Audited hide/show and account restriction exist; quarantine/report/case/expiry/appeal/reversal workflow is absent. [admin.py](../backend/bmt_backend/admin.py) |
| BMT-034 — Result validation trace | P0 | Partial | Accepted-only scoring and stored current outcomes exist; Studio displays retained ticket/receipt/terminal-verification facts and failure codes. No quarantine or complete per-attempt validator history. [studio.py](../backend/bmt_backend/studio.py) |
| BMT-035 — Competition audit | P1 | Partial | Pinned rivalry/challenge groups, best results and score calculation exist; no staff competition audit workspace or complete reward provenance. [rivalry.py](../backend/bmt_backend/rivalry.py) |
| BMT-036 — Creator health | P1 | Partial | Creator/publication/ratings/accepted-racer identities exist; no exposure-aware creator health/return/concentration metric service. [tracks.py](../backend/bmt_backend/tracks.py) |
| BMT-037 — Fair ranking experiments | P2 | Missing | No fair ranking experiment registry/allocation/exposure service; current competitions already pin compatible rules. [rivalry.py](../backend/bmt_backend/rivalry.py) |

### Monetisation

| ID | Priority | Coverage | Implemented evidence and remaining gap |
|---|---|---|---|
| BMT-040 — Authoritative purchase lifecycle | P0 | Partial | Durable ownership/idempotency/atomic grant and simulated lifecycle exist; real Google Play token verification/acknowledgement/notification adapter does not. [commerce.py](../backend/bmt_backend/commerce.py) |
| BMT-041 — Three revenue bases | P0 | Missing | Purchases store SKU/state/times but no verified amount/currency/FX/tax/fee snapshot or settlement sources; catalog prices are not receipts. [commerce_models.py](../backend/bmt_backend/commerce_models.py) |
| BMT-042 — Ad opportunity lifecycle | P0 | Missing | Development rewarded SDK integration exists; no durable analytics opportunity/offer/request/impression/revenue/continuation lifecycle. [ADMOB_DEVELOPMENT.md](../docs/ADMOB_DEVELOPMENT.md) |
| BMT-043 — Reward verification and deduplication | P0 | Missing | Production signed SSV and intent/provider-transaction verification is unconfigured; development preview receipts are not production financial authority. [resumes.py](../backend/bmt_backend/resumes.py) |
| BMT-044 — Entitlement ledger | P0 | Partial | Purchases/publication-slot/resume histories and current entitlements exist; a complete append-only grant/expiry/refund/reversal ledger and rebuild is absent. [commerce_models.py](../backend/bmt_backend/commerce_models.py) |
| BMT-045 — Track slot policy | P0 | Partial | Owner confirms one INITIAL free publishing slot; recurring monthly rewards are a possible later idea without implementation authorization. Atomic initial/paid slot consumption exists; monthly-reset source criterion is superseded. [commerce.py](../backend/bmt_backend/commerce.py) |
| BMT-046 — Ad-free entitlement policy | P0 | Partial | Owner confirms a UTC calendar month on the matching day (Sep12->Oct12), preserving time and existing short-month clamping. Active access extends from expiry; rewarded-resume bypass/forever remain. Source30day proposal is superseded; real-provider acceptance remains absent. [commerce.py](../backend/bmt_backend/commerce.py) |
| BMT-047 — Commercial funnels and fairness | P1 | Missing | No commercial exposure/conversion/expiry-return metrics or registered experiment guardrails. [admin_commerce.py](../backend/bmt_backend/admin_commerce.py) |
| BMT-048 — Reconciliation and refunds | P0 | Missing | No production provider reconciliation/refund/revocation/compensation lifecycle; development expiry/reset is not a refund. [commerce.py](../backend/bmt_backend/commerce.py) |
| BMT-049 — Acquisition economics | P1 | Missing | No acquisition attribution/campaign cost/mature cohort financial facts or LTV forecasting service. [identity_models.py](../backend/bmt_backend/identity_models.py) |

### Player support

| ID | Priority | Coverage | Implemented evidence and remaining gap |
|---|---|---|---|
| BMT-050 — Player 360 search | P0 | Partial | Established support/search/purchases/resumes/history are preserved; player activity now opens linked race evidence. Support codes/cases/active experiments/foreground sessions remain absent. [support.js](../backend/bmt_backend/admin_ui/support.js) |
| BMT-051 — Unified session timeline | P0 | Partial | Bounded server activity and a coherent read-only race lifecycle snapshot now exist. Ticket issuance and verification completion are labelled accurately; mobile sessions/clock alignment remain absent. [studio.py](../backend/bmt_backend/studio.py) |
| BMT-052 — Reproduction bundle | P0 | Partial | Studio exports bounded ownership-matched known-scalar race records with canonical-JSON SHA256, original hashes/IDs and explicit missing coverage. No replay bytes, platform/ABI/client event/config capture or expiring hosted copies. [studio.py](../backend/bmt_backend/studio.py) |
| BMT-053 — Bounded diagnostic capture | P1 | Missing | No consent/purpose-governed scoped production diagnostic capture service or expiry/withdrawal enforcement. [config.py](../backend/bmt_backend/config.py) |
| BMT-054 — Safe compensation | P0 | Partial | Preview-bound audited/idempotent development slot/access adjustments exist; production compensation, support-case identity and full ledger provenance are absent. [admin_purchase_controls.py](../backend/bmt_backend/admin_purchase_controls.py) |
| BMT-055 — Issue impact and prioritisation | P1 | Missing | Health/failure counts exist but no owned incident fingerprints, affected client cohorts or support-case impact domain. [admin.py](../backend/bmt_backend/admin.py) |
| BMT-056 — Account recovery safeguards | P0 | Missing | Login/revocation exists; dedicated verified recovery/conflict/entitlement-transfer workflow is absent. [auth.py](../backend/bmt_backend/auth.py) |
| BMT-057 — Feedback issue linkage | P1 | Missing | No staff feedback ticket/text/deduplication/linkage/resolution service. [admin_support.py](../backend/bmt_backend/admin_support.py) |

### Live operations

| ID | Priority | Coverage | Implemented evidence and remaining gap |
|---|---|---|---|
| BMT-060 — Experiment registration | P1 | Missing | No versioned experiment hypothesis/eligibility/sample/maturity/decision registry. [config.py](../backend/bmt_backend/config.py) |
| BMT-061 — Assignment and actual exposure | P1 | Missing | No experiment assignment or actual-exposure ledger and identity migration policy. [identity_models.py](../backend/bmt_backend/identity_models.py) |
| BMT-062 — Statistical safety | P1 | Missing | No statistical readout/SRM/multiplicity/fixed-horizon service; prototype statistics are illustrative. [app.js](../backend/bmt_backend/admin_ui/app.js) |
| BMT-063 — Versioned remote config | P0 | Partial | Product enabled/revision controls exist; general typed immutable remote config/audience/compatibility/effective-time registry is absent. [commerce_models.py](../backend/bmt_backend/commerce_models.py) |
| BMT-064 — Safe rollback and kill switches | P0 | Partial | Pinned race contracts and product availability controls exist; no general last-known-good remote configuration/rollback lifecycle. [tracks.py](../backend/bmt_backend/tracks.py) |
| BMT-065 — Schedule and preview | P1 | Partial | UTC rivalry/challenge deadlines and idempotent domain flows exist; no general staff schedule/representative-player preview service. [rivalry.py](../backend/bmt_backend/rivalry.py) |
| BMT-066 — Approval policy | P0 | Missing | Owner/analyst roles do not provide independent approval or documented step-up solo break-glass control. [admin.py](../backend/bmt_backend/admin.py) |
| BMT-067 — Experiment interference control | P1 | Missing | No experiment exclusion layers/cluster randomisation or interference policy. [rivalry.py](../backend/bmt_backend/rivalry.py) |

### Operations

| ID | Priority | Coverage | Implemented evidence and remaining gap |
|---|---|---|---|
| BMT-070 — Client quality cockpit | P0 | Missing | Local performance diagnostic evidence is not an ingested client-quality cockpit; no crash/ANR/Play-vitals/build-device-telemetry source. [diagnostics](../game/diagnostics) |
| BMT-071 — Correlated observability | P0 | Partial | Request IDs/structured API and worker logs exist. Studio explicitly marks missing persisted submission trace correlation; no linked distributed trace/log-query facade. [studio.py](../backend/bmt_backend/studio.py) |
| BMT-072 — User-journey SLOs | P0 | Partial | Health/readiness and bounded load tools exist; no registered journey-specific SLO numerator/denominator/window history. [app.py](../backend/bmt_backend/app.py) |
| BMT-073 — Actionable alerts | P0 | Missing | No grouped owned error-budget/low-traffic alerts, acknowledgement and incident runbook record service. [worker_lifecycle.py](../backend/bmt_backend/worker_lifecycle.py) |
| BMT-074 — Job and queue management | P0 | Partial | Durable worker claims/leases/attempts/game retries exist; Studio exposes retained attempts/failure and actual queue-source coverage. No previewed staff DLQ/scoped replay service. [studio.py](../backend/bmt_backend/studio.py) |
| BMT-075 — Backup and recovery evidence | P0 | Partial | Backup/restore scripts and documented backup/local drill evidence exist; no proven proposed RPO/RTO and deletion-tombstone restore gate. [backup.sh](../backend/deploy/backup.sh) |
| BMT-076 — Capacity and cost dashboard | P1 | Missing | No provider cost collector/analytical scan budget/cost-per-player-day source; deployment planning values are not measured costs. [admin.py](../backend/bmt_backend/admin.py) |
| BMT-077 — Release evidence | P0 | Partial | Pinned builds/migrations/worker compatibility and retained rollout evidence exist; no complete staff release registry/native-symbol/canary-cohort gate. [worker_lifecycle.py](../backend/bmt_backend/worker_lifecycle.py) |

### Security

| ID | Priority | Coverage | Implemented evidence and remaining gap |
|---|---|---|---|
| BMT-080 — Staff identity and least privilege | P0 | Partial | Separate owner/analyst bearer roles enforce server access; both roles inspect/export new read-only Studio evidence. Individual SSO/MFA/session expiry and broader permission matrix remain absent. [studio.py](../backend/bmt_backend/studio.py) |
| BMT-081 — Data minimisation and access | P0 | Partial | Studio adds whitelisted scalar manifests, matched-own receipts and credential-free bundles to existing redaction. Identity vault/step-up PII reveal/governed privacy purposes remain absent. [studio.py](../backend/bmt_backend/studio.py) |
| BMT-082 — Privacy lifecycle | P0 | Missing | No rights request/consent-purpose/retention/processor propagation/deletion tombstone workflow. [identity_models.py](../backend/bmt_backend/identity_models.py) |
| BMT-083 — Typed audited commands | P0 | Partial | Typed owner commands have reason, UUID idempotency, expected state, atomic audit; development commands add exact preview. Cases/individual actor/approvals are absent. [admin.py](../backend/bmt_backend/admin.py) |
| BMT-084 — Audit integrity and access logs | P0 | Partial | Append-only application audit and no edit/delete endpoint exist; no sensitive-read audit or tamper-evident export/integrity checker. [admin_models.py](../backend/bmt_backend/admin_models.py) |
| BMT-085 — Secure application boundaries | P0 | Partial | Existing CSP/escaping/request budgets remain; Studio uses same-origin external script, admin auth, no-store bounded exports, missing-entity/cross-account redaction tests. Full security boundary acceptance is incomplete. [studio.py](../backend/bmt_backend/studio.py) |
| BMT-086 — Small-cell and research protection | P1 | Missing | No approved small-cell threshold or aggregate suppression/research eligibility service; existing entity support access is separate. [admin.py](../backend/bmt_backend/admin.py) |
| BMT-087 — Child-aware commercial policy | P0 | Missing | No approved audience/age/territory/consent-purpose commercial policy or shipping personalization enforcement. [identity_models.py](../backend/bmt_backend/identity_models.py) |

### Testing

| ID | Priority | Coverage | Implemented evidence and remaining gap |
|---|---|---|---|
| BMT-090 — Sandbox player factory | P0 | Partial | Development-only server-classified artificial driver factory and isolated test fixtures exist; expiry/progression/friends/cleanup factory coverage is incomplete. [test_drivers.py](../backend/bmt_backend/test_drivers.py) |
| BMT-091 — Clone to staging | P0 | Missing | No redacted new-identity clone-to-staging manifest and fake-provider reproduction workflow. [admin_support.py](../backend/bmt_backend/admin_support.py) |
| BMT-092 — Fault injection scenarios | P0 | Partial | Isolated offline/duplicate/retry/skew/backend failure tests exist; no unified operator fault scenarios for real billing/ad provider lifecycles. [tests](../backend/tests) |
| BMT-093 — Race replay debugging | P1 | Partial | Explicit offline canonical replay diagnostics exist; no Studio ghost/replay UI or cross-platform supported-state divergence matrix. Acceptance remains trajectory-only. [TRAJECTORY_VERIFICATION.md](../docs/TRAJECTORY_VERIFICATION.md) |
| BMT-094 — Synthetic population fixtures | P1 | Partial | Repeatable persistent-trait artificial race populations exist; no complete coherent session/commerce/entitlement analytical fixture suite. [test_population.py](../backend/bmt_backend/test_population.py) |
| BMT-095 — Analytics golden tests | P0 | Partial | Existing commerce/resume/PB/idempotency fixtures test domain authority; no product session/funnel/D1/D7/identity-restatement analytical goldens. [tests](../backend/tests) |
| BMT-096 — Load and soak testing | P1 | Partial | Bounded local race/purchase load tools exist; no combined analytical-ingest/worker/export load-and-soak capacity acceptance. [loadtest.py](../backend/bmt_backend/loadtest.py) |
| BMT-097 — Control plane safety tests | P0 | Partial | Existing mutation tests plus actual browser late-read/Lock-pending-preview/analyst-export checks pass; future approval/CSRF/case/privacy/config command types lack implementation/testing. [test_backend_studio_console.py](../scripts/test_backend_studio_console.py) |

### UX / NFR

| ID | Priority | Coverage | Implemented evidence and remaining gap |
|---|---|---|---|
| BMT-100 — Desktop-first responsive shell | P1 | Partial | Studio grouped shell and race/coverage cards have actual 1440/960/390 browser containment evidence. Complete 1280x800/200 percent zoom and physical-browser acceptance remain. [index.html](../backend/bmt_backend/admin_ui/index.html) |
| BMT-101 — Explicit asynchronous states | P0 | Partial | Studio adds read cancellation, render/auth/dialog generation fencing, explicit 401/403 and contextual Retry; late responses cannot republish locked evidence. General stale/insufficient-sample and cancelled-job states remain incomplete. [app.js](../backend/bmt_backend/admin_ui/app.js) |
| BMT-102 — Accessible interactions | P1 | Partial | Studio adds skip link, aria-current, labelled controls, dialog focus return and daily chart table alternative; actual keyboard/dialog browser checks pass. Full keyboard/contrast/zoom acceptance remains. [index.html](../backend/bmt_backend/admin_ui/index.html) |
| BMT-103 — Bounded query performance | P1 | Partial | Bounded ranges/keyset history and obsolete-read cancellation exist; Studio snapshots cap receipts at100. No heavy-report jobs/scan budgets or measured proposed query SLOs. [studio.py](../backend/bmt_backend/studio.py) |
| BMT-104 — Safe incremental rollout | P0 | Partial | Additive read-only Studio reuses authority/auth/CSP, preserves support/commerce, passes local SQLite/PostgreSQL/browser regressions and changes no schema or provider state. Future telemetry parity/cutover/deployment remains absent. [studio.py](../backend/bmt_backend/studio.py) |
| BMT-105 — Portable service boundaries | P2 | Partial | New versioned JSON capabilities/race evidence contracts are provider-independent; no replacement analytical store/golden metric replay parity proof exists. [studio.py](../backend/bmt_backend/studio.py) |

## Actual inspection, limitations and remaining acceptance

Read `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, `docs/BACKEND_UI.md`, approved commerce/AdMob/trajectory documents, the supplied DOCX/PDF/XLSX/HTML and relevant repository API/models/UI/tooling. Used `rg --files` and bounded `rg` code searches; independent backend and frontend inventories were reconciled. Extraction produced `temp/backend-gui/extracted/{specification.txt,specification-pdf.txt,requirements.json,backlog.json}` and four PDF prototype page images. The actual command `.tools/backend-venv/Scripts/python.exe temp/backend-gui/extracted/build_evidence_map.py` validates all 92 distinct source IDs against 92 assessments and preserves source fields verbatim. A separate path/hash check confirmed every referenced evidence path exists and all four supplied artifact SHA-256 hashes remain unchanged.

No live-cloud reads/writes/deployment, database migration, provider transaction, telemetry collection, refund, privacy deletion, Android export/install or phone test was performed. Phone attachment was not checked. API/UI checks above exercised owned local fixtures; the independent inventory and new local implementation do not establish production parity. Historical test/rollout entries in [BACKEND_UI.md](BACKEND_UI.md) remain separately attributed evidence.

Remaining acceptance: full desktop keyboard/1280x800/200 percent zoom and physical-browser review; deployed parity if rollout is later authorized; representative source volumes/SDK/provider configuration; actual device instrumentation budget if telemetry is added; and each effective per-row acceptance criterion in the JSON. Population, initial free allowance and calendar-month duration are resolved, with no pending owner choice among those three. Draft SLO/retention/capacity/privacy values remain proposals rather than measured or legally approved guarantees. Full-game replay/regression was not run because this slice changes no canonical simulation or acceptance contract.


## Authorized Studio staging deployment, 2026-10-11

The owner subsequently authorized deployment. The reviewed nine-file Studio overlay is now live on the existing retained staging service, with fresh backup, zero-traffic canary, unchanged schema/game/commerce and preserved configuration. Exact-image47 tests and live API/asset/flag/browser/native-worker checks passed. Earlier no-deployment statements describe their original local tasks. See [the actual deployment report](BACKEND_STUDIO_DEPLOY_2026_10_11.md) for commands, evidence, image/revision and remaining boundaries.
