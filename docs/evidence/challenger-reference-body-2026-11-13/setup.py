from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
OLD=OUT.parent/'challenger-surface-joins-2026-11-12'
for name in ['run_check.py','run_preparation.py','garage_detail.gd','guarded_assets.py','prototype.gd']:
    text=(OLD/name).read_text().replace('challenger-surface-joins-2026-11-12','challenger-reference-body-2026-11-13')
    if name=='run_preparation.py':
        text=text.replace("ROOT/'scripts/challenger_panel_geometry.py']","ROOT/'scripts/challenger_panel_geometry.py',ROOT/'scripts/challenger_reference_geometry.py']")
        text=text.replace('str(destination)]','str(destination),"--debug-cache"]')
    if name=='guarded_assets.py':
        text=text.replace('ROOT / "scripts/challenger_panel_geometry.py",','ROOT / "scripts/challenger_panel_geometry.py", ROOT / "scripts/challenger_reference_geometry.py",')
        text=text.replace('engine("bases", "res://tests/bake_modular_car_bases.gd")','engine("bases", "res://tests/bake_modular_car_bases.gd", ["--vehicle=super_rally"])')
        text=text.replace('("compact", "kart", "forklift", "electric", "hovercraft", "super_rally")','("super_rally",)')
        text=text.replace('engine("garage", "res://tests/bake_garage_cars.gd")','engine("garage", "res://tests/bake_garage_cars.gd", ["--vehicle=super_rally"])')
        text=text.replace('engine("pictures", "res://../scripts/bake_garage_previews.gd", native=True)','engine("pictures", "res://../scripts/bake_garage_previews.gd", ["--exclude-vehicle="+id for id in ("compact","kart","forklift","electric","hovercraft")], native=True)')
    (OUT/name).write_text(text)
paths=[ROOT/'.git/index',*list((ROOT/'game/resources/cars').glob('*.tres')),ROOT/'game/vehicle/vehicle_simulation.gd',ROOT/'game/vehicle/handling_config.gd']
paths+=list((ROOT/'game/assets/vehicles/challenger_hellcat_v1').glob('*'))
(OUT/'controls-before.json').write_text(json.dumps({str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths if p.is_file()},indent=2))
