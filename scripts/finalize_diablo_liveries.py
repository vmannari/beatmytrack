"""DR04: exact generated assets, native evidence and a private source checkpoint."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'docs/evidence/diablo-liveries-2026-11-15'
ART = ROOT/'game/assets/liveries/diablo_v3'
WORK = ROOT/'build/diablo-livery-checkpoint'

def read(p): return json.loads(p.read_text(encoding='utf-8'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def size(p): return struct.unpack('>II',p.read_bytes()[16:24])
def git(*args,cwd=ROOT,allowed=(0,)):
    r=subprocess.run(['git','-c','core.autocrlf=false',*args],cwd=cwd,capture_output=True)
    assert r.returncode in allowed,r.stderr.decode(errors='replace')
    return r.stdout

catalog=read(ART/'catalog.json')
prompts=read(OUT/'generation-prompts.json')
provenance=read(ART/'provenance.json')
assert len(catalog)==len(prompts)==len(provenance['assets'])==18
assert {p['id'] for p in prompts}=={p['id'] for p in catalog}
assert all(p['portraits'] is False and p['collection_style']=='diablo_rojo' for p in catalog)
art_hashes={}
for p in provenance['assets']:
    source,target=Path(p['source']),ROOT/p['target']
    assert sha(source)==sha(target),'generation output changed: '+p['id']
    assert size(target)==(1536,1024)
    art_hashes[p['target']]=sha(target)
assert len(set(art_hashes.values()))==18
reports={m:read(OUT/m/'report.json') for m in ['headless','gl_compatibility','mobile']}
assert all(r['failures']==0 for r in reports.values())
assert all(len(reports[m]['frames'])==90 and len(reports[m]['stock_frames'])==6 for m in ['gl_compatibility','mobile'])
parsed=re.search(r'PRODUCTION_PARSE (\d+) scripts, 0 failures',(OUT/'parse.log').read_text(encoding='utf-8'))
assert parsed
parse_count=int(parsed[1])
for name in ['livery_finish.gdshader','livery_finish.gdshaderinc']:
    assert (ROOT/'game/vehicle'/name).read_bytes()==(OUT/'before'/name).read_bytes()
image_hashes={}
for mode in ['gl_compatibility','mobile']:
    for frame in reports[mode]['frames']+reports[mode]['stock_frames']:
        p=OUT/mode/frame['file']
        assert size(p)==(1280,900)
        image_hashes[mode+'/'+frame['file']]=sha(p)
assert len(image_hashes)==192
review_inputs=read(OUT/'review-inputs.json')
assert all(sha(ROOT/p)==digest for p,digest in review_inputs.items()),'review input changed before completion'
gallery=read(OUT/'gallery-check.json')
assert gallery['linked_views']==126 and gallery['javascript_syntax'] is True
runtime=['game/vehicle/livery_catalog.gd','game/vehicle/livery_graphics.gd','game/vehicle/premium_livery_finish.gdshaderinc']
new=['game/tests/review_diablo_liveries.gd','scripts/diablo_livery_briefs.json',
     'scripts/import_diablo_liveries.py','scripts/run_diablo_review.py',
     'scripts/present_diablo_liveries.py','scripts/finalize_diablo_liveries.py',
     'docs/evidence/diablo-liveries-2026-11-15/generation-prompts.json']
new += [p.relative_to(ROOT).as_posix() for p in sorted(ART.iterdir()) if p.is_file() and p.suffix!='.png']
new += [p.relative_to(ROOT).as_posix() for p in sorted((OUT/'before').iterdir()) if p.is_file()]
receipt={'date':'2026-11-15','requirements':{
 'DR01':'18 original premium custom-paint designs, three per car, following Panama decorated-schoolbus inspiration.',
 'DR02':'No portraits; scenery, instruments and machinery with sign-painted nicknames, vivid airbrushing and ornamental borders.',
 'DR03':'Per-car bonnet, side, rear and roof charts; dedicated Kart nose/pods and full-body decorative ground.',
 'DR04':'Unchanged original generated assets, actual native five-view/stock review, wash/restoration/cache controls and exact source checkpoint.'},
 'tool':'built-in image_gen','designs':catalog,'asset_sha256':art_hashes,
 'source_sha256':{p:sha(ROOT/p) for p in runtime+new},
 'tests':{m:{k:v for k,v in r.items() if k not in ['frames','stock_frames']} for m,r in reports.items()},
 'production_parser':{'scripts':parse_count,'failures':0},'native_image_sha256':image_hashes,
 'closing_review_inputs':{'count':len(review_inputs),'unchanged':True},'gallery':gallery,
 'limits':['Owner appearance and physical-device acceptance remain.',
           'Fixed-colour art review; no Garage coin listing or paid products, prices, grants, backend or deployment change.',
           'No all-kit, FPS, whole-project or current prepared-cache qualification.',
           'Bus photographs are style references only; source subjects are not reproduced, and photographs are not shipped.',
           'Both previous collections and their 36 IDs remain archived and valid.']}
(OUT/'report.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')

names={'compact':'Rally','kart':'Kart','forklift':'Forklift','electric':'Volt','hovercraft':'Hover','super_rally':'Super Rally'}
table='\n'.join('| '+name+' | '+' / '.join(p['title'] for p in catalog if p['vehicle']==vehicle)+' |' for vehicle,name in names.items())
doc=f'''# Panama custom-paint liveries - 2026-11-15

DR01-DR04 follow the owner's reference to Panama's custom-painted school buses, with the explicit constraint **no portraits**. The current premium review collection is replaced with **18 original mural liveries, three per car**. [Open the native gallery](evidence/diablo-liveries-2026-11-15/collection.html) or [see all 18](evidence/diablo-liveries-2026-11-15/collection.png). Each card includes five native angles, Stock paint and the original Artwork.

| Car | Designs |
| --- | --- |
{table}

Rally carries coastal roads, mountain passes and rainforest scenery. Kart uses flames, street instruments and lightning. Forklift has port infrastructure, furnaces and polished machinery. Volt uses neon cities, moonlight and tropical sunrise. Hover shows Pacific surf, volcanic islands and Caribbean bays. Super Rally uses hot-rod fire, engines and desert storms. Saturated airbrushing, shaded nickname lettering, pinstripes, scallops and bright framed borders give the collection its bus-paint character. All 18 atlases were visually inspected for the portrait exclusion; generation prompts additionally exclude people, faces, animals, masks and skulls. This is original inspired artwork, not a claim of work by Panamanian bus painters.

Reference study used [La Estrella's report and bus-paint photographs](https://www.laestrella.com.pa/vida-y-cultura/diablos-rojos-legado-vivo-del-arte-popular-panameno-GC14252620) and [La Prensa's account of bus painting](https://www.prensa.com/vivir/el-que-no-conoce-un-diablo-rojo-no-es-panameno-29-anos-pintando-la-historia-sobre-ruedas/). Two photographs were passed to generation as **style-only** references, with explicit instructions not to reproduce their portrait/character subjects. Reference URLs and roles are recorded in provenance; the photos remain disposable authoring references under `build/diablo-style-study/` and are not included as game assets.

Each artwork was generated separately using the **built-in image_gen tool**, with [exact prompts](evidence/diablo-liveries-2026-11-15/generation-prompts.json) and [creative briefs](../scripts/diablo_livery_briefs.json). The 18 source PNGs in `game/assets/liveries/diablo_v3/` are unchanged 1536x1024 copies of generated originals. No raster painting, recolouring or retouching followed generation. The six-tile source layout carries bonnet, left, right, front, rear and ornamental ground art. Shader charts fit the source to each vehicle: readable side lettering, upright bonnet nicknames, decorative roof/fender coverage and a narrower dedicated Kart nose. Side height/width vary by car to retain the intended composition. Original paint geometry, glazing, tyres, trim and physical paint finish are retained; weathering remains above the full-RGB art. Printed chrome and candy effects belong to the illustration. These designs use fixed palettes.

Headless **{reports['headless']['checks']}/0**, Compatibility **{reports['gl_compatibility']['checks']}/0**, desktop Mobile **{reports['mobile']['checks']}/0**, production parser **{parse_count}/0**. Each desktop renderer has 90 art views and six matched stock controls: **192 native images**. Checks cover 18 distinct colour-rich textures, portrait-free metadata, three designs per car, vehicle restrictions, old IDs, exact meshes/transforms, original ordinary shader source/program/pixels, dirt, washing, factory restoration, mipmaps and four-texture/four-shader bounds. Native pilot reviews corrected the Kart bonnet crop before final captures. Gallery links and JavaScript syntax were also checked. Logs and command records remain alongside the machine-readable receipt.

```powershell
python scripts/import_diablo_liveries.py
python scripts/run_diablo_review.py headless
python scripts/run_diablo_review.py gl_compatibility
python scripts/run_diablo_review.py mobile
python scripts/run_diablo_review.py parse
# Presentation uses the available Pillow authoring runtime.
python scripts/present_diablo_liveries.py
python scripts/finalize_diablo_liveries.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

Import uses a small art-only native project and lossless mipmapped PNGs, without touching the owner's editor/library. Native reviews use isolated application-data directories and current authored models. Both earlier collections, their 36 IDs and the 48 released coin wraps are retained. This replaces the active art-review catalogue; Garage availability and real-money product integration remain a release step. No prices, purchases, grants, live account changes, backend, export or deployment were performed.

Three runtime files change: `livery_catalog.gd`, `livery_graphics.gd` and the premium-only shader include. Ordinary livery shader/include files are byte-exact. New art assets, import settings, briefs, exact prompts, provenance and import/review/presentation/checkpoint scripts are included. The [receipt](evidence/diablo-liveries-2026-11-15/report.json) fences original art, task source and native frames by hash. `task-source.patch` is a forward/reverse-verified text-source checkpoint; source PNGs are delivered directly and hashed separately to avoid binary duplication. The shared index and concurrent work are preserved. Standard build retention runs without a task pin.

Owner appearance review, physical-device and fitted-kit/gameplay-distance review remain before paid release. There is no phone, FPS, whole-project or prepared-cache readiness claim. No owner save/process changes were made.
'''
doc_path='docs/DIABLO_LIVERIES_2026_11_15.md'
(ROOT/doc_path).write_text(doc,encoding='utf-8')
prefix=f'''<!-- DIABLO-LIVERIES-20261115 -->
## Premium liveries follow Panama custom-bus paint, without portraits (2026-11-15)
DR01-DR04: 18 original mural liveries, three per car, replace the rejected art direction. Airbrushed scenery/instruments/machinery, nickname lettering and vivid ornamental borders use style-only bus references; no portraits. Dedicated side heights/widths, Kart nose/pods and decorative ground fit actual cars. Headless{reports['headless']['checks']}/0, Compatibility{reports['gl_compatibility']['checks']}/0, desktop Mobile{reports['mobile']['checks']}/0 and production parser{parse_count}/0; 180 art views plus12 stock controls. Original ordinary shader/program/pixels, exact geometry, dirt/wash and archived36 IDs retained. [Gallery, prompts, source and limits](docs/DIABLO_LIVERIES_2026_11_15.md). Owner appearance/device/paid-release acceptance remains; no Garage listing, billing, grants, backend/export/deployment or owner-save/process change. Exact text-source checkpoint and standard retention preserve concurrent work/index.
<!-- /DIABLO-LIVERIES-20261115 -->

'''
before_docs={}
for path in ['AGENTS.md','DEVELOPMENT_STATUS.md']:
    data=(ROOT/path).read_bytes()
    # Remove only our own previous entry; concurrent bytes are retained exactly.
    data=re.sub(rb'<!-- DIABLO-LIVERIES-20261115 -->\r?\n.*?<!-- /DIABLO-LIVERIES-20261115 -->\r?\n\r?\n',b'',data,flags=re.S)
    before_docs[path]=data
    (ROOT/path).write_bytes(prefix.encode('utf-8')+data)
index=git('diff','--cached','--binary')
paths=runtime+new+[doc_path,'AGENTS.md','DEVELOPMENT_STATUS.md']
before,after=WORK/'before',WORK/'after'
before.mkdir(parents=True,exist_ok=True);after.mkdir(parents=True,exist_ok=True)
for path in runtime:
    p=before/path;p.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(OUT/'before'/Path(path).name,p)
for path,data in before_docs.items(): (before/path).write_bytes(data)
for path in paths:
    p=after/path;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/path,p)
patch=git('diff','--no-index','--binary','before','after',cwd=WORK,allowed=(0,1))
lines=[]
for line in patch.splitlines(keepends=True):
    if line.startswith((b'diff --git ',b'--- ',b'+++ ')):
        line=line.replace(b'a/before/',b'a/').replace(b'b/after/',b'b/').replace(b'a/after/',b'a/').replace(b'b/before/',b'b/')
    lines.append(line)
patch_path=OUT/'task-source.patch';patch_path.write_bytes(b''.join(lines))
check=WORK/'check'
if check.exists():
    assert check.resolve().parent==WORK.resolve() and check.resolve().is_relative_to((ROOT/'build').resolve())
    shutil.rmtree(check)
shutil.copytree(before,check)
git('init','--quiet',cwd=check)
git('apply','--check',str(patch_path),cwd=check);git('apply',str(patch_path),cwd=check)
assert all((check/path).read_bytes()==(ROOT/path).read_bytes() for path in paths)
git('apply','--reverse','--check',str(patch_path),cwd=check);git('apply','--reverse',str(patch_path),cwd=check)
assert all((check/p.relative_to(before)).read_bytes()==p.read_bytes() for p in before.rglob('*') if p.is_file())
assert git('diff','--cached','--binary')==index
checkpoint={'text_files':len(paths),'png_assets_hashed_separately':18,'patch_sha256':sha(patch_path),
            'forward_exact':True,'reverse_exact':True,'main_index_unchanged':True}
(OUT/'checkpoint.json').write_text(json.dumps(checkpoint,indent=2)+'\n',encoding='utf-8')
print('DIABLO_FINALIZED',json.dumps(checkpoint))
