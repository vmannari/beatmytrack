"""PL04: source/evidence receipt and a private forward/reverse Git checkpoint."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/evidence/premium-liveries-2026-11-15'
WORK=ROOT/'build/premium-livery-checkpoint'
CATALOG=json.loads((ROOT/'game/assets/liveries/premium_v1/catalog.json').read_text())

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def git(*args,cwd=ROOT,allowed=(0,)):
    p=subprocess.run(['git','-c','core.autocrlf=false',*args],cwd=cwd,capture_output=True)
    assert p.returncode in allowed,p.stderr.decode(errors='replace')
    return p.stdout

reports={mode:json.loads((OUT/mode/'report.json').read_text()) for mode in ['headless','gl_compatibility','mobile']}
assert all(r['failures']==0 for r in reports.values()),'complete final render checks before packaging'
assert all(len(reports[m]['frames'])==90 for m in ['gl_compatibility','mobile'])
assert 'PRODUCTION_PARSE 580 scripts, 0 failures' in (OUT/'parse.log').read_text()
original_files=['livery_finish.gdshader','livery_finish.gdshaderinc']
for name in original_files:
    assert (ROOT/'game/vehicle'/name).read_bytes()==(OUT/'before'/name).read_bytes()
    assert (ROOT/'game/vehicle'/name).read_bytes()==git('show','HEAD:game/vehicle/'+name)
frames={}
for mode in ['gl_compatibility','mobile']:
    for frame in reports[mode]['frames']:
        p=OUT/mode/frame['file']
        assert p.exists()
        frames[mode+'/'+frame['file']]=sha(p)
supplements={str(p.relative_to(OUT)):json.loads(p.read_text()) for p in OUT.glob('*/report-*.json')}
assert all(r['failures']==0 for r in supplements.values())

runtime=['game/vehicle/livery_catalog.gd','game/vehicle/livery_graphics.gd','game/vehicle/vehicle_livery.gd']
new_sources=['game/vehicle/premium_livery_finish.gdshaderinc','game/tests/review_premium_liveries.gd',
             'scripts/build_premium_liveries.py','scripts/import_premium_liveries.py','scripts/present_premium_liveries.py',
             'scripts/run_premium_livery_review.py','scripts/finalize_premium_liveries.py']
new_sources += [str(p.relative_to(ROOT)).replace('\\','/') for p in sorted((ROOT/'game/assets/liveries/premium_v1').iterdir()) if p.is_file()]
new_sources += [str(p.relative_to(ROOT)).replace('\\','/') for p in sorted((OUT/'before').iterdir()) if p.is_file()]
source_hashes={p:sha(ROOT/p) for p in runtime+new_sources}
index_before=git('diff','--cached','--binary')

receipt={
 'date':'2026-11-15','requirements':{
 'PL01':'Three bespoke designs for each of the six current cars; all 18 masks differ.',
 'PL02':'Five independently authored panels, original fictional insignia and outlined Barlow lettering.',
 'PL03':'Car ownership restrictions, mipmaps, four-mask cache, four shader families, original geometry and wash behavior.',
 'PL04':'Native five-view collection, both desktop renderers, explicit review-only commerce boundary and source checkpoint.'},
 'designs':CATALOG,'tests':{k:{key:value for key,value in v.items() if key!='frames'} for k,v in reports.items()},
 'supplementary_checks':supplements,'production_parse':{'scripts':580,'failures':0},
 'original_shader_files_byte_exact':original_files,'source_sha256':source_hashes,'native_view_sha256':frames,
 'limits':['Art review collection; premium designs are not added to the released coin menu or server allowlist.',
           'No real-money products, price, billing, grants, account changes or deployment.',
           'No physical-device test, export, FPS claim, current prepared-cache requalification or whole-project acceptance.',
           'Existing broad parser fixture signature errors are retained in rejected/broad-parser.log.',
           'Owner appearance acceptance is required before treating the collection as sale-ready.',
           'Paint materials are inherited from the cars; finish names are art direction, not foil or new material simulation.']}
(OUT/'report.json').write_text(json.dumps(receipt,indent=2)+'\n')

table='\n'.join('| '+name+' | '+' / '.join(d['title'] for d in CATALOG if d['vehicle']==vehicle)+' |' for vehicle,name in
 [('compact','Rally'),('kart','Kart'),('forklift','Forklift'),('electric','Volt'),('hovercraft','Hover'),('super_rally','Super Rally')])
doc=f'''# Premium livery Collection 01 — 2026-11-15

PL01–PL04 deliver 18 original designs, three for every current car. [Open the interactive native-render gallery](evidence/premium-liveries-2026-11-15/collection.html) or [view the collection sheet](evidence/premium-liveries-2026-11-15/collection.png).

| Car | Designs |
| --- | --- |
{table}

Each identity has individually composed top, left, right, front and rear artwork. Opposite-side shapes mirror while the lettering stays readable; bonnet lettering faces the nose. Original insignia, race numbers, route/contour linework and industrial graphics are outlined vector paths. Barlow Condensed SemiBold comes from the repository's OFL font assets. The masks use the original three editable paint roles. They are individually authored compositions, with no raster generations, outside logos or downloaded reference artwork.

This is an art review collection. It is deliberately separate from the 48 released coin wraps and their unchanged menu and backend allowlist. There are no premium prices, product IDs, purchases or grants. Future real-money release still needs the chosen products, server entitlement integration and owner approval of the designs. The current Garage menu does not list these review designs; the gallery and native review runner are their review surfaces.

The new panel shader is selected only for this collection, including live weathering. It preserves mesh frames, paint and the complete wash state across shader changes. Both original clean shader files remain byte-exact against task-start evidence and Git. Released paint binds the original GPU program. Premium masks are 1536×1024, lossless, mipmapped and held in the existing four-mask cache. Four shared clean/toon/weathering shader families are the tested bound. No meshes, model geometry or additional drawing passes are added. Finish names describe colour/material direction; existing paint materials supply the actual finish.

Final checks: headless **{reports['headless']['checks']}/0**; native Compatibility **{reports['gl_compatibility']['checks']}/0** and desktop Mobile **{reports['mobile']['checks']}/0**, 90 views each; production parser **580/0**. The native review checks source identity, stable original-program pixel comparisons, exact mesh/transform preservation, valid per-car appearances, car restrictions, mipmaps, distinct/covered masks, dirt, washing and factory restoration. Supplementary final placement checks, when present, are recorded in the JSON report. The gallery's JavaScript passes Node's syntax check. This is a desktop art review, with no physical-device, performance, export or full prepared-cache acceptance claim.

Actual commands included:

```powershell
# Authoring Python: fontTools available via PYTHONPATH=build/premium-livery-authoring-lib
python scripts/build_premium_liveries.py
python scripts/import_premium_liveries.py
python scripts/run_premium_livery_review.py headless
python scripts/run_premium_livery_review.py gl_compatibility
python scripts/run_premium_livery_review.py mobile
python scripts/run_premium_livery_review.py parse
# Presentation uses the available Pillow authoring runtime.
python scripts/present_premium_liveries.py
python scripts/finalize_premium_liveries.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

The initial dev Import command hit a locked editor hot-reload DLL. The successful replacement uses a small art-only import project and copies only its 18 native texture outputs. No owner process or library was changed. Early nested SVG panels rasterized incorrectly, and one design's detail coverage failed; translated clipped groups and stronger detail artwork corrected these without lowering gates. A driver comparison made from separately recompiled inlined shader text retained 1-LSB differences; final controls retain the original program identity, exact sources and pixel gate. The first Mobile reference also caught cold environment settling; the final comparison explicitly requires a stable repeated reference first. The broad parser retains unrelated historic fixture signature mismatches, while the unchanged production parser passes. Relevant rejected logs and one failed-art capture remain under `rejected/`.

Changed sources are the three livery catalogue/binding/validation files, one premium shader include, the 18 SVG masks/import settings plus catalogue/notice, native review script and five authoring/import/review/presentation/checkpoint scripts. [The machine-readable receipt](evidence/premium-liveries-2026-11-15/report.json) enumerates every source and native-view hash. `task-source.patch` is a source-only private Git checkpoint verified forward and reverse; no main-index staging or commit is performed. The dev wrapper's generated build identity is excluded. Concurrent workspace work is preserved.

Standard build retention ran; recent/protected/locked output keeps the shared build above its 20 GiB target, with no task pin. Owner visual acceptance and phone rendering/input/memory acceptance remain. No owner-save mutation, real purchase, live request, backend change or deployment was performed.
'''
doc_path='docs/PREMIUM_LIVERY_COLLECTION_2026_11_15.md'
(ROOT/doc_path).write_text(doc,encoding='utf-8')

prefix=f'''<!-- PREMIUM-LIVERY-COLLECTION-20261115 -->
## Eighteen car-specific premium livery designs for review (2026-11-15)
PL01–PL04: three individually composed five-panel vector liveries per current car, original insignia/outlined Barlow lettering and a native five-view gallery. Car restrictions, four-mask/four-shader bounds, exact meshes, dirt/wash and original program/source/pixel controls pass: headless{reports['headless']['checks']}/0, Compatibility{reports['gl_compatibility']['checks']}/0, desktop Mobile{reports['mobile']['checks']}/0; 180 views, production parser580/0. Review collection stays outside the released coin menu/server allowlist; no prices, billing, grants or deployment. [Collection, commands and limits](docs/PREMIUM_LIVERY_COLLECTION_2026_11_15.md). Owner quality and physical-device acceptance remain; existing full-parser fixture failures retained. Original shader files exact, scoped checkpoint and standard retention; concurrent work/index preserved.
<!-- /PREMIUM-LIVERY-COLLECTION-20261115 -->

'''
doc_baselines={}
for path in ['AGENTS.md','DEVELOPMENT_STATUS.md']:
    p=ROOT/path
    doc_baselines[path]=p.read_bytes()
    marker=b'<!-- PREMIUM-LIVERY-COLLECTION-20261115 -->'
    end_marker=b'<!-- /PREMIUM-LIVERY-COLLECTION-20261115 -->\n\n'
    if marker in doc_baselines[path]:
        start=doc_baselines[path].index(marker)
        end=doc_baselines[path].index(end_marker,start)+len(end_marker)
        doc_baselines[path]=doc_baselines[path][:start]+doc_baselines[path][end:]
    p.write_bytes(prefix.encode('utf-8')+doc_baselines[path])

all_sources=runtime+new_sources+[doc_path,'AGENTS.md','DEVELOPMENT_STATUS.md']
before,after=WORK/'before',WORK/'after'
before.mkdir(parents=True,exist_ok=True);after.mkdir(parents=True,exist_ok=True)
for path in runtime:
    p=before/path;p.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(OUT/'before'/Path(path).name,p)
for path,data in doc_baselines.items(): (before/path).write_bytes(data)
for path in all_sources:
    p=after/path;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/path,p)
patch=git('diff','--no-index','--binary','before','after',cwd=WORK,allowed=(0,1))
lines=[]
for line in patch.splitlines(keepends=True):
    if line.startswith((b'diff --git ',b'--- ',b'+++ ')):
        line=line.replace(b'a/before/',b'a/').replace(b'b/after/',b'b/').replace(b'a/after/',b'a/').replace(b'b/before/',b'b/')
    lines.append(line)
patch=b''.join(lines)
patch_path=OUT/'task-source.patch';patch_path.write_bytes(patch)
check=WORK/'check'
if check.exists():
    assert check.resolve().parent==WORK.resolve() and check.resolve().is_relative_to((ROOT/'build').resolve())
    shutil.rmtree(check)
shutil.copytree(before,check)
git('init','--quiet',cwd=check)
git('apply','--check',str(patch_path),cwd=check)
git('apply',str(patch_path),cwd=check)
assert all((check/path).read_bytes()==(ROOT/path).read_bytes() for path in all_sources)
git('apply','--reverse','--check',str(patch_path),cwd=check)
git('apply','--reverse',str(patch_path),cwd=check)
assert all((check/p.relative_to(before)).read_bytes()==p.read_bytes() for p in before.rglob('*') if p.is_file())
assert git('diff','--cached','--binary')==index_before
checkpoint={'files':len(all_sources),'patch_sha256':sha(patch_path),'forward_exact':True,'reverse_exact':True,'main_index_unchanged':True}
(OUT/'checkpoint.json').write_text(json.dumps(checkpoint,indent=2)+'\n')
print('PREMIUM_FINALIZED',json.dumps(checkpoint))
