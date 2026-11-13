from pathlib import Path
import hashlib,json

ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
receipt=json.loads((OUT/'final-acceptance.json').read_text(encoding='utf-8'))
assert all(v['failures']==0 for group in [receipt['opacity'],receipt['actual_app']] for v in group.values())
assert (ROOT/'docs/CHALLENGER_QUALITY_REFINEMENT_2026_11_12.md').exists()
marker='CHALLENGER-QUALITY-20261112'
summary=(
 'CHQ01-CHQ04: Owner requests review/refinement toward AAA quality; AAA finish remains unclaimed. '
 'Authored four-projector optics/light guides, open-cell grille, measured-curve smoked rear panel, rolled exhaust tips, shallow recessed hood vents and concave split-spoke wheels replace weak details. '
 'Consistent opaque glazing normals and local automotive finishes improve close views; original roof boundary, flush contours, no interior and 198km/h/contact tune remain. '
 'Production45389tri/full78697 deliberately raises geometry cost; allocation50k/85k, no tablet-performance claim. '
 'Geometry27/0, fitted316/0, modules/ghost1438/0, prepared physics/replay3677/0, wash1655/0, driving72/0, parser555/0 and shadow-switch20/0 pass; opacity30/0 and actual App13/0 each desktop renderer pass. '
 f'Coherent{receipt["stable_asset_inputs"]}-input/15-command refresh passes551-resource2267/0 and six-picture158-source provenance; Rally geometry/16 PNG controls exact; four concurrent Kart picture updates retained. Four normal thumbnail render differences2/6/6/83pixels are documented; final live provenance/prepared audits pass. The20-image byte-identity gate remains unmet. '
 'Original blend/24 controls exact; six-source reverse-checked checkpoint and50 native hashes retained. '
 'Roof/grille/fascia drafts, optical-hole survey failures and corrected Blender exit/fresh-output qualification are retained. '
 'Concurrent Kart steering changes are preserved and excluded from the authored patch. '
)
receipts={}
for relative,link in [('AGENTS.md','docs/CHALLENGER_QUALITY_REFINEMENT_2026_11_12.md'),('DEVELOPMENT_STATUS.md','docs/CHALLENGER_QUALITY_REFINEMENT_2026_11_12.md'),('docs/PHASE_0_PLAN.md','CHALLENGER_QUALITY_REFINEMENT_2026_11_12.md')]:
    path=ROOT/relative;before=path.read_bytes();assert marker not in before.decode('utf-8')
    archive=OUT/'tracking-before'/relative;archive.parent.mkdir(parents=True,exist_ok=True);archive.write_bytes(before)
    prefix=(f'<!-- {marker} -->\n## Challenger exterior details and materials refined after quality review (2026-11-12)\n\n'+summary+
        f'[Review, native comparisons, commands, tradeoffs and limits]({link}). '
        'Reload/owner art acceptance and device qualification remain; no device query/test, APK, owner-save/process change, backend request, deployment or main-index write.\n'+f'<!-- /{marker} -->\n\n')
    assert path.read_bytes()==before,'Concurrent tracking update; retry from the new input'
    path.write_bytes(prefix.encode('utf-8')+before);after=path.read_bytes();assert after.endswith(before)
    receipts[relative]={'before':hashlib.sha256(before).hexdigest(),'after':hashlib.sha256(after).hexdigest(),'prior_text_exact':True}
(OUT/'tracking-receipt.json').write_text(json.dumps(receipts,indent=2),encoding='utf-8')
print('CHALLENGER_QUALITY_TRACKING: all prior records retained verbatim')
