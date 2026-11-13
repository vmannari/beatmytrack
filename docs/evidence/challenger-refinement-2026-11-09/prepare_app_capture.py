from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
source=(ROOT/'game/tests/test_super_rally_ui.gd').read_text(encoding='utf-8')
source=source.replace('\tcapture("garage")','''	page.showroom.finish_car_transition(); page.showroom.finish_paint_transition(); page.showroom.finish_kit_transition()
	await settle(12)
	print("INSPECT_CONDITION ",page.showroom.weathering.snapshot().dirt," ",page.showroom.weathering.snapshot().wetness)
	for part: MeshInstance3D in page.showroom.car.find_children("*","MeshInstance3D",true,false):
		if "box" in str(part.name):
			var material: Material = part.get_active_material(0)
			print("INSPECT_BOX ",str(page.showroom.car.get_path_to(part))," ",part.mesh.get_aabb()," ",material.get_class()," ",(material as StandardMaterial3D).albedo_color if material is StandardMaterial3D else "shader")
	capture("garage")''')
source=source.replace('\tcapture("garage")','''	page.showroom.process_mode = Node.PROCESS_MODE_DISABLED
	if page.showroom.camera_motion != null: page.showroom.camera_motion.kill()
	capture("garage")
	var key: DirectionalLight3D = page.showroom.showroom_viewport.find_child("GarageKey",true,false)
	key.shadow_normal_bias = 4.0
	page.showroom.invalidate_render(); await settle(12)
	capture("garage-normal-bias-4")
	key.shadow_normal_bias = 8.0
	page.showroom.invalidate_render(); await settle(12)
	capture("garage-normal-bias-8")
	key.shadow_normal_bias = 2.0
	key.directional_shadow_max_distance = 6.0
	page.showroom.invalidate_render(); await settle(12)
	capture("garage-shadow-distance-6")''')
(OUT/'app_capture.gd').write_text(source,encoding='utf-8')
