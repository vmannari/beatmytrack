from pathlib import Path
import json, shutil, subprocess, time

root = Path.cwd()
original = root / 'build/native-shader-preparation-2026-10-28'
jobs = sorted((original / 'programs/jobs-context').glob('*.job'), key=lambda p: p.stat().st_size)
work = root / 'tmp/shader-worker-small-control-20261030'
work.mkdir(parents=True, exist_ok=False)
assert len(jobs) == 192
summaries = []
for i in range(3):
    inputs, outputs = work / f'jobs-{i}', work / f'output-{i}'
    inputs.mkdir(); outputs.mkdir()
    shutil.copyfile(jobs[0], inputs / jobs[0].name)
    for name, command in [('context', [str(root / 'tmp/shader-worker-context-20261030.exe')]), ('smallest', [str(original / 'shader_worker.exe'), str(inputs), str(outputs)])]:
        started = time.monotonic()
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120, creationflags=subprocess.CREATE_NO_WINDOW)
        (work / f'{name}-{i}.log').write_bytes(result.stdout)
        report = json.loads((outputs / 'worker-result.json').read_text()) if name == 'smallest' and (outputs / 'worker-result.json').exists() else [json.loads(line) for line in result.stdout.decode().splitlines()]
        summary = {'run': i, 'kind': name, 'job': jobs[0].name if name == 'smallest' else None, 'job_bytes': jobs[0].stat().st_size if name == 'smallest' else 0, 'exit': result.returncode, 'wall_seconds': time.monotonic()-started, 'report': report}
        summaries.append(summary)
        print(json.dumps(summary), flush=True)
(work / 'summary.json').write_text(json.dumps(summaries, indent=2))
