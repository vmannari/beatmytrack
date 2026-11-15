from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
OLD='challenger-surface-quality-2026-11-15'
for name in ['publish.py','deliver.py','review_native.py','checkpoint.py']:
    text=(ROOT/'docs/evidence'/OLD/name).read_text(encoding='utf-8-sig').replace(OLD,OUT.name)
    if name=='publish.py':text=text.replace('candidate-quality.json','candidate-shape.json')
    if name=='review_native.py':text=text.replace("for script in ['diagnose.py','check_quality.py']:","for script in ['check_shape.py']:")
    if name=='checkpoint.py':
        text=text.replace("files=['scripts/challenger_reference_form.py','scripts/challenger_surface_quality.py','game/tests/bake_challenger_hellcat.gd']","files=['scripts/challenger_reference_form.py','scripts/challenger_side_finish.py','scripts/prepare_challenger.py','game/vehicle/super_rally_model.gd']")
        text=text.replace('three source files','four source files')
    (OUT/name).write_text(text,encoding='utf-8')
path=OUT/'guarded_assets.py';text=path.read_text();text=text.replace('ROOT / "scripts/challenger_surface_quality.py"]','ROOT / "scripts/challenger_surface_quality.py", ROOT / "scripts/challenger_side_finish.py"]');path.write_text(text)
print('Current-source delivery and four-source checkpoint routes configured.')
