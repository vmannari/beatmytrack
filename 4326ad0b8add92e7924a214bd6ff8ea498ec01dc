from pathlib import Path
import shutil
ROOT=Path(__file__).resolve().parents[2];WORK=Path(__file__).resolve().parent;FROZEN=WORK/'frozen'
for kind,source in [('bases','bake_modular_car_bases.gd'),('kits','bake_modular_car_kits.gd'),('garage','bake_garage_cars.gd')]:
    text=(FROZEN/'game/tests'/source).read_text(encoding='utf-8')
    old='preload("res://vehicle/car_mesh_lods.gd").new()' if kind!='garage' else 'preload("res://tests/support/garage_mesh_lods.gd").new()'
    assert text.count(old)==1
    text=text.replace(old,'preload("res://../build/asset-optimisation-2026-11-08/lod_reuse.gd").new()')
    target=FROZEN/'build/asset-optimisation-2026-11-08'/('rebake_'+kind+'.gd');target.write_text(text,encoding='utf-8')
shutil.copyfile(ROOT/'game/core/build_identity.gd',FROZEN/'game/core/build_identity.gd')
shutil.copyfile(ROOT/'game/project.godot',FROZEN/'game/project.godot')
print('Created isolated exact-master LOD reuse recipes; production bakers unchanged.')
