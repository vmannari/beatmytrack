from pathlib import Path
import json,subprocess,sys
p=Path(__file__).resolve().parent;root=p.parents[2]
engine=root/'build/biome-shader-profiles-20261106/godot-4.7.2-stable/bin/godot.windows.template_debug.x86_64.console.exe'
subprocess.run([sys.executable,str(p/'sync_fixture.py')],check=True)
rows=[]
for label,script,extra in [
 ('contracts-final-engine','test_biome_shader_profiles.gd',['--headless']),
 ('pine-full-final','profile_biome_shader_profiles.gd',['--first-emission','--theme=pine','--observe-only']),
 ('pine-selective-final','profile_biome_shader_profiles.gd',['--first-emission','--theme=pine','--require-profiles'])]:
    profile=root/'build/biome-shader-profiles-20261106'/label
    assert not profile.exists(), 'Use a fresh private profile for a valid first-entry comparison'
    command=[sys.executable,str(p/'run_check.py'),label,'res://tests/'+script,'--frozen','--engine',str(engine),'--timeout','240',*extra]
    result=subprocess.run(command,cwd=root,capture_output=True,text=True)
    rows.append({'command':command,'exit_code':result.returncode,'output':result.stdout+result.stderr,'profile_was_absent':True})
    (p/'final-checks.json').write_text(json.dumps(rows,indent=2)+'\n')
    print(result.stdout+result.stderr,flush=True)
    if result.returncode:raise SystemExit(result.returncode)
