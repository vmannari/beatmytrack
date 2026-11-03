import json
from pathlib import Path
from types import SimpleNamespace
from bmt_backend.verifier import GodotVerifier, VerificationError
from bmt_backend.trajectory_verifier import check, CHECKPOINT_LAYOUT_VERSION

root=Path('/tests')
expected=json.loads((root/'manifest.json').read_text())
verifier=GodotVerifier(SimpleNamespace(godot_bin='/usr/local/bin/godot',game_project=Path('/opt/bmt/game'),verifier_timeout_seconds=180))
try:
    assert verifier.manifest()==expected, 'Competitive manifest changed; existing results would move'
    assert CHECKPOINT_LAYOUT_VERSION==24
    geometries={}; rejected=0
    for case in json.loads((root/'cuts.json').read_text()):
        reverse=case['reverse']
        if reverse not in geometries:geometries[reverse]=verifier.race_geometry(case['document'])
        geometry=geometries[reverse]
        assert geometry['checkpoint_layout_version']==24
        assert len(geometry['gates'])==(108 if reverse else 106)
        proof=case['trajectory']
        try:check(geometry,proof['proof'],proof['ticks'],'compact')
        except VerificationError:rejected+=1
        else:raise AssertionError('Historical hairpin cut accepted')
    assert rejected==9
    saved=json.loads((root/'recording.json').read_text())
    assert len(check(geometries[False],saved['race_proof'],saved['time_ticks'],'compact')['lap_ticks'])==5
    actual=verifier.verify_canonical_diagnostic(saved['document'],saved['replay'],'compact',capture_ghost=False)
    assert actual['time_ticks']==saved['time_ticks']==47712
    print('PATCH_ACCEPTANCE='+json.dumps({'manifest':verifier.manifest(),'layout':24,'cuts_rejected':rejected,'canonical_ticks':47712}))
finally:verifier.close()
