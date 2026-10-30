from pathlib import Path
import os, subprocess, time, json, ctypes, ctypes.wintypes as w

root = Path.cwd()
lab = root/'build/re-audit-2026-10-27'
profile = lab/'profiles/soak50-native'
profile.mkdir(parents=True,exist_ok=True)
env = {k:v for k,v in os.environ.items() if not k.startswith('BMT_')}
env.update(APPDATA=str(profile),LOCALAPPDATA=str(profile))
command = ['C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64.exe',
    '--audio-driver','Dummy','--rendering-method','gl_compatibility','--path',str(root/'game'),
    '--script','tests/soak_runtime_correctness.gd','--','--cycles=50',
    '--report-dir=res://../build/re-audit-2026-10-27/soak50-native']
class Counters(ctypes.Structure):
    _fields_=[('cb',w.DWORD),('faults',w.DWORD)]+[(n,ctypes.c_size_t) for n in
        ['peak_working_set','working_set','peak_paged_pool','paged_pool','peak_nonpaged_pool',
         'nonpaged_pool','pagefile','peak_pagefile','private']]
kernel=ctypes.WinDLL('kernel32',use_last_error=True)
kernel.OpenProcess.argtypes=[w.DWORD,w.BOOL,w.DWORD];kernel.OpenProcess.restype=w.HANDLE
kernel.CloseHandle.argtypes=[w.HANDLE]
psapi=ctypes.WinDLL('psapi',use_last_error=True)
psapi.GetProcessMemoryInfo.argtypes=[w.HANDLE,ctypes.POINTER(Counters),w.DWORD]
began=time.monotonic()
with (lab/'soak50-native.log').open('wb') as log, (lab/'soak50-process-memory.jsonl').open('w',encoding='utf-8') as samples:
    process=subprocess.Popen(command,env=env,stdout=log,stderr=subprocess.STDOUT)
    handle=kernel.OpenProcess(0x410,False,process.pid)
    while process.poll() is None:
        value=Counters();value.cb=ctypes.sizeof(value)
        if handle and psapi.GetProcessMemoryInfo(handle,ctypes.byref(value),value.cb):
            samples.write(json.dumps({'seconds':round(time.monotonic()-began,3),'working_set':value.working_set,
                'private':value.private,'peak_working_set':value.peak_working_set})+'\n');samples.flush()
        if time.monotonic()-began>3600:
            process.kill();process.wait();break
        time.sleep(0.5)
    if handle:kernel.CloseHandle(handle)
result={'command':command,'pid':process.pid,'exit':process.returncode,'seconds':round(time.monotonic()-began,3),
    'scope':'Own newly launched process; workstation Compatibility. Other CPU correctness tests may overlap; this is memory/lifetime evidence, not a timing benchmark.'}
(lab/'soak50-execution.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result),flush=True)
