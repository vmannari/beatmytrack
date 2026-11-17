from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[3]
out=Path(__file__).resolve().parent
verified=json.loads((out/'final-verification.json').read_text())
assert verified['complete_preflight']['exit_code']==0
rear=json.loads((out/'candidate-rear.json').read_text())
seam=json.loads((out/'candidate-trunk.json').read_text())
checkpoint=json.loads((out/'source-checkpoint.json').read_text())
assert rear['failures']==0 and seam['failures']==0
assert all(hashlib.sha256((root/name).read_bytes()).hexdigest()==digest for name,digest in checkpoint['after'].items())
text=f"""# Challenger rear bumper and trunk refinement

The rear shelf beneath the tail lights now has a continuous rounded section and an even transverse surface. The trunk uses a smooth deck with a consistent 2.5 mm shut line seated on its final triangles.

## Requirements and source changes

**RRS01** Investigate the rear defects. The original packed shelf varied 4.36 mm in the reduced model and 4.40 mm in full detail. Large source triangles crossed the face, rolled edge and shelf. Their interpolated normals exaggerated the uneven geometry. The source trunk gutters also contained physical openings and irregular recessed edges.

**RRS02** Fair the bumper through the actual offline generator. One fitted transverse profile describes the face. A cubic section matches its tangent to the lamp shelf. Explicit join stations prevent long triangles spanning both surfaces. The rounded outer corners follow the lamp aperture. Shared boundary triangles close the small corner opening. Normals follow the geometric mapping, and the flat shelf uses its physical plane normal.

**RRS03** Rebuild the trunk surface and seams. A smooth symmetric deck replaces the irregular gutter geometry. Constrained triangulation retains the surrounding edge stations, and a bounded 0.75 mm weld removes clipping fragments within the same smooth chart. Forty paired stations define the new shut line. Its two sides are fitted to the actual paint before native pixel-coverage attributes are baked.

**RRS04** Deliver the change through the game. Model revision 18 refreshes the native bank, coarse geometry, modular parts, Garage models, previews and pictures. The authored sources are [rear geometry](../scripts/challenger_rear_surface.py), [converter integration](../scripts/prepare_challenger.py) and [model revision](../game/vehicle/super_rally_model.gd).

## Matched native views

| Before | Updated |
| --- | --- |
| ![Original rear shelf](evidence/{out.name}/views-before-matched/mobile/simple/white-rear-strip.png) | ![Refined rear shelf](evidence/{out.name}/views-final/mobile/simple/white-rear-strip.png) |
| ![Original trunk](evidence/{out.name}/views-before-matched/mobile/simple/red-trunk-top.png) | ![Refined trunk](evidence/{out.name}/views-final/mobile/simple/red-trunk-top.png) |

The final set includes 64 prepared-model views across both detail levels, both desktop renderers, white and red paint, rear angles, overhead views and a front control. Thirty-two matched before views use the same cameras and lighting.

## Triangle counts

| Model | Before | Updated | Change |
| --- | ---: | ---: | ---: |
| Assembled reduced | 49,944 | 49,910 | -34 |
| Assembled full detail | 80,790 | 80,892 | +102, +0.13% |
| Production reduced stock | 45,184 | 45,150 | -34 |

Both tiers retain 22 native material buckets. The existing 50k and 85k allocation checks pass.

## Actual validation

- The packed rear survey passes 16 checks. All 290 shelf samples per tier have coverage. Transverse height variation is below 0.001 mm, and the maximum normal deviation is below 0.006 degrees. Maximum inward chord errors are {rear['metrics']['simple']['bumper_inward_chord_mm']:.4f} mm reduced and {rear['metrics']['full']['bumper_inward_chord_mm']:.4f} mm full, within the existing 0.2 mm survey limit.
- All 7,857 trunk stations per tier have paint backing. The original controls had 208 reduced and 243 full-detail gaps. Eight seam checks pass. All 80 new ribbon vertices per tier have support, with approximately 1.77-1.88 mm clearance and a maximum physical half-width error below 0.036 mm.
- Protected front and side geometry stays within 0.064 mm of the original packed triangles. Nineteen other native mesh arrays match exactly. All 20 retain their topology and native attribute precision, including the red marker packet.
- Allocation passes 17 checks, panel contours 172, fitted kits 316 and the fitted-profile survey 144. Maximum fitted-profile error remains 0.857 mm against its 2 mm limit.
- Modules pass 1,436 checks, vehicle checks 3,677, wash 1,655, driving 72 and production parsing 583. The complete prepared preflight passes 2,267 checks across 551 resources.
- Both desktop renderers pass the final prepared views, 30 opacity checks and 13 actual App checks each. The unlit corner control changes from six dark pixels to zero after the adjoining edges are made conforming.
- The final vehicle fence covers {verified['stable_vehicle_inputs']:,} stable inputs. Sixty-four image imports and six current selection portraits pass their checks.

The actual entry commands were `python docs/evidence/{out.name}/run_preparation.py`, `qualify.py`, `deliver.py`, `checkpoint.py` and `finalize.py`. The evidence includes each subordinate command, exit code, consumed-source pin and output receipt. [Final verification](evidence/{out.name}/final-verification.json), [rear survey](evidence/{out.name}/candidate-rear.json), [seam survey](evidence/{out.name}/candidate-trunk.json) and [corner control](evidence/{out.name}/corner-pixels.json).

## Retained findings and review

Early projections left large triangles spanning the rounded edge and flat shelf. Join stations and shared edges resolve their residual waves and the corner opening found during final visual review. The 0.15 mm shelf, one-degree normal, 0.2 mm chord and original allocation limits remain in force.

The initial protected-geometry fixture compared new clipping stations with old vertex locations. It now measures distance to the original triangles, preserving its 0.08 mm geometry limit. This accommodates legitimate edge stations introduced by the repair. An initial Mobile App run logged two ObjectDB instances and one resource at shutdown. A fresh verbose repeat passes 13 checks with a clean shutdown. The initial capture dependency and optional Python image-library failure remain recorded. Native Godot performs the final image check.

Private checkpoint `{checkpoint['private_commit']}` contains the three authored source changes. Its patch applies and reverses byte-exactly, and checkpoint creation preserves the shared index. [Source patch](evidence/{out.name}/source-only.patch), [verified bundle](evidence/{out.name}/source-checkpoint.bundle).

The original native bank and final evidence are archived. Standard build retention applies. Reload the game to load the current assets. Owner appearance review remains pending. Physical Android testing and device FPS measurement were not performed.
"""
(root/'docs/CHALLENGER_REAR_SURFACE_2026_11_17.md').write_bytes(text.encode('utf-8'))
block=f"""<!-- CHALLENGER-REAR-SURFACE-20261117 -->
## Challenger rear shelf and trunk seams refined (2026-11-17)
RRS01-RRS04 use a shared offline bumper profile, tangent roll, conforming joins and a fitted trunk deck with 2.5 mm native shut lines. Revision 18 refreshes the real native bank and consumers. Shelf variation 4.36/4.40 mm to below 0.001 mm, normal error below 0.006 degrees and trunk gaps 208/243 to zero. Rear16/0, seam8/0, allocation17/0 and contours172/0 pass. Raw reduced49,944 to49,910, full80,790 to80,892 (+0.13%); production45,150. Fitted316/0+144/0, modules1436/0, physics3677/0, wash1655/0, driving72/0, parser583/0 and complete prepared551-resource2267/0 pass. Both desktop renderers qualify 64 final views, opacity30/0 and App13/0 each. Stable {verified['stable_vehicle_inputs']:,}-input fence,64 imports and six current portraits pass. Initial projection, fixture and corner-opening controls remain recorded; an initial Mobile shutdown warning has a clean fresh verbose repeat. Three-source reversible private checkpoint and standard retention preserve concurrent work and shared index. Reload, owner appearance and physical Android/FPS acceptance remain pending. [Changes, views, commands and limits](docs/CHALLENGER_REAR_SURFACE_2026_11_17.md).
<!-- /CHALLENGER-REAR-SURFACE-20261117 -->

"""
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
 path=root/name
 previous=path.read_bytes()
 if b'<!-- CHALLENGER-REAR-SURFACE-20261117 -->' in previous:continue
 prefix=block.replace('(docs/CHALLENGER_REAR_SURFACE_2026_11_17.md)','(CHALLENGER_REAR_SURFACE_2026_11_17.md)') if name.startswith('docs/') else block
 path.write_bytes(prefix.encode('utf-8')+previous)
 assert path.read_bytes().endswith(previous)
print('Rear report and project history updated')
