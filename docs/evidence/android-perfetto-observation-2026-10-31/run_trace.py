"""Owned, profileable Android GL probe: bounded Perfetto sample before launch.

Never changes global debug settings, clears data, attaches to the production
game, dismisses keyguard or terminates a process it did not launch. This script
requires explicit --execute, a device serial, and a stopped isolated package.
The trace includes system scheduling metadata; raw data stays in this workspace.
"""
import argparse
import hashlib
import json
import re
import shlex
import subprocess
import threading
import time
import uuid
from pathlib import Path

PACKAGE = 'org.beatmytrack.rendererprobe.gl20261031'
COMPONENT = PACKAGE + '/com.godot.game.GodotAppLauncher'
ROOT = Path(__file__).resolve().parents[2]
LAB = Path(__file__).resolve().parent
ADB = Path('C:/Users/ville/AppData/Local/Android/Sdk/platform-tools/adb.exe')
CONFIG = LAB / 'config.pbtxt'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--serial', required=True)
parser.add_argument('--execute', action='store_true')
args = parser.parse_args()
if not re.fullmatch(r'[A-Za-z0-9._:-]+', args.serial):
    raise SystemExit('Invalid device serial')
if not args.execute:
    raise SystemExit('Dry run only. Pass --execute after exclusive device handoff.')
target = LAB / ('capture-' + uuid.uuid4().hex[:12])
target.mkdir(exist_ok=False)
remote = '/data/misc/perfetto-traces/bmt-isolated-' + uuid.uuid4().hex + '.pftrace'
receipt = {'package':PACKAGE, 'component':COMPONENT, 'output':str(target),
           'cache_state':'previously exercised; app and driver caches not cleared',
           'trace_scope':'120 seconds, native samples + device scheduler/frequency metadata',
           'limits':['sampled CPU stacks do not establish GL call wall times',
                     'FrameTimeline may not support SurfaceView',
                     'trace overhead and system-wide scheduler metadata',
                     'no direct input-to-photon measurement'], 'commands':[], 'errors':[]}
def adb(*params, payload=None, timeout=20, check=True, retain_output=True):
    command = [str(ADB), '-s', args.serial, *params]
    result = subprocess.run(command, input=payload, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            timeout=timeout, check=False)
    item = {'args':params, 'exit':result.returncode,
            'stdout':result.stdout.decode('utf-8',errors='replace'),
            'stderr':result.stderr.decode('utf-8',errors='replace')}
    receipt['commands'].append(item if retain_output else {**item, 'stdout':'[not retained]'})
    if check and result.returncode:
        raise RuntimeError('ADB failed: ' + repr(params) + ': ' + item['stderr'])
    return item
started = False
owned_pid = None
trace_started = None
surface_stop=threading.Event()
surface_thread=None
try:
    if adb('get-state')['stdout'].strip() != 'device':
        raise RuntimeError('Target is not an authorized device')
    if not adb('shell','pm','path',PACKAGE)['stdout'].strip().startswith('package:'):
        raise RuntimeError('Isolated GL package is not installed')
    previous = adb('shell','pidof',PACKAGE,check=False)
    if previous['stdout'].strip():
        raise RuntimeError('Isolated GL package is already running; refusing to disturb it')
    capabilities=adb('shell','perfetto','--query',check=False,retain_output=False,timeout=30)
    receipt['perfetto_gpu_sources']=[line.strip() for line in capabilities['stdout'].splitlines()
                                      if 'gpu.' in line.lower()][:64]
    receipt['perfetto_query_exit']=capabilities['exit']
    available=adb('shell','cat','/sys/kernel/tracing/available_events',check=False,retain_output=False,timeout=15)
    if available['exit']:
        available=adb('shell','cat','/sys/kernel/debug/tracing/available_events',check=False,retain_output=False,timeout=15)
    available_events=set(available['stdout'].splitlines()) if available['exit']==0 else set()
    optional_events=[pair for pair in [('power:gpu_frequency','power/gpu_frequency'),('gpu_mem:gpu_mem_total','gpu_mem/gpu_mem_total')] if pair[0] in available_events]
    receipt['gpu_ftrace_events']=[pair[1] for pair in optional_events]
    receipt['available_events_query_exit']=available['exit']
    render_sources=sorted(set(re.findall(r'gpu\.renderstages(?:\.[A-Za-z0-9_-]+)?',capabilities['stdout'])))
    receipt['gpu_render_sources_selected']=render_sources
    config_text=CONFIG.read_text(encoding='utf-8').replace('# OPTIONAL_GPU_FTRACE','\n    '.join('ftrace_events: "'+pair[1]+'"' for pair in optional_events))
    for source in render_sources:
        config_text+='\ndata_sources { config { name: "'+source+'" target_buffer: 0 } }\n'
    config=config_text.encode('utf-8')
    (target/'config.pbtxt').write_bytes(config)
    receipt['config_sha256']=hashlib.sha256(config).hexdigest()
    trace_started=time.monotonic()
    result = adb('shell','perfetto','--txt','-c','-','-o',remote,'--background-wait',payload=config,timeout=40)
    receipt['trace_start_host_ns']=time.monotonic_ns()
    (target/'perfetto-start.txt').write_text(result['stdout']+'\n'+result['stderr'],encoding='utf-8')
    started = True
    adb('shell','am','start','-W','-n',COMPONENT,timeout=45)
    current=adb('shell','pidof',PACKAGE)['stdout'].split()
    if len(current)!=1 or not current[0].isdigit(): raise RuntimeError('Cannot establish unique probe PID')
    owned_pid=current[0]
    receipt['pid']=int(owned_pid)
    gate_deadline=time.monotonic()+50
    while time.monotonic()<gate_deadline:
        logs=adb('logcat','-d','--pid',owned_pid,'-v','threadtime',timeout=15)['stdout']
        if 'BMT_PERF_GATE_READY' in logs: break
        time.sleep(1)
    else: raise RuntimeError('Gate not observed; no screen input sent')
    foreground=adb('shell','dumpsys','activity','activities',retain_output=False)['stdout']
    top=[line for line in foreground.splitlines() if 'topResumedActivity' in line]
    if not any(PACKAGE in line for line in top):
        raise RuntimeError('Isolated probe is not foreground; no screen input sent')
    # Sample only this SurfaceView's own latency ring. Never clear the ring.
    layers=adb('shell','dumpsys','SurfaceFlinger','--list',retain_output=False)['stdout']
    pattern=r'SurfaceView\['+re.escape(COMPONENT)+r'\]\(BLAST\)#\d+'
    matches=sorted(set(re.findall(pattern,layers)))
    if len(matches)==1:
        layer=matches[0]
        receipt['surface_layer']=layer
        def poll_surface():
            with (target/'surface-latency.jsonl').open('w',encoding='utf-8') as sink:
                while not surface_stop.is_set():
                    command=[str(ADB),'-s',args.serial,'shell','dumpsys','SurfaceFlinger','--latency',shlex.quote(layer)]
                    started_ns=time.monotonic_ns()
                    try:
                        result=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=8,check=False)
                        row={'host_monotonic_ns':started_ns,'exit':result.returncode,
                             'raw':result.stdout.decode('utf-8',errors='replace'),
                             'stderr':result.stderr.decode('utf-8',errors='replace')}
                    except Exception as exc: row={'host_monotonic_ns':started_ns,'error':repr(exc)}
                    sink.write(json.dumps(row)+'\n');sink.flush()
                    surface_stop.wait(1.0)
        surface_thread=threading.Thread(target=poll_surface,daemon=True)
        surface_thread.start()
    else:
        receipt['surface_latency_unavailable']='Layer identification returned %d matches' % len(matches)
    receipt['gate_visible_host_ns']=time.monotonic_ns()
    adb('shell','input','tap','400','400')
    receipt['gate_tap_host_ns']=time.monotonic_ns()
    # Perfetto self-terminates; no global session is canceled.
    while time.monotonic()-trace_started < 123: time.sleep(2)
    receipt['trace_wait_complete_host_ns']=time.monotonic_ns()
except Exception as exc:
    receipt['errors'].append(repr(exc))
finally:
    surface_stop.set()
    if surface_thread is not None: surface_thread.join(timeout=10)
    if started and owned_pid is None:
        try:
            candidate=adb('shell','pidof',PACKAGE,check=False)['stdout'].split()
            if len(candidate)==1 and candidate[0].isdigit(): owned_pid=candidate[0]
        except Exception as exc: receipt['errors'].append('PID cleanup lookup: '+repr(exc))
    if started and owned_pid:
        try:
            current=adb('shell','pidof',PACKAGE,check=False)['stdout'].split()
            if current == [owned_pid]:
                app_log=adb('logcat','-d','--pid',owned_pid,'-v','epoch',check=False,timeout=30)
                (target/'probe-logcat.txt').write_text(app_log['stdout'],encoding='utf-8')
                adb('shell','am','force-stop',PACKAGE)
                receipt['own_probe_stopped']=True
            else:
                receipt['errors'].append('probe PID changed; did not stop any process')
        except Exception as exc: receipt['errors'].append('cleanup: '+repr(exc))
    if trace_started is not None:
        # If launching/gate failed, still let this uniquely named trace finish.
        while time.monotonic()-trace_started < 123: time.sleep(2)
        try:
            remote_hash=adb('shell','sha256sum',remote,timeout=30)['stdout'].split()[0]
            adb('pull',remote,str(target/'trace.pftrace'),timeout=90)
            local_hash=hashlib.sha256((target/'trace.pftrace').read_bytes()).hexdigest()
            receipt.update(trace_remote=remote, trace_sha256=local_hash, remote_sha256=remote_hash,
                           trace_bytes=(target/'trace.pftrace').stat().st_size)
            if local_hash==remote_hash:
                adb('shell','rm','-f',remote)
                receipt['own_trace_removed']=True
            else:
                receipt['errors'].append('trace hash mismatch; remote trace retained')
        except Exception as exc: receipt['errors'].append('trace retrieval: '+repr(exc))
    (target/'receipt.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
    print(json.dumps({'output':str(target),'pid':owned_pid,'errors':receipt['errors']},indent=2))
if receipt['errors']: raise SystemExit(1)
