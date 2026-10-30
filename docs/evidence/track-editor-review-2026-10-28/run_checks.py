"""Review-only runner: pinned entry point, disposable profile, raw retained logs."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import time

ROOT = Path.cwd()
OUT = ROOT / 'docs/evidence/track-editor-review-2026-10-28'
profile = ROOT / 'build/track-editor-review-2026-10-28/profile'
(profile / 'Circuit01Lab').mkdir(parents=True, exist_ok=True)
(profile / 'Circuit01Lab/backend.cfg').write_text('[backend]\nurl=""\n', encoding='utf-8')
env = {k: v for k, v in os.environ.items() if not k.startswith('BMT_')}
env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile))
results = []
for name in ['test_editor_workflow', 'test_editor_t01_t04', 'test_editor_t05_t11',
             'test_editor_t11_t15', 'test_editor_review_fixes', 'test_editor_preparation',
             'test_creator_capacity', 'test_draft_recovery', 'test_editor_practice']:
    script = ROOT / 'game/tests' / (name + '.gd')
    if not script.exists():
        results.append(dict(test=name, exit='missing'))
        continue
    command = ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
               str(ROOT / 'scripts/dev.ps1'), '-Action', 'TestScript', '-ScriptPath',
               'res://tests/' + name + '.gd', '-CommandTimeoutSeconds', '180']
    start = time.monotonic()
    with (OUT / (name + '-headless.log')).open('wb') as log:
        child = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT)
        try:
            code = child.wait(timeout=205)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait()
            code = 'wrapper-timeout'
    result = dict(test=name, command=command, exit=code, seconds=round(time.monotonic()-start, 3),
                  source_sha256=hashlib.sha256(script.read_bytes()).hexdigest())
    results.append(result)
    (OUT / 'checks.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
    print(json.dumps(result), flush=True)
    lines = (OUT / (name + '-headless.log')).read_text(encoding='utf-8', errors='replace').splitlines()
    print('\n'.join(line for line in lines if any(x in line for x in ['FAIL:', 'SCRIPT ERROR:', 'checks,', 'assertions', 'passed', 'FAILURES', 'EDITOR_']))[-2200:], flush=True)
