extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1440,900)
	var stage: String = "before"
	var candidate: bool = "--candidate" in OS.get_cmdline_user_args()
	var simple: bool = "--full" not in OS.get_cmdline_user_args()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="): stage = arg.trim_prefix("--stage=")
	var prepared: bool = "--prepared" in OS.get_cmdline_user_args()
	preload("res://vehicle/modular_car_base.gd").enabled = prepared
	preload("res://vehicle/modular_car_kits.gd").enabled = prepared
	preload("res://vehicle/prepared_car_cache.gd").enabled = prepared
	preload("res://ui/garage_car_cache.gd").enabled = prepared
	if candidate:
		var prefix: String = "res://../build/challenger-continuous-side-2026-11-15/native/"
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(prefix+"manifest.json"))
		(load(SuperRallyModel.ROOT+"manifest.json") as JSON).data = manifest
		SuperRallyModel.hood_profile = JSON.parse_string(FileAccess.get_file_as_string(prefix+"hood_profile.json"))
		(load(SuperRallyModel.ROOT+"bonnet_contour.json") as JSON).data = JSON.parse_string(FileAccess.get_file_as_string(prefix+"bonnet_contour.json"))
		for tier: String in ["simple","full"]:
			for entry: Dictionary in manifest.tiers[tier]:
				var mesh: ArrayMesh = load(prefix+str(entry.mesh))
				if "--normal-diagnostic" in OS.get_cmdline_user_args() and entry.group=="body" and entry.role=="paint":
					mesh=preload("res://../docs/evidence/challenger-continuous-side-2026-11-15/normal_diagnostic.gd").rebuild(mesh)
				if "--wing-normal-diagnostic" in OS.get_cmdline_user_args() and entry.group=="body" and entry.role=="paint":
					mesh=preload("res://../docs/evidence/challenger-continuous-side-2026-11-15/normal_diagnostic.gd").smooth_wing(mesh)
				if "--side-normal-diagnostic" in OS.get_cmdline_user_args() and entry.group=="body" and entry.role=="paint":
					var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../build/challenger-continuous-side-2026-11-15/side-normal-diagnostic.json"))
					var arrays: Array=mesh.surface_get_arrays(0)
					var normals:=PackedVector3Array()
					for value: Array in data[tier]:normals.append(Vector3(value[0],value[1],value[2]))
					arrays[Mesh.ARRAY_NORMAL]=normals
					var source: ArrayMesh=mesh
					mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
					for meta: StringName in source.get_meta_list():mesh.set_meta(meta,source.get_meta(meta))
				if "--grille-diagnostic" in OS.get_cmdline_user_args() and entry.group == "body" and entry.role == "vent_metal":
					var arrays: Array = mesh.surface_get_arrays(0)
					var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
					for i: int in range(points.size()):
						points[i].y = .724+.70*(points[i].y-.711)
						normals[i].y /= .70; normals[i] = normals[i].normalized()
					arrays[Mesh.ARRAY_VERTEX] = points; arrays[Mesh.ARRAY_NORMAL] = normals
					mesh = ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				mesh.take_over_path(SuperRallyModel.ROOT+str(entry.mesh))
				SuperRallyModel.assets[SuperRallyModel.ROOT+str(entry.mesh)] = mesh
				if "--marking-diagnostic" in OS.get_cmdline_user_args() and entry.role == "contour":
					preload("res://vehicle/panel_contour.gd").meshes[mesh] = mesh
	var view := CarShowroom.new()
	view.vehicle_id = "super_rally"; view.simple_model = simple; view.garage_mode = true
	view.livery = VehicleLivery.defaults("super_rally"); view.size = Vector2(1440,900)
	root.add_child(view)
	while not view.showroom_ready or not view.car.model_ready: await process_frame
	var cache_hits: Dictionary={"base":preload("res://vehicle/modular_car_base.gd").hits,"garage":preload("res://ui/garage_car_cache.gd").hits,"kits":preload("res://vehicle/modular_car_kits.gd").hits}
	if prepared:assert(int(cache_hits.base)+int(cache_hits.garage)>0,"Final view must restore the actual prepared model")
	if "--hide-contour" in OS.get_cmdline_user_args():
		for part: MeshInstance3D in view.car.find_children("*contour*","MeshInstance3D",true,false): part.visible = false
	if "--inspect-paint" in OS.get_cmdline_user_args():
		for part: MeshInstance3D in view.car.find_children("*","MeshInstance3D",true,false):
			if str(part.name) == "Hellcat_body_paint":
				var flat := StandardMaterial3D.new(); flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				flat.albedo_color = Color.WHITE;part.material_override = flat
			elif str(part.name).begins_with("Hellcat_body_") or str(part.name).begins_with("Hellcat_tail_"): part.visible = false
	if "--no-proxy-shadow" in OS.get_cmdline_user_args():
		for part: MeshInstance3D in view.car.find_children("RaceShadowProxy","MeshInstance3D",true,false):
			part.visible=false
	if "--hide-spoiler" in OS.get_cmdline_user_args():
		for part: MeshInstance3D in view.car.find_children("Hellcat_aero_accent","MeshInstance3D",true,false): part.visible = false
	view.finish_car_transition(); view.finish_paint_transition(); view.finish_kit_transition(); view.set_process(false)
	view.yaw = 0; view.turntable.rotation.y = 0
	var folder: String = "res://../build/challenger-continuous-side-2026-11-15/views-"+stage+"/"+RenderingServer.get_current_rendering_method()+"/"+("simple" if simple else "full")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	FileAccess.open(folder.path_join("model-path.json"),FileAccess.WRITE).store_string(JSON.stringify({"prepared":prepared,"candidate":candidate,"simple":simple,"cache_hits":cache_hits},"\t"))
	var captures: int = 0
	for paint: String in ["white","red"]:
		if "--white-only" in OS.get_cmdline_user_args() and paint == "red": continue
		var livery: Dictionary = VehicleLivery.defaults("super_rally")
		livery.colors.body = "ffffff" if paint == "white" else "c52a20"
		livery.colors.accent = "9d2424"; view.livery = livery; view.car.apply_livery(livery)
		for shot: Array in [["rear",Vector3(0,1.25,6.4),Vector3(0,.72,1.0),Vector3.UP],
			["front",Vector3(0,1.20,-6.4),Vector3(0,.72,-1.0),Vector3.UP],
			["left",Vector3(-6.3,1.25,0),Vector3(0,.75,0),Vector3.UP],
			["right",Vector3(6.3,1.25,0),Vector3(0,.75,0),Vector3.UP],
			["overhead",Vector3(0,6.3,-.4),Vector3(0,.7,-.4),Vector3.RIGHT],
			["front-quarter",Vector3(-4.5,2.0,-5.0),Vector3(0,.8,-.3),Vector3.UP],
			["reference-side",Vector3(5.6,1.55,-3.8),Vector3(0,.8,0),Vector3.UP],
			["rear-quarter",Vector3(-4.4,1.7,4.8),Vector3(0,.8,.5),Vector3.UP],
			["cowl",Vector3(-2.4,1.45,-1.3),Vector3(-.78,.95,-.68),Vector3.UP],
			["nose",Vector3(-2.25,1.5,-3.5),Vector3(-.32,.80,-2.05),Vector3.UP],
			["rear-corner",Vector3(-2.4,1.55,3.2),Vector3(-.76,.94,1.96),Vector3.UP]]:
			if "--marked-only" in OS.get_cmdline_user_args() and shot[0] not in ["cowl","nose","rear-corner"]: continue
			if "--flat-paint" in OS.get_cmdline_user_args():
				for part: MeshInstance3D in view.car.find_children("Hellcat_body_paint","MeshInstance3D",true,false):
					var flat := StandardMaterial3D.new();flat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;flat.albedo_color=Color.WHITE
					if "--two-sided" in OS.get_cmdline_user_args(): flat.cull_mode = BaseMaterial3D.CULL_DISABLED
					part.material_override=flat
			if "--rear-only" in OS.get_cmdline_user_args() and shot[0] != "rear-corner": continue
			view.turntable.rotation.y = 0
			var pose: Transform3D = view.car.global_transform
			view.camera.global_position = pose*shot[1]; view.camera.look_at(pose*shot[2],pose.basis*shot[3])
			if "--diagnose-joint" in OS.get_cmdline_user_args() and shot[0] == "nose":
				var part: MeshInstance3D = view.car.find_child("Hellcat_body_paint",true,false)
				var local_pose: Transform3D = view.car.global_transform.affine_inverse()*part.global_transform
				print("JOINT_POSE ",local_pose," camera=",view.camera.fov," viewport=",view.showroom_viewport.size)
				for point: Vector3 in [Vector3(-.8,.83,-2.095),Vector3(-.84,.60,-2.095)]:
					print("JOINT_PROJECT ",point," -> ",view.camera.unproject_position(part.global_transform*point)*Vector2(1440,900)/Vector2(view.showroom_viewport.size))
				var tree: TriangleMesh = part.mesh.generate_triangle_mesh()
				for pixel: Vector2 in [Vector2(968,552),Vector2(975,600),Vector2(990,650)]:
					var actual: Vector2 = pixel*Vector2(view.showroom_viewport.size)/Vector2(1440,900)
					var origin: Vector3 = part.global_transform.affine_inverse()*view.camera.project_ray_origin(actual)
					var direction: Vector3 = part.global_transform.basis.inverse()*view.camera.project_ray_normal(actual)
					print("JOINT_RAY ",pixel," origin=",origin," direction=",direction," hit=",tree.intersect_ray(origin,direction))
			view._update_roof()
			view.reflections.sync(); view.reflections.request_draw(); view.invalidate_render()
			view.showroom_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			for frame: int in range(24): await process_frame; await RenderingServer.frame_post_draw
			captures += 1
			assert(root.get_texture().get_image().save_png(folder.path_join(paint+"-"+shot[0]+".png")) == OK)
	view.free()
	print("PANEL_VIEWS: ",captures," actual model views saved; ",stage," simple=",simple)
	quit()
