"""Write the scoped completion report from retained final receipts."""
from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
state=json.loads((OUT/'final-state.json').read_text());assert state['native_failures']==0
corners=json.loads((OUT/'candidate-seams-corners.json').read_text())
shape=json.loads((OUT/'candidate-shape.json').read_text())
complete=re.search(r'PREPARED_ASSETS (.+)',(OUT/'prepared-complete.log').read_text()).group(1)
raw=state['raw_assembled_triangles'];stock=state['production_stock_triangles'];tag=OUT.name
report=f"""# Challenger hood, seams and front corners ? 16 November 2026

The owner requested a replacement Challenger hood, cleaner bonnet seams and a smaller downward-rolling front corner viewed above the outer headlight. The selected variant follows the supplied Demon-style reference with one wide forward intake and two extractors. The single-inlet design choice follows Dodge's description of the 2018 Demon Air-Grabber. [Official Dodge design reference](https://dodgeblogsdev.azurewebsites.net/features/re-imagining-the-air-grabber-hood-scoop/)

[Final corner](evidence/{tag}/final/mobile/white-owner-corner.png) ? [Final hood seams](evidence/{tag}/final/mobile/white-hood-top.png) ? [Full-detail corner](evidence/{tag}/final-full/gl_compatibility/white-owner-corner.png) ? [Previous corner](evidence/{tag}/before-corners/white-owner-corner.png) ? [Previous seams](evidence/{tag}/before-corners/white-hood-top.png)

## Geometry and shading

- HDR01 replaces both former bonnet surfaces with a coherent deck, a longitudinal intake roof, an actual open mouth and two recessed extractor wells. The raised centre blends into the low surrounding deck. Native checks measure a 530 mm visible intake width, 29 mm opening height and approximately 39 mm tunnel depth. Both extractor beds sit about 7.84 mm below their neighbouring deck samples. The old exposed centre plate and its elevated trim are removed from the generated asset.
- HDR02 corrects physical voids beside the bonnet with a regular offline three-row bank seated 1.5 mm beneath the adjoining skins. Every one of 384 perimeter stations has body support 6 mm outside the hood in each detail level. The preceding model supported 181 stations in the reduced tier and 201 in the full tier. A shared local normal field aligns the outward bank with this same perimeter loft, covering 562 reduced-tier and 1,144 full-tier triangle corners. Returned surfaces and the upright aperture bevel retain separate normal domains.
- HDR03 lowers the marked outer crown by 4.10?8.00 mm using a smooth longitudinal blend. Both corners retain their transverse and longitudinal placement. The black carrier is trimmed to the measured white aperture edge. Lamp optics, wheel geometry, glazing, roof and accepted lower sides retain their checked data or positions. The original nose normal-transform orientation guard remains above 0.65. Independent packed-position errors are recorded in candidate-seams-corners.json.
- HDR04 regenerates the existing bonnet fitting profile and uses model revision 15 for the updated native resources and fitted parts. The replacement stock geometry is baked into the established material batches.

## Triangle cost

| Model | Before | Final | Change |
|---|---:|---:|---:|
| Assembled reduced source | 49,700 | {raw['simple']:,} | {raw['simple']-49700:+,} |
| Assembled full source | 83,154 | {raw['full']:,} | {raw['full']-83154:+,} |
| Production fixed and editable | 44,940 | {stock[0]:,} | {stock[0]-44940:+,} |

The assembled reduced source increases {(raw['simple']/49700-1)*100:.2f}%. The original 50k/85k allocation checks pass.

## Actual validation

The final native hood audit passes {shape['checks']}/0 and the seam/corner audit passes {corners['checks']}/0. The previous geometry rejects four seam/corner controls. Allocation passes 17/0, contours 172/0, fitted hood 316/0, direct profile fitting 80/0 with a maximum 0.731 mm error, modules 1436/0, physics 3677/0, wash 1655/0, driving 72/0 and production parsing 581/0.

The actual prepared Challenger consumer passes 349 checks across 84 resources. Compatibility and desktop Mobile each pass native opacity 30/0 and the actual Garage/race App 13/0. Each renderer has 22 reduced and 11 full-detail review captures. Their model-path receipts require real prepared-cache restoration. All eight car configuration files, canonical simulation/handling sources and four unused legacy native resources remain byte-exact.

The real dependent base, kit, Garage, header, artwork, livery and picture assets were regenerated. Image import verifies 64 files. The bake fence covers {state['bake_input_count']:,} stable inputs. Six selection portraits qualify against 25,651 inputs. The complete project cache preflight reports {complete}. Its findings concern other vehicles.

## Source and retained controls

The five authored sources are scripts/challenger_hood_geometry.py, scripts/challenger_reference_form.py, scripts/challenger_nose_finish.py, scripts/prepare_challenger.py and game/vehicle/super_rally_model.gd. The source-only patch applies and reverses byte-exactly in a private checkpoint. The shared Git index is preserved.

Actual commands and receipts are retained beside this report for run_preparation.py, review_native.py, check_shape.py, check_seams_corners.py, deliver.py, gpu_checks.py, checkpoint.py and finalize.py. Preparation uses the retained measured source-panels.npz because the original downloaded blend file is absent. The two original material roles and existing normal/export pipeline carry the replacement hood.

An early preview substituted cached reduced trim and was excluded from acceptance. The final preview and all receiving checks use the actual rebuilt resources. The unchanged native symmetry assertion rejected an unsplit centreline bank. The offline bank is now split and mirrored before export. Stronger nose and seam-bank deformation prototypes were rejected. Final Mobile reflections exposed a local normal mismatch, which led to the bounded outward-bank normal alignment. Rejection receipts remain under seam-development, including the first landmark fixture and the preceding published candidate.

Owner appearance review and physical-phone acceptance remain. Physical-device testing was not performed. Standard retention kept recent or protected entries above the 20 GiB target. Task-owned cleanup removed 1,093,867,180 bytes. Both operations have separate receipts.
"""
(ROOT/'docs/CHALLENGER_HOOD_REDESIGN_2026_11_16.md').write_text(report,encoding='utf-8')
marker='CHALLENGER-HOOD-REDESIGN-20261116'
entry=f"""<!-- {marker} -->
## Challenger replacement hood, clean seams and downturned corners (2026-11-16)
HDR01-HDR04 use the supplied Demon-style reference for an open forward intake and two recessed extractors. Regular offline banks provide 384/384 perimeter support in both tiers, with shared outward normals. Marked crowns lower 4.10?8.00 mm and the carrier follows the measured aperture. Revision15 refreshes the fitting profile. Native152/0, seam/corner10/0, allocation17/0, contours172/0, fitting316/0+80/0, modules/physics/wash/driving/parser/scoped prepared and both desktop renderer/App checks pass. Raw{raw['simple']}/{raw['full']}, stock{stock[0]}, reduced-source+{(raw['simple']/49700-1)*100:.2f}%. Real consumer/image rebuilds, {state['bake_input_count']}-input fence and five-source exact checkpoint retained. Broader cache findings and owner/phone acceptance remain. Standard retention and concurrent index/work preservation apply. [Views, changes, commands and limits](docs/CHALLENGER_HOOD_REDESIGN_2026_11_16.md).
<!-- /{marker} -->

"""
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
 path=ROOT/name;data=path.read_bytes()
 if ('<!-- '+marker+' -->').encode() not in data:
  assert path.read_bytes()==data
  path.write_bytes(entry.encode()+data)
print('HOOD_REPORT_WRITTEN')
