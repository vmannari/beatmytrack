"""AL04: exact art provenance, native evidence and private text-source checkpoint."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/evidence/artistic-liveries-2026-11-15'
WORK=ROOT/'build/artistic-livery-checkpoint'
ART=ROOT/'game/assets/liveries/artistic_v2'

def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def git(*args,cwd=ROOT,allowed=(0,)):
    result=subprocess.run(['git','-c','core.autocrlf=false',*args],cwd=cwd,capture_output=True)
    assert result.returncode in allowed,result.stderr.decode(errors='replace')
    return result.stdout

catalog=read(ART/'catalog.json')
prompts=read(OUT/'generation-prompts.json')
provenance=read(ART/'provenance.json')
assert len(catalog)==18 and len(prompts)==18 and len(provenance['assets'])==18
assert {p['id'] for p in prompts}=={p['id'] for p in catalog}
art_hashes={}
for p in provenance['assets']:
    source,target=Path(p['source']),ROOT/p['target']
    assert sha(source)==sha(target),'generation output changed: '+p['id']
    art_hashes[p['target']]=sha(target)
assert len(set(art_hashes.values()))==18
reports={m:read(OUT/m/'report.json') for m in ['headless','gl_compatibility','mobile']}
assert all(r['failures']==0 for r in reports.values())
assert all(len(reports[m]['frames'])==90 and len(reports[m]['stock_frames'])==6 for m in ['gl_compatibility','mobile'])
parser=(OUT/'parse.log').read_text(encoding='utf-8')
parsed=re.search(r'PRODUCTION_PARSE (\d+) scripts, 0 failures',parser)
assert parsed
parse_count=int(parsed[1])
for name in ['livery_finish.gdshader','livery_finish.gdshaderinc']:
    assert (ROOT/'game/vehicle'/name).read_bytes()==(OUT/'before'/name).read_bytes()
image_hashes={}
for mode in ['gl_compatibility','mobile']:
    for frame in reports[mode]['frames']+reports[mode]['stock_frames']:
        p=OUT/mode/frame['file']
        image_hashes[mode+'/'+frame['file']]=sha(p)
assert len(image_hashes)==192

runtime=['game/vehicle/livery_catalog.gd','game/vehicle/livery_graphics.gd','game/vehicle/premium_livery_finish.gdshaderinc']
new=['game/tests/review_artistic_liveries.gd','scripts/artistic_livery_briefs.json',
     'scripts/import_artistic_liveries.py','scripts/run_artistic_review.py','scripts/present_artistic_liveries.py',
     'scripts/finalize_artistic_liveries.py','docs/evidence/artistic-liveries-2026-11-15/generation-prompts.json']
new += [p.relative_to(ROOT).as_posix() for p in sorted(ART.iterdir()) if p.is_file() and p.suffix!='.png']
new += [p.relative_to(ROOT).as_posix() for p in sorted((OUT/'before').iterdir()) if p.is_file()]
source_hashes={p:sha(ROOT/p) for p in runtime+new}
receipt={'date':'2026-11-15','requirements':{
 'AL01':'Replace the understated first collection with 18 individually generated full-colour illustrated artworks, three per car.',
 'AL02':'Six artistic identities: woodland engraving, pop art, industrial surrealism, porcelain/ink/glass, ocean myth and dramatic tattoo illustration.',
 'AL03':'Actual model fitting: upright bonnet heroes, side murals, roof supporting art, Kart pod charts, unpainted glazing and faded art boundaries.',
 'AL04':'Original image provenance, native stock comparisons, wash/restoration/cache controls, both desktop renderers and exact source checkpoint.'},
 'tool':'built-in image_gen','designs':catalog,'asset_sha256':art_hashes,'source_sha256':source_hashes,
 'tests':{m:{k:v for k,v in r.items() if k not in ['frames','stock_frames']} for m,r in reports.items()},
 'production_parser':{'scripts':parse_count,'failures':0},'native_image_sha256':image_hashes,
 'limits':['Owner visual acceptance and physical-device tests remain.',
           'This is a fixed-palette full-colour art-review collection; the current Garage coin menu and backend allowlist remain unchanged.',
           'No real-money SKUs, prices, grants, purchase integration, export or deployment.',
           'No FPS claim, all-kit appearance approval, current prepared-cache requalification or whole-project acceptance.',
           'Physical paint finish is inherited; porcelain, gold and stained-glass appearances are printed illustration styles.',
           'The first collection and its IDs remain archived and valid.']}
(OUT/'report.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')

names={'compact':'Rally','kart':'Kart','forklift':'Forklift','electric':'Volt','hovercraft':'Hover','super_rally':'Super Rally'}
table='\n'.join('| '+name+' | '+' / '.join(p['title'] for p in catalog if p['vehicle']==vehicle)+' |' for vehicle,name in names.items())
doc=f'''# Artistic livery collection - 2026-11-15

AL01-AL04 address the owner's rejection of the first collection as too close to plain paint. The current review collection is replaced by **18 full-colour illustrated artworks**, with three compositions for every current car. [Open the new native gallery](evidence/artistic-liveries-2026-11-15/collection.html) or [view the complete collection](evidence/artistic-liveries-2026-11-15/collection.png). Each card has five native angles, matched Stock paint and original Artwork views.

| Car | Artistic designs |
| --- | --- |
{table}

The collection uses woodland woodcut/botanical storytelling for Rally, expressive comic and carnival imagery for Kart, surreal industrial murals for Forklift, porcelain/ink/stained-glass art for Volt, ocean mythology for Hover, and dramatic tattoo illustration for Super Rally. Each atlas was individually generated using the **built-in image_gen tool**, following [18 exact prompts](evidence/artistic-liveries-2026-11-15/generation-prompts.json) and [the creative briefs](../scripts/artistic_livery_briefs.json). All 18 PNGs in `game/assets/liveries/artistic_v2/` are unchanged copies of their generated originals; their paths, original output locations and exact hashes are in the provenance/receipt files. There were no reference photos, generated car mockups, external sponsor marks or raster retouching steps.

The new work uses a colour-correct full-RGB sampler; three-pigment mask recolouring is retained for the first collection. Physical chart scales keep the artwork from stretching, bonnet portraits face the nose, roofs use supporting motifs, and Kart's narrow nose and separate pods have dedicated charts. A soft edge blends out-of-panel artwork into a quiet ground colour rather than stretching the last texture row across the body. Source-generated art remains intact. Painting only replaces existing paint surfaces, beneath weathering, with original glazing, tyres, trim and geometry retained. Gold, porcelain and glass are illustration styles; the underlying car paint finish is unchanged. Full-colour designs have fixed palettes; the older mask liveries retain their original colour roles.

Final headless checks: **{reports['headless']['checks']}/0**. Native Compatibility: **{reports['gl_compatibility']['checks']}/0**. Desktop Mobile: **{reports['mobile']['checks']}/0**. Production parser: **{parse_count}/0**. There are 90 art views and six stock controls per renderer, **192 native images** overall. Controls cover distinct colour-rich imagery, per-car restrictions, exact meshes/transforms, original ordinary shader source/program/pixels, first-collection interpretation, live dirt, washing, factory restoration, mipmaps, the four-mask cache and four shader families. Gallery destinations and JavaScript syntax were checked. Prototype renders found edge stretching and incorrect portrait orientation; those were fixed in the chart mapping before final collection capture.

Actual commands:

```powershell
python scripts/import_artistic_liveries.py
python scripts/run_artistic_review.py headless
python scripts/run_artistic_review.py gl_compatibility
python scripts/run_artistic_review.py mobile
python scripts/run_artistic_review.py parse
# Presentation uses the available Pillow authoring runtime.
python scripts/present_artistic_liveries.py
python scripts/finalize_artistic_liveries.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

Art import uses a small native art-only project, with lossless 1536x1024 mipmapped outputs. No owner editor/library is changed. Review runs have isolated application-data directories and use current authored models; they do not republish unrelated prepared geometry. The first collection is preserved in `premium_v1/`, with its 18 IDs valid; the released 48 coin wraps and standard Garage menu remain intact. This collection remains a review surface, with no prices, SKUs, purchases, grants, backend allowlist update or deployment.

Changed runtime files are `livery_catalog.gd`, `livery_graphics.gd` and the premium-only shader include. New source assets are the 18 full-colour PNG atlases and import settings, catalogue/provenance/notice, creative briefs and exact prompts, native review, import/runner/presentation/checkpoint scripts, and this report. The original ordinary livery shader/include remain byte-exact. The [machine-readable receipt](evidence/artistic-liveries-2026-11-15/report.json) enumerates every art/source/native-view hash. `task-source.patch` is a forward/reverse-verified **text-source** checkpoint; PNG originals are delivered directly in the asset directory and fenced by hash rather than duplicated into the patch. The shared Git index is unchanged, and concurrent work is preserved.

Owner appearance acceptance, physical-device testing and fitted-kit/gameplay-distance review remain before paid release. There is no phone, FPS, whole-project, export, current prepared-cache or paid-store readiness claim. No owner save/process change, real purchase, live account mutation or deployment was performed. Standard build retention ran without a task pin; shared recent/protected output can remain above the 20 GiB target.
'''
doc_path='docs/ARTISTIC_LIVERIES_2026_11_15.md'
(ROOT/doc_path).write_text(doc,encoding='utf-8')
prefix=f'''<!-- ARTISTIC-LIVERIES-20261115 -->
## Premium collection reworked as full-colour illustrated art (2026-11-15)
AL01-AL04 supersede the rejected understated first collection: 18 individually generated illustrated wraps, three per car, with woodland/pop/industrial/porcelain/ocean/tattoo identities. Full-RGB colour, physical chart scales, upright bonnet heroes, roof supporting art and Kart pod charts replace the limited mask treatment. Headless{reports['headless']['checks']}/0, Compatibility{reports['gl_compatibility']['checks']}/0, desktop Mobile{reports['mobile']['checks']}/0 and production parser{parse_count}/0 pass; 180 art views plus12 matched stock controls. Original ordinary shader source/program/pixels, exact geometry and dirt/wash controls retained; first collection IDs archived/valid. [Gallery, prompts, changes and limits](docs/ARTISTIC_LIVERIES_2026_11_15.md). Owner appearance, device and paid release acceptance remain; no Garage listing, billing, grants, backend/export/deployment or owner-save/process change. Exact text-source checkpoint, unchanged index and standard retention preserve concurrent work.
<!-- /ARTISTIC-LIVERIES-20261115 -->

'''
before_docs={}
for path in ['AGENTS.md','DEVELOPMENT_STATUS.md']:
    data=(ROOT/path).read_bytes()
    start_marker=b'<!-- ARTISTIC-LIVERIES-20261115 -->'
    end_marker=b'<!-- /ARTISTIC-LIVERIES-20261115 -->\n\n'
    if start_marker in data:
        start=data.index(start_marker);end=data.index(end_marker,start)+len(end_marker)
        data=data[:start]+data[end:]
    before_docs[path]=data
    (ROOT/path).write_bytes(prefix.encode('utf-8')+data)
index=git('diff','--cached','--binary')
paths=runtime+new+[doc_path,'AGENTS.md','DEVELOPMENT_STATUS.md']
before,after=WORK/'before',WORK/'after'
before.mkdir(parents=True,exist_ok=True);after.mkdir(parents=True,exist_ok=True)
for path in runtime:
    p=before/path;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(OUT/'before'/Path(path).name,p)
for path,data in before_docs.items():(before/path).write_bytes(data)
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
checkpoint={'text_files':len(paths),'png_assets_hashed_separately':18,'patch_sha256':sha(patch_path),'forward_exact':True,'reverse_exact':True,'main_index_unchanged':True}
(OUT/'checkpoint.json').write_text(json.dumps(checkpoint,indent=2)+'\n')
print('ARTISTIC_FINALIZED',json.dumps(checkpoint))
