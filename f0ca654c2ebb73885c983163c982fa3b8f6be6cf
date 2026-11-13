import json
import os
from pathlib import Path
import subprocess
import time

LAB = Path(__file__).resolve().parent
command_root = [str(LAB/'link_bench.exe')]
sources = [str(LAB/'shader-source/captured.vert'), str(LAB/'shader-source/captured.frag')]
records = []

def environment(label, binary=None):
    profile = LAB/'profiles'/label
    profile.mkdir(parents=True, exist_ok=True)
    env = {k: v for k, v in os.environ.items() if not k.startswith('BMT_')}
    env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile))
    if binary:
        env['BMT_BENCH_BINARY_PATH'] = str(binary)
    return env

def run(label, mode, binary):
    command = command_root + [mode] + sources
    began = time.time_ns()//1000
    with (LAB/(label+'.log')).open('wb') as log:
        child = subprocess.Popen(command, env=environment(label, binary), stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            code = child.wait(timeout=30)
        except subprocess.TimeoutExpired:
            child.kill();child.wait();code = 'timeout'
    output = (LAB/(label+'.log')).read_text(encoding='utf-8', errors='replace')
    result = dict(label=label, pid=child.pid, command=command, exit=code, utc_begin_us=began, utc_end_us=time.time_ns()//1000, result=json.loads(output))
    records.append(result)
    return result

for case in ['control', 'compiler-1', 'compiler-2']:
    label = 'process-'+case
    command = command_root + ['heartbeat'] + sources
    child = subprocess.Popen(command, env=environment(label), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
    first = child.stdout.readline()
    assert first == b'READY\r\n' or first == b'READY\n', first
    ready = time.time_ns()//1000
    if case != 'control':
        binary = LAB/'shader-source'/('compiled-'+case+'.bin')
        run(label+'-save', 'save', binary)
        run(label+'-load', 'load', binary)
    try:
        output, _ = child.communicate(timeout=10)
    except subprocess.TimeoutExpired:
        child.kill();output, _ = child.communicate()
    (LAB/(label+'.log')).write_bytes(first+output)
    result = json.loads(output)
    records.append(dict(label=label, pid=child.pid, command=command, exit=child.returncode, utc_ready_us=ready, utc_end_us=time.time_ns()//1000, result=result))
    print(json.dumps({'case':case, 'heartbeat': result}), flush=True)
    (LAB/'process-bench-results.json').write_text(json.dumps(dict(records=records), indent=2), encoding='utf-8')
