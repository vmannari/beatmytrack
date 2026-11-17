"""Refresh official preview identity after image imports, keeping model keys exact."""
from pathlib import Path
import json,subprocess
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent;ASSETS=ROOT/'build'/OUT.name/'assets'
before=json.loads((ASSETS/'client-build-identity.json').read_text(encoding='utf-8-sig'))
command=['powershell','-NoProfile','-ExecutionPolicy','Bypass','-Command',". ./scripts/build_identity.ps1; Write-ClientBuildIdentity (Get-Location).Path 'build/"+OUT.name+"/assets'"]
subprocess.run(command,cwd=ROOT,check=True)
after=json.loads((ASSETS/'client-build-identity.json').read_text(encoding='utf-8-sig'))
assert before['modular_car_sha256']==after['modular_car_sha256'],'Import metadata changed a prepared model key; real rebake required'
(OUT/'post-import-identity.json').write_text(json.dumps({'command':command,'model_keys_exact':True,'header_before':before['header_preview_sha256'],'header_after':after['header_preview_sha256'],'garage_before':before['garage_preview_sha256'],'garage_after':after['garage_preview_sha256'],'real_portrait_render_follows':True},indent=2))
