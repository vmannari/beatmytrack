import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

LAB = Path(__file__).resolve().parent
records = []
for label, mode in [('v2-current-1', 'current'), ('v2-deferred-1', 'deferred'), ('v2-shared-1', 'shared'),
                    ('v2-deferred-2', 'deferred'), ('v2-current-2', 'current'), ('v2-shared-2', 'shared')]:
    profile = LAB / 'profiles' / ('link-' + label)
    profile.mkdir(parents=True, exist_ok=True)
    env = {k: v for k, v in os.environ.items() if not k.startswith('BMT_')}
    env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile))
    command = [str(LAB / 'link_bench.exe'), mode, str(LAB / 'shader-source/captured.vert'), str(LAB / 'shader-source/captured.frag')]
    began = time.monotonic()
    with (LAB / ('link-' + label + '.log')).open('wb') as log:
        process = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            code = process.wait(timeout=90)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            code = 'timeout'
    output = (LAB / ('link-' + label + '.log')).read_text(encoding='utf-8', errors='replace')
    try:
        result = json.loads(output)
    except ValueError:
        result = {'parse_failure': output}
    record = dict(label=label, command=command, pid=process.pid, exit=code, seconds=round(time.monotonic()-began, 3), result=result)
    records.append(record)
    print(json.dumps(record), flush=True)
    (LAB / 'link-bench-results.json').write_text(json.dumps(dict(
        shader_hashes={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (LAB/'shader-source').iterdir()},
        records=records), indent=2), encoding='utf-8')
