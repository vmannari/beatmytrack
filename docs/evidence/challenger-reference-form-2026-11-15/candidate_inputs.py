from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
source=(ROOT/'game/tests/test_panel_contours.gd').read_text(encoding='utf-8-sig')
source=source.replace('res://assets/vehicles/challenger_hellcat_v1/','res://../build/challenger-reference-form-2026-11-15/native/')
(OUT/'panel_candidate_inputs.gd').write_text(source)
child=OUT/'contours_candidate.gd'
text=child.read_text(encoding='utf-8-sig').replace('res://tests/test_panel_contours.gd','res://../docs/evidence/challenger-reference-form-2026-11-15/panel_candidate_inputs.gd')
child.write_text(text)
print('Candidate fixture: unchanged assertions, private native input paths only')
