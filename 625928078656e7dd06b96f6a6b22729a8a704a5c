"""Check task-only forward/reverse application without the main Git index."""
import difflib,hashlib,json,subprocess,time
from pathlib import Path
p=Path(__file__).resolve().parent;root=p.parents[2]
runtime=[x.relative_to(p/'before').as_posix() for x in (p/'before').rglob('*') if x.is_file() and x.name!='AGENTS.md']
trackers=['AGENTS.md','DEVELOPMENT_STATUS.md']
added=['docs/BIOME_SHADER_PROFILES_2026_11_06.md','game/rendering/biome_shader_profile.gd','game/rendering/biome_shader_profiles.json',
       'game/backend/shader_profile_telemetry.gd','game/tests/test_biome_shader_profiles.gd','game/tests/profile_biome_shader_profiles.gd',
       'backend/bmt_backend/shader_profiles.py','backend/tests/test_shader_profiles.py','backend/bmt_backend/migrations/versions/0074_shader_profile_receipts.py']
added += [x.relative_to(root).as_posix() for x in sorted((root/'native/biome_shader_profiles').iterdir()) if x.is_file()]
added += [x.relative_to(root).as_posix() for x in sorted(p.glob('*.py'))]
added += [(p/x).relative_to(root).as_posix() for x in ['summary.json','engine.patch','engine-source.json','engine-build.json','measured-profiles.json']]
before={};after={};parts=[]
for name in runtime+trackers+added:
    new=(root/name).read_bytes().replace(b'\r\n',b'\n');old=b''
    if name in runtime:old=(p/'before'/name).read_bytes().replace(b'\r\n',b'\n')
    elif name in trackers:
        text=new.decode();start=text.index('<!-- BIOME-SHADER-PROFILES-20261106 -->');end=text.index('<!-- /BIOME-SHADER-PROFILES-20261106 -->')+len('<!-- /BIOME-SHADER-PROFILES-20261106 -->')
        if text[end:end+2]=='\n\n':end+=2
        old=(text[:start]+text[end:]).encode()
    before[name]=old;after[name]=new
    parts.append(f'diff --git a/{name} b/{name}\n')
    if name in added:parts.append('new file mode 100644\n')
    for line in difflib.unified_diff(old.decode().splitlines(True),new.decode().splitlines(True),fromfile='/dev/null' if name in added else 'a/'+name,tofile='b/'+name):
        parts.append(line if line.endswith('\n') else line+'\n\\ No newline at end of file\n')
patch=p/'task.patch';patch.write_bytes(''.join(parts).encode())
owned=root/'build/biome-shader-profiles-20261106'/('checkpoint-'+str(time.time_ns()));owned.mkdir(parents=True)
assert owned.resolve().is_relative_to((root/'build/biome-shader-profiles-20261106').resolve())
for name in runtime+trackers:
    target=owned/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(before[name])
commands=[]
for args in [('--check',),(),('--reverse','--check'),('--reverse',)]:
    cmd=['git','apply','--directory='+owned.relative_to(root).as_posix(),*args,str(patch)]
    result=subprocess.run(cmd,cwd=root,capture_output=True,text=True)
    commands.append({'command':cmd,'exit_code':result.returncode,'output':result.stdout+result.stderr})
    assert result.returncode==0,result.stderr
    if not args:assert all((owned/n).read_bytes().replace(b'\r\n',b'\n')==after[n] for n in after)
assert all((owned/n).read_bytes().replace(b'\r\n',b'\n')==before[n] for n in runtime+trackers)
assert all(not (owned/n).exists() for n in added)
(p/'checkpoint.json').write_text(json.dumps({'files':list(after),'patch_sha256':hashlib.sha256(patch.read_bytes()).hexdigest(),
    'forward_exact':True,'reverse_exact':True,'main_index_written':False,'commands':commands,
    'source_sha256':{n:hashlib.sha256(v).hexdigest() for n,v in after.items()}},indent=2)+'\n')
print('Checked task-only patch:',len(after),'files; main index untouched.')
