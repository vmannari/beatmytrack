extends SceneTree
## CSR01: read-only inventory of current stock/fitted race and Garage meshes.
## Counts describe stored base geometry, not visible pixels, draw calls or FPS.
const Base = preload("res://vehicle/modular_car_base.gd")
const Kits = preload("res://vehicle/modular_car_kits.gd")
const Cache = preload("res://vehicle/prepared_car_cache.gd")
var output: String = "res://../build/car-simplification-review-2026-11-07/inventory.json"
var failures: int = 0
var rows: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func inventory(model: Node3D) -> Dictionary:
	var result: Dictionary = {"mesh_nodes":0,"surfaces":0,"base_triangles":0,"base_vertices":0,"shadow_triangles":0,"surfaces_with_lods":0,"triangles_on_lod_surfaces":0,"top_surfaces":[]}
	var materials: Dictionary = {}
	var shaders: Dictionary = {}
	for node: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if node.mesh == null or not node.is_visible_in_tree(): continue
		var shadow_only: bool = node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if not shadow_only: result.mesh_nodes += 1
		var stored: Array = node.mesh.get("_surfaces") if node.mesh is ArrayMesh else []
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: int = arrays[Mesh.ARRAY_VERTEX].size()
			var corners: int = arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty() else vertices
			if corners % 3 != 0 or vertices == 0:
				failures += 1
				printerr("CSR01 invalid triangle surface ",model.get_path_to(node))
			var triangles: int = corners / 3
			if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: result.shadow_triangles += triangles
			if shadow_only: continue
			result.surfaces += 1
			result.base_triangles += triangles
			result.base_vertices += vertices
			var has_lods: bool = surface < stored.size() and not stored[surface].get("lods",[]).is_empty()
			if has_lods:
				result.surfaces_with_lods += 1
				result.triangles_on_lod_surfaces += triangles
			var material: Material = node.get_active_material(surface)
			var shader_path: String = ""
			if material != null:
				materials[material.get_instance_id()] = true
				if material is ShaderMaterial and material.shader != null:
					shader_path = material.shader.resource_path
					shaders[shader_path] = true
			result.top_surfaces.append({"path":str(model.get_path_to(node)),"surface":surface,"triangles":triangles,"shader":shader_path,"has_lods":has_lods})
	result.unique_materials = materials.size()
	result.shader_paths = shaders.keys()
	result.top_surfaces.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.triangles > b.triangles)
	result.top_surfaces = result.top_surfaces.slice(0,8)
	return result

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	var stage := Node3D.new()
	root.add_child(stage)
	for id: String in VehicleCatalog.IDS:
		for simple: bool in [false,true]:
			for fitted: bool in [false,true]:
				var car := CarVisual.new()
				car.vehicle_id = id
				car.simple_model = simple
				car.cache_rest_pose = false
				car.customisation = VehicleCustomisation.defaults()
				if fitted:
					for category: String in VehicleCustomisation.CATEGORIES:
						var options: Array = VehicleCustomisation.options(category,id)
						car.customisation[category] = str(options[-1][0])
				var base_hits: int = Base.hits
				var kit_hits: int = Kits.hits
				stage.add_child(car)
				var deadline: int = Time.get_ticks_msec()+60000
				while not car.model_ready and Time.get_ticks_msec() < deadline: await process_frame
				if not car.model_ready:
					failures += 1
					printerr("CSR01 model timeout ",id)
				var row: Dictionary = inventory(car)
				row.merge({"vehicle":id,"context":"race","simple":simple,"fitted":fitted,"parts":car.customisation.duplicate(),"prepared_base_hits":Base.hits-base_hits,"prepared_kit_hits":Kits.hits-kit_hits})
				rows.append(row)
				print("CSR01 ",id," simple=",simple," fitted=",fitted," triangles=",row.base_triangles," surfaces=",row.surfaces," lod_surfaces=",row.surfaces_with_lods)
				car.free()
				await process_frame
		var path: String = "res://assets/garage/cars_v1/"+id+".scn"
		var scene: PackedScene = load(path)
		var holder: Node3D = scene.instantiate()
		stage.add_child(holder)
		var row: Dictionary = inventory(holder)
		row.merge({"vehicle":id,"context":"garage_template","path":path,"sha256":FileAccess.get_sha256(path)})
		rows.append(row)
		holder.free()
		await process_frame
	stage.free()
	var directory: String = ProjectSettings.globalize_path(output.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(directory) != OK: failures += 1
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null:
		printerr("CSR01 cannot write inventory ",output)
		quit(1)
		return
	file.store_string(JSON.stringify({"requirement":"CSR01","engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"build_identity_sha256":FileAccess.get_sha256("res://core/build_identity.gd"),"failures":failures,"notes":["Read-only inventory; no geometry, material or persistent player-state edits.","Stored base triangle counts; LOD selection, occlusion, outlines, shadows and reflection passes are not render measurements.","Fitted sample selects the final catalogue choice per category; not an exhaustive kit sweep.","No appearance, device performance or loading improvement is established by this inventory."],"rows":rows},"\t")+"\n")
	file.close()
	print("CSR01 complete rows=",rows.size()," failures=",failures," output=",output)
	quit(1 if failures else 0)
