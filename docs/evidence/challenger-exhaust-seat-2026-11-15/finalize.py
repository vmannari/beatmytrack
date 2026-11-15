"""Retain the exact-scope source, native attachment and prepared-render proof."""
from pathlib import Path
import gzip,hashlib,json,re,shutil
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent;BUILD=ROOT/'build'/OUT.name
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
shape=json.loads((OUT/'candidate-shape.json').read_text());assert shape['failures']==0
old=json.loads((OUT/'baseline-shape.json').read_text());assert old['failures']==16
pub=json.loads((OUT/'native-publication.json').read_text());assert len(pub['changed'])==6
assert all(sha(ROOT/'game/assets/vehicles/challenger_hellcat_v1'/name)==digest for name,digest in pub['private_native'].items())
prep=json.loads((OUT/'preparation-command.json').read_text());assert prep['stable'] and prep['exit_code']==0
assert all(sha(Path(name))==digest for name,digest in prep['after'].items())
checkpoint=json.loads((OUT/'source-checkpoint.json').read_text());assert checkpoint['forward_reverse_byte_exact']
assert all(sha(ROOT/name)==digest for name,digest in checkpoint['after'].items())
start=json.loads((OUT/'task-start.json').read_text())
controls={name:sha(ROOT/name)==digest for name,digest in start.items() if name.startswith('game/resources/cars/') or name in ['game/vehicle/handling_config.gd','game/vehicle/vehicle_simulation.gd','game/vehicle/super_rally_model.gd']}
assert all(controls.values())
legacy={name:sha(ROOT/name)==digest for name,digest in start.items() if name.startswith('game/assets/vehicles/challenger_hellcat_v1/') and Path(name).name not in pub['private_native']}
assert len(legacy)==4 and all(legacy.values())
labels=['native-bake','candidate-export','allocation','candidate-contours','before-final','coarse','livery','portraits','fitted-hood','modules','physics','wash','driving','production-parse','prepared-complete','opacity-gl','prepared-views-gl','opacity-mobile','prepared-views-mobile','prepared-close-gl','prepared-close-mobile','app-gl','app-mobile']
diagnostics={}
for label in labels:
    result=json.loads((OUT/(label+'-command.json')).read_text());assert result['exit_code']==0 and result['script_errors']==0,label
    lines=(OUT/(label+'.log')).read_text(encoding='utf-8',errors='replace').splitlines();diagnostics[label]=[line for line in lines if line.startswith(('ERROR:','WARNING:')) or 'ObjectDB instances leaked' in line]
fence=json.loads((BUILD/'assets/source-receipt.json').read_text());assert fence['before']==fence['after']
identity=json.loads((BUILD/'assets/client-build-identity.json').read_text(encoding='utf-8-sig'))
live=json.loads(re.search(r'MODULAR_CAR_SHA256: Dictionary = (\{[^\n]+\})',(ROOT/'game/core/build_identity.gd').read_text())[1]);assert live==identity['modular_car_sha256']
reuse=json.loads((OUT/'exact-native-reuse.json').read_text());assert len(reuse)==40
for r in reuse:assert sha(ROOT/'game/assets/vehicles/challenger_hellcat_v1'/r['file'])==r['retained_sha256']
raw=json.loads((OUT/'allocation.log').read_text().split('; ')[-1].strip());assembled={('simple' if row['simple'] else 'full'):row['triangles'] for row in raw};assert assembled=={'simple':49958,'full':83940}
stock=[int(n) for n in re.findall(r'COARSE_STOCK super_rally editable=\w+ triangles=(\d+)',(OUT/'coarse.log').read_text())];assert stock==[45198,45198]
retained={}
def keep(source,dest):
    dest.parent.mkdir(parents=True,exist_ok=True)
    if dest.suffix=='.gz':dest.write_bytes(gzip.compress(source.read_bytes(),compresslevel=9,mtime=0))
    else:shutil.copyfile(source,dest)
    retained[dest.relative_to(OUT).as_posix()]=sha(dest)
for name in ['baseline.json','candidate.json']:keep(BUILD/name,OUT/(name+'.gz'))
for renderer in ['gl_compatibility','mobile']:
    accepted=json.loads((BUILD/'app'/renderer/'acceptance.json').read_text());assert accepted['checks']==13 and accepted['failures']==0
    for name in ['white-rear.png','white-rear-quarter.png','white-rear-corner.png','red-rear-quarter.png']:
        keep(BUILD/'views-final'/renderer/'simple'/name,OUT/'final'/renderer/name)
    for name in ['white-rear.png','white-rear-corner.png']:
        keep(BUILD/'views-final-close'/renderer/'full'/name,OUT/'final-full'/renderer/name)
    for p in (BUILD/'app'/renderer).rglob('*'):
        if p.is_file() and p.suffix in ['.json','.png']:keep(p,OUT/'final/app'/renderer/p.relative_to(BUILD/'app'/renderer))
for name in ['white-rear.png','white-rear-quarter.png','white-rear-corner.png']:keep(BUILD/'views-before/gl_compatibility/simple'/name,OUT/'before'/name)
for p in (BUILD/'assets').iterdir():
    if p.is_file() and p.suffix in ['.json','.log']:
        dest=OUT/'asset-receipts'/p.name
        if p.stat().st_size>500000:dest=Path(str(dest)+'.gz')
        keep(p,dest)
receipt={'shape_checks':shape['checks'],'shape_failures':0,'unchanged_native_resources':40,'changed_native_files':pub['changed'],'assembled_triangles':assembled,'production_triangles':stock,'configuration_simulation_runtime_exact':controls,'legacy_native_exact':legacy,'stable_bake_inputs':len(fence['after']),'diagnostics':{k:v for k,v in diagnostics.items() if v},'retained':retained}
(OUT/'final-state.json').write_text(json.dumps(receipt,indent=2))
centres=shape['metrics']['simple']['outlet_centres'];lift=(centres[0][1]-.351)*1000;burial=min(v for s in shape['metrics']['simple']['upper_neck_burial_metres'] for v in s)*1000
report=f'''# Challenger exhaust attachment - 15 November 2026

The owner marks both exhaust tips visibly detached below the rear bumper.

[Before](evidence/{OUT.name}/before/white-rear-corner.png) / [After](evidence/{OUT.name}/final/gl_compatibility/white-rear-corner.png)

[Before, wider view](evidence/{OUT.name}/before/white-rear-quarter.png) / [After, wider view](evidence/{OUT.name}/final/gl_compatibility/white-rear-quarter.png)

EXS01 - Cause and correction. The offline exhaust generator retained its original fixed Y=0.351 position after the rear valance changed. The visible defect was a real attachment gap. `scripts/challenger_detail_geometry.py` now surveys the final paint/accent/dark bumper skins, finds the lower valance edge at both outlets, and seats the existing tubes and cavities together in one level, symmetric pose. Their upper necks are buried behind the actual bumper, with a controlled 45 mm mouth projection. The lateral centres are explicitly symmetric in the source; the native mirroring stage already aligned the preceding tips and cavities, so no native lateral redesign was required. `scripts/prepare_challenger.py` applies this after the finished body deformations and records the measured attachment.

Native reduced-tier measurement gives approximately {lift:.2f} mm lift and at least {burial:.2f} mm of upper-neck burial across three lateral probes per outlet. The full tier independently passes the same attachment bounds. Oval width/height, existing tube length, recessed cavity depth, materials and per-part triangle counts are retained. No extra mesh, draw group, runtime fitting or shader adjustment is introduced.

EXS02 - Exact scope and pipeline. Forty unaffected native mesh resources retain their exact original bytes. Freshly regenerated versions first prove that every byte is identical apart from the exporter-generated local ArrayMesh identifier; their original resources are then reused. This includes every body/bonnet/contour/roof/glazing/optical/aero mesh outside the chrome and rubber buckets. Non-exhaust chrome remains within native packing precision. The original immutable bonnet and its original matching outline/provenance are retained together. Only six published native files change: four exhaust-containing chrome/rubber meshes, the manifest and source receipt. The completed source conversion is independently decoded and checked before the guarded 48-file publication. Real dependent bases/kits/Garage/header images and catalogue/selection photographs are regenerated; imports are verified and official preview identity is refreshed before the final portrait render. The accepted bake has {len(fence['after']):,} stable inputs. No metadata-only repair substitutes for changed geometry.

EXS03 - Verification and delivery. Native attachment/protection passes {shape['checks']}/0; the old native geometry rejects16 mounting assertions. Unchanged allocation17/0 and panel-contour172/0 pass. Raw assembled reduced/full remain49,958/83,940; production fixed/editable remains45,198. Fitted hood316/0, Challenger modules1436/0, physics/replay3677/0, wash1655/0, driving72/0, production parsing and complete prepared-resource validation pass. Opacity30/0 and actual Garage/race App13/0 pass on each desktop renderer. Six prepared rear views per renderer and three full-tier rear views qualify the visible attachment with actual prepared-cache hits. Exact arguments, outputs and diagnostics are in the adjacent command receipts.

The first exact-byte check rejected random local resource IDs; those controls remain unchanged and now pass through proved exact reuse. The first contour check rejected the generated outline's reference to the newly generated hood ID/hash; the entire original matching outline/hood pair is retained after proving every other field identical. These rejections and original results are preserved. No repository assertion was weakened. Known raw-PNG loader or shutdown diagnostics, if observed, remain in `final-state.json`.

Only two source files are authored by this task. Their source-only patch applies and reverses byte-exactly in a private repository. Configuration, simulation and runtime Challenger builder controls remain exact, as do four unused legacy native files. Concurrent work and the shared Git index are preserved. Standard retention and task-only disposable cleanup have separate receipts.

Commands and helpers: `run_preparation.py`, `reuse_exact.py`, `review_native.py`, `deliver.py`, `post_import_identity.py`, `gpu_checks.py`, `checkpoint.py`, `run_retention.py`, `finalize.py` in `docs/evidence/{OUT.name}`. No physical-device test, export, backend request, deployment, owner-save/process action or shared-index staging/commit was performed. Reload the game for owner appearance review; phone/device acceptance remains.
'''
(ROOT/'docs/CHALLENGER_EXHAUST_SEATING_2026_11_15.md').write_text(report,encoding='utf-8')
block=f'''<!-- CHALLENGER-EXHAUST-SEAT-20261115 -->
## Challenger exhaust tips seat against the finished rear valance (2026-11-15)
EXS01-EXS03: final-skin ray survey replaces stale fixed outlet height; approximately{lift:.2f}mm lift, at least{burial:.2f}mm upper-neck burial and45mm mouth projection seat both existing tips/cavities level and symmetric. Oval size, tube/cavity depth and triangle counts retained. Native{shape['checks']}/0 rejects old16 mounting controls; original40 resources and immutable bonnet/outline pair retained byte-exact after complete local-ID-only proof. Only6 native files change; raw49958/83940 and production45198 unchanged. Allocation17/0, contours172/0, fitted/modules/physics/wash/driving/parser, complete prepared and both desktop renderer/App checks pass. Two-source exact checkpoint, real dependent/image rebuilds, {len(fence['after'])}-input bake, retention and concurrent work/index preservation. [Changes, before/after, commands and limits](docs/CHALLENGER_EXHAUST_SEATING_2026_11_15.md). Reload/owner/device acceptance remains; no phone/FPS/export/backend/deployment/owner-save/process or shared-index action.
<!-- /CHALLENGER-EXHAUST-SEAT-20261115 -->

'''
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
    p=ROOT/name;data=p.read_bytes();prefix=block.replace('(docs/CHALLENGER_EXHAUST_SEATING_2026_11_15.md)','(CHALLENGER_EXHAUST_SEATING_2026_11_15.md)') if name.startswith('docs/') else block
    if b'<!-- CHALLENGER-EXHAUST-SEAT-20261115 -->' not in data:p.write_bytes(prefix.encode('utf-8')+data)
print('EXHAUST_SEATING_CLOSED native attachment, exact controls, prepared views and source checkpoint verified.')
