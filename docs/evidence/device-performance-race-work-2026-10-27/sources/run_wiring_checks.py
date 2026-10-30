import pathlib,os,subprocess,time,json,concurrent.futures,sys
ROOT=pathlib.Path(__file__).resolve().parents[2];TASK=pathlib.Path(__file__).resolve().parent
CASES=[('wiring-cold-compatibility-final','tests/test_garage_cold_opening.gd','gl_compatibility'),('wiring-app-headless-final','tests/test_app.gd','headless')]
def run(case):
 name,script,renderer=case;out=TASK/name;out.mkdir(exist_ok=True);env=os.environ.copy();appdata=out/'appdata';appdata.mkdir(exist_ok=True);env['APPDATA']=str(appdata)
 userdata=appdata/'Circuit01Lab';userdata.mkdir(parents=True,exist_ok=True);(userdata/'backend.cfg').write_text('[backend]\nurl=""\n')
 args=['--headless'] if renderer=='headless' else ['--rendering-method',renderer,'--position','-32000,-32000','--resolution','1280x720','--max-fps','60']
 cmd=[r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64.exe',*args,'--audio-driver','Dummy','--path',str(ROOT/'game'),'--script','res://'+script,'--','--output=res://../build/device-performance-race-fixes-2026-10-27/'+name]
 start=time.monotonic()
 with (out/'stdout.log').open('w',encoding='utf-8') as stdout,(out/'stderr.log').open('w',encoding='utf-8') as stderr:
  p=subprocess.Popen(cmd,env=env,stdout=stdout,stderr=stderr)
  try:code=p.wait(timeout=300)
  except subprocess.TimeoutExpired:p.terminate();p.wait(timeout=10);code=-999
 result={'case':name,'command':cmd,'exit':code,'seconds':time.monotonic()-start};(out/'result.json').write_text(json.dumps(result,indent=2));print(json.dumps(result),flush=True);return result
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
 results=list(pool.map(run,CASES))
sys.exit(0 if all(x['exit']==0 for x in results) else 1)
