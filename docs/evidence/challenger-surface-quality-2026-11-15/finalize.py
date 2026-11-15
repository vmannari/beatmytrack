"""Retain concise evidence and describe only completed, current-source checks."""
from pathlib import Path
import gzip,hashlib,json,re,shutil
import numpy as np
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
BUILD=ROOT/'build'/OUT.name
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
quality=json.loads((OUT/'candidate-quality.json').read_text());assert quality['failures']==0
publication=json.loads((OUT/'native-publication.json').read_text())
assert all(sha(ROOT/'game/assets/vehicles/challenger_hellcat_v1'/name)==digest for name,digest in publication['private_native'].items())
prep=json.loads((OUT/'preparation-command.json').read_text())
assert prep['stable'] and all(sha(Path(p))==digest for p,digest in prep['after'].items())
checkpoint=json.loads((OUT/'source-checkpoint.json').read_text())
assert all(sha(ROOT/name)==digest for name,digest in checkpoint['after'].items())
start=json.loads((OUT/'task-start.json').read_text())
controls={p:sha(ROOT/p)==digest for p,digest in start.items() if p.startswith('game/resources/cars/') or p in ['game/vehicle/super_rally_model.gd','game/vehicle/handling_config.gd','game/vehicle/vehicle_simulation.gd']}
assert all(controls.values())
legacy={p:sha(ROOT/p)==digest for p,digest in start.items() if p.startswith('game/assets/vehicles/challenger_hellcat_v1/') and Path(p).name not in publication['private_native']}
assert len(legacy)==4 and all(legacy.values())
labels=['native-bake','candidate-export','allocation','candidate-contours','coarse','livery','portraits','fitted-hood','modules','physics','wash','driving','live-contours','production-parse','prepared-complete','opacity-gl','prepared-views-gl','opacity-mobile','prepared-views-mobile','prepared-close-gl','prepared-close-mobile','app-gl','app-mobile']
receipts={label:json.loads((OUT/(label+'-command.json')).read_text()) for label in labels}
assert all(r['exit_code']==0 and r['script_errors']==0 for r in receipts.values())
assets=BUILD/'assets';fence=json.loads((assets/'source-receipt.json').read_text())
assert fence['before']==fence['after']
identity=json.loads((assets/'client-build-identity.json').read_text(encoding='utf-8-sig'))
live=json.loads(re.search(r'MODULAR_CAR_SHA256: Dictionary = (\{[^\n]+\})',(ROOT/'game/core/build_identity.gd').read_text())[1])
assert live['super_rally']==identity['modular_car_sha256']['super_rally']
for renderer in ['gl_compatibility','mobile']:
    app=json.loads((BUILD/'app'/renderer/'acceptance.json').read_text())
    assert app['checks']==13 and app['failures']==0
retained={}
def keep(source,destination):
    destination.parent.mkdir(parents=True,exist_ok=True)
    if destination.suffix=='.gz':destination.write_bytes(gzip.compress(source.read_bytes(),compresslevel=9,mtime=0))
    else:shutil.copyfile(source,destination)
    retained[destination.relative_to(OUT).as_posix()]=sha(destination)
for name in ['baseline.json','candidate.json']:
    keep(BUILD/name,OUT/(name+'.gz'))
for source in assets.iterdir():
    if source.suffix not in ['.json','.log'] or not source.is_file():continue
    dest=OUT/'asset-receipts'/source.name
    if source.stat().st_size>500000:dest=Path(str(dest)+'.gz')
    keep(source,dest)
for renderer in ['gl_compatibility','mobile']:
    for name in ['red-front-quarter.png','white-front-quarter.png','red-cowl.png','red-nose.png']:
        keep(BUILD/'views-final'/renderer/'simple'/name,OUT/'final'/renderer/'simple'/name)
    for name in ['red-cowl.png','red-nose.png']:
        keep(BUILD/'views-final-close'/renderer/'full'/name,OUT/'final'/renderer/'full'/name)
    for source in (BUILD/'app'/renderer).rglob('*'):
        if source.is_file() and source.suffix in ['.png','.json']:keep(source,OUT/'final/app'/renderer/source.relative_to(BUILD/'app'/renderer))
for name in ['red-cowl.png','red-nose.png']:
    keep(BUILD/'views-paired-before/gl_compatibility/simple'/name,OUT/'before-views'/name)
native=json.loads((ROOT/'game/assets/vehicles/challenger_hellcat_v1/source.json').read_text())
raw=json.loads((OUT/'allocation.log').read_text().split('; ')[-1].strip())
metrics=quality['metrics'];improvements={}
for tier,m in metrics.items():
    a=np.mean([row['second_difference_p95_mm'] for row in m['before_tracks']]);b=np.mean([row['second_difference_p95_mm'] for row in m['after_tracks']])
    improvements[tier]={'physical_curvature_kink_p95_mean_before_mm':a,'physical_curvature_kink_p95_mean_after_mm':b,'improvement_percent':(1-b/a)*100,
        'normal_step_max_before_deg':max(row['normal_step_max_deg'] for row in m['before_tracks']),'normal_step_max_after_deg':max(row['normal_step_max_deg'] for row in m['after_tracks'])}
summaries={label:[line for line in (OUT/(label+'.log')).read_text(encoding='utf-8',errors='replace').splitlines() if any(word in line for word in [' checks, ','_ASSETS:','SCRIPT_PARSE','COARSE_STOCK'])] for label in labels}
diagnostics={label:[line for line in (OUT/(label+'.log')).read_text(encoding='utf-8',errors='replace').splitlines() if line.startswith(('ERROR:','WARNING:')) or 'ObjectDB instances leaked' in line] for label in labels}
final={'qualified':True,'native_quality':{'checks':quality['checks'],'failures':0},'assembled_raw_counts':raw,'production_reduced_triangles':45234,
    'improvements':improvements,'configuration_and_runtime_model_controls':controls,'unused_legacy_controls':legacy,'current_super_rally_key':live['super_rally'],
    'stable_asset_inputs':len(fence['after']),'retained':retained,'test_summaries':summaries,'diagnostics':{k:v for k,v in diagnostics.items() if v},
    'scope':'Challenger body surfaces and derived assets; desktop native renderers. No physical-device acceptance.'}
(OUT/'final-state.json').write_text(json.dumps(final,indent=2))
simple=improvements['simple'];full=improvements['full']
report=f'''# Challenger surface quality — 15 November 2026

Refined the existing Challenger through its offline Blender converter and Godot native baker. [Before nose](evidence/{OUT.name}/before-views/red-nose.png), [after nose](evidence/{OUT.name}/final/gl_compatibility/simple/red-nose.png), [before cowl](evidence/{OUT.name}/before-views/red-cowl.png), [after cowl](evidence/{OUT.name}/final/gl_compatibility/simple/red-cowl.png), and [prepared whole car](evidence/{OUT.name}/final/gl_compatibility/simple/white-front-quarter.png) are actual engine captures. Materials, lighting recipes and runtime smoothing were not changed.

VSQ01 — Diagnosis. The upper wing combined masked geometric deformations with transferred source normals, irregular interior triangulation and thin returned skins. Native ray surveys found physical curvature kinks separately from normal discontinuities. The broad bonnet was already continuous; its crown, vents and all native hood attributes are retained. Roof, pillars, glazing, rear body and lower-side shape controls pass unchanged. The existing longitudinal side chart remains in use.

VSQ02 — Geometry. A regularised C2 tensor-product sheet is fitted to 2,333 full / 2,344 reduced uniformly measured outward-surface samples. Existing vertices are projected onto that measured design; only the eligible patch interior receives constrained triangulation. Its source border stations are retained. Geometry corrections reach about 12.85 mm at the deepest inherited creases; final native closest-surface distances are {metrics['simple']['maximum_body_vertex_distance_mm']:.3f} mm reduced / {metrics['full']['maximum_body_vertex_distance_mm']:.3f} mm full. Complete body bounds and protected body points are exact in the decoded native controls.

VSQ03 — Normals and packing. Continuous exterior copies share the fitted surface tangents. Downward bonnet gutter returns remain a separate hard domain. Inward faces are removed only with an outward-face coverage proof within 6 mm. The native baker repairs poor interior diagonals without changing their boundary or triangle count; one interior station receives bounded X-only fairing where a constrained concave quad cannot accept a diagonal flip. No runtime mesh, smoothing pass, shader trick, roughness change or normal map was added. Winding and outward native shading pass.

| Measurement | Before | Final |
| --- | ---: | ---: |
| Assembled raw reduced triangles | 49,462 | 49,994 (+1.08%) |
| Assembled raw full triangles | 82,452 | 83,964 (+1.83%) |
| Production reduced stock, fixed/editable | 44,702 | 45,234 (+1.19%) |
| Broad longitudinal normal step, reduced | {simple['normal_step_max_before_deg']:.3f}° | {simple['normal_step_max_after_deg']:.3f}° |
| Broad longitudinal normal step, full | {full['normal_step_max_before_deg']:.3f}° | {full['normal_step_max_after_deg']:.3f}° |
| Mean P95 physical curvature-kink metric, reduced | {simple['physical_curvature_kink_p95_mean_before_mm']:.4f} mm | {simple['physical_curvature_kink_p95_mean_after_mm']:.4f} mm |
| Mean P95 physical curvature-kink metric, full | {full['physical_curvature_kink_p95_mean_before_mm']:.4f} mm | {full['physical_curvature_kink_p95_mean_after_mm']:.4f} mm |

The geometric metric uses independent 5 mm ray tracks, not the construction equations. Its mean P95 improves {simple['improvement_percent']:.1f}% reduced / {full['improvement_percent']:.1f}% full. Maxima and all raw assertions remain in `candidate-quality.json`; this does not claim every individual triangle improves or every sharp panel boundary is smooth. Existing 50k/85k allocation assertions and all repository assertions remain unchanged.

The actual-App logs retain raw-Image selection-portrait loading warnings. All 64 image imports are current, but no export qualification or portrait-loader fix is claimed. Any shutdown diagnostics are preserved in `final-state.json` and the complete logs.

VSQ04 — Receiving assets. Published the native allowlist, rebuilt coarse recipes, base and kit masters, Garage/header models, 49 livery pictures, native artwork, Garage photographs and selection portraits, then refreshed texture imports. Prepared captures assert actual cache hits. The source fence covers {len(fence['after'])} stable inputs. Completed commands and individual counts are in `final-state.json` and their adjacent logs. Native surface qualification is 62/0; the original native control rejects 62/4. Allocation is 17/0 and panel contours 172/0. Fitted modules, all kits, physics/replay, wash, driving, production parsing, prepared preflight, opacity and actual Garage/race App checks pass. Both desktop renderers were exercised.

VSQ05 — Delivery. Source changes are `scripts/challenger_surface_quality.py`, its call in `scripts/challenger_reference_form.py`, and offline native packing repair in `game/tests/bake_challenger_hellcat.gd`. The three-source patch applies and reverses byte-exactly in a private repository. Car configurations, runtime SuperRallyModel and simulation source controls remain exact; four unused legacy native resources remain exact. Concurrent workspace/index changes are preserved. No task-authored shared-index staging or commit, owner-save/process change, physical-device test, game export, backend operation or deployment was performed.

Rejections are retained: the initial bounded chart candidate, prototype GLTF round-trip attribute differences, generated-version source-fence changes, the reduced-grid allocation rejection, and the final skinny-triangle normal rejection before the packing correction. The full diagnostic survey also includes intentional hard return domains; it is not a zero-normal-split claim. Desktop evidence does not establish phone FPS or AAA/whole-project appearance acceptance. Reload the project/game to release in-memory model resources before owner appearance review.

Reproduction uses the pinned Blender and Godot builds through:

```text
python docs/evidence/{OUT.name}/run_preparation.py
python docs/evidence/{OUT.name}/review_native.py
python docs/evidence/{OUT.name}/deliver.py
python docs/evidence/{OUT.name}/checkpoint.py
python docs/evidence/{OUT.name}/run_retention.py
python docs/evidence/{OUT.name}/finalize.py
```
'''
(ROOT/'docs/CHALLENGER_SURFACE_QUALITY_2026_11_15.md').write_text(report,encoding='utf-8')
block='''<!-- CHALLENGER-SURFACE-QUALITY-20261115 -->
## Challenger body surfaces refined without runtime smoothing (2026-11-15)
VSQ01-VSQ05: Measured C2 upper-wing fitting, constrained interior topology, distinct gutter normals, coverage-proven return removal and offline packing repair correct physical/shading defects. Raw49,462→49,994 reduced (+1.08%)/82,452→83,964 full (+1.83%); production44,702→45,234. Native62/0 rejects original62/4; allocation17/0 and contours172/0 pass. Hood attributes, protected body/bounds, glazing, runtime model and handling controls retained. Prepared consumers and both desktop renderer/App paths verified; no phone/FPS/AAA acceptance claim. Three-source checked patch; concurrent workspace/index preserved. [Changes, captures, commands and limits](docs/CHALLENGER_SURFACE_QUALITY_2026_11_15.md). Reload for appearance review; no owner-save/process, device/export/backend/deployment or shared-index action. Standard build retention; no task pin.
<!-- /CHALLENGER-SURFACE-QUALITY-20261115 -->

'''
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
    path=ROOT/name;data=path.read_bytes()
    prefix=block.replace('(docs/CHALLENGER_SURFACE_QUALITY_2026_11_15.md)','(CHALLENGER_SURFACE_QUALITY_2026_11_15.md)') if name.startswith('docs/') else block
    if b'<!-- CHALLENGER-SURFACE-QUALITY-20261115 -->' not in data:path.write_bytes(prefix.encode('utf-8')+data)
print('SURFACE_FINAL',quality['checks'],'native checks; report, comparisons and current-source receipts retained.')
