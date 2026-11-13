from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
receipt=json.loads((OUT/'final-acceptance.json').read_text(encoding='utf-8'))
assert all(v['failures']==0 for group in [receipt['opacity'],receipt['actual_app']] for v in group.values())
marker='CHALLENGER-SURFACE-20261109'
summary=(
 'CHR01-CHR04: Owner requests contour-only doors/handles/fuel cap, a cleaner hood, longer nose and fewer surface artefacts. '
 'Thin continuous door skins, flattened connected fuel embossing and unshadowed contour markings replace the raised details. '
 'Measured-boundary regular hood/flush vents, roof boundary retention, fitted side normals and inset glazing backing improve the surface. '
 'Ray-picked exposed grille backing is narrowed/lowered; nose gains14cm ahead of the front arch with original contacts/198km/h tune exact. '
 'Production28577tri/full48996; original source and21 shared/canonical controls exact. '
 'Geometry27/0, fitted316/0, module/ghost1438/0, prepared physics/replay3677/0, wash1655/0, driving72/0 and parser554/0 pass. '
 'Super-only Garage shadow bias removes bumper mottling with casters/range retained and20/0 switch/default restoration checks. '
 'Native opacity/contour30/0 and actual App13/0 each desktop renderer pass. '
 f'Coherent{receipt["stable_asset_inputs"]}-input/15-command geometry plus7-command presentation refresh passes551-resource2267/0 and six-picture157-source provenance; normal Rally geometry/20 PNG controls exact. '
 'Source-pinned final conversion, retained drafts, fixture-output correction and ten-file reverse-checked source checkpoint are recorded. '
)
receipts={}
for relative,link in [('AGENTS.md','docs/CHALLENGER_SURFACE_REFINEMENT_2026_11_09.md'),('DEVELOPMENT_STATUS.md','docs/CHALLENGER_SURFACE_REFINEMENT_2026_11_09.md'),('docs/PHASE_0_PLAN.md','CHALLENGER_SURFACE_REFINEMENT_2026_11_09.md')]:
    path=ROOT/relative;before=path.read_bytes();assert marker not in before.decode('utf-8')
    archive=OUT/'tracking-before'/relative;archive.parent.mkdir(parents=True,exist_ok=True);archive.write_bytes(before)
    prefix=(f'<!-- {marker} -->\n## Challenger details made flush, hood smoothed and nose extended (2026-11-09)\n\n'+summary+f'[Changes, native comparisons, commands, receipts and limits]({link}). '
      'Reload/owner appearance and device qualification remain; no device query/test, APK, owner-save/process change, backend request, deployment or main-index write; concurrent work preserved.\n'+f'<!-- /{marker} -->\n\n')
    assert path.read_bytes()==before,'Concurrent tracking update; retry from the new input'
    path.write_bytes(prefix.encode('utf-8')+before);after=path.read_bytes();assert after.endswith(before)
    receipts[relative]={'before':hashlib.sha256(before).hexdigest(),'after':hashlib.sha256(after).hexdigest(),'prior_text_exact':True}
(OUT/'tracking-receipt.json').write_text(json.dumps(receipts,indent=2),encoding='utf-8')
print('CHALLENGER_SURFACE_TRACKING: all prior records retained verbatim')
