from pathlib import Path
import hashlib,json,subprocess,time
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
source=Path(r'C:\Users\ville\Downloads\Dodge Challenger HellCat - Rigged.blend')
original_source=source
source=source if source.is_file() else ROOT/'art_sources/challenger_hellcat_v1/source-panels.npz'
script=ROOT/'scripts/prepare_challenger.py'
labels=ROOT/'art_sources/challenger_hellcat_v1/components.npz'
destination=ROOT/'build/challenger-reference-form-2026-11-15/converted'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
inputs=[source,script,labels,ROOT/'scripts/challenger_detail_geometry.py',ROOT/'scripts/challenger_panel_geometry.py',ROOT/'scripts/challenger_reference_geometry.py',ROOT/'scripts/challenger_shell_geometry.py',ROOT/'scripts/challenger_clean_panels.py',ROOT/'scripts/challenger_exterior_geometry.py']
if source.suffix=='.npz':inputs.append(source.with_name('source-facts.json'))
before={str(p):sha(p) for p in inputs}
before[str(ROOT/'scripts/challenger_side_surface.py')]=sha(ROOT/'scripts/challenger_side_surface.py')
before[str(ROOT/'scripts/challenger_reference_form.py')]=sha(ROOT/'scripts/challenger_reference_form.py')
command=[str(ROOT/'build/tools/blender-4.5.15-windows-x64/blender.exe'),'--background','--factory-startup','--disable-autoexec','--python-exit-code','1','--python',str(script),'--',str(source),str(labels),str(destination),"--debug-cache"]
started=time.monotonic()
with (OUT/'preparation-qualified.log').open('w',encoding='utf-8') as log:
    result=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=420)
after={p:sha(Path(p)) for p in before}
receipt={'command':command,'exit_code':result.returncode,'elapsed_seconds':time.monotonic()-started,'before':before,'after':after,'stable':before==after,'original_download_available':original_source.is_file()}
if result.returncode==0:
    receipt['outputs']={p.name:sha(p) for p in destination.glob('*')}
(OUT/'preparation-command.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
assert result.returncode==0 and before==after
log=(OUT/'preparation-qualified.log').read_text(encoding='utf-8')
assert 'Traceback (most recent call last)' not in log and log.count('CHALLENGER_EXPORT')==2 and 'CHALLENGER_PREPARED' in log
assert all((destination/name).stat().st_mtime>time.time()-(time.monotonic()-started)-2 for name in ['full.glb','simple.glb','manifest.json','hood_profile.json']), 'Every output must come from this run'
print('CHALLENGER_PREPARATION: exact source, labels and script; both final tiers written')

