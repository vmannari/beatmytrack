import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

BASE = Path(__file__).resolve().parent
ROOT = next(p for p in BASE.parents if (p / 'godot-version.txt').exists())
SOURCES = ['game/core/app.gd', 'game/ui/garage_cached_thumbnail.gd',
           'game/tests/test_garage_entry_carousel.gd']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(*args):
    result = subprocess.run(['git', *args], cwd=ROOT, capture_output=True, text=True)
    assert result.returncode == 0, (args, result.stdout, result.stderr)
    return dict(command=['git', *args], exit_code=result.returncode,
                stdout=result.stdout, stderr=result.stderr)


sources = {}
for name in SOURCES:
    target = BASE / 'after' / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / name, target)
    sources[name] = dict(before=sha(BASE / 'before' / name), after=sha(target))

receipts = {}
for path in sorted(BASE.glob('*/command.json')):
    record = json.loads(path.read_text())
    raw = (path.parent / 'run.log').read_text(errors='replace')
    counts = re.search(r'APP_TESTS: (\d+) checks, (\d+) failures', raw)
    if counts:
        record['assertions'] = dict(checks=int(counts[1]), failures=int(counts[2]))
    for line in raw.splitlines():
        if line.startswith(('GARAGE_ENTRY_CAROUSEL:', 'GARAGE_LIVE_ENTRY ', 'GARAGE_FIRST_ENTRY ')):
            record['assertions'] = json.loads(line[line.index('{'):])
    receipts[path.parent.name] = record

patch = BASE / 'task.patch'
git('diff', '--binary', '--output=' + str(patch), '--', *SOURCES)
checkpoint = [git('diff', '--check', '--', *SOURCES),
              git('apply', '--reverse', '--check', str(patch))]
roundtrip = ROOT / 'build/garage-initial-liveries-checkpoint'
for name in SOURCES:
    target = roundtrip / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(BASE / 'before' / name, target)
prefix = '--directory=' + roundtrip.relative_to(ROOT).as_posix()
checkpoint.append(git('apply', '--check', prefix, str(patch)))
checkpoint.append(git('apply', prefix, str(patch)))
for name in SOURCES:
    assert (roundtrip / name).read_text() == (ROOT / name).read_text(), name
checkpoint.append(git('apply', '--reverse', prefix, str(patch)))
for name in SOURCES:
    assert (roundtrip / name).read_bytes() == (BASE / 'before' / name).read_bytes(), name

for label in ['fixed-headless', 'fixed-compatibility', 'fixed-mobile',
              'live-compatibility', 'preloaded-compatibility', 'app-headless', 'parse-app']:
    assert receipts[label]['exit_code'] == 0, label

generated = {}
for name in ['game/core/build_identity.gd', 'game/project.godot']:
    target = BASE / 'generated-test-metadata' / name
    if not target.exists():
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, target)
    generated[name] = dict(test_generated_sha256=sha(target), current_sha256=sha(ROOT / name))

shared = {}
for name in ['AGENTS.md', 'DEVELOPMENT_STATUS.md', 'docs/PHASE_0_PLAN.md']:
    text = (ROOT / name).read_text(encoding='utf-8')
    prior = re.sub(r'^<!-- GARAGE-INITIAL-LIVERIES-20261028 -->.*?<!-- /GARAGE-INITIAL-LIVERIES-20261028 -->\n\n', '', text, flags=re.S)
    assert prior == (BASE / 'doc-base' / Path(name).name).read_text(encoding='utf-8'), name
    shared[name] = dict(prior_content_preserved=True, after_sha256=sha(ROOT / name))

report = dict(requirements=['GL01', 'GL02', 'R01', 'Q01'],
              engine=(ROOT / 'godot-version.txt').read_text().strip(),
              sources=sources, receipts=receipts, checkpoint=checkpoint,
              patch_sha256=sha(patch), shared_documents=shared, generated_metadata=generated,
              screenshots={p.relative_to(BASE).as_posix(): sha(p) for p in sorted(BASE.glob('*/*.png'))},
              limitations=['Uncached custom thumbnails wait empty for an exact picture.',
                           'Cold construction and shader hitches remain possible.',
                           'No physical-device test or attachment query.',
                           'Reload and owner appearance/input/latency acceptance remain.'])
(BASE / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(dict(sources=len(sources), receipts=len(receipts),
                     screenshots=len(report['screenshots']), checkpoint='pass')))
