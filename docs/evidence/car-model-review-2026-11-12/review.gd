extends SceneTree
## CMR01-CMR04: read-only current-model inventory and in-memory packing study.
const Base = preload("res://vehicle/modular_car_base.gd")
const Kits = preload("res://vehicle/modular_car_kits.gd")
const Cache = preload("res://vehicle/prepared_car_cache.gd")
const Packing = preload("res://rendering/mesh_vertex_packing.gd")
const OUT = "res://../docs/evidence/car-model-review-2026-11-12"
var rows: Array = []
var world: Node3D
var camera: Camera3D
var viewport: SubViewport
var graphical: bool
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("CMR_FAIL ",label)

func payload(mesh: Mesh) -> int:
	var size: int = 0
	for surface: int in range(mesh.get_surface_count()):
		var packet: Dictionary = mesh.get("_surfaces")[surface] if mesh is ArrayMesh else RenderingServer.mesh_get_surface(mesh.get_rid(),surface)
		for key: String in ["vertex_data","attribute_data","skin_data","index_data"]:
			size += packet.get(key,PackedByteArray()).size()
		size += packet.get("blend_shapes",PackedByteArray()).size()
		var lods: Array = packet.get("lods",[])
		for index: int in range(1,lods.size(),2): size += lods[index].size()
	return size

func fingerprint(mesh: ArrayMesh) -> String:
	# Compare ordered encoded corners, including all distance levels, without
	# decoding/re-encoding normals or relying on screenshot identity alone.
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for surface: int in range(mesh.get_surface_count()):
		var packet: Dictionary = mesh.get("_surfaces")[surface]
		var count: int = packet.vertex_count
		var format: int = mesh.surface_get_format(surface)
		var ps: int = RenderingServer.mesh_surface_get_format_vertex_stride(format,count)
		var ns: int = RenderingServer.mesh_surface_get_format_normal_tangent_stride(format,count)
		var ats: int = RenderingServer.mesh_surface_get_format_attribute_stride(format,count)
		var vertices: PackedByteArray = packet.vertex_data
		var attributes: PackedByteArray = packet.get("attribute_data",PackedByteArray())
		var indices: PackedByteArray = packet.get("index_data",PackedByteArray())
		var corners: int = int(packet.get("index_count",0))
		var stride: int = indices.size()/corners if corners else 2
		var streams: Array = [indices]
		var lods: Array = packet.get("lods",[])
		for level: int in range(1,lods.size(),2): streams.append(lods[level])
		for stream: PackedByteArray in streams:
			var length: int = stream.size()/stride if not stream.is_empty() else count
			hash.update(var_to_bytes(length))
			for corner: int in range(length):
				var index: int = corner if stream.is_empty() else stream.decode_u16(corner*stride) if stride==2 else stream.decode_u32(corner*stride)
				hash.update(vertices.slice(index*ps,(index+1)*ps))
				if ns: hash.update(vertices.slice(count*ps+index*ns,count*ps+(index+1)*ns))
				if ats: hash.update(attributes.slice(index*ats,(index+1)*ats))
	return hash.finish().hex_encode()

func unused(mesh: Mesh) -> Dictionary:
	var dead: int = 0
	var bytes: int = 0
	if not mesh is ArrayMesh or mesh.get_blend_shape_count()>0: return {"vertices":0,"bytes":0}
	for surface: int in range(mesh.get_surface_count()):
		var packet: Dictionary = mesh.get("_surfaces")[surface]
		var count: int = packet.vertex_count
		var indices: PackedByteArray = packet.get("index_data",PackedByteArray())
		var corners: int = int(packet.get("index_count",0))
		if corners==0: continue
		var stride: int = indices.size()/corners
		var streams: Array = [indices]
		var lods: Array = packet.get("lods",[])
		for level: int in range(1,lods.size(),2): streams.append(lods[level])
		var used: Dictionary = {}
		for stream: PackedByteArray in streams:
			for corner: int in range(stream.size()/stride):
				used[stream.decode_u16(corner*stride) if stride==2 else stream.decode_u32(corner*stride)] = true
		var missing: int = count-used.size()
		dead += missing
		var format: int = mesh.surface_get_format(surface)
		if not format & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES and not format & Mesh.ARRAY_FORMAT_BONES:
			bytes += missing*(RenderingServer.mesh_surface_get_format_vertex_stride(format,count)+RenderingServer.mesh_surface_get_format_normal_tangent_stride(format,count)+RenderingServer.mesh_surface_get_format_attribute_stride(format,count))
	return {"vertices":dead,"bytes":bytes}

func inventory(car: CarVisual, study: bool) -> Dictionary:
	var result: Dictionary = {"triangles":0,"shadow_only_triangles":0,"surfaces":0,"mesh_instances":0,"unique_meshes":0,"unique_materials":0,"buffer_bytes":0,"candidate_bytes":0,"packing_meshes":0,"lod_surfaces":0,"blend_meshes":0,"blend_bytes":0,"unused_vertices":0,"unused_bytes":0,"parts":[]}
	var seen: Dictionary = {}
	var materials: Dictionary = {}
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.mesh == null or not part.is_visible_in_tree(): continue
		var mesh: Mesh = part.mesh
		var triangles: int = 0
		var levels: int = 0
		for surface: int in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var indices: int = arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size()
			triangles += indices/3
			var material: Material = part.get_active_material(surface)
			if material != null: materials[material.get_instance_id()] = true
			if mesh is ArrayMesh and not mesh.get("_surfaces")[surface].get("lods",[]).is_empty(): levels += 1
		var shadow_only: bool = part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		result.shadow_only_triangles += triangles if shadow_only else 0
		result.triangles += 0 if shadow_only else triangles
		result.surfaces += 0 if shadow_only else mesh.get_surface_count()
		result.mesh_instances += 1
		result.lod_surfaces += levels
		var shapes: int = mesh.get_blend_shape_count() if mesh is ArrayMesh else 0
		var unused_data: Dictionary = unused(mesh)
		result.parts.append({"path":str(car.get_path_to(part)),"triangles":triangles,"surfaces":mesh.get_surface_count(),"bytes":payload(mesh),"lod_surfaces":levels,"blend_shapes":shapes,"shadow_only":shadow_only,"unused":unused_data})
		if seen.has(mesh): continue
		seen[mesh] = true
		result.buffer_bytes += payload(mesh)
		result.unused_vertices += unused_data.vertices
		result.unused_bytes += unused_data.bytes
		if shapes>0:
			result.blend_meshes += 1
			for packet: Dictionary in mesh.get("_surfaces"):
				result.blend_bytes += packet.get("blend_shapes",PackedByteArray()).size()
		var candidate: Mesh = Packing.pack(mesh) if study and mesh is ArrayMesh else mesh
		result.candidate_bytes += payload(candidate)
		if candidate != mesh:
			result.packing_meshes += 1
			check(fingerprint(mesh)==fingerprint(candidate),"ordered GPU corners and LODs "+str(car.vehicle_id)+"/"+str(part.name))
	result.unique_meshes = seen.size()
	result.unique_materials = materials.size()
	result.parts.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.triangles>b.triangles)
	return result

func settle() -> void:
	for frame: int in range(5):
		await process_frame
		await RenderingServer.frame_post_draw

func capture(car: CarVisual, label: String) -> Dictionary:
	var changes: Dictionary = {}
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.mesh is ArrayMesh:
			var candidate: Mesh = Packing.pack(part.mesh)
			if candidate != part.mesh: changes[part] = [part.mesh,candidate]
	var observations: Array = []
	for view: Array in [["front",Vector3(-5,3.0,-6)],["rear",Vector3(5,2.8,6)],["race",Vector3(0,8,4)]]:
		camera.position = view[1]
		camera.look_at(Vector3(0,0.55,0))
		camera.size = 5.1 if view[0]!="race" else 8.5
		# Exclude first-use viewport/shadow settling before the strict comparisons.
		for warmup: int in range(4): await settle()
		await settle()
		var original: Image = viewport.get_texture().get_image()
		await settle()
		check(original.get_data()==viewport.get_texture().get_image().get_data(),"unchanged original repeat pixels "+label+"/"+view[0])
		var draw_info: int = viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		original.save_png(OUT.path_join(label+"-"+view[0]+".png"))
		for part: MeshInstance3D in changes: part.mesh = changes[part][1]
		await settle()
		var candidate: Image = viewport.get_texture().get_image()
		var exact: bool = original.get_data()==candidate.get_data()
		candidate.save_png(OUT.path_join(label+"-"+view[0]+"-packed.png"))
		for part: MeshInstance3D in changes: part.mesh = changes[part][0]
		await settle()
		var control: Image = viewport.get_texture().get_image()
		control.save_png(OUT.path_join(label+"-"+view[0]+"-restored.png"))
		var restored: bool = original.get_data()==control.get_data()
		check(exact,"native packing pixels "+label+"/"+view[0])
		check(restored,"native restoration pixels "+label+"/"+view[0])
		observations.append({"view":view[0],"visible_draws":draw_info,"packing_pixel_exact":exact,"restoration_pixel_exact":restored})
	return {"changed_mesh_instances":changes.size(),"views":observations}

func run() -> void:
	graphical = DisplayServer.get_name()!="headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	viewport = SubViewport.new()
	viewport.size = Vector2i(1000,760)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	if graphical:
		camera = Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.current = true
		world.add_child(camera)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-55,-32,0)
		light.shadow_enabled = true
		world.add_child(light)
		var ambient := WorldEnvironment.new()
		ambient.environment = Environment.new()
		ambient.environment.background_mode = Environment.BG_COLOR
		ambient.environment.background_color = Color("28343f")
		ambient.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		ambient.environment.ambient_light_color = Color("ccd5de")
		ambient.environment.ambient_light_energy = 0.65
		world.add_child(ambient)
	for id: String in VehicleCatalog.IDS:
		for case: int in range(1 if graphical else 5):
			var car := CarVisual.new()
			car.vehicle_id = id
			car.simple_model = true
			car.editable_kits = case in [2,3]
			car.batch_parts = case!=4
			car.livery = VehicleLivery.defaults(id)
			car.customisation = VehicleCustomisation.defaults()
			if case in [1,3]:
				for category: String in ["hood","aero","rims","body"]:
					var options: Array = VehicleCustomisation.options(category,id)
					if options.size()>1: car.customisation[category] = options[1][0]
			Base.enabled = case!=4
			Kits.enabled = case!=4
			Cache.enabled = case!=4
			Cache.entries.clear()
			var before_base: int = Base.hits
			var before_kits: int = Kits.hits
			var started: int = Time.get_ticks_usec()
			world.add_child(car)
			while not car.model_ready: await process_frame
			var elapsed: int = Time.get_ticks_usec()-started
			var row: Dictionary = inventory(car,case==0)
			row.merge({"id":id,"case":case,"editable":car.editable_kits,"selection":car.customisation,"construction_usec":elapsed,"base_hits":Base.hits-before_base,"kit_hits":Kits.hits-before_kits})
			check(row.triangles>0,"constructed "+id+" case "+str(case))
			if graphical: row["native"] = await capture(car,id+"-"+RenderingServer.get_current_rendering_method())
			rows.append(row)
			print("CMR_CASE ",id," ",case," triangles=",row.triangles," surfaces=",row.surfaces," bytes=",row.buffer_bytes," candidate=",row.candidate_bytes," base_hits=",row.base_hits)
			car.free()
			await process_frame
	var mode: String = RenderingServer.get_current_rendering_method() if graphical else "headless"
	var file := FileAccess.open(OUT.path_join(mode+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info(),"checks":checks,"failures":failures,"rows":rows},"\t"))
	file.close()
	viewport.free()
	print("CMR_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
