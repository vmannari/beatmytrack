from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
OLD='challenger-reference-form-2026-11-15';TAG=OUT.name
for name in ['guarded_assets.py','import_images.py','bake_coarse.gd','gpu_checks.py','run_retention.py']:
    text=(ROOT/'docs/evidence'/OLD/name).read_text(encoding='utf-8-sig').replace(OLD,TAG)
    if name=='bake_coarse.gd':text=text.replace('challenger-continuous-side-2026-11-15',TAG)
    if name=='guarded_assets.py':
        text=text.replace('before = sources()', 'before = sources()',1)
        text=text.replace('files += [ROOT / "scripts/challenger_reference_form.py"]','files += [ROOT / "scripts/challenger_reference_form.py", ROOT / "scripts/challenger_surface_quality.py"]')
    (OUT/name).write_text(text,encoding='utf-8')
print('Delivery routes configured.')
