from pathlib import Path
import hashlib,json,shutil,subprocess

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
SCRATCH=ROOT/'build/collision-onset-audit'
paths=['DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md','docs/COLLISION_ONSET_AUDIT.md',
       'scripts/review_collision_onset.py','game/tests/test_collision_source_onset.gd',
       'game/tests/test_collision_source_onset.gd.uid']
before=SCRATCH/'before';after=SCRATCH/'after'
before.mkdir(parents=True,exist_ok=True);after.mkdir(parents=True,exist_ok=True)
rows=[]
for relative in paths:
    source=ROOT/relative;prior=OUT/'before'/relative
    target=after/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
    if prior.exists():
        target=before/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(prior,target)
    rows.append(dict(file=relative,sha256=hashlib.sha256(source.read_bytes()).hexdigest(),before_sha256=hashlib.sha256(prior.read_bytes()).hexdigest() if prior.exists() else None))
diff=subprocess.run(['git','diff','--no-index','--binary','--','build/collision-onset-audit/before','build/collision-onset-audit/after'],cwd=ROOT,capture_output=True)
assert diff.returncode==1,diff.stderr.decode()
patch=diff.stdout
for stage in ['before','after']:
    patch=patch.replace(('a/build/collision-onset-audit/'+stage+'/').encode(),b'a/').replace(('b/build/collision-onset-audit/'+stage+'/').encode(),b'b/')
(OUT/'scoped-change.patch').write_bytes(patch)
check=subprocess.run(['git','apply','--reverse','--check',str(OUT/'scoped-change.patch')],cwd=ROOT,capture_output=True)
(OUT/'patch-check.txt').write_text('reverse_check_exit='+str(check.returncode)+'\n'+check.stderr.decode(errors='replace'),encoding='utf-8')
assert check.returncode==0,check.stderr.decode()
(OUT/'source-hashes.json').write_text(json.dumps(rows,indent=2)+'\n',encoding='utf-8')
bank=ROOT/'game/assets/audio/vehicles'
manifest=json.loads((bank/'manifest.json').read_text())
for row in manifest['outputs']:
    assert hashlib.sha256((bank/row['file']).read_bytes()).hexdigest()==row['sha256'],row['file']
report=dict(scoped_files=len(paths),reverse_check=0,unchanged_bank_masters=len(manifest['outputs']),runtime_audio_changed=False)
(OUT/'checkpoint-review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
