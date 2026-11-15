"""Save actual results, selected comparisons and a scoped completion journal."""
from pathlib import Path
import gzip,hashlib,json,re,shutil
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent;BUILD=ROOT/'build'/OUT.name
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda n:json.loads((OUT/n).read_text())
assert read('delivery-continuation.json')['exit_code']==0
shape=read('candidate-shape.json');baseline=read('baseline-shape.json')
assert shape['failures']==0 and baseline['failures']==6
prep=read('preparation-command.json');assert prep['exit_code']==0 and prep['stable']
assert all(sha(Path(p))==h for p,h in prep['after'].items())
pub=read('native-publication.json')
assert all(sha(ROOT/'game/assets/vehicles/challenger_hellcat_v1'/n)==h for n,h in pub['private_native'].items())
checkpoint=read('source-checkpoint.json');assert checkpoint['forward_reverse_byte_exact']
assert all(sha(ROOT/n)==h for n,h in checkpoint['after'].items())
start=read('task-start.json')
controls={n:sha(ROOT/n)==h for n,h in start.items() if n.startswith('game/resources/cars/') or n in ['game/vehicle/handling_config.gd','game/vehicle/vehicle_simulation.gd']}
assert all(controls.values())
legacy={n:sha(ROOT/n)==h for n,h in start.items() if n.startswith('game/assets/vehicles/challenger_hellcat_v1/') and Path(n).name not in pub['private_native']}
assert len(legacy)==4 and all(legacy.values())
labels=['baseline-export','before-gl','native-bake','candidate-export','allocation','candidate-contours','candidate-gl','coarse','livery','portraits','fitted-hood','modules','physics','wash','driving','production-parse','prepared-scoped','profile-refresh','opacity-gl','prepared-views-gl','opacity-mobile','prepared-views-mobile','prepared-close-gl','prepared-close-mobile','app-gl','app-mobile']
diagnostics={}
for label in labels:
    receipt=read(label+'-command.json');assert receipt['exit_code']==0 and receipt['script_errors']==0,label
    diagnostics[label]=[s for s in (OUT/(label+'.log')).read_text(errors='replace').splitlines() if s.startswith(('ERROR:','WARNING:')) or 'ObjectDB instances leaked' in s]
scope=read('delivery-scope.json');assert scope['challenger_scoped_passed']
fence=json.loads((BUILD/'assets/source-receipt.json').read_text());assert fence['before']==fence['after']
identity=json.loads((BUILD/'assets/client-build-identity.json').read_text(encoding='utf-8-sig'))
live=json.loads(re.search(r'MODULAR_CAR_SHA256: Dictionary = (\{[^\n]+\})',(ROOT/'game/core/build_identity.gd').read_text())[1])
assert live['super_rally']==identity['modular_car_sha256']['super_rally']
allocation=json.loads((OUT/'allocation.log').read_text().split('; ')[-1].strip())
assembled={('simple' if r['simple'] else 'full'):r['triangles'] for r in allocation}
stock=[int(v) for v in re.findall(r'COARSE_STOCK super_rally editable=\w+ triangles=(\d+)',(OUT/'coarse.log').read_text())]
timings={label:re.findall(r'GARAGE_LIVE_READY_MS[ :=]*(\d+(?:\.\d+)?)',(OUT/(label+'.log')).read_text()) for label in ['app-gl','app-mobile']}
retained={}
def keep(src,dst):
    dst.parent.mkdir(parents=True,exist_ok=True)
    if dst.suffix=='.gz':dst.write_bytes(gzip.compress(src.read_bytes(),compresslevel=9,mtime=0))
    else:shutil.copyfile(src,dst)
    retained[dst.relative_to(OUT).as_posix()]=sha(dst)
for name in ['baseline.json','candidate.json']:keep(BUILD/name,OUT/(name+'.gz'))
for renderer in ['gl_compatibility','mobile']:
    app=json.loads((BUILD/'app'/renderer/'acceptance.json').read_text());assert app['checks']==13 and app['failures']==0
    for name in ['white-owner-side.png','white-owner-front-right.png','white-nose-right.png','white-profile.png','white-rear-corner.png']:
        keep(BUILD/'views-final'/renderer/'simple'/name,OUT/'final'/renderer/name)
    for name in ['white-nose-right.png','white-profile.png']:
        keep(BUILD/'views-final-close'/renderer/'full'/name,OUT/'final-full'/renderer/name)
    for p in (BUILD/'app'/renderer).rglob('*'):
        if p.is_file() and p.suffix in ['.png','.json']:keep(p,OUT/'final/app'/renderer/p.relative_to(BUILD/'app'/renderer))
for name in ['white-owner-side.png','white-nose-right.png','white-profile.png']:
    keep(BUILD/'views-before/gl_compatibility/simple'/name,OUT/'before'/name)
for p in (BUILD/'assets').iterdir():
    if p.is_file() and p.suffix in ['.log','.json']:
        dst=OUT/'asset-receipts'/p.name
        if p.stat().st_size>500000:dst=Path(str(dst)+'.gz')
        keep(p,dst)
result={'native_checks':shape['checks'],'native_failures':0,'baseline_rejected_controls':baseline['failures'],'raw_assembled_triangles':assembled,'production_stock_triangles':stock,'configuration_simulation_exact':controls,'legacy_controls_exact':legacy,'bake_input_count':len(fence['after']),'complete_preflight_exit_code':scope['complete_preflight_exit_code'],'garage_entry_ms_samples':timings,'diagnostics':{k:v for k,v in diagnostics.items() if v},'retained':retained}
(OUT/'final-state.json').write_text(json.dumps(result,indent=2))
drops=[v for m in shape['metrics'].values() for v in m['deck_drop_mm']];centre=max(m['centre_max_change_mm'] for m in shape['metrics'].values())
whole='The complete prepared-resource preflight also passes.' if scope['complete_preflight_exit_code']==0 else 'The complete prepared-resource preflight retains findings outside Challenger; those findings remain in prepared-complete.log. Whole-project cache readiness is not claimed.'
report=f'''# Challenger lower bonnet deck - 15 November 2026

The owner requests a lower overall bonnet, with only its central air-intake section raised.

[Before side](evidence/{OUT.name}/before/white-owner-side.png) / [After side](evidence/{OUT.name}/final/gl_compatibility/white-owner-side.png)

[Before front](evidence/{OUT.name}/before/white-nose-right.png) / [After front](evidence/{OUT.name}/final/gl_compatibility/white-nose-right.png)

LHD01 - Geometry cause and correction. The shared reference chart placed the entire bonnet deck high beneath a separate 42mm central power-bulge term. The existing chart now lowers the outer deck by up to50mm, using smooth longitudinal end blends and the same transverse footprint as the central intake. The centreline's absolute height is retained. The surrounding wing banks, vents, contour backing and fitted-profile output follow this shared chart. No new geometry, material, lighting or runtime smoothing layer is introduced.

LHD02 - Independent native survey. Sixteen outer-deck stations per tier measure {min(drops):.2f}-{max(drops):.2f}mm reduction, while centreline height changes at most{centre:.3f}mm after native packing/interpolation. The centre descends continuously to the outer deck in the sampled transverse profiles. Roof, glazing, lighting assemblies, rear outline, exhaust seating, lower sides, wheel contacts and canonical handling are protected. Native acceptance passes{shape['checks']}/0; the preceding model rejects the six intended height/relative-intake controls. Initial fixture incorrectly classified intentional vertical perimeter returns as inverted; its rejected output is retained and the final gate explicitly accepts upward or vertical winding. The first fixed rear blend exposed a cowl gap and was rejected before publication; the final blend ends before the actual curved rear boundary, which is checked within0.2mm. Early fixture slope/marker-identity assumptions and their measured corrections remain in rejections.json. No repository assertion was weakened.

LHD03 - Fitted parts and revision. The exported bonnet profile is regenerated from the corrected chart. Model revision12 clears the preceding fitting dictionary with the native mesh generation and reloads its JSON resource once, preventing a cached higher profile from lifting fitted parts. A private actual-previous-builder control reproduces the stale fitting height; the new profile refresh check passes6/0 and compares the complete current profile.

LHD04 - Delivery and validation. Actual assembled raw triangles: {assembled}; production fixed/editable: {stock}. Original50k/85k allocation17/0 and panel-contour172/0 checks pass. Fitted hood316/0, Challenger modules1436/0, physics/replay3677/0, wash1655/0, driving72/0, production parsing and strict Challenger-scoped prepared checks pass. Native opacity30/0 and actual Garage/race App13/0 pass in both desktop renderers. The initial desktop Mobile opacity run reported30/7 byte-exact repeat/probe failures; an unchanged repeat passes30/0. The failed GPU receipt/observed stdout and successful repeat remain in renderer-rejections; the initial per-command file was overwritten before archival, which is explicitly recorded. The cause of that initial nondeterminism remains unqualified. Selected prepared images prove actual cache restoration. {whole} Garage-entry samples(ms): {timings}; these are observations, not responsiveness, FPS or phone qualification.

Authored sources: scripts/challenger_reference_form.py and game/vehicle/super_rally_model.gd. Fresh full/reduced conversion, independent native checks, guarded48-file publication, actual dependent base/kit/Garage/header/artwork/picture rebuilds and native image imports precede acceptance. The accepted asset bake closes {len(fence['after']):,} source inputs. The two-source checkpoint applies and reverses byte-exactly outside the shared index. Configuration/simulation and four unused native legacy controls remain exact. Concurrent work and the shared index are preserved.

Commands and receipts: run_preparation.py, review_native.py, check_shape.py, deliver.py, gpu_checks.py prepared-views-mobile, resume_delivery.py, test_profile_refresh.gd, checkpoint.py, finalize.py, run_retention.py and prune_working.py in the adjacent evidence folder. Current inputs, diagnostics, output hashes and final native/App captures are recorded in final-state.json and per-command receipts. Standard build retention and task-only disposable cleanup have separate receipts.

Reload for owner appearance review. No phone/device attachment query or test, export, backend operation, deployment, owner-save/process action or shared-index staging/commit was performed. Owner appearance and physical-device acceptance remain.
'''
(ROOT/'docs/CHALLENGER_LOW_HOOD_2026_11_15.md').write_text(report)
marker='CHALLENGER-LOW-HOOD-20261115'
entry=f'''<!-- {marker} -->
## Challenger main bonnet lowered around the raised intake (2026-11-15)
LHD01-LHD04: shared reference chart lowers the outer bonnet up to50mm while retaining the centreline intake height. Native deck survey{min(drops):.2f}-{max(drops):.2f}mm; centre change<={centre:.3f}mm. Shared wing/vent/contour/fitted profile updates; revision12 refreshes the cached fitting profile, actual old control6/0. Native{shape['checks']}/0 rejects preceding6 height controls; original allocation/contours, fitted/modules/physics/wash/driving/parser/scoped prepared and desktop renderer/App checks pass. Initial Mobile opacity30/7, unchanged repeat30/0 retained. Raw{assembled['simple']}/{assembled['full']}; production{stock}. Actual consumer/image rebuild and{len(fence['after'])}-input fence, two-source exact checkpoint and configuration/legacy controls retained. Concurrent work/index preserved. [Views, changes, commands and limits](docs/CHALLENGER_LOW_HOOD_2026_11_15.md). Reload/owner/device acceptance remains; no phone/FPS/export/backend/deployment/owner-save/process or shared-index action. Standard retention; no task pin.
<!-- /{marker} -->

'''
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
    p=ROOT/name;data=p.read_bytes();text=data.decode('utf-8-sig')
    if '<!-- '+marker+' -->' not in text:p.write_bytes(entry.encode()+data)
print('LOW_HOOD_FINAL',json.dumps({k:v for k,v in result.items() if k!='retained'}))
