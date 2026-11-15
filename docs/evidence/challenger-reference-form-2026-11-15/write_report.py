from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
quality=json.loads((OUT/'native-quality-final.json').read_text())
baseline=json.loads((OUT/'baseline-quality-final.json').read_text())
scope=json.loads((OUT/'asset-receipts/final-scope.json').read_text())
native=json.loads((ROOT/'game/assets/vehicles/challenger_hellcat_v1/source.json').read_text())
legacy=json.loads((OUT/'native-side-diagnostic.json').read_text())
start=json.loads((OUT/'task-start.json').read_text());pub=json.loads((OUT/'native-publication.json').read_text())
changed=sum(start.get('game/assets/vehicles/challenger_hellcat_v1/'+name)!=digest for name,digest in pub['private_native'].items())
assert quality['checks']==30 and quality['failures']==0 and baseline['failures']==12
assert scope['full_preflight']['exit_code']==0
metrics=quality['metrics'];old=baseline['metrics']
report=f'''# Challenger reference form — 15 November 2026

The owner rejects the current Challenger against the supplied clean white-car reference. This pass changes the bonnet and front proportions rather than continuing to preserve the rejected original bonnet exactly. The final [prepared Garage view](evidence/{OUT.name}/final/views-final/gl_compatibility/simple/white-front-quarter.png), [front view](evidence/{OUT.name}/final/views-final/gl_compatibility/simple/white-front.png), and [cowl close-up](evidence/{OUT.name}/final/views-final-close/gl_compatibility/full/red-cowl.png) use the actual rebuilt game assets. The [earlier cowl render](evidence/{OUT.name}/cowl-before.png) retains the dent found during visual review.

**CRF01 — Broader, rounded front.** A common final-coordinate taper widens the nose progressively by up to 9.5%, with the lamp carrier and trim following the same form. Four freshly authored circular projectors share a near-upright front plane. A rounded white rim, a real aperture cut, and the recessed black carrier replace the malformed grille edges. The central and lower grilles have geometric honeycomb cells. The new aperture has a 61 mm inner corner radius; its carrier radius is 63 mm. The frame and openings are geometry, with no runtime ray fitting.

**CRF02 — Regular bonnet and cowl.** A smooth bonnet crown, a restrained 42 mm central power bulge and rounded boundary replace the inherited bonnet folds. Its curved rear edge retains the windshield/cowl layout. Full and reduced bonnets use regular triangulation, unchanged vent paths, and native supported 2.5 mm markings. The fitted-hood height grid is regenerated in the existing attachment domain. The upper wing now joins that bonnet through a manufactured section using exactly the lower side's shoulder and width curves. This removes the dent below the windshield and keeps the long bend continuous. A close render exposed the dent after the first publication; this final chart is included in the final publication and fresh receiving-app checks.

The source also contains a thin inward returned skin near the nose. The shared fairing could put it just outside the visible skin, producing reverse normal hits. The converter removes only inward returns with outward paint proven within 5 mm at their centroids: {int(native['tiers']['full']['clean_panels']['manufactured_exterior']['reference_form']['covered_nose_return_triangles_removed'])} full and {int(native['tiers']['simple']['clean_panels']['manufactured_exterior']['reference_form']['covered_nose_return_triangles_removed'])} reduced triangles. The existing shoulder normal/support/outward checks now pass in both tiers. No existing repository assertion was changed.

**CRF03 — Reference wheel proportions and preserved controls.** Factory alloy surfaces scale by 1.14 in the wheel plane and use darker gunmetal. The tyre radius, wheel centres, game scale, chassis, canonical configurations, driving/replay logic and purchased rim designs remain. Reduced factory lugs use six-sided hardware. Roof and rear source positions are retained; changed native body bounds introduce at most {max(v['rear_native_packing_error_mm'] for v in metrics.values()):.3f} mm of coordinate-packing difference. This is measured shape retention, not byte-identical native vertices.

| Native measurement | Task start | Final |
| --- | ---: | ---: |
| Front half-width, full | {old['full']['front_half_width']*1000:.2f} mm | {metrics['full']['front_half_width']*1000:.2f} mm |
| Front half-width, reduced | {old['simple']['front_half_width']*1000:.2f} mm | {metrics['simple']['front_half_width']*1000:.2f} mm |
| Lamp/grille median depth separation | {old['full']['lamp_grille_depth_mm']:.2f} mm | {metrics['full']['lamp_grille_depth_mm']:.2f} mm |
| Largest broad bonnet normal step, full/reduced | {old['full']['bonnet_normal_max_degrees']:.2f} / {old['simple']['bonnet_normal_max_degrees']:.2f} degrees | {metrics['full']['bonnet_normal_max_degrees']:.2f} / {metrics['simple']['bonnet_normal_max_degrees']:.2f} degrees |
| Largest cowl normal step, full/reduced | {old['full']['cowl_normal_max_step_degrees']:.3f} / {old['simple']['cowl_normal_max_step_degrees']:.3f} degrees | {metrics['full']['cowl_normal_max_step_degrees']:.3f} / {metrics['simple']['cowl_normal_max_step_degrees']:.3f} degrees |
| Front bonnet height drop across the surveyed 160 mm, full/reduced | {old['full']['front_bonnet_drop_mm']:.2f} / {old['simple']['front_bonnet_drop_mm']:.2f} mm | {metrics['full']['front_bonnet_drop_mm']:.2f} / {metrics['simple']['front_bonnet_drop_mm']:.2f} mm |

The normal surveys exclude intentional vent walls. Native cowl tracks have 137/137 supported samples each. The unchanged old side suite still rejects eight original-bonnet/bounds/pixel-coordinate/silhouette preservation checks: the owner now requests a different front and bonnet, and packed vertices differ below 0.1 mm. Its 18 shoulder tangent/support checks and two outward-shading checks pass; maximum shoulder normal steps are {max(x['maximum_normal_step_degrees'] for x in legacy['metrics']['full']['shoulder_tracks']):.2f} degrees full and {max(x['maximum_normal_step_degrees'] for x in legacy['metrics']['simple']['shoulder_tracks']):.2f} degrees reduced. The complete legacy rejection is retained, with no assertion relaxed.

**CRF04 — Rebuild and verify the receiving paths.** All {changed} native allowlist files differ from task start; four unused legacy native resources remain unchanged. Final raw stock counts are 49,462 reduced / 82,452 full, below the existing 50k/85k limits. Production reduced fixed/editable stock is 44,702 triangles in both cases. Compared with task start's raw 48,572/82,332, the geometry cost is +890/+120 triangles. The reduced bonnet uses 40 mm interior spacing with its boundary, vent paths and analytic normals retained.

| Final verification | Result |
| --- | --- |
| Independent reference-form survey / task-start control | 30/0 / 30/12 |
| Native allocation / live panel contours | 17/0 / 172/0 |
| Fitted hood / all Super Rally modules | 316/0 / 1,436/0 |
| Physics and replay / wash / driving | 3,677/0 / 1,655/0 / 72/0 |
| Production parser | 576 scripts, 0 failures |
| Prepared opacity / actual Garage and race App | 30/0 / 13/0 per desktop renderer |
| Prepared native views | 22 reduced + 6 full close-ups per renderer |
| Complete prepared preflight | 551 resources, 2,267 checks, 0 failures |
| Challenger scoped prepared preflight | 84 resources, 349 checks, 0 failures |
| Native catalogue / imports / workshop | 173 source hashes / 58 imports / 28 source hashes |
| Final consumed-input fence | {scope['stable_inputs']:,} unchanged inputs |

Both desktop renderers use actual prepared cache hits. The final Mobile App passes its 13 assertions but retains a two-object/one-resource shutdown diagnostic; no clean-shutdown fix is claimed. No phone, FPS, pixel-identity, exact single-photo reconstruction, AAA finish or whole-project acceptance claim is made. Fine source faceting at fittings and some original edge joins remains.

Intermediate inherited-outline support failures, centre-crossing symmetry failures, stale prepared module/physics rejections, the retained inward-return survey, and a capture rejected during generated version stamping explain the discarded attempts. Final conversion inputs, native publication, source checkpoint, identity keys, current imports and preview provenance are checked again in `final-state.json`. Final native consumers were actually rebuilt; no asset metadata-only restamp substitutes for generation.

The [four-source incremental checkpoint](evidence/{OUT.name}/source-only.patch) applies and reverses byte-exactly in a disposable private repository. Concurrent model/UI/index work is preserved. Other car model sources and physical configurations were not authored. No owner save/process, device, export, backend, deployment or main-index staging action was performed. Standard build retention is recorded separately, with no task pin. Restart the game/project to discard cached in-memory model resources before appearance review.

Completed commands and exact arguments are retained beside the report. The final ordered invocation is:

```text
python docs/evidence/{OUT.name}/run_preparation.py
python docs/evidence/{OUT.name}/final_pass.py
python docs/evidence/{OUT.name}/checkpoint.py
python docs/evidence/{OUT.name}/retain_final.py
python docs/evidence/{OUT.name}/run_retention.py
```
'''
(ROOT/'docs/CHALLENGER_REFERENCE_FORM_2026_11_15.md').write_text(report,encoding='utf-8')
journal='''<!-- CHALLENGER-REFERENCE-FORM-20261115 -->
## Challenger front and bonnet follow the supplied reference (2026-11-15)
CRF01-CRF04: Progressive broader nose, rounded white aperture rim and coplanar four-projector carrier, regular downturned bonnet and shared upper-wing chart replace the rejected pinched front, bonnet folds and cowl dent. Factory alloys are larger/darker; tyre radius, wheel centres, roof/rear source positions, scale and handling remain. Covered inward nose returns are removed after an outward-skin proof; native packing differs <=0.068mm. Native30/0 rejects baseline30/12; shoulder support/tangents/outward checks pass, while eight superseded exact-bonnet/bounds/packing/silhouette controls remain rejected. Raw49462/82452tri fits50k/85k; production44702 fixed/editable. Allocation17/0, contours172/0, fitted316/0, modules1436/0, physics3677/0, wash1655/0, driving72/0, parser576/0, opacity30/0 and actual App13/0 each desktop renderer pass. Complete551-resource2267/0, scoped84-resource349/0, photo173-source,58 imports and workshop28-source pass. Mobile App retains2-object/1-resource teardown diagnostic; no AAA/pixel/FPS/device/whole-project acceptance claim. Native48/four legacy controls and four-source exact checkpoint retained; initial outline/symmetry/cache/version rejections documented. [Implementation, final views, commands and limits](docs/CHALLENGER_REFERENCE_FORM_2026_11_15.md). Restart/owner appearance remains; no owner-save/process, device/export/backend/deployment or main-index action. Standard retention recorded; no task pin.
<!-- /CHALLENGER-REFERENCE-FORM-20261115 -->

'''
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md']:
    path=ROOT/name;old_text=path.read_text(encoding='utf-8-sig')
    assert '<!-- CHALLENGER-REFERENCE-FORM-20261115 -->' not in old_text
    path.write_text(journal+old_text,encoding='utf-8')
print('REFERENCE_FORM_REPORT source scope, final views, actual checks and limits recorded')
