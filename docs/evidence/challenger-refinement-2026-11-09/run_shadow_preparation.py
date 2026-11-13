from pathlib import Path
import hashlib,json,subprocess,time
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
source=Path(r'C:\Users\ville\Downloads\Dodge Challenger HellCat - Rigged.blend')
script=ROOT/'scripts/prepare_challenger.py'
labels=ROOT/'docs/evidence/challenger-hellcat-2026-11-09/components.npz'
destination=ROOT/'build/challenger-refinement-2026-11-09/converted-shadow-clean'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
before={str(p):sha(p) for p in [source,script,labels]}
command=[str(ROOT/'build/tools/blender-4.5.15-windows-x64/blender.exe'),'--background','--factory-startup','--disable-autoexec','--python',str(script),'--',str(source),str(labels),str(destination)]
started=time.monotonic()
with (OUT/'preparation-shadow.log').open('w',encoding='utf-8') as log:
    result=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=300)
after={p:sha(Path(p)) for p in before}
receipt={'command':command,'exit_code':result.returncode,'elapsed_seconds':time.monotonic()-started,'before':before,'after':after,'stable':before==after}
if result.returncode==0:
    receipt['outputs']={p.name:sha(p) for p in destination.glob('*')}
(OUT/'preparation-shadow-command.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
assert result.returncode==0 and before==after
print('CHALLENGER_PREPARATION: exact source, labels and script; both final tiers written')
