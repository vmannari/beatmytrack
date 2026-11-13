import hashlib,json,os,subprocess
from pathlib import Path
OUT=Path(__file__).resolve().parent;ROOT=OUT/'snapshot'
record=json.loads((OUT/'export-result.json').read_text());assert record['exit_code']==0
assert set(record['source_changes'])<={'game/core/build_identity.gd','game/project.godot'},record['source_changes']
apk=Path(record['apk']['path']);assert hashlib.sha256(apk.read_bytes()).hexdigest()==record['apk']['sha256']
env={**os.environ,'GIT_OPTIONAL_LOCKS':'0','GIT_CONFIG_COUNT':'1','GIT_CONFIG_KEY_0':'safe.directory','GIT_CONFIG_VALUE_0':ROOT.as_posix()}
command=['powershell','-NoProfile','-ExecutionPolicy','Bypass','-Command',". ./scripts/build_identity.ps1; Write-ClientBuildIdentity (Get-Location).Path 'build/identity-confirm'"]
with (OUT/'identity-confirm.log').open('w',encoding='utf-8') as log:
 result=subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=180)
assert result.returncode==0
identity=json.loads((ROOT/'build/identity-confirm/client-build-identity.json').read_text(encoding='utf-8-sig'))
receipt={'exported_build':record['build_id'],'recomputed_build':identity['build_id'],'equal':record['build_id']==identity['build_id'],'source_changes':record['source_changes']}
(OUT/'identity-confirm.json').write_text(json.dumps(receipt,indent=2)+'\n')
assert receipt['equal'],receipt
print('Export source audit and settled-index build identity match:',record['build_id'])
