from pathlib import Path
import os, subprocess, sys
root=Path.cwd().resolve()
assert (root/'game/project.godot').is_file()
name, renderer, script = sys.argv[1:4]
profile=root/'build/kart-kit-paint'/name
profile.mkdir(parents=True,exist_ok=True)
env=os.environ.copy()
for key,folder in [('APPDATA','appdata'),('LOCALAPPDATA','localappdata')]:
    p=profile/folder; p.mkdir(exist_ok=True); env[key]=str(p)
env['BMT_API_URL']=''
args=['C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe','--path',str(root/'game')]
args += ['--headless'] if renderer=='headless' else ['--rendering-method',renderer]
args += ['--script',script,'--','--evidence-root='+str(root/'docs/evidence/kart-kit-paint-2026-11-17'/name)]
result=subprocess.run(args,cwd=root,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=300)
out=root/'docs/evidence/kart-kit-paint-2026-11-17'
(out/(name+'.log')).write_bytes(result.stdout)
print(result.stdout.decode(errors='replace')[-5000:])
print('EXIT',result.returncode)
sys.exit(result.returncode)
