from pathlib import Path
import hashlib,json,os,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
ENGINE=Path(r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe')
def snapshot():
    rows=[]
    for base in ('game','backend/bmt_backend','backend/tests','scripts'):
        for p in (ROOT/base).rglob('*'):
            if not p.is_file() or any(x in p.parts for x in ('.godot','android','build','__pycache__')):continue
            if p.suffix not in ('.gd','.py','.po','.pot','.json','.cfg','.godot','.java','.h','.hpp','.ps1'):continue
            data=p.read_bytes();rel=p.relative_to(ROOT)
            dest=OUT/'before'/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
            rows.append({'path':rel.as_posix(),'sha256':hashlib.sha256(data).hexdigest()})
    (OUT/'baseline.json').write_text(json.dumps(rows,indent=2))
    (OUT/'git-status-before.txt').write_bytes(subprocess.check_output(['git','status','--porcelain=v1'],cwd=ROOT))
    print('Snapshot',len(rows),'files')
def run(name,script,extra=(),graphical=False,timeout=180,renderer='gl_compatibility',engine_extra=()):
    sources=[]
    for base in ('game','backend/bmt_backend','native/google_sign_in/src','scripts'):
        for path in sorted((ROOT/base).rglob('*')):
            if not path.is_file() or any(part in path.parts for part in ('.godot','android','__pycache__')):continue
            if path.suffix not in ('.gd','.py','.po','.pot','.java','.json','.cfg','.godot','.ps1','.gdshader'):continue
            sources.append({'path':path.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    (OUT/(name+'.sources.json')).write_text(json.dumps(sources,indent=2),encoding='utf-8')
    env=os.environ.copy();env.update(APPDATA=str(OUT/'profiles'/name),LOCALAPPDATA=str(OUT/'profiles'/name/'local'),BMT_API_URL='',BMT_DEV_AUTH_KEY='',BMT_STORE_EVIDENCE_DIR=str(OUT/'store-captures'),BMT_MENU_FIX_OUTPUT=str(OUT/'retention'/name),BMT_RACE_MENU_LABEL_OUTPUT=str(OUT/'pause'/name),PYTHONDONTWRITEBYTECODE='1')
    Path(env['APPDATA']).mkdir(parents=True,exist_ok=True)
    args=[str(ENGINE),*engine_extra]+(['--rendering-method',renderer,'--audio-driver','Dummy','--position','10000,10000'] if graphical else ['--headless'])+['--path',str(ROOT/'game'),'--script',script]+(['--',*extra] if extra else [])
    begin=time.monotonic()
    with (OUT/(name+'.log')).open('w',encoding='utf-8') as log:
        try:code=subprocess.run(args,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=timeout).returncode
        except subprocess.TimeoutExpired:code='timeout'
    result={'command':args,'exit_code':code,'seconds':round(time.monotonic()-begin,3)}
    (OUT/(name+'.json')).write_text(json.dumps(result,indent=2));print(name,result,flush=True)
if __name__=='__main__':snapshot()
