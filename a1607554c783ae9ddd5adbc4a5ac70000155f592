"""Serial native controls; stop on failure before promoting any profile."""
from pathlib import Path
import json,subprocess,sys,shutil
p=Path(__file__).resolve().parent;root=p.parents[2]
engine=root/'build/biome-shader-profiles-20261106/godot-4.7.2-stable/bin/godot.windows.template_debug.x86_64.console.exe'
project=Path(json.loads((p/'frozen-project.json').read_text())['project'])
commands=[]
def run(args):
    result=subprocess.run([sys.executable,*map(str,args)],cwd=root,capture_output=True,text=True)
    commands.append({'args':list(map(str,args)),'exit_code':result.returncode,'output':result.stdout+result.stderr})
    (p/'native-matrix.json').write_text(json.dumps(commands,indent=2)+'\n')
    print(result.stdout+result.stderr,flush=True)
    if result.returncode: raise SystemExit(result.returncode)
def check(label,script,*extra,timeout=600):
    run([p/'run_check.py',label,'res://tests/'+script,'--frozen','--engine',engine,'--timeout',timeout,*extra])
check('contracts-engine','test_biome_shader_profiles.gd','--headless',timeout=60)
assert not json.loads((project/'rendering/biome_shader_profiles.json').read_text())['profiles']
check('coverage-observe','profile_biome_shader_profiles.gd','--first-emission')
run([root/'native/biome_shader_profiles/collect_profiles.py',p/'coverage-observe/profiles.json','--output',project/'rendering/biome_shader_profiles.json'])
shutil.copyfile(project/'rendering/biome_shader_profiles.json',p/'measured-profiles.json')
check('coverage-selective','profile_biome_shader_profiles.gd','--first-emission','--require-profiles')
check('missing-controls','profile_biome_shader_profiles.gd','--first-emission','--theme=pine','--require-profiles','--omit-profile-entry','--inject-shader-miss',timeout=240)
