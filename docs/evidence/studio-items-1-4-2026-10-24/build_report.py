"""Rebuild the dated delivery receipt and a patch containing only this task."""
import difflib
import hashlib
import html
import json
import subprocess
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
FILES = [
    'backend/bmt_backend/admin.py', 'backend/bmt_backend/app.py',
    'backend/bmt_backend/admin_ui/app.js', 'backend/bmt_backend/admin_ui/index.html',
    'backend/bmt_backend/admin_ui/platform.js', 'backend/bmt_backend/admin_ui/ranking.js',
    'backend/bmt_backend/studio_analysis.py', 'backend/bmt_backend/studio_governance.py',
    'backend/bmt_backend/studio_exports.py', 'backend/bmt_backend/studio_metrics.py',
    'backend/bmt_backend/studio_release_reports.py', 'backend/bmt_backend/studio_ranking.py',
    'backend/bmt_backend/studio_jobs.py', 'backend/bmt_backend/studio_watchdog.py',
    'backend/bmt_backend/world_ranking_worker.py', 'backend/tests/test_studio_review_fixes.py',
    'backend/tests/test_studio_reporting.py', 'scripts/test_studio_review_fixes_console.py',
    'backend/README.md', 'backend/deploy/README.md', 'AGENTS.md', 'DEVELOPMENT_STATUS.md',
]


def segment(text, first, until):
    start = text.index(first)
    return text[start:text.index(until, start)]


def transplant(base, current, first, until):
    return base.replace(segment(base, first, until), segment(current, first, until), 1)


def effective_base(name, current):
    path = HERE/'before'/name
    if not path.exists():
        return ''
    base = path.read_text(encoding='utf-8')
    # Preserve concurrent hardening and Game Configuration edits in the base.
    # These are not part of this task's implementation checkpoint.
    if name.endswith('/admin.py'):
        base = transplant(base, current, 'def access(', '\n\nAccess =')
        old = next(line for line in base.splitlines() if 'if name not in (' in line)
        new = next(line for line in current.splitlines() if 'if name not in (' in line).replace(', "ranking.js"', '')
        base = base.replace(old, new)
    elif name == 'backend/bmt_backend/app.py':
        base = current.replace('        from . import studio_ranking\n        app.include_router(studio_ranking.router)\n', '')
    elif name.endswith('/admin_ui/app.js'):
        base = transplant(base, current, 'async function api(', 'function login(')
        base = transplant(base, current, 'function wire(', 'function dialogToken(')
    elif name.endswith('/admin_ui/index.html'):
        base = current.replace('  <script src="/admin/assets/ranking.js" defer></script>\n', '')
    elif name.endswith('/admin_ui/platform.js'):
        old = next(line for line in base.splitlines() if "pTabs([['studio','Metrics & coverage']" in line)
        new = next(line for line in current.splitlines() if "pTabs([['studio','Metrics & coverage']" in line)
        base = base.replace(old, new)
        for line in current.splitlines():
            if line.startswith(" if(tab==='config')") or line.startswith(" if(tab==='experiments')return head+"):
                base = base.replace(" if(tab==='saved'){", line+"\n if(tab==='saved'){")
    elif name in ('AGENTS.md', 'DEVELOPMENT_STATUS.md'):
        note = (HERE/'task-note.txt').read_text(encoding='utf-8')
        base = current.replace(note, '', 1)
        if name == 'AGENTS.md' and base.startswith('## Studio reporting and operations items '):
            base = base.split('\n', 1)[1]
    return base


parts, hashes, bases = [], {}, {}
for name in FILES:
    p = ROOT/name
    current = p.read_text(encoding='utf-8')
    base = effective_base(name, current)
    # Some shared files mix LF and CRLF. Equal context must retain each
    # working line's actual ending, not one guessed style for the whole file.
    raw_current = p.read_bytes().decode('utf-8')
    old_lines, new_lines = base.splitlines(keepends=True), current.splitlines(keepends=True)
    raw_lines = raw_current.splitlines(keepends=True)
    raw_base = []
    for tag, i, j, k, l in difflib.SequenceMatcher(None, old_lines, new_lines, autojunk=False).get_opcodes():
        raw_base.extend(raw_lines[k:l] if tag == 'equal' else old_lines[i:j])
    base, current = ''.join(raw_base), raw_current
    destination = HERE/'checkpoint-base'/name
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(base.encode('utf-8'))
    hashes[name] = hashlib.sha256(p.read_bytes()).hexdigest()
    bases[name] = hashlib.sha256(base.encode()).hexdigest()
    lines = list(difflib.unified_diff(base.splitlines(keepends=True), current.splitlines(keepends=True),
                                    fromfile='a/'+name if base else '/dev/null', tofile='b/'+name))
    if lines:
        parts.append('diff --git a/'+name+' b/'+name+'\n'+''.join(lines))
patch = HERE/'checkpoint.patch'
patch.write_bytes(''.join(parts).encode('utf-8'))
checked = subprocess.run(['git','apply','--reverse','--check',str(patch.relative_to(ROOT))],
                         cwd=ROOT,capture_output=True,text=True)
(HERE/'checkpoint-check.txt').write_text(checked.stdout+checked.stderr,encoding='utf-8')
if checked.returncode:
    raise RuntimeError('Scoped patch reverse check failed: inspect checkpoint-check.txt')


def suite(name):
    root = ET.parse(HERE/name).getroot().find('testsuite')
    a = root.attrib
    return {'passed': int(a['tests'])-int(a['failures'])-int(a['errors'])-int(a['skipped']),
            'failed': int(a['failures']), 'errors': int(a['errors']), 'skipped': int(a['skipped']),
            'seconds':float(a['time'])}


browser = json.loads((HERE/'browser/browser.json').read_text(encoding='utf-8'))
items = [
    {'id':'BSI01','title':'Dependable reporting',
     'result':'Behaviour/release CSVs share isolated report queries, pool/concurrency/deadline and WAL-fence policy. Downloads identify a fresh query and carry scope, effective UTC dates, query time, source watermark and collection status. Guided report links retain compatible dimensions and disclose unsupported ones. Verification KPIs use their exact five-minute terminal-time interval. Freshness and pending work are visible, calendar gaps distinguish observed zero from unavailable coverage, and partial days are labelled. Independent overview feed failures retain other successful cards.',
     'checks':'Replica-only fact SQL tracing; prompt busy/unconfigured failures; scope round trips; terminal-time reconciliation; stale-source and partial-feed fault injections.'},
    {'id':'BSI02','title':'Reliable saved investigations and downloads',
     'result':'Validated record IDs and system subroutes survive saved-location round trips using the existing JSON column. Case status and current configuration view/draft filters are retained. Rename/delete are actor-scoped, idempotent, revision-fenced and audited. Activity, retention, first-race journey, engagement and release comparison have dedicated CSV formats and explicit fresh-query provenance.',
     'checks':'Player/race/queue/case round trips, rename/delete retries, foreign-actor/stale-revision/path rejection, CSV scope/provenance/formula handling and actual browser downloads.'},
    {'id':'BSI03','title':'World Ranking operations and worker coverage',
     'result':'Content & competitions has World Ranking publication/working generation, phase, progress cursor, worker heartbeat, last progress, recent pinned circuits and bounded correction history. Named audit actors and affected-player links are retained. Owners prepare a read-only impact preview, then explicitly confirm the existing revision-fenced correction command. Ranking worker metadata is sampled between batches at most once per 15 seconds. Ranking and achievement queues have bounded labelled counts; missing age or worker evidence stays unknown. Rebuilds do not borrow historical week age as a delay measurement.',
     'checks':'Read/preview performs no settlement, correction or audit writes. Named correction replay and publication fences pass. Stale worker and unknown rarity age remain distinct; 10,001 pending projections return a labelled 10,000 bound.'},
    {'id':'BSI04','title':'Stronger release comparisons',
     'result':'Candidate and baseline share selected platform/device/OS/track/render-context scope on the isolated reader. Reports show weighted frame rates and differences, package/frame denominators, independent player-coverage availability, exploratory sample warnings and normalized device rows with scoped frame/heatmap links. Missing player coverage is unavailable rather than zero. Comparisons remain descriptive; no rollout verdict is inferred.',
     'checks':'Exact paired aggregates and frame deltas; unavailable denominator handling; same-scope report/export parity; preserved device/build/OS diagnostic links and missing-baseline browser views.'},
]
report = {
    'schema':'bmt-studio-items-1-4-v1', 'date':'2026-10-24', 'timezone':'Europe/Helsinki',
    'generated_at':datetime.now(timezone.utc).isoformat(),
    'status':'Implemented locally; deployment and production acceptance remain separate.',
    'requirements':['BSI01','BSI02','BSI03','BSI04','R01','G01','Q01','BMT-002','BMT-016','BMT-019','BMT-020','BMT-028','BMT-031','BMT-034','BMT-070','BMT-071','BMT-077','BMT-100','BMT-104','BMT-105'],
    'implementation':items, 'changed_files':FILES, 'source_sha256':hashes,
    'effective_checkpoint_base_sha256':bases,
    'checkpoint':{'file':'checkpoint.patch','git_reverse_check':True,
                  'scope':'Captured task-original sources plus explicitly retained concurrent hardening/configuration in shared-file bases. No Git index/commit or existing worktree changes were made by patch validation.'},
    'validation':{'final_backend':suite('final-pytest.xml'),'deselected':25,
                  'post_final_coverage_guard':suite('final-coverage-check.xml'),
                  'initial_focused':suite('pytest-initial.xml'), 'initial_regression':suite('regression.xml'),
                  'task_original_migration_control':suite('original-migration-control.xml'),
                  'browser_checks':len(browser['checks']),'browser_views':len(browser['pages']),
                  'javascript_errors':browser['javascript_errors'],
                  'page_wide_overflows':sum(p['global_overflow'] for p in browser['pages']),
                  'ruff':'All checked task Python sources pass.', 'javascript_parse':'All admin UI JavaScript compiled with Edge new Function without parse errors.'},
    'initial_corrections':[
        'Concurrent authentication hardening required explicit test-only legacy credentials in the owned browser fixture.',
        'A shared operations navigation helper accidentally removed during UI replacement was restored; final browser flows pass.',
        'The engine-injection rejection fixture now explicitly selects a non-test environment after shared auth fixtures changed to test mode. The guard remains strict.',
    ],
    'limitations':[
        'The migration-preservation assertion for a retired discovery_budget table also fails with task-original edited modules on the same concurrent migration tree (0062_retire_discovery_cache). The assertion is retained; its failure is recorded separately and excluded from the final focused selection. This is not a full repository regression pass.',
        'PostgreSQL was unavailable and the existing Docker endpoint probe returned unavailable. SQLite correctness and mocked replica/deadline contracts do not certify production PostgreSQL plans, WAL replication or load.',
        'Matching API/admin assets, ranking worker and independent watchdog rollout is required. The reporting reader now also needs SELECT on race_statistics_days.',
        'The 15-minute source-age notice distinguishes old evidence from proven collector failure. Exploratory 30-package/1,000-frame warnings and worker delay thresholds need production calibration.',
        'Browser fixtures are synthetic, with a separately copied SQLite test reporting mirror. They are not canonical race, monetary, device-performance or live operational evidence.',
        'Phone/tablet attachment was not checked; no physical-device test, APK, live account/backend mutation, notification, provider purchase or deployment was performed.',
        'Concurrent authentication, Game Configuration, discovery, schema, game and documentation work was preserved. No gameplay or native binary was changed by this task.',
    ],
    'acceptance_remaining':['Deploy matching approved sources with the reporting-reader grants and required concurrent migrations.','Validate operator workflows against the intended environment and calibrate report/worker warning thresholds.','Perform the separately configured independent monitoring outage/recovery and real notification delivery acceptance.'],
    'command_environment':{'shell':'PowerShell','working_directory':str(ROOT),'PYTHONPATH':'backend'},
    'original_control_command':'Inline Python imported bmt_backend, prepended docs/evidence/studio-items-1-4-2026-10-24/before/backend/bmt_backend to its __path__, then ran pytest.main for backend/tests/test_world_ranking.py::test_upgrade_preserves_previous_schema_rows[sqlite] with -q --tb=short -p no:cacheprovider and the original-migration-control.xml receipt.',
    'commands':[
        '.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_studio_review_fixes.py backend/tests/test_studio_platform.py backend/tests/test_studio_performance.py backend/tests/test_studio_operations.py -q --tb=short -p no:cacheprovider --junitxml=docs/evidence/studio-items-1-4-2026-10-24/pytest-initial.xml',
        '.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_studio_reporting.py backend/tests/test_world_ranking.py backend/tests/test_world_ranking_service.py backend/tests/test_studio.py backend/tests/test_studio_alarms.py -k "not postgres" -q --tb=short -p no:cacheprovider --junitxml=docs/evidence/studio-items-1-4-2026-10-24/regression.xml',
        '.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_studio_review_fixes.py backend/tests/test_studio_reporting.py backend/tests/test_studio_platform.py backend/tests/test_studio_performance.py backend/tests/test_studio_operations.py backend/tests/test_studio_alarms.py backend/tests/test_studio.py backend/tests/test_world_ranking.py backend/tests/test_world_ranking_service.py -k "not postgres and not test_upgrade_preserves_previous_schema_rows" -q --tb=short -p no:cacheprovider --junitxml=docs/evidence/studio-items-1-4-2026-10-24/final-pytest.xml',
        '.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_studio_review_fixes.py -k calendar_gap -q --tb=short -p no:cacheprovider --junitxml=docs/evidence/studio-items-1-4-2026-10-24/final-coverage-check.xml',
        '.tools/backend-venv/Scripts/python.exe scripts/test_studio_review_fixes_console.py',
        '.tools/backend-venv/Scripts/python.exe -m ruff check backend/bmt_backend/admin.py backend/bmt_backend/studio_analysis.py backend/bmt_backend/studio_governance.py backend/bmt_backend/studio_exports.py backend/bmt_backend/studio_metrics.py backend/bmt_backend/studio_release_reports.py backend/bmt_backend/studio_ranking.py backend/bmt_backend/studio_jobs.py backend/bmt_backend/studio_watchdog.py backend/bmt_backend/world_ranking_worker.py backend/tests/test_studio_review_fixes.py scripts/test_studio_review_fixes_console.py --output-format concise',
        '.tools/backend-venv/Scripts/python.exe docs/evidence/studio-items-1-4-2026-10-24/build_report.py',
        'git apply --reverse --check docs/evidence/studio-items-1-4-2026-10-24/checkpoint.patch',
    ],
}
(HERE/'report.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')

e=html.escape
cards=''.join(f'<article><small>{r["id"]}</small><h2>{e(r["title"])}</h2><p>{e(r["result"])}</p><p><b>Verification:</b> {e(r["checks"])}</p></article>' for r in items)
gallery=''.join(f'<figure><a href="browser/{name}"><img loading="lazy" src="browser/{name}" alt="{e(caption)}"></a><figcaption>{e(caption)}</figcaption></figure>' for name,caption in [
    ('activity-stale-source.png','Source age remains visible while details are closed.'),
    ('overview-partial-metrics.png','A metrics-only failure retains incident and verification evidence.'),
    ('quality-comparison-desktop.png','Comparable release scopes, rate differences, source coverage and diagnostic links.'),
    ('ranking-operations-desktop.png','Published/working generation and separate worker progress evidence.'),
    ('ranking-correction-preview.png','Read-only impact preview precedes a separate explicit confirmation.'),
    ('saved-390.png','Saved investigations and actions at a phone-width viewport.'),
])
files=''.join(f'<li><a href="../../../{e(f)}">{e(f)}</a></li>' for f in FILES)
doc=f'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Studio items 1–4 · 24 October 2026</title><style>body{{margin:0;color:#173237;background:#f3f6f5;font:16px/1.65 system-ui,sans-serif}}main{{max-width:1100px;margin:auto;padding:36px 24px 80px}}h1{{font-size:40px;line-height:1.2}}h2{{font-size:23px}}article,.note{{background:#fff;border:1px solid #d5e1dd;border-radius:10px;padding:24px;margin:20px 0}}small{{color:#985121;font-weight:700}}a{{color:#1b5c66}}.note{{border-left:5px solid #bc7132}}.gallery{{display:grid;grid-template-columns:1fr 1fr;gap:20px}}figure{{margin:0;background:white;padding:12px;border:1px solid #d5e1dd}}img{{width:100%;max-height:650px;object-fit:contain;object-position:top}}figcaption{{font-size:13px;color:#4e675c}}li{{margin:8px 0;overflow-wrap:anywhere}}pre{{white-space:pre-wrap;overflow-wrap:anywhere;font-size:12px}}@media(max-width:700px){{main{{padding:24px 14px}}.gallery{{grid-template-columns:1fr}}h1{{font-size:30px}}}}</style><main><small>BEAT MY TRACK · LOCAL IMPLEMENTATION · 24 OCTOBER 2026</small><h1>Studio reporting and operations: items 1–4</h1><p>Implemented reporting reliability, saved investigations, World Ranking operations and stronger release comparisons. Existing all-player defaults and canonical race behavior remain.</p><p><a href="report.json">Structured receipt and source hashes</a> · <a href="checkpoint.patch">Scoped implementation patch</a> · <a href="browser/browser.json">Browser checks</a> · <a href="final-pytest.xml">Backend results</a></p><aside class="note"><b>Validation:</b> 133 backend checks passed, 2 skipped; 25 explicitly deselected. A final additional source-coverage check passed. Ten browser scenarios cover 45 views at 1440×1000, 1280×800 and 390×844 with zero JavaScript errors or page-wide overflow. Ruff and all Studio JavaScript parsing pass. The scoped patch passes Git’s reverse-application check.</aside>{cards}<h2>Selected actual browser evidence</h2><p>All screens contain isolated synthetic fixtures. Open an image for the full view.</p><div class="gallery">{gallery}</div><h2>Corrections retained during implementation</h2><ul>{''.join('<li>'+e(v)+'</li>' for v in report['initial_corrections'])}</ul><h2>Limits and remaining acceptance</h2><ul>{''.join('<li>'+e(v)+'</li>' for v in report['limitations'])}</ul><p>The broader initial regression recorded 64 passes, two skips and two failures. The non-test injection fixture was corrected explicitly. The discovery-table migration assertion reproduces with task-original edited sources and remains intact: <a href="original-migration-control.xml">control evidence</a>. PostgreSQL, deployed operator acceptance and independent monitoring delivery remain unverified.</p><h2>Files and actual commands</h2><details><summary>Changed source/documentation files</summary><ul>{files}</ul></details><details><summary>Commands</summary><pre>{e(chr(10).join(report['commands']))}</pre></details></main></html>'''
(HERE/'report.html').write_text(doc,encoding='utf-8')
print(json.dumps({'files':len(FILES),'backend':report['validation']['final_backend'],
                  'browser_views':len(browser['pages']),'scoped_patch_reverse_check':True,'report':str(HERE/'report.html')}))
