from pathlib import Path
import hashlib,json,re,shutil,subprocess
ROOT=Path.cwd(); WORK=ROOT/'build/runtime-stall-investigation-2026-10-26'; OUT=ROOT/'docs/evidence/runtime-stalls-2026-10-26'
review=WORK/('review-'+str(len(list(WORK.glob('review-*')))+1)); review.mkdir()
existing=['AGENTS.md','DEVELOPMENT_STATUS.md','docs/RUNTIME_MEMORY_CORRECTNESS_FIXES_2026_10_26.md']
baseline={}
for path in existing:
    now=(ROOT/path).read_bytes()
    if path.endswith('RUNTIME_MEMORY_CORRECTNESS_FIXES_2026_10_26.md'):
        own=b'\nStall follow-up: [measured causes and diagnostic prototypes](RUNTIME_STALL_INVESTIGATION_2026_10_26.md). This later investigation does not ship further runtime changes or close the remaining performance targets.\n'
        assert now.count(own)==1
        baseline[path]=now.replace(own,b'',1)
    else:
        pattern=rb'<!-- RUNTIME-STALL-INVESTIGATION-20261026 -->.*?<!-- /RUNTIME-STALL-INVESTIGATION-20261026 -->\r?\n\r?\n'
        baseline[path],count=re.subn(pattern,b'',now,flags=re.S); assert count==1,path
new=['docs/RUNTIME_STALL_INVESTIGATION_2026_10_26.md']
for path in sorted(OUT.rglob('*')):
    if path.is_file() and path.name not in ['checkpoint.patch','source-manifest.json','checkpoint-validation.json']:
        new.append(str(path.relative_to(ROOT)).replace('\\','/'))
subprocess.run(['git','init','--quiet',str(review)],check=True)
subprocess.run(['git','-C',str(review),'config','core.autocrlf','false'],check=True)
subprocess.run(['git','-C',str(review),'config','core.whitespace','cr-at-eol'],check=True)
# Preserve raw snapshots/logs as byte-exact evidence; review active probes as text.
(review/'.git/info/attributes').write_text('docs/evidence/runtime-stalls-2026-10-26/before/** -diff\ndocs/evidence/runtime-stalls-2026-10-26/dependencies/** -diff\ndocs/evidence/runtime-stalls-2026-10-26/logs/** -diff\ndocs/evidence/runtime-stalls-2026-10-26/*/trace.json -diff\ndocs/evidence/runtime-stalls-2026-10-26/timeline.perfetto.json -diff\n',encoding='utf-8')
for path,data in baseline.items():
    target=review/path; target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(data)
subprocess.run(['git','-C',str(review),'add','.'],check=True)
for path in existing+new:
    target=review/path; target.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(ROOT/path,target)
subprocess.run(['git','-C',str(review),'add','-N','--',*new],check=True)
subprocess.run(['git','-C',str(review),'diff','--check'],check=True)
patch=subprocess.check_output(['git','-C',str(review),'diff','--binary','--no-ext-diff','--no-color'])
(OUT/'checkpoint.patch').write_bytes(patch)
for flags in [['--reverse','--check'],['--reverse']]: subprocess.run(['git','-C',str(review),'apply',*flags,str(OUT/'checkpoint.patch')],check=True)
for path,data in baseline.items(): assert (review/path).read_bytes()==data,path
for flags in [['--check'],[]]: subprocess.run(['git','-C',str(review),'apply',*flags,str(OUT/'checkpoint.patch')],check=True)
manifest=[]
for path in existing+new:
    data=(ROOT/path).read_bytes(); assert (review/path).read_bytes()==data,path
    manifest.append({'path':path,'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)})
(OUT/'source-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
validation={'path':'checkpoint.patch','sha256':hashlib.sha256(patch).hexdigest(),'files':len(manifest),'bytes':len(patch),'checks':'Isolated Git diff --check, apply/reverse checks and exact byte round-trip; no root staging or production source changes'}
(OUT/'checkpoint-validation.json').write_text(json.dumps(validation,indent=2)+'\n',encoding='utf-8')
print('Verified task-only checkpoint:',len(manifest),'files,',len(patch),'bytes; root index untouched.')
