"""Retain the accepted front/exhaust correction, controls and actual scope."""
from pathlib import Path
import hashlib,gzip,json,re,shutil
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent;BUILD=ROOT/'build'/OUT.name
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
shape=json.loads((OUT/'candidate-shape.json').read_text());assert shape['failures']==0
audit=json.loads((OUT/'candidate-audit.json').read_text());baseline=json.loads((OUT/'baseline-shape.json').read_text());assert baseline['failures']==28
pub=json.loads((OUT/'native-publication.json').read_text());assert all(sha(ROOT/'game/assets/vehicles/challenger_hellcat_v1'/name)==digest for name,digest in pub['private_native'].items())
prep=json.loads((OUT/'preparation-command.json').read_text());assert prep['stable'] and prep['exit_code']==0
assert all(sha(Path(name))==digest for name,digest in prep['after'].items())
checkpoint=json.loads((OUT/'source-checkpoint.json').read_text());assert checkpoint['forward_reverse_byte_exact']
assert all(sha(ROOT/name)==digest for name,digest in checkpoint['after'].items())
start=json.loads((OUT/'task-start.json').read_text());controls={name:sha(ROOT/name)==digest for name,digest in start.items() if name.startswith('game/resources/cars/') or name in ['game/vehicle/handling_config.gd','game/vehicle/vehicle_simulation.gd']};assert all(controls.values())
legacy={name:sha(ROOT/name)==digest for name,digest in start.items() if name.startswith('game/assets/vehicles/challenger_hellcat_v1/') and Path(name).name not in pub['private_native']};assert len(legacy)==4 and all(legacy.values())
labels=['native-bake','candidate-export','allocation','candidate-contours','before-final','coarse','livery','portraits','fitted-hood','modules','physics','wash','driving','production-parse','prepared-scoped','native-refresh','opacity-gl','prepared-views-gl','opacity-mobile','prepared-views-mobile','prepared-close-gl','prepared-close-mobile','app-gl','app-mobile']
diagnostics={}
for label in labels:
    r=json.loads((OUT/(label+'-command.json')).read_text());assert r['exit_code']==0 and r['script_errors']==0,label
    diagnostics[label]=[line for line in (OUT/(label+'.log')).read_text(encoding='utf-8',errors='replace').splitlines() if line.startswith(('ERROR:','WARNING:')) or 'ObjectDB instances leaked' in line]
scope=json.loads((OUT/'delivery-scope.json').read_text());assert scope['challenger_scoped_passed']
fence=json.loads((BUILD/'assets/source-receipt.json').read_text());assert fence['before']==fence['after']
identity=json.loads((BUILD/'assets/client-build-identity.json').read_text(encoding='utf-8-sig'));live=json.loads(re.search(r'MODULAR_CAR_SHA256: Dictionary = (\{[^\n]+\})',(ROOT/'game/core/build_identity.gd').read_text())[1]);assert live==identity['modular_car_sha256']
raw=json.loads((OUT/'allocation.log').read_text().split('; ')[-1].strip());assembled={('simple' if r['simple'] else 'full'):r['triangles'] for r in raw};assert assembled=={'simple':49970,'full':83582}
stock=[int(n) for n in re.findall(r'COARSE_STOCK super_rally editable=\w+ triangles=(\d+)',(OUT/'coarse.log').read_text())];assert stock==[45210,45210]
retained={}
def keep(source,dest):
    dest.parent.mkdir(parents=True,exist_ok=True)
    if dest.suffix=='.gz':dest.write_bytes(gzip.compress(source.read_bytes(),compresslevel=9,mtime=0))
    else:shutil.copyfile(source,dest)
    retained[dest.relative_to(OUT).as_posix()]=sha(dest)
for name in ['baseline.json','candidate.json']:keep(BUILD/name,OUT/(name+'.gz'))
for renderer in ['gl_compatibility','mobile']:
    r=json.loads((BUILD/'app'/renderer/'acceptance.json').read_text());assert r['checks']==13 and r['failures']==0
    for name in ['white-owner-side.png','white-owner-front-right.png','white-nose-right.png','white-profile.png','white-rear-corner.png','red-owner-front-right.png']:
        keep(BUILD/'views-final'/renderer/'simple'/name,OUT/'final'/renderer/name)
    for name in ['white-nose-right.png','white-rear-corner.png']:keep(BUILD/'views-final-close'/renderer/'full'/name,OUT/'final-full'/renderer/name)
    for p in (BUILD/'app'/renderer).rglob('*'):
        if p.is_file() and p.suffix in ['.json','.png']:keep(p,OUT/'final/app'/renderer/p.relative_to(BUILD/'app'/renderer))
for name in ['white-owner-side.png','white-nose-right.png','white-rear-corner.png']:keep(BUILD/'views-before/gl_compatibility/simple'/name,OUT/'before'/name)
for p in (BUILD/'assets').iterdir():
    if p.is_file() and p.suffix in ['.json','.log']:
        dest=OUT/'asset-receipts'/p.name
        if p.stat().st_size>500000:dest=Path(str(dest)+'.gz')
        keep(p,dest)
receipt={'native_checks':shape['checks'],'native_failures':0,'assembled_triangles':assembled,'production_stock_triangles':stock,'configuration_and_simulation_exact':controls,'unused_legacy_exact':legacy,'bake_input_count':len(fence['after']),'complete_preflight_exit_code':scope['complete_preflight_exit_code'],'diagnostics':{k:v for k,v in diagnostics.items() if v},'retained':retained};(OUT/'final-state.json').write_text(json.dumps(receipt,indent=2))
m=shape['metrics'];improvement={tier:100*(1-v['front_rms_after_mm']/v['front_rms_before_mm']) for tier,v in m.items()}
whole='The complete prepared-resource check also passes.' if scope['complete_preflight_exit_code']==0 else 'The complete prepared-resource check retains out-of-scope findings from concurrent livery changes. Those original findings remain in prepared-complete.log; whole-project prepared readiness is not claimed.'
report=f'''# Challenger front crown and connected exhausts - 15 November 2026

The owner rejects the still bulky and uneven forward bonnet/wing transition and the apparent detached exhaust tips. The marked side view and earlier vehicle photograph guide this refinement.

[Before front](evidence/{OUT.name}/before/white-nose-right.png) / [After front](evidence/{OUT.name}/final/gl_compatibility/white-nose-right.png)

[Before side angle](evidence/{OUT.name}/before/white-owner-side.png) / [After side angle](evidence/{OUT.name}/final/gl_compatibility/white-owner-side.png)

[Before exhaust](evidence/{OUT.name}/before/white-rear-corner.png) / [After exhaust](evidence/{OUT.name}/final/gl_compatibility/white-rear-corner.png)

FCR01 - Actual cause. The continuous-side chart previously faded out before the visible nose corner. Its normals were still applied to some vertices that could not be geometrically projected onto that chart, producing false surface folds. The existing chart now surveys the forward region and applies normal interpolation with the same projection weight as the geometry. It retains the nose aperture's deliberate inward returns and fades at the actual bonnet boundary to preserve its panel gap. No separate smoothing layer or material adjustment is introduced.

FCR02 - Front proportions and flow. A bounded C2 thinning/taper correction lowers the marked crown by approximately {m['simple']['mean_crown_drop_mm']:.2f} mm reduced / {m['full']['mean_crown_drop_mm']:.2f} mm full in paired transverse sampling. An additional maximum18mm inward adjustment per side reduces the swollen outer corner while preserving the existing lamp layout. The fitted-hood helper uses the same coordinate map. Roof/pillars, glazing, rear proportions, wheel positions, handling and the earlier shortening are retained. The independent native audit measures front normal-contour residual improvements of {improvement['simple']:.1f}% / {improvement['full']:.1f}%, after removing a fifth-degree longitudinal trend from15/20/22degree reflected-normal contours. The accepted sides retain their existing smoothness within explicit sampling/packing allowances. This is a surface-flow measure, not a universal G2, pixel-identity, AAA, FPS or device claim.

FCR03 - Physical exhaust connection. The former short tips overlapped only the upper valance. Existing ring vertices now form a narrower neck with a239mm longitudinal span, lifted at the root, with only25mm mouth projection. Every sampled vertex of both complete inboard root loops is hidden at least150mm behind the actual bumper skin. The dark bore is placed ahead of the obstructing rear sheet so the mouth stays open. The original oval mouth dimensions, material buckets and triangle allocation are retained; no extra runtime mesh is created.

FCR04 - Cached native resources. The preceding builder retained native meshes by path and could keep the previous loaded ArrayMesh after an asset revision. The updated builder clears the previous native generation and replaces engine-cached mesh data once per model revision, then shares the current immutable meshes. A private warm-cache regression compiles the actual task-start builder, reproduces its stale resource, and verifies that the new builder restores the exact current native arrays and reuses them thereafter:6/0 checks. Model key advances to11.

FCR05 - Verification and delivery. Native acceptance passes150/0 and rejects the task-start model150/28. Original panel-contour172/0 and allocation17/0 assertions pass. Raw reduced49,958to49,970 (+12); full83,940to83,582 (-358). Production fixed/editable45,198to45,210 (+0.027%). Fitted hood316/0, Challenger modules1436/0, physics/replay3677/0, wash1655/0, driving72/0, parsing and strict Challenger-scoped prepared validation pass. Opacity30/0 and actual Garage/race App13/0 pass in both desktop renderers, with actual prepared-cache hits. The actual desktop Mobile receiving run recorded252,996.796ms Garage entry before completing; that cold-entry sample is not qualified for latency or device acceptance. {whole}

Five authored sources: `scripts/challenger_side_finish.py`, `scripts/challenger_nose_finish.py`, `scripts/challenger_detail_geometry.py`, `scripts/prepare_challenger.py`, `game/vehicle/super_rally_model.gd`. Fresh source conversion and native validation precede guarded48-file publication, actual dependent base/kit/Garage/header/image rebuilds and native imports. The accepted bake closes {len(fence['after']):,} inputs. The five-source patch applies/reverses byte-exactly in a private repository. Configuration/simulation and four unused legacy controls remain exact; concurrent work/index are preserved. No metadata-only restamping substitutes for actual changed geometry.

Rejected separate height-chart prototypes produced a crease; a first extended-side prototype moved the bonnet bank and was rejected before publication. The final source protects the actual hood boundary. Early prototype centre-crossing/timing failures, mismatched fixed-X crown sampling and concurrent livery/identity source-fence rejections remain in rejections.json and adjacent rejected folders. The paired crown survey retains the original35mm material-station bound while preserving the fixed-X measurements separately. No repository assertion was weakened. Known diagnostics remain in final-state.json.

Exact commands and results are beside this report: `run_preparation.py`, native `run_check.py` receipts, `audit_surface.py`, `check_shape.py`, `deliver.py`, `test_native_refresh.gd`, `gpu_checks.py`, `checkpoint.py`, `run_retention.py`, `finalize.py`. Standard retention and task-only disposable cleanup have separate receipts. No physical-device test, export, backend request, deployment, owner-save/process action or shared-index staging/commit was performed. Reload before owner appearance review; phone/device acceptance remains.
'''
(ROOT/'docs/CHALLENGER_FRONT_CROWN_2026_11_15.md').write_text(report,encoding='utf-8')
block=f'''<!-- CHALLENGER-FRONT-CROWN-20261115 -->
## Challenger front crown thinned and exhaust necks physically connected (2026-11-15)
FCR01-FCR05: continuous-side chart reaches the nose, normal weight follows geometric projection, actual bonnet boundary and inward aperture returns are protected. C2 crown reduction approximately{m['simple']['mean_crown_drop_mm']:.2f}mm, additional18mm maximum corner inset, front reflection residual-{improvement['simple']:.1f}%/-{improvement['full']:.1f}%; established sides retained. Existing exhaust rings form239mm necks, complete roots hidden>150mm and25mm mouth projection. Revision11 native cache replacement passes6/0 with actual original stale control. Native150/0 rejects150/28, contours172/0, allocation17/0 and fitted/modules/physics/wash/driving/parser/scoped prepared/desktop renderer/App checks pass. Raw49970/83582; production45210(+12tri). Five-source exact checkpoint, actual consumer/image rebuilds and {len(fence['after'])}-input bake. Rejected crease/gap prototypes and concurrent livery/global-cache findings retained; concurrent work/index preserved. [Views, implementation, commands and limits](docs/CHALLENGER_FRONT_CROWN_2026_11_15.md). Reload/owner/device acceptance remains; no phone/FPS/AAA/export/backend/deployment/owner-save/process or shared-index action. Standard retention; no task pin.
<!-- /CHALLENGER-FRONT-CROWN-20261115 -->

'''
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
    p=ROOT/name;data=p.read_bytes();prefix=block.replace('(docs/CHALLENGER_FRONT_CROWN_2026_11_15.md)','(CHALLENGER_FRONT_CROWN_2026_11_15.md)') if name.startswith('docs/') else block
    if b'<!-- CHALLENGER-FRONT-CROWN-20261115 -->' not in data:p.write_bytes(prefix.encode('utf-8')+data)
print('FRONT_CROWN_CLOSED source, native surface flow, physical exhaust roots, warm-cache regression and prepared views verified.')
