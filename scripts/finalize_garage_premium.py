"""GP03: scoped Garage integration receipt and exact private source checkpoint."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/evidence/garage-premium-2026-11-16'
WORK=ROOT/'build/garage-premium-checkpoint'

def read(p): return json.loads(p.read_text(encoding='utf-8'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def git(*args,cwd=ROOT,allowed=(0,)):
    r=subprocess.run(['git','-c','core.autocrlf=false',*args],cwd=cwd,capture_output=True)
    assert r.returncode in allowed,r.stderr.decode(errors='replace')
    return r.stdout

start=read(OUT/'start.json')
assert hashlib.sha256(git('diff','--cached','--binary')).hexdigest()==start['index_sha256']
reports={m:read(OUT/m/'report.json') for m in ['headless','gl_compatibility','mobile']}
for mode,r in reports.items():
    assert r['failures']==0
    command=read(OUT/(mode+'-command.json'))
    assert command['exit_code']==0 and not command['log_errors']
    log=(OUT/(mode+'.log')).read_text(encoding='utf-8')
    assert 'SCRIPT ERROR:' not in log and '\nERROR:' not in log
assert 'GARAGE_PAINT_LIST: 147 checks, 0 failures' in (OUT/'standard.log').read_text(encoding='utf-8')
parsed=re.search(r'PRODUCTION_PARSE (\d+) scripts, 0 failures',(OUT/'parse.log').read_text(encoding='utf-8'))
assert parsed
preserved=read(OUT/'preserved-art.json')
for group in preserved.values():
    assert all(sha(ROOT/p)==h for p,h in group.items())

catalog=read(ROOT/'game/assets/liveries/diablo_v3/catalog.json')
names=[p['id'] for p in catalog]+['standard-discovery','premium-960','premium-1280','app-premium-1280']
images={mode+'/'+name+'.png':sha(OUT/mode/(name+'.png')) for mode in ['gl_compatibility','mobile'] for name in names}
runtime=['game/ui/garage_page.gd','game/ui/garage_livery_menu.gd','game/ui/garage_premium_liveries.gd']
new=['game/tests/test_garage_premium_liveries.gd','scripts/run_garage_premium.py','scripts/finalize_garage_premium.py']
for p in runtime+new:
    if (ROOT/(p+'.uid')).exists() and p not in start['before_sha256']: new.append(p+'.uid')
new=list(dict.fromkeys(new))
receipt={'date':'2026-11-16','requirements':{
 'GP01':'Expose all 18 current liveries through Garage > Appearance > Patterns > Premium, with three for the current car.',
 'GP02':'Preview on the retained live car with matching native icons, explicit preview-only labelling and no paid or coin grant.',
 'GP03':'Restore exact equipped paint, preserve records/camera/meshes/kits, cancel on account/tab/car changes and keep existing cache bounds.'},
 'tests':reports,'standard_paint_checks':147,'production_parse_scripts':int(parsed[1]),
 'source_sha256':{p:sha(ROOT/p) for p in runtime+new},'native_image_sha256':images,'preserved':preserved,
 'initial_findings':['Initial test used a progressive-showroom-only property and mixed Vector2/Vector2i in a native assertion; fixture accesses/types were corrected.',
                     'First App image captured the existing paint sweep mid-animation; final captures wait for all native paint/model transitions and assert every premium binding.',
                     'One Compatibility restore input observation failed; the unchanged restore gate and added per-car diagnostics qualify the subsequent final run. Original failed receipt/log retained.'],
 'limits':['Reload the running game to receive this source change.',
           'Preview only. No premium purchase, price, SKU, grant, backend allowlist, saved premium appearance, export or deployment.',
           'Desktop renderer/App checks are not a physical-device or FPS qualification. Owner appearance review remains.']}
(OUT/'report.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')

doc=f'''# Premium livery previews in Garage - 2026-11-16

GP01-GP03 fix the missing Garage entry for the 18 portrait-free liveries. The artwork previously existed only in the review catalogue and external gallery. After reloading the game, open **Garage > select a car > Appearance > Patterns > Premium**. [Actual App view](evidence/garage-premium-2026-11-16/gl_compatibility/app-premium-1280.png), [compact layout](evidence/garage-premium-2026-11-16/gl_compatibility/premium-960.png).

Patterns now has Standard/Premium selectors. Standard retains all 49 existing paint choices and its original purchase/equip flow. Premium shows exactly the current car's three designs, native model icons and a clear **Coming soon - Preview only** notice. Tapping a row uses the existing live-car paint animation. Restore equipped paint returns the exact saved palette and stickers. The selected collection survives car changes; its designs rebuild for the new car. Leaving Patterns, switching collection/car, hiding the Garage or changing account cancels the temporary preview through the existing preview lifecycle.

Premium has no purchase/equip action, ownership badge or coin price, and the generic equip callback also rejects this preview kind. The preview never mutates the draft appearance or saved records. Existing geometry, camera, fitted parts and paint artwork are retained. Visible icons reuse the normal 24-image paint cache and one temporary studio per active browser; hidden premium work is cancelled and its studio released. The 18 source PNGs and seven original paint/render inputs retain their exact hashes. No image regeneration, ordinary livery rendering, economy catalogue, backend allowlist or purchase integration changes were needed.

Final headless **{reports['headless']['checks']}/0**, Compatibility with actual App **{reports['gl_compatibility']['checks']}/0**, desktop Mobile with actual App **{reports['mobile']['checks']}/0**. Existing standard paint-list checks **147/0**, production parse **{parsed[1]}/0**. There are 22 final native captures per desktop renderer: all 18 designs on the actual Garage models, the Standard discovery view, two preview layouts and the complete actual App. Checks use real mouse/touch events, all six cars, 960x540 and 1280x720, exact saved palettes/stickers, meshes/camera, icon/cache bounds, wrong-car/unknown IDs, account/tab/collection cancellation and rejected purchase/save attempts.

Initial fixtures used a property available only on the progressive showroom and compared Vector2 with Vector2i; both were corrected without changing product assertions. The first App capture was taken during the existing paint animation; final captures wait for paint/car/kit transitions and check every premium paint binding. One Compatibility restore input observation failed in an earlier run. That failed log/receipt is retained; the final run retains the exact restore gate with per-car failure diagnostics. No assertion was relaxed.

```powershell
python scripts/run_garage_premium.py headless
python scripts/run_garage_premium.py gl_compatibility --app
python scripts/run_garage_premium.py mobile --app
python scripts/run_garage_premium.py standard
python scripts/run_garage_premium.py parse
python scripts/finalize_garage_premium.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

Runs use isolated application-data directories and dummy audio. No owner profile or process is changed; the one stopped process was an owned failed test run. Production edits are limited to `garage_page.gd`, `garage_livery_menu.gd` and new `garage_premium_liveries.gd`. Focused tests and a runner/finalizer support the change. The [receipt](evidence/garage-premium-2026-11-16/report.json) records source/art/native-view hashes. `task-source.patch` is a forward/reverse-verified private source checkpoint. The shared index and concurrent car-stat work are preserved. Standard build retention runs without a task pin.

The designs are now inspectable in Garage. They remain previews pending paid-product setup and owner appearance acceptance. There is no physical-device, FPS, paid-release, export, backend or deployment claim.
'''
doc_path='docs/GARAGE_PREMIUM_LIVERIES_2026_11_16.md'
(ROOT/doc_path).write_text(doc,encoding='utf-8')
prefix=f'''<!-- GARAGE-PREMIUM-LIVERIES-20261116 -->
## Premium mural liveries are discoverable in Garage (2026-11-16)
GP01-GP03: Appearance > Patterns > Premium exposes the current car's three designs, 18 overall, with native icons and explicit preview-only status. Live-car previews retain exact saved palettes/stickers/meshes/camera; restore and account/tab/car/collection cancellation are checked. No price, ownership or purchase/equip action; generic equip rejects premium previews. Existing49 standard options and 24-image/four-texture bounds remain. Headless{reports['headless']['checks']}/0, Compatibility/App{reports['gl_compatibility']['checks']}/0, desktop Mobile/App{reports['mobile']['checks']}/0, standard147/0 and parser{parsed[1]}/0; 44 final native views. Initial fixture/type/mid-sweep capture and one restore-input observation retained without relaxed assertions. Three UI runtime files; original18 art and seven rendering inputs exact. [Route, App views, checks and limits](docs/GARAGE_PREMIUM_LIVERIES_2026_11_16.md). Reload/owner/device and paid-product setup remain; no owner-save/process, billing/grant, backend/export/deployment or shared-index action. Exact private source checkpoint and standard retention preserve concurrent work.
<!-- /GARAGE-PREMIUM-LIVERIES-20261116 -->

'''
before_docs={}
for path in ['AGENTS.md','DEVELOPMENT_STATUS.md']:
    data=(ROOT/path).read_bytes()
    data=re.sub(rb'<!-- GARAGE-PREMIUM-LIVERIES-20261116 -->\r?\n.*?<!-- /GARAGE-PREMIUM-LIVERIES-20261116 -->\r?\n\r?\n',b'',data,flags=re.S)
    before_docs[path]=data
    (ROOT/path).write_bytes(prefix.encode('utf-8')+data)
before,after=WORK/'before',WORK/'after'
before.mkdir(parents=True,exist_ok=True);after.mkdir(parents=True,exist_ok=True)
for path in start['before_sha256']:
    source=OUT/'before'/Path(path).name
    assert sha(source)==start['before_sha256'][path]
    target=before/path;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
for path,data in before_docs.items(): (before/path).write_bytes(data)
paths=runtime+new+[doc_path,'AGENTS.md','DEVELOPMENT_STATUS.md']
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
assert hashlib.sha256(git('diff','--cached','--binary')).hexdigest()==start['index_sha256']
checkpoint={'files':len(paths),'patch_sha256':sha(patch_path),'forward_exact':True,'reverse_exact':True,'main_index_unchanged':True}
(OUT/'checkpoint.json').write_text(json.dumps(checkpoint,indent=2)+'\n',encoding='utf-8')
print('GARAGE_PREMIUM_FINALIZED',json.dumps(checkpoint))
