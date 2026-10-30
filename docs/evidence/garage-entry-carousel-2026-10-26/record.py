"""Record this task's commands and a review patch without concurrent edits."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BEFORE = OUT/'before'
SCOPE = OUT/'scope-base'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

app_path = 'game/core/app.gd'
original = (BEFORE/app_path).read_text(encoding='utf-8')
current = (ROOT/app_path).read_text(encoding='utf-8')
base = current
guard = original[original.index('\t# Identity can also change'):original.index('\tif screen == "create" and next != "create": _flush_editor_writes()')]
base = base.replace('\tif screen == "create" and next != "create": _flush_editor_writes()', guard+'\tif screen == "create" and next != "create": _flush_editor_writes()', 1)
base = base.replace('\t# Publish at most one real swipe neighbor per frame. Only retained Garage\n\t# pages participate; entering a cold Garage uses the\n\t# normal menu transition, without a separate restoring/loading screen.', '\t# Publish at most one real swipe neighbor per frame. Only an already visited\n\t# Garage may be prepared here; cold Garage entry owns its loading cover.')
covered = original[original.index('func _prepare_garage_covered()'):original.index('func _rebuild_profile_menu(')]
branch = 'func _rebuild_profile_menu(destination: String) -> void:\n\t# Garage owns its account fence in _garage, like the other menu pages.\n\tif destination == "garage":\n\t\t_show_screen(destination)\n\t\treturn\n'
assert branch in base
base = base.replace(branch, covered+'func _rebuild_profile_menu(destination: String) -> void:\n', 1)
start, end = base.index('func _rebuild_profile_menu('), base.index('func _garage_appearance_changed(')
section = base[start:end]
section = section.replace('\tif not is_inside_tree()', '\tif destination == "garage": await _prepare_garage_covered()\n\tif not is_inside_tree()', 1)
base = base[:start]+section+base[end:]
(SCOPE/app_path).parent.mkdir(parents=True, exist_ok=True)
(SCOPE/app_path).write_bytes(base.encode('utf-8'))
for path in ('AGENTS.md', 'DEVELOPMENT_STATUS.md'):
    content = (ROOT/path).read_bytes().decode('utf-8')
    without_note, count = re.subn(r'<!-- GARAGE-ENTRY-CAROUSEL-20261026 -->\r?\n.*?<!-- /GARAGE-ENTRY-CAROUSEL-20261026 -->\r?\n\r?\n', '', content, count=1, flags=re.S)
    assert count == 1
    (SCOPE/path).write_bytes(without_note.encode('utf-8'))

paths = [app_path, 'game/ui/garage_cached_thumbnail.gd', 'game/ui/garage_preview_cache.gd',
         'game/tests/test_mobile_audit_fixes.gd', 'game/tests/test_garage_entry_carousel.gd',
         'game/tests/profile_garage_entry.gd', 'scripts/run_garage_entry_check.py',
         'game/assets/garage/previews_v1/provenance.json', 'AGENTS.md', 'DEVELOPMENT_STATUS.md',
         'docs/GARAGE_ENTRY_CAROUSEL_2026_10_26.md',
         'docs/evidence/garage-entry-carousel-2026-10-26/record.py']
patch = []
for path in paths:
    old = SCOPE/path if (SCOPE/path).exists() else BEFORE/path
    old_text = old.read_bytes().decode('utf-8') if old.exists() else ''
    new_text = (ROOT/path).read_bytes().decode('utf-8')
    patch.extend(difflib.unified_diff(old_text.splitlines(True), new_text.splitlines(True),
                                    fromfile='a/'+path if old.exists() else '/dev/null', tofile='b/'+path))
(OUT/'task-only.patch').write_bytes(''.join(patch).encode('utf-8'))
review = subprocess.run(['git', 'apply', '--reverse', '--check', str(OUT/'task-only.patch')],
                        cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
commands = []
for path in sorted(OUT.glob('*.json')):
    try: row = json.loads(path.read_text(encoding='utf-8'))
    except (ValueError, OSError): continue
    if not isinstance(row, dict) or 'command' not in row: continue
    log = path.with_suffix('.log')
    text = log.read_text(encoding='utf-8') if log.exists() else ''
    row['name'] = path.stem
    row['log'] = log.name
    row['results'] = [line for line in text.splitlines() if line.startswith(('GARAGE_ENTRY_CAROUSEL:', 'MOBILE_AUDIT_FIXES:', 'APP_TESTS:', 'SCRIPT_PARSE:', 'GARAGE_FIRST_DRAW:'))]
    row['failure_lines'] = [line for line in text.splitlines() if line.startswith('FAIL:') or 'SCRIPT ERROR:' in line][:40]
    row['certificate_store_environment_error'] = 'root certificate store' in text
    commands.append(row)
images = {}
for path in (ROOT/'game/assets/garage/previews_v1').glob('*.png'):
    images[path.name] = {'sha256': sha(path), 'task_start_identical': sha(path)==sha(BEFORE/'game/assets/garage/previews_v1'/path.name)}
provenance = subprocess.run(['python', 'scripts/check_garage_previews.py'], cwd=ROOT,
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
report = {
    'requirements': ['GEC01', 'GEC02', 'GEC03', 'R01', 'Q01'],
    'date': '2026-10-26',
    'commands': commands,
    'changed_files': [{'path': path, 'sha256': sha(ROOT/path)} for path in paths],
    'native_photographs': images,
    'preview_provenance_check': {'exit_code': provenance.returncode, 'output': provenance.stdout},
    'checkpoint': {'path': 'task-only.patch', 'sha256': sha(OUT/'task-only.patch'), 'reverse_check_exit_code': review.returncode, 'output': review.stdout},
    'concurrent_work': 'Rivalry summary and race render-preparation App edits are retained in scope-base and excluded. Paint animation, model/handling, tracks and other Garage edits remain untouched. Thumbnail signature matches the concurrent parent.',
    'baseline': 'Staged task-start App/cache/thumbnail behavior. The old thumbnail only receives the concurrent optional method parameter; original bytes are retained. Baseline does not write to production sources.',
    'limits': ['Loading-screen removal is not an asynchronous/cold-latency optimization. Fresh profile shader draws still hitch; timings include concurrent workstation activity.', 'Catalogue pictures may temporarily use factory paint until the exact saved appearance arrives.', 'No device attachment check/test, APK/AAB, real authentication/purchase, live mutation, deployment, staging, commit or owner-process restart.'],
    'initial_failures': ['PowerShell execution policy prevented the first wrapper invocation; the isolated pinned-engine runner was used afterward.', 'Fixture initially seeded settings before startup load, then directly assigned conditions instead of staging the condition store.', 'Concurrent parent signature changed during the task; cached-thumbnail signature now matches.', 'Absolute render count included existing dirty-car jobs; the corrected fixture preserves the one-new-render bound relative to its starting count.', 'In-memory baseline reload failed after concurrent class changes; the staged baseline retains old behavior with only the documented signature adapter.'],
    'captures': [p.name for p in sorted(OUT.glob('*.png'))],
}
(OUT/'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({'commands':len(commands), 'patch_reverse_check':review.returncode, 'provenance_check':provenance.returncode, 'unchanged_photos':sum(row['task_start_identical'] for row in images.values())}))
if review.returncode: print(review.stdout)
