"""Refresh only the vehicle affected by the final shoulder refinement."""
from pathlib import Path
source=Path(__file__).with_name('guarded_assets.py').read_text()
source=source.replace('build/challenger-surface-joins-2026-11-12/assets','build/challenger-surface-joins-2026-11-12/assets-final')
source=source.replace('engine("bases", "res://tests/bake_modular_car_bases.gd")','engine("bases", "res://tests/bake_modular_car_bases.gd", ["--vehicle=super_rally"])')
source=source.replace('("compact", "kart", "forklift", "electric", "hovercraft", "super_rally")','("super_rally",)')
source=source.replace('engine("garage", "res://tests/bake_garage_cars.gd")','engine("garage", "res://tests/bake_garage_cars.gd", ["--vehicle=super_rally"])')
source=source.replace('engine("pictures", "res://../scripts/bake_garage_previews.gd", native=True)','engine("pictures", "res://../scripts/bake_garage_previews.gd", ["--exclude-vehicle="+id for id in ("compact","kart","forklift","electric","hovercraft")], native=True)')
exec(compile(source,str(__file__),'exec'))
