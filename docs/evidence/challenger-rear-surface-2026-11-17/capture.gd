extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1440,900)
	var stage: String = "before"
	var baseline: bool = "--baseline" in OS.get_cmdline_user_args()
	var candidate: bool = "--candidate" in OS.get_cmdline_user_args() or baseline
	var simple: bool = "--full" not in OS.get_cmdline_user_args()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="): stage = arg.trim_prefix("--stage=")
	var prepared: bool = "--prepared" in OS.get_cmdline_user_args()
	if candidate or "--prototype" in OS.get_cmdline_user_args() or "--native-source" in OS.get_cmdline_user_args():preload("res://vehicle/car_coarse_reduction.gd").enabled=false
	preload("res://vehicle/modular_car_base.gd").enabled = prepared
	preload("res://vehicle/modular_car_kits.gd").enabled = prepared
	preload("res://vehicle/prepared_car_cache.gd").enabled = prepared
	preload("res://ui/garage_car_cache.gd").enabled = prepared
	if candidate:
		var prefix: String = "res://../build/challenger-rear-surface-2026-11-17/native/"
		if baseline: prefix = "res://../build/challenger-rear-surface-2026-11-17/before-native/"
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(prefix+"manifest.json"))
		(load(SuperRallyModel.ROOT+"manifest.json") as JSON).data = manifest
		SuperRallyModel.hood_profile = JSON.parse_string(FileAccess.get_file_as_string(prefix+"hood_profile.json"))
		(load(SuperRallyModel.ROOT+"bonnet_contour.json") as JSON).data = JSON.parse_string(FileAccess.get_file_as_string(prefix+"bonnet_contour.json"))
		SuperRallyModel._asset_revision = SuperRallyModel.KEY
		for tier: String in ["simple","full"]:
			for entry: Dictionary in manifest.tiers[tier]:
				var mesh: ArrayMesh = load(prefix+str(entry.mesh))
				if "--normal-diagnostic" in OS.get_cmdline_user_args() and entry.group=="body" and entry.role=="paint":
					mesh=preload("res://../docs/evidence/challenger-rear-surface-2026-11-17/normal_diagnostic.gd").rebuild(mesh)
				if "--wing-normal-diagnostic" in OS.get_cmdline_user_args() and entry.group=="body" and entry.role=="paint":
					mesh=preload("res://../docs/evidence/challenger-rear-surface-2026-11-17/normal_diagnostic.gd").smooth_wing(mesh)
				if "--side-normal-diagnostic" in OS.get_cmdline_user_args() and entry.group=="body" and entry.role=="paint":
					var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../build/challenger-rear-surface-2026-11-17/side-normal-diagnostic.json"))
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
	if "--prototype" in OS.get_cmdline_user_args():
		SuperRallyModel._asset_revision = SuperRallyModel.KEY
		var prototype: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../build/challenger-rear-surface-2026-11-17/prototype.json"))
		for tier: String in ["simple","full"]:
			for name: String in prototype[tier]:
				var item: Dictionary=prototype[tier][name]
				var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX)
				var points:=PackedVector3Array(); var normals:=PackedVector3Array()
				for value: Array in item.points: points.append(Vector3(value[0],value[1],value[2]))
				for value: Array in item.normals: normals.append(Vector3(value[0],value[1],value[2]))
				var source: ArrayMesh=load(SuperRallyModel.ROOT+tier+"_"+name+".res")
				if name=="body_contour":
					source=load(SuperRallyModel.ROOT+tier+"_"+name+".res")
					arrays=source.surface_get_arrays(0).duplicate()
				arrays[Mesh.ARRAY_VERTEX]=points; arrays[Mesh.ARRAY_NORMAL]=normals; arrays[Mesh.ARRAY_INDEX]=PackedInt32Array(item.indices)
				if name=="body_paint":
					var native_baker: SceneTree=load("res://tests/bake_challenger_hellcat.gd").new()
					print("PREVIEW_FENDER_REPAIR ",native_baker.repair_fender_diagonals(arrays,tier+"/body/paint"))
					native_baker.free()
				var mesh:=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				if source!=null:
					for metadata: StringName in source.get_meta_list():mesh.set_meta(metadata,source.get_meta(metadata))
				var path: String=SuperRallyModel.ROOT+tier+"_"+name+".res"
				SuperRallyModel.assets[path]=mesh
	var view := CarShowroom.new()
	view.vehicle_id = "super_rally"; view.simple_model = simple; view.garage_mode = true
	if "--extractor" in OS.get_cmdline_user_args():view.customisation=VehicleCustomisation.defaults();view.customisation.hood="extractor"
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
	var folder: String = "res://../build/challenger-rear-surface-2026-11-17/views-"+stage+"/"+RenderingServer.get_current_rendering_method()+"/"+("simple" if simple else "full")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	FileAccess.open(folder.path_join("model-path.json"),FileAccess.WRITE).store_string(JSON.stringify({"prepared":prepared,"candidate":candidate,"baseline":baseline,"simple":simple,"cache_hits":cache_hits},"\t"))
	var captures: int = 0
	var original_fov: float = view.camera.fov
	for paint: String in ["white","red"]:
		if "--white-only" in OS.get_cmdline_user_args() and paint == "red": continue
		var livery: Dictionary = VehicleLivery.defaults("super_rally")
		livery.colors.body = "ffffff" if paint == "white" else "c52a20"
		livery.colors.accent = "9d2424"; view.livery = livery; view.car.apply_livery(livery)
		if "--no-car-shadows" in OS.get_cmdline_user_args():
			for part: MeshInstance3D in view.car.find_children("*","MeshInstance3D",true,false):
				part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if "--normal-colour" in OS.get_cmdline_user_args():
			var diagnostic:=ShaderMaterial.new()
			var shader:=Shader.new()
			shader.code="shader_type spatial; render_mode unshaded; varying vec3 n; void vertex(){n=NORMAL;} void fragment(){ALBEDO=normalize(n)*0.5+vec3(0.5);}"
			diagnostic.shader=shader
			for part: MeshInstance3D in view.car.find_children("Hellcat_body_paint","MeshInstance3D",true,false):
				part.material_override=diagnostic
		if "--identify-carrier" in OS.get_cmdline_user_args():
			for part: MeshInstance3D in view.car.find_children("*","MeshInstance3D",true,false):
				var material: Material=part.get_active_material(0)
				if material is StandardMaterial3D and material.albedo_color.is_equal_approx(Color("172125")):
					print("BLACK_NODE ",part.get_path()," ",part.mesh.get_aabb())
					var diagnostic:=StandardMaterial3D.new(); diagnostic.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; diagnostic.albedo_color=Color.MAGENTA;part.material_override=diagnostic

		for shot: Array in [["rear",Vector3(0,1.25,6.4),Vector3(0,.72,1.0),Vector3.UP],
			["rear-close",Vector3(0,1.4,4.4),Vector3(0,.78,2.0),Vector3.UP],
			["rear-owner",Vector3(0,3.6,6.0),Vector3(0,.75,.5),Vector3.UP],
			["rear-strip",Vector3(0,2.35,4.3),Vector3(0,.77,1.9),Vector3.UP],
			["rear-left",Vector3(-3.8,1.7,4.5),Vector3(0,.8,1.5),Vector3.UP],
			["rear-right",Vector3(3.8,1.7,4.5),Vector3(0,.8,1.5),Vector3.UP],
			["trunk-top",Vector3(0,4.0,1.8),Vector3(0,.8,1.8),Vector3.FORWARD],
			["front-control",Vector3(-3.4,1.30,-6),Vector3(0,.79,-.15),Vector3.UP]]:
			if "--mark-only" in OS.get_cmdline_user_args() and shot[0]!="rear-right":continue
			if "--nose-only" in OS.get_cmdline_user_args() and not str(shot[0]).begins_with("nose-strip"):continue
			if "--sweep-only" in OS.get_cmdline_user_args() and not str(shot[0]).begins_with("sweep-"):continue
			if "--corner-only" in OS.get_cmdline_user_args() and shot[0] != "owner-corner": continue
			if "--fender-only" in OS.get_cmdline_user_args() and not str(shot[0]).begins_with("fender-"):continue
			if "--marked-only" in OS.get_cmdline_user_args() and shot[0] not in ["cowl","nose","rear-corner","owner-corner","hood-top","fender-wide","fender-close","fender-close-right"]: continue
			if "--owner-only" in OS.get_cmdline_user_args() and shot[0] not in ["owner-front-right","profile","reference-side","nose","nose-right","owner-side","front","rear-quarter","rear-corner","owner-corner","hood-top","fender-wide","fender-close","fender-close-right"]: continue
			if "--flat-paint" in OS.get_cmdline_user_args():
				for part: MeshInstance3D in view.car.find_children("Hellcat_body_paint","MeshInstance3D",true,false):
					var flat := StandardMaterial3D.new();flat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;flat.albedo_color=Color.WHITE
					if "--two-sided" in OS.get_cmdline_user_args(): flat.cull_mode = BaseMaterial3D.CULL_DISABLED
					part.material_override=flat
			if "--rear-only" in OS.get_cmdline_user_args() and shot[0] != "rear-corner": continue
			view.turntable.rotation.y = 0
			var pose: Transform3D = view.car.global_transform
			view.camera.projection = Camera3D.PROJECTION_ORTHOGONAL if shot[0] in ["profile","hood-top","trunk-top"] else Camera3D.PROJECTION_PERSPECTIVE
			if shot[0] == "profile": view.camera.size=3.5
			if shot[0] in ["hood-top","trunk-top"]: view.camera.size=1.90
			view.camera.fov=31.5 if shot[0] in ["owner-front","owner-front-right","owner-side","fender-wide"] else original_fov
			view.camera.global_position = pose*shot[1]; view.camera.look_at(pose*shot[2],pose.basis*shot[3])
			if "--inspect-corner" in OS.get_cmdline_user_args() and shot[0]=="fender-close":
				await process_frame
				await RenderingServer.frame_post_draw
				print("RAY_SETUP ",view.get_global_rect()," ",view.get_screen_transform()," ",view.showroom_viewport.size," ",view.camera.global_transform," ",view.camera.fov," ",root.size," ",root.get_visible_rect())
				view.showroom_viewport.get_texture().get_image().save_png(folder.path_join("direct.png"))
				for pixel: Vector2 in [Vector2(879,595),Vector2(885,620),Vector2(855,610)]:
					var screen: Vector2=pixel*root.get_visible_rect().size/Vector2(root.size)*Vector2(view.showroom_viewport.size)/view.size
					var ray_origin: Vector3=view.camera.project_ray_origin(screen)
					var ray_direction: Vector3=view.camera.project_ray_normal(screen)
					var closest: float=100.0; var found: Array=[]
					for part: MeshInstance3D in view.car.find_children("*","MeshInstance3D",true,false):
						if not part.visible or part.mesh==null:continue
						var local: Transform3D=part.global_transform.affine_inverse()
						var origin: Vector3=local*ray_origin
						var direction: Vector3=local.basis*ray_direction
						for surface: int in part.mesh.get_surface_count():
							var data: Array=part.mesh.surface_get_arrays(surface)
							var vertices: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
							var indices: PackedInt32Array=data[Mesh.ARRAY_INDEX]
							for index: int in range(0,indices.size(),3):
								var a: Vector3=vertices[indices[index]];var b: Vector3=vertices[indices[index+1]];var c: Vector3=vertices[indices[index+2]]
								var hit: Variant=Geometry3D.ray_intersects_triangle(origin,direction,a,b,c)
								if hit!=null and ray_origin.distance_to(part.global_transform*hit)<closest:
									closest=ray_origin.distance_to(part.global_transform*hit)
									found=[part.name,local*pose,hit,[a,b,c],[data[Mesh.ARRAY_NORMAL][indices[index]],data[Mesh.ARRAY_NORMAL][indices[index+1]],data[Mesh.ARRAY_NORMAL][indices[index+2]]]]
					print("CORNER_RAY ",pixel," ",found)
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

			if "--inspect-rear" in OS.get_cmdline_user_args() and shot[0]=="rear-right":
				for pixel: Vector2 in [Vector2(808,588),Vector2(810,590),Vector2(811,587),Vector2(805,593)]:
					var actual: Vector2=pixel*Vector2(view.showroom_viewport.size)/Vector2(1440,900)
					var origin: Vector3=view.camera.project_ray_origin(actual)
					var direction: Vector3=view.camera.project_ray_normal(actual)
					var hits: Array=[]
					for part: MeshInstance3D in view.car.find_children("*","MeshInstance3D",true,false):
						if not part.visible or part.mesh==null:continue
						var inverse: Transform3D=part.global_transform.affine_inverse()
						var hit: Dictionary=part.mesh.generate_triangle_mesh().intersect_ray(inverse*origin,inverse.basis*direction)
						if not hit.is_empty():hits.append([part.name,origin.distance_to(part.global_transform*hit.position),hit.position])
					print("REAR_RAY ",pixel," ",hits)

			view._update_roof()
			view.reflections.sync(); view.reflections.request_draw(); view.invalidate_render()
			view.showroom_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			for frame: int in range(24): await process_frame; await RenderingServer.frame_post_draw
			captures += 1
			assert(root.get_texture().get_image().save_png(folder.path_join(paint+"-"+shot[0]+".png")) == OK)
	view.free()
	print("PANEL_VIEWS: ",captures," actual model views saved; ",stage," simple=",simple)
	quit()
