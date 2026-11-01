"""Bounded Perfetto sampling capability check for one task-owned shell PID."""
import hashlib
import json
import subprocess
import uuid
from pathlib import Path

adb = r'C:\Users\ville\AppData\Local\Android\Sdk\platform-tools\adb.exe'
prefix = [adb, '-s', 'f0ba474a']
outdir = Path('build/android-perfetto-observation-20261031/shell-sampling-check-verified')
outdir.mkdir(parents=True, exist_ok=True)
workload = "echo $$; end=$(( $(date +%s) + 12 )); while [ $(date +%s) -lt $end ]; do i=0; while [ $i -lt 10000 ]; do i=$((i+1)); done; done"
task = subprocess.Popen(prefix + ['shell', 'sh', '-c', "'" + workload + "'"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
pid_line = task.stdout.readline().strip()
if not pid_line.isdecimal():
    raise RuntimeError('Owned workload did not report a numeric PID: ' + repr(pid_line))
pid = int(pid_line)
config = f'''buffers {{ size_kb: 8192 fill_policy: DISCARD }}
duration_ms: 4000
data_sources {{ config {{
  name: "linux.perf"
  perf_event_config {{
    timebase {{ counter: SW_CPU_CLOCK frequency: 99 timestamp_clock: PERF_CLOCK_MONOTONIC }}
    callstack_sampling {{ scope {{ target_pid: {pid} }} kernel_frames: false }}
  }}
}} }}
data_sources {{ config {{ name: "linux.process_stats" process_stats_config {{ scan_all_processes_on_start: true }} }} }}
'''
(outdir / 'config.pbtxt').write_text(config, encoding='utf-8')
remote = '/data/misc/perfetto-traces/bmt-owned-perf-' + uuid.uuid4().hex + '.pftrace'
trace = subprocess.run(prefix + ['shell', 'perfetto', '--txt', '-c', '-', '-o', remote], input=config.encode(), capture_output=True, timeout=20)
(outdir / 'perfetto-stderr.txt').write_bytes(trace.stderr)
task_out, task_err = task.communicate(timeout=20)
remote_hash_run = subprocess.run(prefix + ['shell', 'sha256sum', remote], capture_output=True, text=True, timeout=20, check=True)
remote_hash = remote_hash_run.stdout.split()[0]
pull = subprocess.run(prefix + ['pull', remote, str(outdir / 'trace.pftrace')], capture_output=True, text=True, timeout=20, check=True)
trace_bytes = (outdir / 'trace.pftrace').read_bytes()
local_hash = hashlib.sha256(trace_bytes).hexdigest()
if local_hash != remote_hash:
    raise RuntimeError('Device and host trace hashes differ; remote retained at ' + remote)
cleanup = subprocess.run(prefix + ['shell', 'rm', remote], capture_output=True, text=True, timeout=20)
receipt = {'owned_pid': pid, 'workload_naturally_ended': task.returncode == 0, 'workload_returncode': task.returncode, 'workload_remaining_stdout': task_out, 'workload_stderr': task_err, 'trace_returncode': trace.returncode, 'trace_bytes': len(trace_bytes), 'device_sha256': remote_hash, 'host_sha256': local_hash, 'remote_path': remote, 'pull_stdout': pull.stdout, 'pull_stderr': pull.stderr, 'cleanup_returncode': cleanup.returncode, 'note': 'No app launched, no cache cleared; unique remote trace deleted after matching hashes; task is self-terminating.'}
(outdir / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
print(json.dumps(receipt, indent=2))
