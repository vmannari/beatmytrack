import pathlib,os,subprocess,time,json,hashlib,sys
root=pathlib.Path(__file__).resolve().parents[2];task=pathlib.Path(__file__).resolve().parent;renderer=sys.argv[1] if len(sys.argv)>1 else 'headless';case='accepted-optional-'+renderer;out=task/case;out.mkdir(exist_ok=False)
paths=['game/core/app.gd','game/core/game.gd','game/ui/garage_preloader.gd','game/ui/header_car_appearance_cache.gd','game/backend/menu_snapshot_writer.gd']
def hashes():return {p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in paths}
env=os.environ.copy();env['APPDATA']=str(out/'appdata');pathlib.Path(env['APPDATA']).mkdir()
cmd=[r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe',*(['--headless'] if renderer=='headless' else ['--rendering-method',renderer,'--position','-32000,-32000','--resolution','1280x720']),'--audio-driver','Dummy','--path',str(root/'game'),'--script','res://tests/test_race_optional_work.gd','--','--drive','--report=res://../build/device-performance-race-fixes-2026-10-27/'+case+'/observations.json']
before=hashes();start=time.monotonic()
with (out/'stdout.log').open('w',encoding='utf-8') as stdout,(out/'stderr.log').open('w',encoding='utf-8') as stderr:
 p=subprocess.Popen(cmd,env=env,stdout=stdout,stderr=stderr)
 try:code=p.wait(timeout=300)
 except subprocess.TimeoutExpired:
  subprocess.run(['taskkill','/PID',str(p.pid),'/T','/F'],capture_output=True);code=-999
result={'command':cmd,'exit':code,'seconds':time.monotonic()-start,'before':before,'after':hashes()};(out/'result.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
