"""Adapt retained assertions/views to explicit Rally scope and current async API."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
text=(root/'game/tests/test_compact_grille.gd').read_text()
text=text.replace('var car := CarVisual.new()', '''preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/modular_car_kits.gd").enabled = false
	var car := CarVisual.new()
	car.simple_model = false''')
text=text.replace('var source := CarVisual.new()', 'var source := CarVisual.new()\n\tsource.simple_model = false')
for name in ('first','restored'):
    text=text.replace('var '+name+' := CarVisual.new()','var '+name+' := CarVisual.new()\n\t'+name+'.simple_model = false')
for name in ('car','source','simple','first','restored'):
    text=text.replace('root.add_child('+name+')','root.add_child('+name+')\n\twhile not '+name+'.model_ready: await process_frame')
(root/'game/tests/test_rally_front_legacy.gd').write_text(text)
text=(root/'game/tests/capture_car15.gd').read_text().replace('car15-2026-11-15','rally-front-2026-11-15')
text=text.replace('for id: String in VehicleCatalog.IDS:', 'for id: String in ["compact"]:')
text=text.replace('var views: Array=[["front",', 'var views: Array=[["head-on",0.0,0.18,0.9],["front",')
text=text.replace('if id=="compact": views.append_array(', 'if id=="compact": views.append_array([["lamp-close",0.0,0.3,1.0],["grille-close",0.0,0.3,1.0],["oblique-close",0.0,0.3,1.0]]);views.append_array(')
text=text.replace('match str(shot[0]):', '''match str(shot[0]):
					"lamp-close": camera_position=Vector3(0.72,0.92,-3.03);target=Vector3(0.60,0.80,-2.08)
					"grille-close": camera_position=Vector3(0,0.90,-3.6);target=Vector3(0,0.79,-2.07)
					"oblique-close": camera_position=Vector3(1.6,1.04,-3.0);target=Vector3(0.28,0.79,-2.07)''')
text=text.replace('+("-decorated" if decorated else "")','+("-decorated" if decorated else "")+("-night" if "--night" in OS.get_cmdline_user_args() else "")')
text=text.replace('ShowroomStudio._studio_glass(old,{})','''ShowroomStudio._studio_glass(old,{})
			check(old.transform.is_equal_approx(view.car.transform),"matched original/current model root transform "+id+mode)
			if "--night" in OS.get_cmdline_user_args():
				view.car.set_night_headlights(true)
				var lights: Node3D=view.car.headlights.duplicate()
				old.add_child(lights)
				lights.global_transform=view.car.headlights.global_transform''')
text=text.replace('for shot: Array in views:', '''if "--night" in OS.get_cmdline_user_args():
				views=views.filter(func(shot: Array) -> bool: return shot[0] in ["head-on","lamp-close","oblique-close","distance"])
			for shot: Array in views:''')
(root/'game/tests/capture_rally_front.gd').write_text(text)
text=(root/'game/tests/test_car15_app.gd').read_text().replace('car15-2026-11-15','rally-front-2026-11-15')
text=text.replace('for id: String in VehicleCatalog.IDS:','for id: String in ["compact"]:')
(root/'game/tests/test_rally_front_app.gd').write_text(text)
text=(root/'game/tests/bake_header_car_thumbnails.gd').read_text().replace('for id: String in VehicleCatalog.IDS:', 'for id: String in ["compact"]:')
(root/'game/tests/bake_rally_front_header.gd').write_text(text)
text=(root/'scripts/import_car_model_revert_images.py').read_text().replace('car-model-revert-2026-11-15','rally-front-2026-11-15')
text=text.replace('for car in ["compact", "kart", "forklift", "electric", "hovercraft"]:', 'for car in ["compact", "super_rally"]:')
text=text.replace('images += [ROOT / "game/assets/garage/previews_v1" / (car + ".png"), ROOT / "game/assets/menu/header_cars_v1" / (car + ".png")]', 'images.append(ROOT / "game/assets/garage/previews_v1" / (car + ".png"))\n    if car == "compact": images.append(ROOT / "game/assets/menu/header_cars_v1" / (car + ".png"))')
(root/'scripts/import_rally_front_images.py').write_text(text)
print('RALLY_FRONT_FIXTURES original assertions retained with explicit tiers, waits and Rally close views')
