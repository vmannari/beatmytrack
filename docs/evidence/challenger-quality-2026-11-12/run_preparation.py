from pathlib import Path
import hashlib,json,subprocess,time
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
source=Path(r'C:\Users\ville\Downloads\Dodge Challenger HellCat - Rigged.blend')
script=ROOT/'scripts/prepare_challenger.py'
labels=ROOT/'docs/evidence/challenger-hellcat-2026-11-09/components.npz'
destination=ROOT/'build/challenger-quality-2026-11-12/converted-final'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
before={str(p):sha(p) for p in [source,script,labels,ROOT/'scripts/challenger_detail_geometry.py']}
command=[str(ROOT/'build/tools/blender-4.5.15-windows-x64/blender.exe'),'--background','--factory-startup','--disable-autoexec','--python-exit-code','1','--python',str(script),'--',str(source),str(labels),str(destination)]
started=time.monotonic()
with (OUT/'preparation-qualified.log').open('w',encoding='utf-8') as log:
    result=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=300)
after={p:sha(Path(p)) for p in before}
receipt={'command':command,'exit_code':result.returncode,'elapsed_seconds':time.monotonic()-started,'before':before,'after':after,'stable':before==after}
if result.returncode==0:
    receipt['outputs']={p.name:sha(p) for p in destination.glob('*')}
(OUT/'preparation-command.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
assert result.returncode==0 and before==after
log=(OUT/'preparation-qualified.log').read_text(encoding='utf-8')
assert 'Traceback (most recent call last)' not in log and log.count('CHALLENGER_EXPORT')==2 and 'CHALLENGER_PREPARED' in log
assert all((destination/name).stat().st_mtime>time.time()-(time.monotonic()-started)-2 for name in ['full.glb','simple.glb','manifest.json']), 'Every output must come from this run'
print('CHALLENGER_PREPARATION: exact source, labels and script; both final tiers written')
