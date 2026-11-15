"""Close the source/native/rendered proof and retain reviewable comparisons."""
from pathlib import Path
import gzip,hashlib,json,re,shutil
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent;BUILD=ROOT/'build'/OUT.name
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
shape=json.loads((OUT/'candidate-shape.json').read_text());assert shape['failures']==0
pub=json.loads((OUT/'native-publication.json').read_text())
assert all(sha(ROOT/'game/assets/vehicles/challenger_hellcat_v1'/name)==digest for name,digest in pub['private_native'].items())
prep=json.loads((OUT/'preparation-command.json').read_text());assert prep['stable'] and prep['exit_code']==0
assert all(sha(Path(name))==digest for name,digest in prep['after'].items())
checkpoint=json.loads((OUT/'source-checkpoint.json').read_text());assert checkpoint['forward_reverse_byte_exact']
assert all(sha(ROOT/name)==digest for name,digest in checkpoint['after'].items())
start=json.loads((OUT/'task-start.json').read_text())
controls={name:sha(ROOT/name)==digest for name,digest in start.items() if name.startswith('game/resources/cars/') or name in ['game/vehicle/handling_config.gd','game/vehicle/vehicle_simulation.gd']}
assert all(controls.values())
legacy={name:sha(ROOT/name)==digest for name,digest in start.items() if name.startswith('game/assets/vehicles/challenger_hellcat_v1/') and Path(name).name not in pub['private_native']}
assert len(legacy)==4 and all(legacy.values())
labels=['native-bake','candidate-export','allocation','candidate-contours','before-final','coarse','livery','portraits','fitted-hood','modules','physics','wash','driving','live-contours','production-parse','prepared-complete','opacity-gl','prepared-views-gl','opacity-mobile','prepared-views-mobile','prepared-close-gl','prepared-close-mobile','app-gl','app-mobile']
diagnostics={}
for label in labels:
    result=json.loads((OUT/(label+'-command.json')).read_text());assert result['exit_code']==0 and result['script_errors']==0,label
    lines=(OUT/(label+'.log')).read_text(encoding='utf-8',errors='replace').splitlines()
    diagnostics[label]=[line for line in lines if line.startswith(('ERROR:','WARNING:')) or 'ObjectDB instances leaked' in line]
fence=json.loads((BUILD/'assets/source-receipt.json').read_text());assert fence['before']==fence['after']
identity=json.loads((BUILD/'assets/client-build-identity.json').read_text(encoding='utf-8-sig'))
live=json.loads(re.search(r'MODULAR_CAR_SHA256: Dictionary = (\{[^\n]+\})',(ROOT/'game/core/build_identity.gd').read_text())[1])
assert live==identity['modular_car_sha256']
stock=[int(n) for n in re.findall(r'COARSE_STOCK super_rally editable=\w+ triangles=(\d+)',(OUT/'coarse.log').read_text())];assert len(stock)==2 and stock[0]==stock[1]
raw=json.loads((OUT/'allocation.log').read_text().split('; ')[-1].strip())
assembled={('simple' if row['simple'] else 'full'):row['triangles'] for row in raw}
assert assembled=={'simple':49958,'full':83940}
retained={}
def keep(source,dest):
    dest.parent.mkdir(parents=True,exist_ok=True)
    if dest.suffix=='.gz':dest.write_bytes(gzip.compress(source.read_bytes(),compresslevel=9,mtime=0))
    else:shutil.copyfile(source,dest)
    retained[dest.relative_to(OUT).as_posix()]=sha(dest)
for name in ['baseline.json','candidate.json']:keep(BUILD/name,OUT/(name+'.gz'))
for renderer in ['gl_compatibility','mobile']:
    accepted=json.loads((BUILD/'app'/renderer/'acceptance.json').read_text());assert accepted['checks']==13 and accepted['failures']==0
    for name in ['white-profile.png','white-owner-front-right.png','white-front.png','white-nose.png','red-owner-front-right.png']:
        keep(BUILD/'views-final'/renderer/'simple'/name,OUT/'final'/renderer/name)
    for p in (BUILD/'app'/renderer).rglob('*'):
        if p.is_file() and p.suffix in ['.json','.png']:keep(p,OUT/'final/app'/renderer/p.relative_to(BUILD/'app'/renderer))
for name in ['white-profile.png','white-owner-front-right.png','white-front.png','white-nose.png']:
    keep(BUILD/'views-before/gl_compatibility/simple'/name,OUT/'before'/name)
for p in (BUILD/'assets').iterdir():
    if p.is_file() and p.suffix in ['.log','.json']:
        dest=OUT/'asset-receipts'/p.name
        if p.stat().st_size>500000:dest=Path(str(dest)+'.gz')
        keep(p,dest)
receipt={'shape_checks':shape['checks'],'shape_failures':0,'assembled_triangles':assembled,'native_source_triangles':{tier:m['native_triangles'] for tier,m in shape['metrics'].items()},'production_stock_triangles':stock,'configuration_and_simulation_exact':controls,'unused_legacy_exact':legacy,'stable_bake_inputs':len(fence['after']),'diagnostics':{k:v for k,v in diagnostics.items() if v},'retained':retained}
(OUT/'final-state.json').write_text(json.dumps(receipt,indent=2))
m=shape['metrics']['simple'];inset=m['right_lamps'][0]['inset_mm'];narrow=m['before_grille_width_mm']-m['grille_width_mm']
report=f'''# Challenger nose downturn and grille refinement - 15 November 2026

The owner requests a more downturned leading edge and a slightly narrower grille with the lamps brought inward. This refines the shortened nose from the previous pass and retains its improved shoulder.

[Before profile](evidence/{OUT.name}/before/white-profile.png) / [After profile](evidence/{OUT.name}/final/gl_compatibility/white-profile.png)

[Before front](evidence/{OUT.name}/before/white-front.png) / [After front](evidence/{OUT.name}/final/gl_compatibility/white-front.png)

[Before three-quarter](evidence/{OUT.name}/before/white-owner-front-right.png) / [After three-quarter](evidence/{OUT.name}/final/gl_compatibility/white-owner-front-right.png)

NDT01 - Profile. The preceding front chart flattened the last outer-wing section into the fascia. A final offline cubic downturn now has zero displacement, slope and curvature at its rearward start (Z=-1.62), then increases slope towards the tip. It uses a 54 mm coefficient over a 0.50 m longitudinal run. Native silhouette sampling measures {m['tip_drop_mm']:.2f} mm of additional leading outer-wing drop. Every sampled forward interval keeps a descending nose. The earlier 140 mm shortening and longitudinal extents are retained.

NDT02 - Front assembly. One coordinated taper narrows the central grille by {narrow:.2f} mm overall and brings each projector pair inward approximately {inset:.2f} mm. The central compression blends smoothly into a rigid lateral translation at the lamps; the projectors retain their circular transverse diameter. The carrier, aperture rim, paint, bonnet, honeycomb and supported markings all follow the same chart. This avoids disconnected detail layers. The lower lip and body rearward of the change remain within native packing precision. Materials, colours, lights, tyre geometry, wheel centres, roof, glazing and handling are not authored by this pass.

NDT03 - Geometry and normals. `scripts/challenger_nose_finish.py` edits existing mesh coordinates and transports split normals with the inverse-transpose equivalent cofactor calculation. The deformation must retain a Jacobian determinant greater than 0.65 at every exported corner. Source vertex identities and contour-pair attributes survive; no runtime smoother or extra mesh is added. `scripts/prepare_challenger.py` applies the finish after shortening and exports the corresponding bonnet outline. `game/vehicle/super_rally_model.gd` mirrors this coordinate chart for existing fitted-hood samples and advances the mesh key.

Raw assembled triangles remain {assembled['simple']:,} reduced / {assembled['full']:,} full. Production stock fixed/editable is {stock[0]:,}. The independently decoded native test passes {shape['checks']} checks; the previous native model rejects 12 of the new requirements. Original allocation17/0, contours172/0, fitted hood316/0, all Challenger modules1436/0, physics/replay3677/0, wash1655/0 and driving72/0 pass. Actual results and arguments for production parsing and complete prepared-resource validation are in their command receipts. Opacity30/0 and actual Garage/race App13/0 pass in both desktop Compatibility and Mobile renderers; final screenshots verify actual prepared-cache hits. This is desktop qualification, not a physical-device or FPS claim.

NDT04 - Delivery. Fresh source conversion, private native review and guarded 48-file publication precede real dependent-resource and image rebuilds. A complete pre-bake survey isolated stale Challenger masters and shared Garage/header snapshots; other car masters already validated, so they were retained. The concurrent dependency manifest routes the Challenger model source to its own vehicle; that routing change was not authored by this task. The accepted asset bake closes {len(fence['after']):,} stable inputs. Photographs, stock selection portraits and native texture imports are refreshed. The three-source checkpoint applies and reverses byte-exactly in a private repository; the shared index and concurrent work are preserved. Configuration/simulation controls and four unused legacy native files remain exact.

The 65 mm and near-threshold 55 mm candidates was rejected by the unchanged new deformation-thickness guard; the 54 mm design satisfies it. An initial new shoulder test accidentally included unrelated hard panel boundaries and rejected the old mesh too; the final test uses the previously established continuous-shoulder band, with its original outward-normal threshold. The original fixed outboard profile band omitted the newly inset full-tier rim; identical baseline/candidate sampling now covers the actual outer front at X>0.58 m, retaining all original downturn and coverage thresholds. An early before-capture source fence rejected concurrent App/header/dependency-map edits and was rerun. A later generated-identity rewrite during the live contour test was rejected despite172/0 actual assertions. Final post-import identity retained all model keys, and the stock portraits were genuinely rendered again against the advanced Garage/header preview revisions before completing the contour, whole prepared and GPU checks. These records are retained in `rejections.json` and the rejected evidence folders. No existing repository assertion was weakened. Known raw-PNG portrait-loader warnings and any native shutdown diagnostics remain listed in `final-state.json`.

Commands are recorded alongside this report, including `run_preparation.py`, `review_native.py`, `deliver.py`, `gpu_checks.py`, `checkpoint.py`, `run_retention.py`, `finish_delivery.py` and `finalize.py` in `docs/evidence/{OUT.name}`. Standard build retention and disposable task-profile cleanup have separate receipts. No physical-device test, game export, backend request, deployment, owner-save/process action or shared-index staging/commit was performed. Reload before owner appearance review; device acceptance remains.
'''
(ROOT/'docs/CHALLENGER_NOSE_DOWNTURN_2026_11_15.md').write_text(report,encoding='utf-8')
block=f'''<!-- CHALLENGER-NOSE-DOWNTURN-20261115 -->
## Challenger nose turns down with a narrower grille and inset lamps (2026-11-15)
NDT01-NDT04: shared offline cubic downturn and fascia taper give {m['tip_drop_mm']:.2f}mm additional leading outer-wing drop, {narrow:.2f}mm narrower grille and approximately {inset:.2f}mm lamp inset each side with circular diameters retained. Source normals use cofactor transport, determinant>0.65; fitted hood follows the same chart. Prior shortening, rearward shoulder, lower lip, wheels, glazing, roof and handling retained. Raw49958/83940 and production{stock[0]} unchanged; native{shape['checks']}/0, allocation17/0, contours172/0, fitted/modules/physics/wash/driving/parser, complete prepared and both desktop renderer/App checks pass. Real consumer/image rebuilds, three-source exact checkpoint and stable {len(fence['after'])}-input bake; concurrent work/index preserved. Rejected65mm/fixture/concurrent controls retained. [Changes, matched views, commands and limits](docs/CHALLENGER_NOSE_DOWNTURN_2026_11_15.md). Reload/owner/device acceptance remains; no phone/FPS/AAA/export/backend/deployment/owner-save/process or shared-index action. Standard retention; no task pin.
<!-- /CHALLENGER-NOSE-DOWNTURN-20261115 -->

'''
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
    p=ROOT/name;data=p.read_bytes();prefix=block.replace('(docs/CHALLENGER_NOSE_DOWNTURN_2026_11_15.md)','(CHALLENGER_NOSE_DOWNTURN_2026_11_15.md)') if name.startswith('docs/') else block
    if b'<!-- CHALLENGER-NOSE-DOWNTURN-20261115 -->' not in data:p.write_bytes(prefix.encode('utf-8')+data)
print('NOSE_FINISH_CLOSED source, native, prepared render, images and controls verified.')
