from pathlib import Path
import json, os, shutil, subprocess, time

root = Path.cwd()
original = root / 'build/native-shader-preparation-2026-10-28'
worker = original / 'shader_worker.exe'
jobs = sorted((original / 'programs/jobs-context').glob('*.job'), key=lambda p: p.stat().st_size, reverse=True)
work = root / 'tmp/shader-worker-batch-20261030'
work.mkdir(parents=True, exist_ok=True)
assert len(jobs) == 192 and worker.is_file()
summary = []
for count in (1, 4, 16):
    inputs = work / f'jobs-{count}'
    outputs = work / f'output-{count}'
    inputs.mkdir(exist_ok=False)
    outputs.mkdir(exist_ok=False)
    for job in jobs[:count]:
        shutil.copyfile(job, inputs / job.name)
    start = time.monotonic()
    result = subprocess.run([str(worker), str(inputs), str(outputs)], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180, creationflags=subprocess.CREATE_NO_WINDOW)
    elapsed = time.monotonic() - start
    (work / f'worker-{count}.log').write_bytes(result.stdout)
    report = json.loads((outputs / 'worker-result.json').read_text()) if (outputs / 'worker-result.json').exists() else {}
    summary.append({'count': count, 'job_bytes': sum(p.stat().st_size for p in jobs[:count]), 'exit': result.returncode, 'wall_seconds': elapsed, 'report': report})
    print(json.dumps(summary[-1]), flush=True)
(work / 'summary.json').write_text(json.dumps(summary, indent=2))
