from pathlib import Path
import difflib
import hashlib
import json
import shutil
import subprocess

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'godot-version.txt').exists())
OUT = Path(__file__).resolve().parent
rel = 'game/ui/garage_page.gd'
before = (OUT / 'before/garage_page.gd').read_text()
source = ROOT / rel
after = source.read_text()
(OUT / 'after').mkdir(exist_ok=True)
(OUT / 'after/garage_page.gd').write_bytes(source.read_bytes())
patch = ''.join(difflib.unified_diff(before.splitlines(keepends=True), after.splitlines(keepends=True),
                                    fromfile='a/' + rel, tofile='b/' + rel))
(OUT / 'task.patch').write_text(patch, encoding='utf-8', newline='\n')
check_rel = 'build/carousel-label-overlay-patch-check'
baseline = ROOT / check_rel / rel
baseline.parent.mkdir(parents=True, exist_ok=True)
baseline.write_text(before, encoding='utf-8', newline='\n')
checks = []
for args in [['--reverse'], ['--directory=' + check_rel, '--whitespace=error']]:
    command = ['git', 'apply', '--check'] + args + [str(OUT / 'task.patch')]
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    checks.append(dict(command=command, exit_code=result.returncode, output=result.stdout + result.stderr))
    assert result.returncode == 0, checks[-1]
generated = OUT / 'generated'
generated.mkdir(exist_ok=True)
for metadata in ['game/core/build_identity.gd', 'game/project.godot']:
    shutil.copyfile(ROOT / metadata, generated / Path(metadata).name)
captures = sorted(str(p.relative_to(ROOT)) for p in (OUT / 'native-gl').glob('*.png'))
record = dict(requirement='CL05: translucent label overlays the miniature garage picture',
              runtime_sources={rel: hashlib.sha256(source.read_bytes()).hexdigest()},
              native_run=json.loads((OUT / 'native-gl/command.json').read_text()),
              captures=captures, checkpoint_checks=checks,
              scope='One runtime layout change; existing capture helper unchanged; generated metadata excluded.',
              limitations=['Desktop Compatibility capture evidence; no device test or phone performance claim.',
                           'Reload/rebuild and owner appearance acceptance remain.',
                           'No owner-save/live mutation, deployment, owner-process restart or main-index staging/commit/merge.'])
(OUT / 'report.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(dict(captures=len(captures), checks=checks, source_hash=record['runtime_sources'])))
