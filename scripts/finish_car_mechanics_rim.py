"""Retain the 12 mm distant-rim bound after rejecting a larger angular gap."""
import json
import subprocess
import sys
from run_car_mechanics import ROOT, OUT, run
def check(label,script,*args):assert run(label,script,*args)==0,label
subprocess.run([sys.executable,'scripts/publish_car_mechanics.py','--distance','--revise'],cwd=ROOT,check=True)
import refresh_car_10k_assets as refresh
refresh.prior.IDS=('compact','kart','forklift','hovercraft')
current=refresh.identity('identity-rim-final')
check('rim-bases-kart','res://tests/bake_modular_car_bases.gd','--headless','--','--vehicle=kart')
check('rim-kits-kart','res://tests/bake_modular_car_kits.gd','--headless','--','--vehicle=kart')
check('rim-garage-kart','res://tests/bake_garage_cars.gd','--headless','--','--vehicle=kart')
check('rim-modules-kart','res://tests/test_modular_car_assets.gd','--headless','--','--vehicle=kart','--all-kits')
check('rim-prepared-models','res://tests/test_car_mechanics.gd','--headless','--','--prepared')
for method in ('gl_compatibility','mobile'):
    check('rim-native-'+method,'res://tests/capture_car_mechanics.gd','--rendering-method',method,'--','--vehicle=kart','--decorated')
    check('rim-distance-'+method,'res://tests/capture_car_mechanics_distance.gd','--rendering-method',method,'--','--vehicle=kart')
    check('rim-app-'+method,'res://tests/test_car_mechanics_app.gd','--rendering-method',method,'--','--vehicle=kart')
print('MECHANICS_RIM_FINAL new angular pattern, original quality gate')
