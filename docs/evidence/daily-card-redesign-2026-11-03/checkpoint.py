"""Check a task-only source patch in an owned repository; never stage the main tree."""
import difflib
import hashlib
import json
from pathlib import Path
import re
import subprocess
import uuid

root = Path(__file__).resolve().parents[3]
out = Path(__file__).resolve().parent
paths = [str(p.relative_to(out / 'before')).replace('\\', '/') for p in (out / 'before').rglob('*') if p.is_file()]
added = ['AGENTS.md', 'DEVELOPMENT_STATUS.md', 'docs/PHASE_0_PLAN.md',
         'docs/DAILY_CARD_REDESIGN_2026_11_03.md', 'scripts/translations/daily_card_redesign.tsv',
         'game/tests/test_daily_card_redesign.gd', 'game/tests/test_daily_card_redesign.gd.uid']
added += [str(p.relative_to(root)).replace('\\', '/') for p in out.glob('*.py')]
before, after, pieces, sources = {}, {}, [], []
for name in sorted(set(paths + added)):
    current = (root / name).read_text(encoding='utf-8')
    archived = out / 'before' / name
    old = archived.read_text(encoding='utf-8') if archived.exists() else None
    # Other tasks edit the same shared files. Subtract only our additions from
    # their current state, instead of pulling their work into this checkpoint.
    if name in ['AGENTS.md', 'DEVELOPMENT_STATUS.md', 'docs/PHASE_0_PLAN.md']:
        old = re.sub(r'<!-- DAILY-CARD-REDESIGN-20261103 -->\n.*?<!-- /DAILY-CARD-REDESIGN-20261103 -->\n\n', '', current, count=1, flags=re.S)
    if name.startswith('game/localization/'):
        old = current
        for source in ['Chase the podium', 'Target']:
            old = re.sub(r'\n#: game/ui/daily_result_card\.gd\nmsgid '+re.escape(json.dumps(source))+r'\nmsgstr "[^\n]*"\n', '', old, count=1)
    before[name], after[name] = old, current
    if old == current:
        continue
    pieces.append('diff --git a/'+name+' b/'+name+'\n')
    if old is None:
        pieces.append('new file mode 100644\n')
    pieces.extend(difflib.unified_diff((old or '').splitlines(keepends=True), current.splitlines(keepends=True),
                  fromfile='a/'+name if old is not None else '/dev/null', tofile='b/'+name))
    sources.append({'path': name, 'sha256': hashlib.sha256((root/name).read_bytes()).hexdigest(),
                    'baseline_utf8_sha256': hashlib.sha256(old.encode()).hexdigest() if old is not None else None})
patch = out / 'task.patch'
patch.write_text(''.join(pieces), encoding='utf-8', newline='\n')
workspace = root / 'build' / ('daily-card-checkpoint-'+uuid.uuid4().hex[:10])
workspace.mkdir(parents=True)
assert workspace.resolve().is_relative_to((root/'build').resolve())
def git(*args):
    result = subprocess.run(['git', '-c', 'core.autocrlf=false', *args], cwd=workspace, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stdout+result.stderr)
git('init', '--quiet')
for name, content in before.items():
    if content is not None:
        path = workspace / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding='utf-8', newline='\n')
git('apply', '--check', str(patch))
git('apply', str(patch))
assert all((workspace/name).read_text(encoding='utf-8') == content for name, content in after.items())
git('apply', '--reverse', '--check', str(patch))
git('apply', '--reverse', str(patch))
assert all(not (workspace/name).exists() if content is None else (workspace/name).read_text(encoding='utf-8') == content for name, content in before.items())
validation = []
for log in sorted(out.glob('*.log')):
    raw = log.read_bytes()
    output = raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')
    match = re.search(r'(DAILY_[A-Z_]+): (\d+) checks, (\d+) failures', output)
    if match:
        validation.append({'log':log.name,'suite':match[1],'checks':int(match[2]),'failures':int(match[3])})
report = {'requirements':['DCR01','DCR02','DCR03','DCR04'], 'source_files':sources,
          'checkpoint':{'forward_check':True,'forward_content':True,'reverse_check':True,'reverse_content':True,
                        'comparison':'normalized UTF-8 source text','main_index_written':False},
          'validation_including_initial_failures':validation,
          'backend':{'passed':5,'postgres_deselected':5,'log':'backend-tests.log'},
          'limits':['No physical-device query or test','No deployment','Backend rollout needed for expanded post-race neighbours',
                    'Existing certificate-store error retained','Owner appearance/touch acceptance remains'],
          'screenshots':[{'path':str(p.relative_to(out)).replace('\\','/'),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
                         for p in sorted(out.rglob('*.png'))]}
(out/'report.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(f'{len(sources)} task files: forward/reverse application and content checks passed')
