from pathlib import Path
import subprocess,os,json,time,shutil
R=next(p for p in Path(__file__).resolve().parents if (p/'godot-version.txt').exists())
E=Path(__file__).resolve().parent/'preferred-final';E.mkdir(exist_ok=True)
env=os.environ.copy();env['APPDATA']=str(R/'build/garage-first-entry-user/preferred-final');env['BMT_API_URL']=''
Path(env['APPDATA']).mkdir(parents=True,exist_ok=True)
cmd=['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(R/'scripts/dev.ps1'),'-Action','CheckScript','-ScriptPath','res://core/app.gd','-GodotPath',r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe','-CommandTimeoutSeconds','120']
t=time.monotonic()
with (E/'run.log').open('wb') as log:
 p=subprocess.Popen(cmd,cwd=R,env=env,stdout=log,stderr=subprocess.STDOUT)
 (E/'process.json').write_text(json.dumps({'pid':p.pid,'command':cmd},indent=2))
 try:code=p.wait(timeout=180)
 except subprocess.TimeoutExpired:p.kill();code=124
source=R/'build/logs'/('CheckScript-'+str(p.pid))
if source.exists():
 for f in source.iterdir():
  if f.is_file():shutil.copyfile(f,E/f.name)
record={'command':cmd,'exit_code':code,'seconds':time.monotonic()-t,'environment':{'APPDATA':env['APPDATA'],'BMT_API_URL':''},'log_source':str(source)}
(E/'command.json').write_text(json.dumps(record,indent=2))
print(json.dumps(record));print((E/'run.log').read_text(errors='replace')[-1200:])
raise SystemExit(code)
