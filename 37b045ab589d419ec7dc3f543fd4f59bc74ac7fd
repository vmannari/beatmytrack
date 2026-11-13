from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
receipt=json.loads((OUT/'final-acceptance.json').read_text())
assert receipt['status']=='passed' and receipt['picture_controls']['exact']==20
assert (ROOT/'docs/CHALLENGER_HOOD_SIDE_REFINEMENT_2026_11_12.md').is_file()
marker='CHALLENGER-PANELS-20261112'
summary=(
 'CHP01-CHP04: Owner marks hood/sides, rear-window and rear-accent defects. '
 'Source-sampled bonnet topology, continuous fitted front fenders with1044 locked join vertices, measured side skins and local handle fairing correct the surfaces. '
 'Single opaque pane skins/clear backing and removal of overlapping old rear trim correct glazing/applique artefacts; flush contours, no interior,14cm nose extension and198km/h/contact tune remain. '
 'Production49985tri/full84753 stay within50k/85k; AAA/device performance unclaimed. '
 'Panels884/0 reject old884/84; glazing/trim784/0 reject old784/99. Geometry27/0, fitted316/0, modules/ghost1438/0, prepared physics/replay3677/0, wash1655/0, driving72/0, parser553/0 and shadow-switch20/0 pass. '
 'Opacity30/0 and actual App13/0 each desktop renderer pass. '
 'Coherent433-input/15-command refresh and final live audits pass551-resource2267/0 and six-picture157-source provenance;20 immediate pre-refresh PNG controls exact. '
 'Concurrent Kart/shared picture updates and preview-baker changes are preserved. '
 'Owner-removed blend is supported by retained measured source art;6-source byte-exact forward/reverse checkpoint,23 shared controls and51 native hashes retained. '
 'Rejected surface/boundary drafts and corrected gates retained; redundant draft/probe PNGs pruned. '
)
records={}
for name,link in [('AGENTS.md','docs/CHALLENGER_HOOD_SIDE_REFINEMENT_2026_11_12.md'),
                  ('DEVELOPMENT_STATUS.md','docs/CHALLENGER_HOOD_SIDE_REFINEMENT_2026_11_12.md'),
                  ('docs/PHASE_0_PLAN.md','CHALLENGER_HOOD_SIDE_REFINEMENT_2026_11_12.md')]:
    path=ROOT/name;before=path.read_bytes();assert marker.encode() not in before
    prefix=(f'<!-- {marker} -->\n## Challenger hood, sides, rear glazing and trim refined (2026-11-12)\n\n'+summary+
      f'[Changes, native comparisons, commands, receipts and limits]({link}). '
      'Fresh desktop launch/owner appearance and device qualification remain; no device query/test, APK, owner-save/process change, backend request, deployment or main-index write.\n'+f'<!-- /{marker} -->\n\n').encode('utf-8')
    assert path.read_bytes()==before,'Concurrent tracking change; retry with the new input'
    path.write_bytes(prefix+before);after=path.read_bytes();assert after[len(prefix):]==before
    records[name]={'before':hashlib.sha256(before).hexdigest(),'after':hashlib.sha256(after).hexdigest(),
       'prefix_bytes':len(prefix),'prefix_sha256':hashlib.sha256(prefix).hexdigest(),'prior_text_exact':True}
(OUT/'tracking-receipt.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
print('CHALLENGER_PANEL_TRACKING: prior records preserved byte-exact in all three files')
