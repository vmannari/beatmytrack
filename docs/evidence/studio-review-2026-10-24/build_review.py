"""Build the dated review artifact from recorded browser and source evidence."""
import hashlib
import html
import json
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def source(path, needle):
    lines = (ROOT / path).read_text(encoding='utf-8').splitlines()
    number = next(i for i, line in enumerate(lines, 1) if needle in line)
    return {'path': path, 'line': number}


UI = 'backend/bmt_backend/admin_ui/'
BE = 'backend/bmt_backend/'
findings = [
    {
        'id': 'STR01', 'priority': 'P1', 'kind': 'Confirmed source routing defect',
        'title': 'Activity CSV bypasses the isolated reporting reader',
        'impact': 'An operator can run a broad export on the gameplay database even though the matching report has a dedicated reader, deadline and concurrency guard. The download also has no report snapshot or watermark to reconcile it with the screen.',
        'evidence': 'The report uses studio_reporting.snapshot; the CSV uses the primary session_factory and limits output after aggregation. In a deliberately divergent test mirror, the report returned 546 starts while the CSV returned 18. This proves the separate source paths; it is not a naturally occurring replica-consistency failure or a claim about live totals.',
        'recommendation': 'Route export through the same isolated reader and query policy. Include effective dates, filters, definition version and watermark in a companion manifest. Either export a frozen report snapshot or clearly identify a new query.',
        'acceptance': 'SQL tracing shows no analytical fact scan on primary for report or export; busy/timeouts fail promptly; an unchanged snapshot produces matching aggregates and export totals.',
        'sources': [source(BE+'studio_governance.py', 'def export('), source(BE+'studio_analysis.py', 'with request.app.state.studio_reporting.snapshot('), source(BE+'studio_reporting.py', 'class StudioReporting:')],
        'requirements': ['BMT-006', 'BMT-019', 'BMT-100', 'BMT-105'],
    },
    {
        'id': 'STR02', 'priority': 'P1', 'kind': 'Browser-reproduced report context defects',
        'title': 'Guided links silently change the population and reporting question',
        'impact': 'An analyst investigating one build or population can unknowingly continue with all builds and players. The overview result count also leads to a different time definition.',
        'evidence': 'From build=release-a, platform=android, mode=free_race and population=real, all three Next questions links retained only dates. Workspace tabs preserve more filters. The overview Verified results card says Last five minutes but its link inherits the selected multi-day dates; the directory filters created_at while the KPI counts finished_at.',
        'recommendation': 'Use one supported-scope link builder across tabs, actions and KPI drilldowns. Preserve compatible fields and explicitly explain unsupported ones. Give operational KPIs exact pulse intervals and the same timestamp semantics as their evidence lists.',
        'acceptance': 'A scoped Activity → Retention → Activity and Activity → Quality round trip retains all supported dimensions. The last-five-minute drilldown reconciles to the KPI by verification terminal time.',
        'sources': [source(UI+'platform.js', "card('Next questions'"), source(UI+'app.js', 'function scopedHref('), source(BE+'admin.py', 'def overview('), source(BE+'admin.py', 'def entities(')],
        'requirements': ['BMT-002', 'BMT-019', 'BMT-020'],
    },
    {
        'id': 'STR03', 'priority': 'P1', 'kind': 'Fault-injected browser reproduction and report feature gap',
        'title': 'Freshly queried pages can present stale observations without a visible warning',
        'impact': 'The footer records when the query ran. It does not tell the operator whether the underlying projection is current enough for a decision.',
        'evidence': 'A valid-shape injected response with a two-day-old watermark and three-day-old latest observation showed ordinary headline counts and no warning. Freshness was inside a closed details section. Activity also displays today alongside complete days without an in-progress label, and omits dates with no fact rows.',
        'recommendation': 'Show source watermark, lag, pending work and coverage beside the headline. Distinguish current partial day, observed zero, unobserved day, stale projection and disabled collection. Keep historical reports available with explicit status.',
        'acceptance': 'A stale or backlogged projection is visibly labelled without opening details; zero activity is distinct from missing coverage; period comparisons exclude or consistently match partial days.',
        'sources': [source(UI+'platform.js', 'Definition, freshness and limits'), source(UI+'app.js', "$('#freshness').textContent='Queried '"), source(BE+'studio_analysis.py', '"available": bool(')],
        'requirements': ['BMT-016', 'BMT-017', 'BMT-020', 'BMT-100'],
    },
    {
        'id': 'STR04', 'priority': 'P1', 'kind': 'Fault-injected browser reproduction',
        'title': 'One optional feed failure removes the entire overview',
        'impact': 'An incident-response entry point becomes least useful during a partial outage, even when queue data and incident records are available.',
        'evidence': 'Returning 503 only for /v1/admin/metrics replaced the whole overview with Unable to load records. The overview awaits metrics and incidents with Promise.all, then falls into the global page error handler.',
        'recommendation': 'Load independent cards separately and expose per-source unavailable states with retry. Retain successful operational information and its observation time.',
        'acceptance': 'Failure of metrics leaves incident response and verification backlog visible; failure of incidents leaves the other valid cards visible. No failed card is shown as a healthy zero.',
        'sources': [source(UI+'platform.js', "Promise.all([api('incidents?limit=6'),api('metrics')])"), source(UI+'app.js', "denied?'Access restricted':'Unable to load records'")],
        'requirements': ['BMT-071', 'BMT-100', 'BMT-104'],
    },
    {
        'id': 'STR05', 'priority': 'P1 before World Ranking launch', 'kind': 'Source-confirmed missing integration',
        'title': 'World Ranking status and settlement are outside the Studio workflow',
        'impact': 'Staff cannot readily see or explain a stuck ranking generation, pending correction or stale published snapshot from the normal competition and worker views.',
        'evidence': 'GET /v1/admin/ranking/status and audited correction APIs already exist. Studio competition choices are Rivalry and Challenges. The queue registry covers race, publication, validation, erasure, histogram, news and notification, plus a product projection summary; it does not include ranking settlement or achievement projection. The watchdog derives queue signals from that registry.',
        'recommendation': 'Integrate existing ranking status into Content & competitions and Operations. Expose published snapshot, working phase, progress, publication age, retry/error state and audited correction history/preview. Add bounded health coverage for ranking and achievement workers without running settlement in an HTTP read.',
        'acceptance': 'An owned stalled-generation fixture is visible and alarmed; an intentionally disabled future launch is labelled correctly. Staff can explain a published rank and a rebuilding correction through linked evidence.',
        'sources': [source(BE+'world_ranking.py', '@router.get("/v1/admin/ranking/status")'), source(BE+'world_ranking.py', '@router.post("/v1/admin/ranking/corrections")'), source(BE+'studio_jobs.py', 'specs = ('), source(UI+'platform.js', 'async function platformCompetitions(')],
        'requirements': ['WRI01-WRI08', 'BMT-034', 'BMT-071', 'BMT-077'],
    },
    {
        'id': 'STR06', 'priority': 'P2', 'kind': 'Report quality and decision-support gap',
        'title': 'Release comparison needs comparable samples and actionable device evidence',
        'impact': 'The current cards are useful descriptive totals, but provide limited support for a release decision or for identifying a regression in a smaller device group.',
        'evidence': 'The fixture baseline had 10 race packages and zero analysis-v1 reporting players, with no prominent source-coverage warning. A nonexistent baseline displayed 0/0 packages and zero players. The only comparison delta is completion; device rows show package and slow-frame counts, without frame denominators, rates or direct diagnostic links. Candidate/baseline filters support platform, but no matched device/OS/track scope.',
        'recommendation': 'Show sample sufficiency and independent coverage for packages versus user counts. Add slow-frame deltas, normalized device rates and links that retain build/device/OS/track context. Offer descriptive matched-scope comparisons with explicit minimums; retain the existing noncausal wording.',
        'acceptance': 'Missing coverage is distinct from zero affected users; each device rate has a denominator; an analyst can open a problem segment directly; tiny or incompatible samples do not receive a release-quality verdict.',
        'sources': [source(BE+'studio_metrics.py', 'def compare('), source(UI+'platform.js', 'async function platformQuality(')],
        'requirements': ['BMT-028', 'BMT-031', 'BMT-070', 'BMT-077'],
    },
    {
        'id': 'STR07', 'priority': 'P2', 'kind': 'Missing focused product reports; existing data and legacy renderers partly present',
        'title': 'Behaviour reports answer too few product questions',
        'impact': 'Staff can inspect activity, returns, first-race journey and sessions, but cannot easily tell what changed over time or whether discovery, publication and store journeys are improving.',
        'evidence': 'The active behaviour workspace has four tabs and no previous-period comparison or activity trend visualization. productAnalyticsView still contains publication-request reach, car/biome exposure and selection, store actions, challenge actions and collection-loss reports; it is loaded but has no caller in the active UI.',
        'recommendation': 'Add focused trend and previous-comparable-period reports, publication-to-external-racer reach, discovery exposure-to-selection, and purchase-delivery funnels using governed sources. Reuse valid prepared facts with bounded dedicated reads. Preserve the intentional retirement of the heavy duplicate historical bundle and local-draft collection.',
        'acceptance': 'Each focused report is reachable, has a source/denominator/maturity contract, and runs within the reporting budget. Artificial accounts remain in the default totals; no population policy is silently changed.',
        'sources': [source(UI+'platform.js', 'async function platformBehaviour('), source(UI+'product_analytics.js', 'function productAnalyticsView('), source(UI+'app.js', "section==='product'")],
        'requirements': ['BMT-020', 'BMT-022', 'BMT-023', 'BMT-024', 'BMT-027', 'BMT-047'],
    },
    {
        'id': 'STR08', 'priority': 'P2; urgent for a staffed moderation queue', 'kind': 'Source-confirmed incomplete operator workflow',
        'title': 'Case triage fields do not help prioritize the case list',
        'impact': 'Urgent, overdue or assigned cases can sink below recently updated routine cases. Operators must open individual cases to find the information needed to choose their next task.',
        'evidence': 'Case triage stores assignee, normal/high/urgent priority, due_at and linked incident. The case directory projects the base case, filters only state and orders by updated_at. It displays page-local unresolved counts without priority, due date, assignment, overdue or SLA filtering.',
        'recommendation': 'Join a bounded triage projection into the list. Add My cases, unassigned, urgent and overdue views, due-date sorting and search by player/track/reference. Retain append-only evidence and owner-authorized actions.',
        'acceptance': 'An older urgent overdue case is discoverable from the first queue view without opening every case; assignment and due-date changes update the list and preserve an audit trail.',
        'sources': [source(BE+'studio_governance.py', 'class Triage('), source(BE+'studio_cases.py', 'def list_cases('), source(UI+'operations.js', 'function caseWorkspace(')],
        'requirements': ['BMT-033', 'BMT-050', 'BMT-054', 'BMT-056'],
    },
    {
        'id': 'STR09', 'priority': 'P2', 'kind': 'Browser-reproduced saved-view defect',
        'title': 'Save view cannot faithfully reopen several places where it is offered',
        'impact': 'An operator believes an investigation has been saved but returns to a directory or another workspace. Unsupported detail routes can fail validation.',
        'evidence': 'Saving players/<fixture-id> stored route=players with dates, discarding the player ID. The same first-path-segment logic loses system/jobs. The server route allowlist excludes races while the global Save view button is offered on race pages. The filter allowlist also omits the case-list status field.',
        'recommendation': 'Define validated route-specific saved locations and filters, preserving safe entity identifiers and subroutes. Restrict the button where the feature is unsupported. Provide rename/delete so the 50-view limit is manageable.',
        'acceptance': 'Player, race, queue and filtered-case round trips reopen their exact intended location, or clearly explain that only a workspace filter is being saved; saved-view limits have a recovery path.',
        'sources': [source(UI+'platform.js', "if($('#platform-save'))"), source(BE+'studio_governance.py', 'ROUTES = {'), source(BE+'studio_governance.py', 'FILTERS = {')],
        'requirements': ['BMT-002', 'BMT-019', 'BMT-100'],
    },
    {
        'id': 'STR10', 'priority': 'P2', 'kind': 'Declared evidence gap',
        'title': 'Race investigation lacks the context needed to diagnose a player report',
        'impact': 'Support can prove the pinned result and current outcome, but cannot reliably connect a reported hitch, rejection or delay to the submitting build, device and verifier attempt.',
        'evidence': 'The race evidence API explicitly marks client diagnostics, request trace, client session spans and bundle expiry unavailable. Attempt count is retained, but executed validator versions and per-attempt timing are not. Network summaries retain selected request IDs elsewhere; a persisted correlation to the run is absent.',
        'recommendation': 'Persist minimal governed correlation at receipt and verification boundaries: request ID, build, supported device/render context, verifier version and bounded phase timings. Link the existing quality/network views and case. Keep enhanced capture separately consented and purpose-bound.',
        'acceptance': 'An owned failed-run fixture can be followed from case to submission, request evidence and specific verifier attempt without guessing from nearby timestamps or exposing credentials/proof bytes.',
        'sources': [source(BE+'studio.py', '"key": "client_diagnostics"'), source(BE+'studio.py', '"key": "request_trace"'), source(BE+'studio.py', '"key": "verification_history"')],
        'requirements': ['BMT-003', 'BMT-051', 'BMT-052', 'BMT-053', 'BMT-071'],
    },
    {
        'id': 'STR11', 'priority': 'P2 before staff expansion', 'kind': 'Partly implemented access feature and missing UX',
        'title': 'Staff sign-in and roles need an ordinary staff workflow',
        'impact': 'Pasting an identity token or shared legacy key is awkward for daily staff use. The owner/analyst split grants either broad writes or read-only inspection, leaving no dedicated support or release role.',
        'evidence': 'The login requires a Staff identity token or legacy key. Named staff audiences, allowlists, signed MFA claims and revocation are implemented. Browser SSO is still an integration dependency; this is not an absence of backend identity controls. The reviewed read handlers do not create a purpose-bound sensitive-read audit record.',
        'recommendation': 'Provide a configured sign-in/session flow, meaningful expiry/re-authentication UX, and role policies for actual staff duties. Add purpose and audit coverage for sensitive support access and evidence downloads. Keep current restrictions until these policies are chosen.',
        'acceptance': 'A staff member signs in without copying a raw token, sees expiry/revocation clearly, and can perform their assigned support tasks without unrestricted release/finance powers. Sensitive reads have appropriate traceable purpose.',
        'sources': [source(UI+'app.js', 'function login('), source(BE+'studio_access.py', 'def named_access('), source(BE+'admin.py', 'def access(')],
        'requirements': ['BMT-080', 'BMT-081', 'BMT-082', 'BMT-085'],
    },
    {
        'id': 'STR12', 'priority': 'P2', 'kind': 'Measured usability and report-distribution gap',
        'title': 'Investigation evidence sits too far below the first screen',
        'impact': 'The visual hierarchy is calm and readable, but recurring operators spend substantial space and scrolling on headings and card padding before reaching evidence.',
        'evidence': 'At 1280×800, the Activity table began at y=726, catalogue at y=711 and the candidate-device table at y=1021. Core 390-pixel pages stayed contained, but long tables require horizontal scrolling inside their panels. Export activity appears on every behaviour tab and always downloads the narrow activity CSV, including on Retention or Engagement.',
        'recommendation': 'Offer a compact operator density, make each report action explicit, and add report-specific exports containing definitions, scope, maturity and source time. Use readable charts with table alternatives for trends. Consider scheduled summaries only after report semantics are stable.',
        'acceptance': 'The main evidence is reachable with less scrolling at 1280×800; Retention offers its own cohort export or clearly labels Activity-only export. Keyboard, real 200% browser zoom, screen-reader and contrast checks receive separate acceptance.',
        'sources': [source(UI+'app.js', "id=\"platform-export\""), source(UI+'platform.js', "if($('#platform-export'))"), source(UI+'platform.css', '.platform-')],
        'requirements': ['BMT-019', 'BMT-100', 'BMT-101', 'BMT-103'],
    },
]

gates = [
    {
        'id': 'STRG01', 'when': 'Before relying on automatic incident response',
        'title': 'Activate and prove the full monitoring chain',
        'state': 'Watchdog, incident ledger, source freshness, signed outbox and notification retries are implemented. Independent hosting, supervised collection/delivery and actual receiver acceptance require environment evidence. This review did not inspect their live configuration.',
        'required': 'Show expected sources, last successful probe, supervised collector health, delivery test, exhausted retries and recovery. Exercise an owned outage while the API is unreachable, including a stopped watchdog. Add the newer ranking coverage in STR05.',
        'sources': [source('docs/STUDIO_PLATFORM_ACTIVATION.md', '## Independent monitoring'), source(BE+'studio_incidents.py', 'configured_sources')],
    },
    {
        'id': 'STRG02', 'when': 'Before treating real-money commerce as operationally complete',
        'title': 'Close purchase delivery, refund and reconciliation gaps',
        'state': 'Provider verification and account binding, retry-safe grants, estimated AdMob imports and separate Coin accounting exist. Full live Billing/notification/refund/revocation handling and settled financial reconciliation are declared dependencies. Finance cannot establish player LTV or ARPDAU from catalogue prices or aggregate ad estimates.',
        'required': 'Provide a purchase-exception queue, provider completion/retry state, refunds/revocations/reversals, outstanding liabilities and reconciled currency/basis totals. Build attribution and mature value cohorts before offering LTV or ARPDAU.',
        'sources': [source('docs/STUDIO_PLATFORM_ACTIVATION.md', '## Provider money and purchase delivery'), source(BE+'studio_finance.py', 'def report(')],
    },
    {
        'id': 'STRG03', 'when': 'Before making production recovery guarantees',
        'title': 'Expose backup and restore evidence with owners and age',
        'state': 'The service-health view has a configured backup marker and correctly says that it does not observe cloud backups or prove restore success. A source-connected backup/restore evidence workflow and tested recovery objectives remain absent from Studio.',
        'required': 'Surface backup identity, age, coverage, last successful owned restore drill, measured recovery point/time, failure actions and accountable owner. Keep account recovery and compensation separate, with verified policy and case-bound authority before enabling them.',
        'sources': [source(UI+'monitor_views.js', 'A local backup marker does not observe cloud backups'), source(BE+'studio.py', 'Expiring scopes, verified recovery and production compensation')],
    },
]

browser = json.loads((HERE/'browser-review.json').read_text(encoding='utf-8'))
suite = ET.parse(HERE/'pytest.xml').getroot().find('testsuite')
validation = {
    'browser_views': len(browser['pages']), 'javascript_errors': len(browser['errors']),
    'page_wide_overflows': sum(p['overflow'] > 1 for p in browser['pages']),
    'viewports': sorted({(p['width'], p['viewport_height']) for p in browser['pages']}),
    'browser_read_scope': 'Newly owned loopback service, synthetic SQLite records and a separate test reporting mirror; headless Microsoft Edge; owner and analyst reads.',
    'faults': 'Deliberately injected metrics 503, stale projection metadata and divergent mirror facts. One expected overview failure is recorded, not hidden.',
    'pytest': {'tests': int(suite.attrib['tests']), 'passed': 62, 'skipped': int(suite.attrib['skipped']), 'errors': int(suite.attrib['errors']), 'failures': int(suite.attrib['failures']), 'seconds': float(suite.attrib['time'])},
    'postgres_limitation': 'The PostgreSQL reporting test timed out connecting to localhost:55439 during fixture setup. No PostgreSQL pass, load, WAL-replica or live-environment certification is claimed.',
    'initial_attempt': 'The first browser fixture failed because test environment was combined with development auth. The review-only fixture was corrected to disable development auth/purchase simulation before starting; production code was not changed.',
    'artifact_validation': {'rendered_in_headless_edge': True, 'report_page_wide_overflow': False, 'report_links': 68, 'finding_articles': 12, 'conditional_gate_articles': 3, 'source_hashes_verified': 22, 'python_artifacts_parse': True},
    'commands': [
        '.tools/backend-venv/Scripts/python.exe build/studio-review-2026-10-24/review_browser.py',
        '$env:PYTHONPATH="backend"; .tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_studio_reporting.py backend/tests/test_studio_performance.py backend/tests/test_studio_platform.py backend/tests/test_studio_operations.py -q --tb=short -p no:cacheprovider --junitxml=docs/evidence/studio-review-2026-10-24/pytest.xml',
        '.tools/backend-venv/Scripts/python.exe docs/evidence/studio-review-2026-10-24/build_review.py',
    ],
}
paths = sorted({s['path'] for f in findings+gates for s in f['sources']} | {
    'backend/bmt_backend/admin_ui/index.html', 'backend/bmt_backend/admin_ui/monitor.js',
    'backend/bmt_backend/admin_ui/operations.js', 'backend/bmt_backend/studio_watchdog.py',
})
manifest = {p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths}
review = {
    'schema':'bmt-studio-review-v1', 'date':'2026-10-24', 'timezone':'Europe/Helsinki',
    'generated_at':datetime.now(timezone.utc).isoformat(),
    'conclusion':'The Studio has a useful operational foundation. Reporting trust, continuity of investigation and completion of operational workflows deserve priority over adding more dashboard cards.',
    'severity_policy':'No P0 outage, data-loss or unauthorized-write issue was established by this scoped review. P1 findings affect reporting trust or incident response. Readiness gates are conditional on depending on the associated production feature; they are not evidence of a live outage.',
    'scope':'Local working tree reviewed on 2026-10-24. Current deployed image/configuration and real player data were not inspected. Earlier requirement inventories are historical evidence, not a fresh missing-feature count.',
    'findings':findings, 'conditional_readiness_gates':gates, 'validation':validation,
    'source_sha256':manifest,
    'limits':['No runtime implementation or configuration changed.', 'No deployment, live mutation, notification, financial provider interaction or device action.', 'Phone/tablet attachment was not checked and no physical-device test was performed.', 'No production benchmark, complete accessibility certification, penetration test or restore drill.', 'Existing concurrent work was preserved.'],
    'suggested_order':[
        'Fix report/export isolation, scope propagation, freshness and partial-source overview handling (STR01–STR04).',
        'Add ranking status and monitoring before its launch; establish applicable monitoring and recovery evidence (STR05, STRG01, STRG03).',
        'Finish release diagnostics, support prioritization and saved-location continuity (STR06, STR08, STR09, STR10).',
        'Add focused product comparisons/reach reports and report-specific exports (STR07, STR12).',
        'Complete staff and real-money operational dependencies when those capabilities are activated (STR11, STRG02).',
    ],
}
(HERE/'report.json').write_text(json.dumps(review,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')

e = html.escape


def refs(items):
    return ' · '.join(f'<a href="../../../{e(s["path"])}#L{s["line"]}">{e(s["path"].split("/")[-1])}:{s["line"]}</a>' for s in items)


articles = []
for f in findings:
    articles.append(f'''<article class="finding" id="{f['id']}"><div class="eyebrow">{f['id']} · {e(f['priority'])} · {e(f['kind'])}</div><h3>{e(f['title'])}</h3><p>{e(f['impact'])}</p><dl><dt>Evidence</dt><dd>{e(f['evidence'])}</dd><dt>Recommended change</dt><dd>{e(f['recommendation'])}</dd><dt>Acceptance</dt><dd>{e(f['acceptance'])}</dd></dl><p class="source">{refs(f['sources'])}<br>Requirement mapping: {e(', '.join(f['requirements']))}</p></article>''')
gate_html = ''.join(f'<article class="finding"><div class="eyebrow">{g["id"]} · {e(g["when"])}</div><h3>{e(g["title"])}</h3><p>{e(g["state"])}</p><p><b>Required evidence:</b> {e(g["required"])}</p><p class="source">{refs(g["sources"])}</p></article>' for g in gates)
index = ''.join(f'<tr><td><a href="#{f["id"]}">{f["id"]}</a></td><td>{e(f["priority"])}</td><td>{e(f["title"])}</td></tr>' for f in findings)
strengths = [
    'Eight focused navigation areas provide a clear starting structure. Desktop and 390-pixel layouts contained their content in the inspected views.',
    'Race evidence retains immutable player/ticket/track contracts, uses pinned tick rates, redacts credentials and supplies a checksummed bundle.',
    'Behaviour reports have exact aggregate semantics, cohort follow-up maturity and an isolated reader. Quality diagnostics already include frame buckets, route heatmaps, rendering context, network timing and OS exit evidence.',
    'Incident occurrences, acknowledgement, ownership, recovery and outbox retries are implemented. Case and moderation decisions retain revision/idempotency fences and audit evidence.',
    'Finance correctly separates estimated provider money, purchase fulfilment and noncash Coins. Catalogue prices are not presented as revenue.',
    'All-player default reporting, including artificial accounts, remains an explicit owner requirement. Missing guest coverage and missing crash-free denominators are honestly described.',
]
workspace_rows = [
    ('Overview','Clear incident-first entry','Partial-source resilience; exact KPI drilldown context'),
    ('Operations & alarms','Durable incident and retry workflows','Activation evidence; newer worker coverage; recovery evidence'),
    ('Player behaviour','Activity, mature retention, first-race journey, sessions','Freshness, comparison periods, focused publication/discovery reports'),
    ('Game quality','Weighted frame totals, detailed device/track/network views','Comparable samples, missing-versus-zero coverage, direct device investigation'),
    ('Monetisation','Separated provider money, delivery and Coin flows','Refund/reversal/reconciliation lifecycle before live-money reliance'),
    ('Content & competitions','Published catalogue, pinned Rivalry/Challenge evidence and future calendar','World Ranking workflow and generation visibility'),
    ('Player support','Linked cases, player history and accountable moderation','Urgent/overdue/assigned queue views; run-level diagnostic correlation'),
    ('Administration','Definitions, saved views, staff gates, releases and experiments','Exact saved locations, browser sign-in, report version/snapshot handling'),
]
rows = ''.join('<tr>'+''.join(f'<td>{e(c)}</td>' for c in row)+'</tr>' for row in workspace_rows)
shots = [('05-product-desktop.png','Activity: source definitions are available, while freshness sits in a closed details section.'),('09-quality-desktop.png','Release comparison: two sources can have different coverage; the device table needs normalized rates and drilldowns.'),('overview-optional-feed-failure.png','Injected metrics-only failure removes otherwise available operational cards.'),('00-overview-390.png','Phone-width layout is contained; this is a browser viewport check, not a physical-device test.')]
gallery = ''.join(f'<figure><a href="{name}"><img src="{name}" loading="lazy" alt="{e(caption)}"></a><figcaption>{e(caption)}</figcaption></figure>' for name,caption in shots)
doc = f'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Backend Studio review · 24 October 2026</title>
<style>:root{{color-scheme:light;--ink:#183137;--muted:#516972;--line:#d5e1e2}}*{{box-sizing:border-box}}body{{margin:0;background:#f3f6f5;color:var(--ink);font:16px/1.65 system-ui,sans-serif}}main{{max-width:1120px;margin:auto;padding:40px 24px 80px}}h1{{font-size:clamp(30px,5vw,48px);line-height:1.14;margin:12px 0 20px}}h2{{margin-top:48px;font-size:27px}}h3{{font-size:21px;line-height:1.35;margin:12px 0}}p{{max-width:93ch}}a{{color:#185d64}}.eyebrow{{color:#9c4b22;font-size:12px;text-transform:uppercase;letter-spacing:.07em;font-weight:700}}.lead{{font-size:21px;line-height:1.5}}.note,.finding{{padding:24px;background:white;border:1px solid var(--line);border-radius:12px;margin:18px 0}}.note{{border-left:5px solid #bd6c3a}}.source{{font-size:12px;color:var(--muted);overflow-wrap:anywhere}}table{{width:100%;border-collapse:collapse;background:white}}th,td{{text-align:left;vertical-align:top;border-bottom:1px solid var(--line);padding:14px}}th{{background:#e4eeeb}}.tablewrap{{overflow:auto}}dt{{font-weight:700;margin-top:16px}}dd{{margin:4px 0 0}}.gallery{{display:grid;grid-template-columns:1fr 1fr;gap:24px}}figure{{margin:0;padding:12px;background:white;border:1px solid var(--line)}}img{{width:100%;max-height:600px;object-fit:contain;object-position:top}}figcaption{{font-size:13px;color:var(--muted)}}nav{{display:flex;gap:16px;flex-wrap:wrap}}code{{overflow-wrap:anywhere}}@media(max-width:700px){{main{{padding:24px 14px}}.finding{{padding:18px}}.gallery{{grid-template-columns:1fr}}}}</style>
<main><div class="eyebrow">Beat my track · local source review · 24 October 2026</div><h1>Make the reports trustworthy and the investigations continuous.</h1><p class="lead">{e(review['conclusion'])}</p><nav><a href="#priorities">Priorities</a><a href="#workspaces">Workspace coverage</a><a href="#findings">Findings</a><a href="#gates">Readiness gates</a><a href="#validation">Validation</a><a href="report.json">Structured backlog & hashes</a></nav>
<aside class="note"><b>Scope and severity.</b> {e(review['scope'])} {e(review['severity_policy'])}</aside>
<h2>What already works well</h2><ul>{''.join('<li>'+e(v)+'</li>' for v in strengths)}</ul>
<h2 id="priorities">Prioritized review</h2><div class="tablewrap"><table><thead><tr><th>ID</th><th>Priority</th><th>Finding</th></tr></thead><tbody>{index}</tbody></table></div>
<h2 id="workspaces">Workspace coverage</h2><div class="tablewrap"><table><thead><tr><th>Workspace</th><th>Useful foundation</th><th>Main gap</th></tr></thead><tbody>{rows}</tbody></table></div>
<h2 id="findings">Findings and acceptance criteria</h2>{''.join(articles)}
<h2 id="gates">Conditional critical readiness gates</h2><p>These are required before depending on the associated feature in production. Existing adapters and services are credited; their current live activation was not assessed.</p>{gate_html}
<h2>Suggested delivery order</h2><ol>{''.join('<li>'+e(v)+'</li>' for v in review['suggested_order'])}</ol>
<h2>Selected browser evidence</h2><p>All screenshots contain synthetic owned fixtures. Open an image for the full view.</p><div class="gallery">{gallery}</div>
<h2 id="validation">Validation and limits</h2><p><b>{validation['browser_views']} browser views; zero JavaScript errors; zero page-wide horizontal overflows.</b> Inspected viewport sizes: 1440×1000, 1280×800 and 390×844. Owner and analyst views are included. One deliberate optional-feed failure produced the expected failing overview recorded in STR04.</p>
<p><b>Backend checks: 62 passed, 1 skipped, 1 setup error.</b> The PostgreSQL fixture connection timed out on localhost:55439. This is not a PostgreSQL pass or a product assertion failure. Detailed evidence: <a href="browser-review.json">final browser observations and reproductions</a>, <a href="browser-review-initial.json">initial completed browser run</a>, <a href="pytest.xml">test results</a>, <a href="review_browser.py">reproducible browser harness</a>.</p><p>{e(validation['initial_attempt'])}</p><ul>{''.join('<li>'+e(v)+'</li>' for v in review['limits'])}</ul><details><summary>Actual commands</summary><pre>{e(chr(10).join(validation['commands']))}</pre></details></main></html>'''
(HERE/'review.html').write_text(doc,encoding='utf-8')
copy = HERE/'review_browser.py'
runner = ROOT/'build/studio-review-2026-10-24/review_browser.py'
if not runner.is_file():
    runner = copy
text = runner.read_text(encoding='utf-8').replace("ROOT = Path(__file__).resolve().parents[2]", "ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'backend/pyproject.toml').is_file())")
copy.write_text(text,encoding='utf-8')
print(json.dumps({'findings':len(findings),'conditional_gates':len(gates),'browser_views':validation['browser_views'],'output':str(HERE/'review.html')}))
