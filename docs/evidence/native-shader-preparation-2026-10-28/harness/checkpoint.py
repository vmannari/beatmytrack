from pathlib import Path
import hashlib,json,os,shutil,subprocess

LAB=Path(__file__).resolve().parent;ROOT=LAB.parent.parent
marker='NATIVE-SHADER-PREPARATION-20261028'
block='''
<!-- NATIVE-SHADER-PREPARATION-20261028 -->
## Runtime cold-render plan implementation and native proof (2026-10-28)
NSP01-NSP05/R01/Q01: Owner proceeds with the plan. Separate explicit warming from CanvasItem._draw and require finished setup; exact original16/5 becomes16/0 headless/Compatibility. Rear fitting groups now cooperate and stop on cancellation, preserving exact full/simple arrays: original14/6 becomes14/0 each; largest observed full-car slice50.945/61.512to16.483ms, simple snapshot17.036ms remains. Retained model21/install1598/App141/parser1359/preferred check pass. Evidence-only async/default-aware adapters retain lifecycle400/native geometry28 assertions; deliberate wrong-glass control still fails2. Original raw4/default-headless2, stale-source7, timing/fixture/timeouts and attempts retained. Matching core/forward-compatible context enables192 exact-program imports withzero misses and384 main compiles bypassed; original native picture exact, queued input263/263/max39.341ms. First draws still221-235ms and full compiler162.027MiB exceed frame/96MiB optional gates: no production helper, unsupported hook, engine API or renderer change. Star5.206896s frame is98.264% timed compile/link spans; cache packing5.146ms is not its cause. Three runtime sources/two tests; seven native template derivatives include current concurrent Electric authors and are excluded from the source-only checkpoint. Account/Electric edits and build metadata preserved; no whole-tree release/phone/10-runtime claim. Commands, sources, native images, gates and review checkpoint: docs/NATIVE_SHADER_PREPARATION_2026_10_28.md and docs/evidence/native-shader-preparation-2026-10-28/report.json. Reload/rebuild, native first-draw/workspace/queue and Android acceptance remain. No device attachment query/test, APK/AAB, real auth/purchase, owner-save/live mutation, deployment, owner-process restart or main-index staging/commit/merge.
<!-- /NATIVE-SHADER-PREPARATION-20261028 -->
'''
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md']:
    path=ROOT/name;before=LAB/'metadata-before'/name
    if marker.encode() not in path.read_bytes():
        before.parent.mkdir(parents=True,exist_ok=True);before.write_bytes(path.read_bytes())
        with path.open('ab') as stream:stream.write(block.encode('utf-8'))
    assert before.exists(),'Original metadata snapshot is required'

plan='docs/COLD_RENDER_IMPROVEMENT_PLAN_2026_10_27.md'
addition='Implementation follow-up, 28 October: the [runtime changes and complete native proof](NATIVE_SHADER_PREPARATION_2026_10_28.md) fix callback scheduling and split Compact rear construction. All 192 programs import with matching context flags, but first-draw and memory gates still fail; native production integration remains deferred.\n\n'
before_plan=LAB/'metadata-before'/plan;before_plan.parent.mkdir(parents=True,exist_ok=True)
text=(ROOT/plan).read_text(encoding='utf-8');assert text.count(addition)==1
before_plan.write_text(text.replace(addition,'',1),encoding='utf-8',newline='\n')

checkpoint=LAB/'checkpoint';before=checkpoint/'before';after=checkpoint/'after';verify=checkpoint/'verify'
assert not checkpoint.exists(),'Use a new checkpoint directory; never recursively replace a shared directory'
runtime=['game/ui/garage_preloaded_studio.gd','game/vehicle/compact_detail.gd','game/vehicle/compact_rear_design.gd']
new=['game/tests/test_garage_warm_scheduling.gd','game/tests/test_compact_rear_preparation.gd','docs/NATIVE_SHADER_PREPARATION_2026_10_28.md']
new += [n+'.uid' for n in new[:2] if (ROOT/(n+'.uid')).exists()]
changed=runtime+['AGENTS.md','DEVELOPMENT_STATUS.md',plan]
for name in changed:
    source=LAB/('before' if name in runtime else 'metadata-before')/name
    target=before/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(source.read_bytes())
paths=changed+new+[str(p.relative_to(ROOT)).replace('\\','/') for p in sorted((ROOT/'docs/evidence/native-shader-preparation-2026-10-28').rglob('*')) if p.is_file()]
for name in paths:
    target=after/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((ROOT/name).read_bytes())
env={k:v for k,v in os.environ.items() if k not in ['GIT_DIR','GIT_WORK_TREE','GIT_INDEX_FILE']}
env.update(GIT_CEILING_DIRECTORIES=str(LAB),GIT_CONFIG_NOSYSTEM='1')
diff_command=['git','-c','core.autocrlf=false','diff','--no-index','--binary','--no-renames','before','after']
diff=subprocess.run(diff_command,cwd=checkpoint,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
assert diff.returncode==1,(diff.returncode,diff.stderr)
lines=diff.stdout.splitlines(keepends=True)
for index,line in enumerate(lines):
    if line.startswith((b'diff --git ',b'--- ',b'+++ ',b'Binary files ')):
        for old,new_prefix in [(b'a/before/',b'a/'),(b'a/after/',b'a/'),(b'b/before/',b'b/'),(b'b/after/',b'b/')]:line=line.replace(old,new_prefix)
        lines[index]=line
patch=LAB/'task-only.patch';patch.write_bytes(b''.join(lines))
shutil.copytree(before,verify)
commands=[]
for args in [['apply','--check',str(patch)],['apply',str(patch)]]:
    command=['git','-c','core.autocrlf=false']+args
    result=subprocess.run(command,cwd=verify,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    commands.append(dict(command=command,exit=result.returncode,stdout=result.stdout.decode(errors='replace'),stderr=result.stderr.decode(errors='replace')))
    assert result.returncode==0,commands[-1]
hashes={}
for name in paths:
    wanted=(after/name).read_bytes();actual=(verify/name).read_bytes()
    assert actual==wanted,name
    hashes[name]=hashlib.sha256(wanted).hexdigest()
receipt=dict(kind='source-only; regenerated native resources excluded',commands=commands,verified_files=len(hashes),
    all_after_images_byte_exact=True,patch_sha256=hashlib.sha256(patch.read_bytes()).hexdigest(),patch_bytes=patch.stat().st_size,
    main_repository_index_used=False,after_hashes=hashes)
(LAB/'checkpoint-verification.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in receipt.items() if k not in ['after_hashes','commands']},indent=2))
