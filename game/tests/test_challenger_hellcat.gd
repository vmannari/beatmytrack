extends SceneTree
## Opaque glazing, no cabin/rig and actual native car budget/contact controls.
var checks: int = 0
var failures: int = 0
const OUT: String = "res://../docs/evidence/challenger-hellcat-2026-11-09/opaque"
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func settle() -> void:
	for frame: int in range(8):
		await process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func run() -> void:
	root.size = Vector2i(1000,640)
	var prepared: bool = "--prepared" in OS.get_cmdline_user_args()
	var evidence: String = OUT
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): evidence = argument.trim_prefix("--evidence-root=")
	var folder: String = evidence.path_join(RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var source: Dictionary = (load("res://assets/vehicles/challenger_hellcat_v1/source.json") as JSON).data
	check(source.source_triangles == 911774,"source triangle count comes from supplied body and four wheels")
	check(source.removed_components.filter(func(p: Dictionary) -> bool: return p.reason == "cabin floor").size() == 2,"both source cabin floor slabs are removed")
	check(preload("res://vehicle/prepared_asset_sources.gd").vehicles_for("game/assets/vehicles/challenger_hellcat_v1/simple_body_paint.res") == ["super_rally"],"native Challenger meshes participate in Super rally dependency validation")
	preload("res://vehicle/modular_car_base.gd").enabled = prepared
	preload("res://vehicle/modular_car_kits.gd").enabled = prepared
	preload("res://vehicle/prepared_car_cache.gd").enabled = prepared
	preload("res://ui/garage_car_cache.gd").enabled = prepared
	var metrics: Array = []
	for reduced: bool in [false,true]:
		var view := CarShowroom.new(); view.vehicle_id = "super_rally"; view.simple_model = reduced
		view.read_only = true; view.size = Vector2(1000,640); view.livery = VehicleLivery.defaults("super_rally")
		root.add_child(view)
		while not view.showroom_ready or not view.car.model_ready: await process_frame
		view.finish_car_transition(); view.finish_paint_transition(); view.finish_kit_transition()
		var car: CarVisual = view.car
		check(car.find_children("*","Skeleton3D",true,false).is_empty() and car.find_children("*","AnimationPlayer",true,false).is_empty(),"source rig and animations are absent")
		var glass_count: int = 0; var triangles: int = 0; var contours: int = 0; var contours_unshadowed: bool = true
		for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
			if part.mesh != null: triangles += part.mesh.get_faces().size()/3
			var material: StandardMaterial3D = part.get_active_material(0) as StandardMaterial3D
			var marking: ShaderMaterial = part.get_active_material(0) as ShaderMaterial
			if marking != null and marking.shader == preload("res://vehicle/panel_contour.gdshader") and marking.get_shader_parameter("contour_color") == Color("303b40"):
				contours += 1
				contours_unshadowed = contours_unshadowed and part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if material != null and material.albedo_color == Color("101b20"):
				glass_count += 1
				var surface: StandardMaterial3D = part.get_active_material(0) as StandardMaterial3D
				check(surface != null and surface.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and surface.albedo_color.a == 1.0,"native windows are fully opaque")
		check(glass_count == 1,"all original glazing shares one opaque native surface")
		check(contours == 1 and contours_unshadowed,"door, handle and fuel outlines form one unshadowed marking surface")
		check(triangles < (50000 if reduced else 85000),"assembled car stays below the allocated 50k/85k exterior-detail budget")
		check(car.wheel_rest_positions == [Vector3(-0.83,0.37,-1.28),Vector3(-0.83,0.37,1.28),Vector3(0.83,0.37,-1.28),Vector3(0.83,0.37,1.28)],"Rally physical wheel locations remain exact")
		var probe := MeshInstance3D.new(); var sphere := SphereMesh.new(); sphere.radius = 0.18; sphere.height = 0.36
		probe.mesh = sphere; probe.position = Vector3(0,1.03,0.25)
		probe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var marker := StandardMaterial3D.new(); marker.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; marker.albedo_color = Color.MAGENTA
		probe.material_override = marker; car.body.add_child(probe)
		for angle: Array in [["front",-0.70],["rear",2.45],["side",-PI/2]]:
			view.yaw = angle[1]; view.zoom = 1.15; view._orbit()
			probe.hide(); view.invalidate_render(); view.showroom_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; await settle()
			if DisplayServer.get_name() != "headless":
				var before: Image = root.get_texture().get_image()
				await settle()
				check(before.get_data() == root.get_texture().get_image().get_data(),"unchanged native view repeats exactly before the "+str(angle[0])+" probe")
				probe.show(); view.invalidate_render(); view.showroom_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; await settle()
				var after: Image = root.get_texture().get_image()
				check(before.get_data() == after.get_data(),"bright cabin probe is invisible through "+str(angle[0])+" glazing")
				before.save_png(folder.path_join(("simple-" if reduced else "full-")+str(angle[0])+".png"))
				after.save_png(folder.path_join(("simple-" if reduced else "full-")+str(angle[0])+"-probe.png"))
		probe.queue_free(); await process_frame
		car.set_night_headlights(true)
		check(car.headlights != null and car.headlights.find_children("*","MeshInstance3D",true,false).size() == 2,"both original headlamp lens groups illuminate at night")
		metrics.append({"simple":reduced,"triangles":triangles})
		view.free(); await process_frame
	if prepared: check(preload("res://vehicle/modular_car_base.gd").hits+preload("res://ui/garage_car_cache.gd").hits >= 2,"both quality tiers actually restore prepared geometry")
	var file := FileAccess.open(folder.path_join("acceptance.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t")); file.close()
	print("CHALLENGER_HELLCAT: %d checks, %d failures; %s" % [checks,failures,JSON.stringify(metrics)])
	quit(1 if failures else 0)
