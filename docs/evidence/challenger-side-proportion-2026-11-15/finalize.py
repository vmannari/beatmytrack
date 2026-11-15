"""Retain the owner-angle comparison and completed verification evidence."""
from pathlib import Path
import gzip,hashlib,json,re,shutil
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent;BUILD=ROOT/'build'/OUT.name
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
shape=json.loads((OUT/'candidate-shape.json').read_text());assert shape['failures']==0
pub=json.loads((OUT/'native-publication.json').read_text())
assert all(sha(ROOT/'game/assets/vehicles/challenger_hellcat_v1'/n)==v for n,v in pub['private_native'].items())
prep=json.loads((OUT/'preparation-command.json').read_text());assert prep['stable']
assert all(sha(Path(p))==v for p,v in prep['after'].items())
checkpoint=json.loads((OUT/'source-checkpoint.json').read_text())
assert all(sha(ROOT/p)==v for p,v in checkpoint['after'].items())
start=json.loads((OUT/'task-start.json').read_text())
controls={p:sha(ROOT/p)==v for p,v in start.items() if p.startswith('game/resources/cars/') or p in ['game/vehicle/handling_config.gd','game/vehicle/vehicle_simulation.gd']}
assert all(controls.values())
legacy={p:sha(ROOT/p)==v for p,v in start.items() if p.startswith('game/assets/vehicles/challenger_hellcat_v1/') and Path(p).name not in pub['private_native']}
assert len(legacy)==4 and all(legacy.values())
labels=['native-bake','candidate-export','allocation','candidate-contours','coarse','livery','portraits','fitted-hood','modules','physics','wash','driving','live-contours','production-parse','prepared-scoped','prepared-complete-final','opacity-gl','prepared-views-gl','opacity-mobile','prepared-views-mobile','prepared-close-gl','prepared-close-mobile','app-gl','app-mobile']
for label in labels:
    receipt=json.loads((OUT/(label+'-command.json')).read_text())
    assert receipt['exit_code']==0 and receipt['script_errors']==0,label
assets=BUILD/'assets';fence=json.loads((assets/'source-receipt.json').read_text());assert fence['before']==fence['after']
if (assets/'shared-source-receipt.json').exists():
    shared=json.loads((assets/'shared-source-receipt.json').read_text())
    if shared['before']==shared['after']:fence=shared
identity=json.loads((assets/'client-build-identity.json').read_text(encoding='utf-8-sig'))
live=json.loads(re.search(r'MODULAR_CAR_SHA256: Dictionary = (\{[^\n]+\})',(ROOT/'game/core/build_identity.gd').read_text())[1])
assert live==identity['modular_car_sha256']
raw=json.loads((OUT/'allocation.log').read_text().split('; ')[-1].strip())
stock=[int(x) for x in re.findall(r'COARSE_STOCK super_rally editable=\w+ triangles=(\d+)',(OUT/'coarse.log').read_text())]
assert len(stock)==2 and stock[0]==stock[1]
diagnostics={label:[line for line in (OUT/(label+'.log')).read_text(encoding='utf-8',errors='replace').splitlines() if line.startswith(('ERROR:','WARNING:')) or 'ObjectDB instances leaked' in line] for label in labels}
retained={}
def keep(source,destination):
    destination.parent.mkdir(parents=True,exist_ok=True)
    if destination.suffix=='.gz':destination.write_bytes(gzip.compress(source.read_bytes(),compresslevel=9,mtime=0))
    else:shutil.copyfile(source,destination)
    retained[destination.relative_to(OUT).as_posix()]=sha(destination)
for name in ['baseline.json','candidate.json']:keep(BUILD/name,OUT/(name+'.gz'))
for renderer in ['gl_compatibility','mobile']:
    acceptance=json.loads((BUILD/'app'/renderer/'acceptance.json').read_text());assert acceptance['checks']==13 and acceptance['failures']==0
    for name in ['white-owner-front-right.png','white-profile.png','white-reference-side.png','red-owner-front-right.png']:
        keep(BUILD/'views-final'/renderer/'simple'/name,OUT/'final'/renderer/name)
    for source in (BUILD/'app'/renderer).rglob('*'):
        if source.is_file() and source.suffix in ['.png','.json']:keep(source,OUT/'final/app'/renderer/source.relative_to(BUILD/'app'/renderer))
for name in ['white-owner-front-right.png','white-profile.png','white-reference-side.png']:
    keep(BUILD/'views-before/gl_compatibility/simple'/name,OUT/'before-views'/name)
for source in assets.iterdir():
    if source.is_file() and source.suffix in ['.json','.log']:
        dest=OUT/'asset-receipts'/source.name
        if source.stat().st_size>500000:dest=Path(str(dest)+'.gz')
        keep(source,dest)
changes={tier:100*(1-m['mean_p95_after_mm']/m['mean_p95_before_mm']) for tier,m in shape['metrics'].items()}
receipt={'native_shape_checks':shape['checks'],'native_shape_failures':0,'raw_assembled':raw,'production_stock':stock,'reflection_ripple_reduction_percent':changes,'configuration_and_simulation_exact':controls,'unused_legacy_exact':legacy,'stable_bake_inputs':len(fence['after']),'all_model_keys_current':True,'diagnostics':{k:v for k,v in diagnostics.items() if v},'retained':retained}
scope=json.loads((OUT/'delivery-scope.json').read_text());receipt['complete_preflight_exit_code']=scope['complete_preflight_exit_code']
receipt['identity_keys_current']=receipt.pop('all_model_keys_current')
(OUT/'final-state.json').write_text(json.dumps(receipt,indent=2))
simple=shape['metrics']['simple'];full=shape['metrics']['full']
report=f'''# Challenger shoulder and front proportions — 15 November 2026

The owner rejected the remaining scalloped side reflections and the long front overhang, supplying a marked game view, a side view and a clean vehicle photograph. These override the earlier requirement to retain the extended nose. This pass addresses the marked shoulder itself and removes the added front length.

[Before, owner-side angle](evidence/{OUT.name}/before-views/white-owner-front-right.png) · [After, same angle](evidence/{OUT.name}/final/gl_compatibility/white-owner-front-right.png)

[Before, orthographic profile](evidence/{OUT.name}/before-views/white-profile.png) · [After, orthographic profile](evidence/{OUT.name}/final/gl_compatibility/white-profile.png)

CSP01 — Root cause. The old 4 mm shoulder bend had irregularly spaced source triangles crossing it. The earlier upper-wing refinement stopped above this bend. Smooth source normals could not keep the reflected boundary even on that topology. The new test measures three actual native normal-isocontours along the entire marked side, rather than only sampling the upper fender. The prototype comparison from the owner-visible side reproduces the old scallops and shows their reduction.

CSP02 — Geometry and topology. A robust C2 fit retains the measured broad side shape, with a 9 mm transverse shoulder-transition parameter. Constrained longitudinal edge rows explicitly resolve that bend. The existing 3D boundary stations and wheel-arch cutouts stay attached; no global subdivision is used. Coverage-proven inward returns free enough triangles for these rows. The allocation guard adjusts longitudinal spacing until the complete body fits its starting count. Materials, studio lighting and production shaders are unchanged. Normals come from the same surface; both native tiers pass the shoulder outward-hemisphere check.

CSP03 — Front proportions. A common monotone final-coordinate transform shortens the nose by 140 mm, fading to zero ahead of the front tyre. Body, bonnet, optics, grilles, trim, authored markings and stock splitter receive that transform together. The runtime fitted-hood coordinate helper and fitted splitter position follow it. Wheel centres, tyres, wheelbase, car configurations, simulation, roof and window shapes are retained. The attachment height grid keeps its existing source domain; no runtime smoothing or additional mesh layer was introduced.

| Native measurement | Before | Final |
| --- | ---: | ---: |
| Assembled raw reduced triangles | 49,994 | {next(r['triangles'] for r in raw if r['simple'])} |
| Assembled raw full triangles | 83,964 | {next(r['triangles'] for r in raw if not r['simple'])} |
| Production reduced stock, fixed/editable | 45,234 | {stock[0]} |
| Mean P95 reflection-contour ripple, reduced | {simple['mean_p95_before_mm']:.4f} mm | {simple['mean_p95_after_mm']:.4f} mm |
| Mean P95 reflection-contour ripple, full | {full['mean_p95_before_mm']:.4f} mm | {full['mean_p95_after_mm']:.4f} mm |
| Front shortening | 0 | {simple['nose_shortening_mm']:.3f} mm |

The reflection measure follows 15°, 20° and 22° transverse normal-angle contours using independent ray intersections and barycentric native normals at 10 mm longitudinal stations. Their mean P95 second difference improves {changes['simple']:.1f}% reduced / {changes['full']:.1f}% full. This is a contour-ripple measure, not an FPS, universal curvature, pixel-identity or AAA acceptance claim. Full traces, coverage, assertions and the retained old-mesh rejection are in `candidate-shape.json` and `baseline-shape.json`. Protected roof points differ only by approximately 0.065 mm of native packing. Side marker Y/Z shape and triangle count are retained; their existing producer re-seats X on the new body with a checked 3 mm offset.

CSP04 — Pipeline and verification. Fresh source conversion, private native bake and independent shape checks precede the native allowlist publication. The original 50k/85k assembled allocation test and all 172 panel-contour assertions pass unchanged. Fitted hood tests, all Challenger kit permutations, physics/replay, wash, driving, production parsing, Challenger-scoped prepared preflight, opacity and actual Garage/race checks pass. Both desktop renderers use real prepared-cache hits. An initial all-car rebuild was rejected when concurrent Volt assets and the shared VisualGeometry source changed. A later wider repair was also rejected when the shared car-surface shader allowlist changed. Challenger consumers were rebuilt against the latest helpers, with all six default photographs/portraits regenerated. After the concurrent cache rebuild settled, the final complete preflight passes 551 resources / 2,267 checks with zero failures. The earlier out-of-scope findings are retained in their original receipts. Other car model sources were not authored and no cache metadata-only restamp was used. The Challenger bake closed a {len(fence['after'])}-input fence. A later concurrent Garage-header edit rejected one broad capture fence; that capture was rerun successfully. The original portrait producer also rejected two concurrent nonstock-kit writes before completing with 25,585 stable inputs. Final prepared-resource consistency is qualified at this snapshot; wider product/device acceptance remains.

CSP05 — Delivery and limits. Four source files changed: `scripts/challenger_side_finish.py`, its call in `scripts/challenger_reference_form.py`, the final transform in `scripts/prepare_challenger.py`, and the fitted-part coordinates in `game/vehicle/super_rally_model.gd`. The source-only patch applies and reverses exactly in a private repository. Configuration/simulation controls and four unused legacy native files remain exact. Concurrent work and the shared index were preserved. All actual command arguments, results and diagnostics are beside this report. Standard build retention and task-only disposable cleanup are recorded separately.

Early sparse-grid budget rejections, a partial prototype conversion rejection, generated-version source-fence changes, and the initial over-strict amber-marker X-control rejection are retained. The marker check now verifies its intended attachment to the actual finished skin as well as its unchanged Y/Z profile. No existing repository assertion was removed or relaxed. Any retained portrait-loader warnings or shutdown diagnostics are listed in `final-state.json`; they do not establish export readiness.

No physical-device test, game export, backend operation, deployment, owner-save/process change or shared-index staging/commit was performed. Reload the project/game before appearance review so it releases old in-memory model resources. Owner appearance and physical-device acceptance remain.

Recorded workflow, including recovery from concurrent edits (exact arguments and exit codes are in adjacent receipts):

```text
python docs/evidence/{OUT.name}/run_preparation.py
python docs/evidence/{OUT.name}/review_native.py
python docs/evidence/{OUT.name}/deliver.py
python docs/evidence/{OUT.name}/resume_delivery.py
python docs/evidence/{OUT.name}/finish_global.py
python docs/evidence/{OUT.name}/finish_scope.py
python docs/evidence/{OUT.name}/checkpoint.py
python docs/evidence/{OUT.name}/run_retention.py
python docs/evidence/{OUT.name}/finalize.py
```
'''
(ROOT/'docs/CHALLENGER_SIDE_AND_PROPORTIONS_2026_11_15.md').write_text(report,encoding='utf-8')
block=f'''<!-- CHALLENGER-SIDE-PROPORTIONS-20261115 -->
## Challenger marked shoulder and nose proportions corrected (2026-11-15)
CSP01-CSP05: owner rejects remaining reflection scallops and excess nose length. C2 side fit, explicit longitudinal rows through a 9 mm shoulder transition and coverage-proven return removal improve native contour ripple {changes['simple']:.1f}%/{changes['full']:.1f}%. A common 140 mm front shortening includes optics/bonnet/markings/stock aero and fitted attachment coordinates; wheels, handling, glazing and roof retained. Raw {next(r['triangles'] for r in raw if r['simple'])}/{next(r['triangles'] for r in raw if not r['simple'])}, production {stock[0]}; counts decrease. Native {shape['checks']}/0, allocation17/0, contours172/0, fitted/all-kit/physics/wash/driving/parser, complete prepared551-resource2267/0 and desktop renderer/App checks pass. Dependent assets actually rebaked; four-source exact checkpoint, concurrent work/index preserved. [Before/after, implementation, commands and limits](docs/CHALLENGER_SIDE_AND_PROPORTIONS_2026_11_15.md). Reload/owner/device acceptance remains; no phone/FPS/AAA/export/backend/deployment/owner-save/process or shared-index action. Standard retention; no task pin.
<!-- /CHALLENGER-SIDE-PROPORTIONS-20261115 -->

'''
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
    path=ROOT/name;data=path.read_bytes();prefix=block.replace('(docs/CHALLENGER_SIDE_AND_PROPORTIONS_2026_11_15.md)','(CHALLENGER_SIDE_AND_PROPORTIONS_2026_11_15.md)') if name.startswith('docs/') else block
    if b'<!-- CHALLENGER-SIDE-PROPORTIONS-20261115 -->' not in data:path.write_bytes(prefix.encode('utf-8')+data)
print('SIDE_PROPORTIONS_FINAL current native publication, keys, comparisons and controls verified.')
