from pathlib import Path
import ctypes,hashlib,json,os,secrets,socket,subprocess,sys,time

ROOT=Path.cwd();LAB=ROOT/'build/native-shader-preparation-2026-10-28'
ENGINE=Path('C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64.exe')
assert hashlib.sha256(ENGINE.read_bytes()).hexdigest()=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'
label,mode=sys.argv[1:3]
profile=LAB/'profiles'/label;profile.mkdir(parents=True,exist_ok=True)
output=LAB/'programs'/label;output.mkdir(parents=True,exist_ok=True)
jobs=LAB/'programs/jobs-context';jobs.mkdir(parents=True,exist_ok=True)
binary_label=next((a.split('=',1)[1] for a in sys.argv if a.startswith('--reuse-binaries=')),label)
binaries=LAB/'programs'/('binaries-'+binary_label);binaries.mkdir(parents=True,exist_ok=True)
env={k:v for k,v in os.environ.items() if not k.startswith('BMT_')}
env.update(APPDATA=str(profile),LOCALAPPDATA=str(profile),BMT_PREP_MODE=mode,BMT_PREP_JOBS=str(jobs),
    BMT_PREP_BINARIES=str(binaries),BMT_PREP_REPORT=str(output/'native-report.json'),BMT_PREP_OUTPUT=str(output),BMT_PREP_INPUT_TOKEN=secrets.token_hex(16))
if mode=='import':
    bootstrap=LAB/'programs/bootstrap-jobs-context';bootstrap.mkdir(parents=True,exist_ok=True)
    first=sorted(jobs.glob('*.job'),key=lambda p:p.stat().st_mtime_ns)[:2]
    assert len(first)==2
    for path in first:(bootstrap/path.name).write_bytes(path.read_bytes())
    before=time.monotonic()
    bootstrap_command=[str(LAB/'shader_worker.exe'),str(bootstrap),str(binaries)]
    with (output/'bootstrap.log').open('wb') as bootstrap_log:
        boot=subprocess.run(bootstrap_command,env=env,stdout=bootstrap_log,stderr=subprocess.STDOUT,timeout=30,creationflags=subprocess.CREATE_NO_WINDOW)
    (output/'bootstrap-execution.json').write_text(json.dumps(dict(command=bootstrap_command,exit=boot.returncode,seconds=round(time.monotonic()-before,3))),encoding='utf-8')
    assert boot.returncode==0,'Bootstrap compiler must succeed before launching import process'
command=[str(ENGINE),'--audio-driver','Dummy','--rendering-method','gl_compatibility','--path',str(ROOT/'game'),'--script',str(LAB/'garage_program_probe.gd')]
user=ctypes.windll.user32
user.PostMessageW.argtypes=[ctypes.c_void_p,ctypes.c_uint,ctypes.c_size_t,ctypes.c_ssize_t]
user.GetWindowThreadProcessId.argtypes=[ctypes.c_void_p,ctypes.POINTER(ctypes.c_ulong)]
posts=[];last_post=0;began=time.monotonic();input_sender=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
with (LAB/(label+'.log')).open('wb') as log:
    child=subprocess.Popen(command,env=env,stdout=log,stderr=subprocess.STDOUT)
    (LAB/(label+'-pid.json')).write_text(json.dumps(dict(pid=child.pid,command=command)),encoding='utf-8')
    while child.poll() is None and time.monotonic()-began<240:
        try:
            state=json.loads((output/'pulse-state.json').read_text())
        except (OSError,ValueError):state={}
        if state.get('enabled') and time.monotonic()-last_post>=0.1 and len(posts)<2048:
            hwnd=state['hwnd'];owner=ctypes.c_ulong()
            user.GetWindowThreadProcessId(hwnd,ctypes.byref(owner))
            assert owner.value==child.pid==state['pid'],'Only inject into this owned test window'
            posted=time.time_ns()//1000
            payload=dict(sequence=len(posts)+1,utc_us=posted,token=env['BMT_PREP_INPUT_TOKEN'])
            size=input_sender.sendto(json.dumps(payload).encode(),('127.0.0.1',state['port']))
            posts.append(dict(sequence=payload['sequence'],utc_us=posted,phase=state['phase'],sent=size>0))
            last_post=time.monotonic()
        time.sleep(0.01)
    if child.poll() is None:child.kill();child.wait();code='timeout'
    else:code=child.returncode
result=dict(label=label,mode=mode,pid=child.pid,command=command,exit=code,seconds=round(time.monotonic()-began,3),
    input_method='Independent loopback queue; real Viewport mouse press/release over two frames; not physical input',
    cache_seeded=False,engine_sha256=hashlib.sha256(ENGINE.read_bytes()).hexdigest(),posts=posts)
(output/'execution.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
sys.stdout.reconfigure(encoding='utf-8');print(json.dumps({k:v for k,v in result.items() if k!='posts'}));print((LAB/(label+'.log')).read_text(encoding='utf-8',errors='replace')[-2500:])
