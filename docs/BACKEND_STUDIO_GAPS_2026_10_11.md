# Current Studio against the specification, 2026-10-11

Local telemetry follow-up: [signed-in telemetry and product analysis](PRODUCT_TELEMETRY_2026_10_11.md) now implements bounded collection, prepared activity, ordered journeys, exact-day retention and exposure/action reporting. Collection is disabled by default and has not been deployed. The review below describes its original snapshot; broader requirements and live coverage remain separately assessed.

Reviewed the current deployed release, supplied specification/prototype and the
92-row workbook evidence map. Live checks at **16:28 Helsinki / 13:28 UTC**
confirm revision `bmt-stg-e7a444ab-api-00028-yak` serves100%, its image is the
reviewed `8146e3af...` release, all six UI assets match, schema0023 is unchanged,
API/worker are ready and all395 accounts remain included. Inspection used only
GET/read-only cloud commands; no live configuration or player state changed.

The shipped Studio provides operational counts, player search/support/history,
real/artificial flags, pinned race/track evidence, redacted JSON downloads,
development purchase/access controls, visibility/account restriction, queue
health and command audit history. The comprehensive specification contains much
more product measurement and operational workflow than this first slice.

The existing evidence map records **43 Missing / 49 Partial** broad requirements.
Those are not percentages of functionality: a broad Partial requirement can
contain substantial working behavior and still lack another domain or acceptance
step. Your decisions are fulfilled and supersede the draft: inclusive Studio
population with a stored player flag, one initial slot and calendar-month access.
Synthetic exclusion, recurring monthly free slots and fixed30-day access are
therefore **not missing features**.

## Functional gaps

| Area | Coverage | Missing compared with the specification | Relevant IDs |
|---|---|---|---|
| Event and data foundation | Missing | Governed client event schemas; bounded offline collection; durable batch ingress/acknowledgements; authoritative transaction event outbox; foreground/session/clock semantics; authenticated guest/account linking; separate analytical projections; freshness/schema/orphan/drop-quality checks. | BMT-004–007,010–017 |
| Product analytics | Missing | Activity/activation/retention with maturity; onboarding/creator/challenge/store funnels; saved cohorts and behavioral exploration; discovery exposure and car/biome preference; qualitative feedback; metric registry, snapshots, late-event corrections and golden results. Current submission counts do not establish these behaviors. | BMT-008,016–017,020–028,047,095 |
| Client quality | Missing | Ingested build/device/platform data, crash/ANR evidence, frame histograms, route-segment quality and bounded purpose-aware diagnostic capture. Local development profiling is not a deployed telemetry source. | BMT-028,031,053,070 |
| Provider commerce/revenue | Partial domain, missing live providers | Real Play purchase verification/notification handling; signed rewarded-ad verification; impression/opportunity/continuation events; verified amounts/currencies and estimated/settled revenue bases; reconciliation/refunds/revocations; complete entitlement grant/expiry/reversal ledger and reconstruction. Development purchase controls already work. | BMT-040–044,047–049 |
| Tracks, discovery and competition | Partial | Rich validation/eligibility/incident inspector; normalized layer-aware spatial heatmaps; recommendation exposure diagnostics; creator-health metrics; a staff rivalry/challenge inspector explaining roster, pinned rules, attempts, scoring/ties/finalization and accepted-result provenance. Server competition/track records already exist. | BMT-030–037 |
| Support and moderation | Partial | Support cases/notes/issue linkage; report, quarantine, decision/expiry/appeal/reversal workflows; production case-bound compensation; verified account recovery and entitlement conflicts. Existing restriction/visibility and development access controls are narrower. | BMT-033,050,054–057 |
| Session lab and reproduction | Partial | Client session/monotonic timeline, persisted request-trace links, per-attempt validator history, build/platform/ABI/state/config capture, visual ghost/replay inspection, redacted sandbox clone and audited/expiring reproduction access. Current bundles contain bounded server evidence rather than a complete reproduction. | BMT-003,034,051–053,071,091,093 |
| Remote configuration | Missing | Typed/versioned config registry; audience and compatibility preview; approval, safe-boundary publication, offline known-good payloads, schedules, rollback and kill-switch lifecycle. Product availability toggles and infrastructure image rollback already exist; neither is this service. | BMT-063–066 |
| Experiments | Missing | Hypothesis/eligibility/sample/guardrail registration; stable assignment and actual exposure; mature outcome analysis, allocation checks and recorded decisions; interference/exclusion layers and competition-consistent allocation. | BMT-060–062,067 |
| Reliability and operational workflow | Partial | Journey SLO history; linked traces/log-query tools; grouped alerts, incident ownership/acknowledgement/runbooks; scoped DLQ/retry preview; provider backup/restore evidence in Studio; cost/capacity dashboards; client-release/symbol and cohort-quality gates. Worker health, durable queues and deployment canaries/backups already exist. | BMT-055,071–077 |
| Staff access and audit | Partial | Configure a distinct analyst credential on staging; individual staff SSO/MFA/expiry and granular roles; independent approval or documented solo break-glass; sensitive-read auditing and tamper-evident audit evidence. Code supports analyst reads, but the current live environment has only the owner binding. | BMT-066,080–085 |
| Privacy and audience policy | Missing | Verified access/erasure request workflows, cross-system delivery/cleanup, tombstones and restore handling, purpose/consent/retention governance, step-up identity access, small-cell/research protection and approved audience/age/territory commercial rules. | BMT-081–082,086–087 |
| QA sandbox and release testing | Partial | Operator UI for coherent synthetic player/session/commerce scenarios, redacted clones and unified fault injection; analytical session/funnel/retention goldens; combined ingest/query/worker/export soak; complete requirement-linked release registry. Artificial race populations, isolated fixtures and backend regressions already exist. | BMT-090–097,077 |
| Shared context, exports and UI acceptance | Partial | Multi-environment switching with scoped access and cleared entity/preview state; global build/platform/cohort/snapshot context and remembered exploration; governed CSV/Parquet or async exports; long-job progress/cancellation; comprehensive stale/partial/insufficient-sample states; exact1280x800/200%zoom/full keyboard/contrast acceptance and measured reporting-query budgets. UTC range/links, bounded JSON exports, cancellation and several responsive/focus checks already work. | BMT-002,006,019,100–105 |
| Advanced learning | Missing/later | Governed read-only AI analysis, fair ranking experiments, acquisition attribution/cohort financial value/forecasting, and replacement analytical-store replay with golden parity. These do not block the existing read-only slice. | BMT-029,037,049,105 |

## Concrete live observations

- The Configuration screen explicitly has no remote-config registry/activation/
  rollback service. Submission explorer contains daily received attempts and
  verification states; retention/funnels/device views have no data source.
- The capabilities API marks behavior, client quality, provider commerce,
  remote config/experiments and individual staff identity unavailable.
- The five-product catalog and purchase listing work, but real store billing is
  not connected. Catalog prices are not verified spend or revenue.
- The current live API has no analyst credential binding. A separate analyst
  role is implemented and locally tested, so this is partly a configuration gap.
- Competition health reports backup `not_configured`. The fresh successful Cloud
  SQL deployment backup is real; the Studio lacks a provider backup collector.
  Do not interpret this display as evidence that no backup exists. A rehearsed
  restore/RPO/RTO guarantee remains separately unverified.
- The infrastructure deployment canary and rollback are verified. They must not
  be listed as missing simply because the remote game-config lifecycle is absent.

## What existing data can support next

Existing track/version/validation, rivalry/challenge membership/results and player
history tables can support richer read-only inspectors and competition audit
views without introducing mobile telemetry. Cloud provider observations can
support a backup/status view once access/collection is implemented.

Retention, discovery preference, session abandonment, editor/social funnels and
device-quality analysis require new observations. Historic submissions cannot
reconstruct the missing activity/exposure data. Real commerce/revenue needs
provider verification and financial facts. These are data/service additions,
not changes that can be completed by displaying more cards.

The package references `contracts/`, `qa/` and `IMPLEMENTATION_PROMPT.md`, which
were not supplied. Exact ingestion/analytical acceptance definitions need to be
finished or supplied alongside those features. New vendors, financial/privacy
policies and deployments remain decisions for their own authorized slices.

## Evidence and limits

Live inspection command:
`.tools/backend-venv/Scripts/python.exe build/backend-studio-review-2026-10-11/live_review.py`.
[Sanitized receipt](evidence/backend-studio-review-2026-10-11/live-review.json)
records image/asset parity, health/capability status, active schema and absent
analyst binding. All checks are read-only; screenshots from the deployed release
and prior exact-image/browser tests remain in the
[deployment report](BACKEND_STUDIO_DEPLOY_2026_10_11.md).

The [92-row inventory](BACKEND_STUDIO_REQUIREMENTS_2026_10_11.md) and
[exact source/evidence JSON](backend-studio-requirements-2026-10-11.json) provide
individual priorities, criteria and gaps. This review distinguishes implementation
absence from broader acceptance still needed. It does not run a new game/device
test, provider callback, restore drill, penetration test or load soak. Phone
attachment was not checked. No backend/game implementation or deployment changed.
