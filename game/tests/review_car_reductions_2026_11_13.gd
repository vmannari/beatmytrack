extends "res://tests/review_model_refinement_metrics.gd"
## Read-only measured candidates. No ResourceSaver or production cache writes.
const DEST = "res://../docs/evidence/car-reduction-review-2026-11-13"
const CAR_IDS: Array[String] = ["compact","kart","forklift","electric","hovercraft"]
var study_rows: Array = []
var candidate_cache: Dictionary = {}
var generated_cache: Dictionary = {}
var source_view: bool = false
var axial_only: bool = false
var hover_only: bool = false

func _initialize() -> void:
	node_added.connect(func(node: Node) -> void:
		if source_view and node is CarVisual: node.batch_parts=false)
	axial_only = "--axial-only" in OS.get_cmdline_user_args()
	hover_only = "--hover-only" in OS.get_cmdline_user_args()
	study.call_deferred()

func detail_inventory(car: CarVisual) -> Dictionary:
	var data: Dictionary = inventory(car,false)
	for part: Dictionary in data.parts:
		var node: MeshInstance3D = car.get_node(NodePath(part.path))
		part["bounds"] = str(node.mesh.get_aabb().size)
		part["kind"] = node.mesh.get_class()
		part["surface_details"] = []
		if node.mesh is CylinderMesh:
			part["axial_rings"] = node.mesh.rings
			part["radial_segments"] = node.mesh.radial_segments
		for surface: int in range(node.mesh.get_surface_count()):
			var packet: Dictionary = node.mesh.get("_surfaces")[surface] if node.mesh is ArrayMesh else RenderingServer.mesh_get_surface(node.mesh.get_rid(),surface)
			var lods: Array = packet.get("lods",[])
			var stride: int = 2 if int(packet.vertex_count)<=65536 else 4
			var levels: Array = []
			for at: int in range(0,lods.size(),2): levels.append({"error":lods[at],"triangles":lods[at+1].size()/stride/3})
			var material: Material = node.get_active_material(surface)
			part.surface_details.append({"master_triangles":int(packet.get("index_count",packet.vertex_count))/3,"lods":levels,"material":material.resource_path if material!=null else ""})
	return data

func primitive_candidate(source: Mesh) -> Mesh:
	if not source is CylinderMesh or source.rings<=1: return source
	var result: CylinderMesh = source.duplicate()
	result.rings = 1
	result.custom_aabb = source.get_aabb()
	return result

func hover_grid(source: Mesh, columns: int, grid_rows: int) -> Mesh:
	if not source is ArrayMesh or source.get_surface_count()!=1: return source
	var arrays: Array = source.surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_VERTEX].size()==(columns+1)*(grid_rows+1),"expected authored Hover grid")
	if arrays[Mesh.ARRAY_VERTEX].size()!=(columns+1)*(grid_rows+1): return source
	var old_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var reverse: bool = old_indices[1]>old_indices[2]
	var indices := PackedInt32Array()
	for row: int in range(grid_rows):
		for column: int in range(0,columns,2):
			var a: int = row*(columns+1)+column
			for triangle: Array in [[a,a+2,a+columns+3],[a,a+columns+3,a+columns+1]]:
				if reverse: triangle.reverse()
				for vertex: int in triangle: indices.append(vertex)
	var packets: Array = source.get("_surfaces").duplicate(true)
	var stride: int = 2 if int(packets[0].vertex_count)<=65536 else 4
	var encoded := PackedByteArray()
	encoded.resize(indices.size()*stride)
	for corner: int in range(indices.size()):
		if stride==2: encoded.encode_u16(corner*stride,indices[corner])
		else: encoded.encode_u32(corner*stride,indices[corner])
	packets[0].index_data = encoded
	packets[0].index_count = indices.size()
	packets[0].erase("lods")
	var result := ArrayMesh.new()
	result.set("_surfaces",packets)
	result.custom_aabb = source.custom_aabb
	return result

func lod_candidate(source: Mesh, metric: float) -> Mesh:
	if not source is ArrayMesh or source.get_blend_shape_count()>0: return source
	var key: String = str(source.get_instance_id())+"|"+str(metric)
	if candidate_cache.has(key): return candidate_cache[key]
	var packets: Array = source.get("_surfaces").duplicate(true)
	if not generated_cache.has(source): generated_cache[source] = preload("res://vehicle/car_mesh_lods.gd").new().prepare(source)
	var prepared: ArrayMesh = generated_cache[source]
	packets = prepared.get("_surfaces").duplicate(true)
	var changed: bool = false
	for packet: Dictionary in packets:
		var stride: int = 2 if int(packet.vertex_count)<=65536 else 4
		var original: int = int(packet.get("index_count",0))
		var selected: PackedByteArray = packet.get("index_data",PackedByteArray())
		var levels: Array = packet.get("lods",[])
		for at: int in range(0,levels.size(),2):
			# Study a metric in model metres; this is not a screen-size policy.
			if float(levels[at])<=metric and levels[at+1].size()<selected.size(): selected=levels[at+1]
		if not selected.is_empty() and selected.size()/stride<original:
			packet.index_data = selected
			packet.index_count = selected.size()/stride
			packet.erase("lods")
			changed = true
	if not changed:
		candidate_cache[key] = source
		return source
	var result := ArrayMesh.new()
	result.set("_surfaces",packets)
	result.custom_aabb = source.custom_aabb
	result.shadow_mesh = source.shadow_mesh
	# Encoded positions, normals, UVs and finishes are untouched; only indices vary.
	for surface: int in range(source.get_surface_count()):
		check(result.get("_surfaces")[surface].vertex_data==source.get("_surfaces")[surface].vertex_data,"candidate encoded vertices")
	candidate_cache[key] = result
	return result

func candidates(car: CarVisual, mode: String) -> Dictionary:
	var changes: Dictionary = {}
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.mesh==null or not part.is_visible_in_tree() or part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		var source: Mesh = part.mesh
		var target: Mesh = source
		if mode=="axial": target = primitive_candidate(source)
		elif mode.begins_with("hover-"):
			var label: String = str(part.name)
			if mode=="hover-rings" and (label.begins_with("SportDuctRim") or label.begins_with("SportGuardRing")): target=hover_grid(source,40,6)
			if mode=="hover-seams" and label.begins_with("SportSkirtSeam"): target=hover_grid(source,4,6)
			if mode=="hover-skirt" and label=="SportPressureSkirt": target=hover_grid(source,192,10)
		else:
			# Keep reflection layers and moving driver original, as production does.
			if not preload("res://vehicle/car_mesh_lods.gd").new().eligible(part,car.vehicle_id): continue
			target = lod_candidate(source,0.001 if mode=="lod1mm" else 0.003)
		if target!=source: changes[part] = [source,target]
	return changes

func swap(changes: Dictionary, candidate: bool) -> void:
	for part: MeshInstance3D in changes: part.mesh = changes[part][1 if candidate else 0]

func difference(a: Image, b: Image) -> Dictionary:
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var original: PackedByteArray = a.get_data()
	var current: PackedByteArray = b.get_data()
	check(original.size()==current.size(),"comparison dimensions")
	var changed: int = 0
	var significant: int = 0
	var total: int = 0
	for offset: int in range(0,original.size(),4):
		var peak: int = 0
		for channel: int in range(3):
			var delta: int = absi(int(original[offset+channel])-int(current[offset+channel]))
			total+=delta
			peak=maxi(peak,delta)
		if peak>0: changed+=1
		if peak>8: significant+=1
	return {"changed_pixels":changed,"significant_pixels":significant,"rgb_mae_255":float(total)/(a.get_width()*a.get_height()*3)}

func wait_view(view: CarShowroom) -> void:
	view.invalidate_render()
	for frame: int in range(12):
		await process_frame
		await RenderingServer.frame_post_draw

func graphical_study(id: String, directory: String) -> Dictionary:
	source_view = axial_only or hover_only
	Base.enabled = not source_view
	Kits.enabled = not source_view
	Cache.enabled = not source_view
	Cache.entries.clear()
	var view := CarShowroom.new()
	view.vehicle_id = id
	view.simple_model = true
	view.read_only = true
	view.livery = VehicleLivery.defaults(id)
	view.customisation = VehicleCustomisation.defaults()
	view.size = Vector2(1000,760)
	root.add_child(view)
	while not view.showroom_ready or not view.car.model_ready: await process_frame
	var result: Dictionary = {"vehicle":id,"baseline":detail_inventory(view.car),"candidates":[]}
	var modes: Array = ["hover-rings","hover-seams","hover-skirt"] if hover_only else (["axial"] if axial_only else ["lod1mm","lod3mm"])
	for mode: String in modes:
		var changes: Dictionary = candidates(view.car,mode)
		swap(changes,true)
		var measured: Dictionary = inventory(view.car,false)
		swap(changes,false)
		var observations: Array = []
		for shot: Array in [["front",-0.70,0.31,1.0],["rear",2.45,0.31,1.0],["race-distance",-0.4,1.02,3.1]]:
			view.yaw = shot[1]
			view.elevation = shot[2]
			view.zoom = float(shot[3])*(1.05 if id in ["compact","forklift"] else 0.85)
			view._orbit()
			await wait_view(view)
			var before_image: Image = view.showroom_viewport.get_texture().get_image()
			var before_primitives: int = view.showroom_viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
			await wait_view(view)
			var repeat: Dictionary = difference(before_image,view.showroom_viewport.get_texture().get_image())
			swap(changes,true)
			await wait_view(view)
			var after_image: Image = view.showroom_viewport.get_texture().get_image()
			var after_primitives: int = view.showroom_viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
			var diff: Dictionary = difference(before_image,after_image)
			swap(changes,false)
			await wait_view(view)
			var restored: Dictionary = difference(before_image,view.showroom_viewport.get_texture().get_image())
			var stem: String = directory.path_join(id+"-"+mode+"-"+shot[0])
			check(before_image.save_png(stem+"-before.png")==OK,"save before")
			check(after_image.save_png(stem+"-candidate.png")==OK,"save candidate")
			check(repeat.significant_pixels==0,"stable native repeat "+id+mode+shot[0])
			check(restored.significant_pixels==0,"restored native repeat "+id+mode+shot[0])
			observations.append({"view":shot[0],"difference":diff,"repeat":repeat,"restored":restored,"visible_primitives_before":before_primitives,"visible_primitives_candidate":after_primitives})
		result.candidates.append({"mode":mode,"changed_meshes":changes.size(),"inventory":measured,"views":observations})
		print("REDUCTION_NATIVE ",id," ",mode," triangles=",measured.triangles)
	view.free()
	await process_frame
	return result

func study() -> void:
	graphical = DisplayServer.get_name()!="headless"
	var mode: String = RenderingServer.get_current_rendering_method() if graphical else "headless"
	var directory: String = DEST.path_join(mode+("-hover" if hover_only else ("-axial" if axial_only else "")))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	world = Node3D.new()
	root.add_child(world)
	for id: String in CAR_IDS:
		if hover_only and id!="hovercraft": continue
		if graphical:
			study_rows.append(await graphical_study(id,directory))
			continue
		for source_case: bool in [false,true]:
			Base.enabled = not source_case
			Kits.enabled = not source_case
			Cache.enabled = not source_case
			Cache.entries.clear()
			var car := CarVisual.new()
			car.vehicle_id = id
			car.simple_model = true
			car.batch_parts = not source_case
			car.cache_rest_pose = false
			car.livery = VehicleLivery.defaults(id)
			car.customisation = VehicleCustomisation.defaults()
			var hits: int = Base.hits
			world.add_child(car)
			while not car.model_ready: await process_frame
			var baseline: Dictionary = detail_inventory(car)
			check(baseline.triangles>0,"car built "+id)
			var entry: Dictionary = {"vehicle":id,"construction":"source" if source_case else "prepared","base_hits":Base.hits-hits,"baseline":baseline,"candidates":[]}
			var modes: Array = ["hover-rings","hover-seams","hover-skirt"] if hover_only and source_case else (["axial"] if source_case else ["lod1mm","lod3mm"])
			for candidate: String in modes:
				var changes: Dictionary = candidates(car,candidate)
				swap(changes,true)
				var measured: Dictionary = inventory(car,false)
				swap(changes,false)
				check(inventory(car,false).triangles==baseline.triangles,"candidate restores model")
				entry.candidates.append({"mode":candidate,"changed_meshes":changes.size(),"inventory":measured})
			study_rows.append(entry)
			print("REDUCTION_CASE ",id," ",entry.construction," triangles=",baseline.triangles," bytes=",baseline.buffer_bytes)
			car.free()
			await process_frame
	world.free()
	var file := FileAccess.open(directory.path_join("inventory.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"engine":Engine.get_version_info(),"rows":study_rows},"\t"))
	file.close()
	print("CAR_REDUCTION_REVIEW checks=",checks," failures=",failures)
	quit(1 if failures else 0)
