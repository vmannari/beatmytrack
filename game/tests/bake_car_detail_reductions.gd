extends SceneTree
## CLV02: export exact frame geometry, or stage verified index-only recipes.
const Detail=preload("res://vehicle/car_detail_reduction.gd")
const WORK: String="res://../build/car-detail-reduction-2026-11-14"
const OUT: String="res://../docs/evidence/car-detail-reduction-2026-11-14"
const Compact=preload("res://tests/support/car_static_reduction_bake.gd")
var contexts: Dictionary={}
var geometry_file: FileAccess
var publish: bool=false
var proposals: Dictionary={}
var observations: Array=[]
var current_car: CarVisual
var stage_directory: String=WORK.path_join("staged")

func _initialize() -> void: run.call_deferred()

func packed_mesh(source: Mesh) -> ArrayMesh:
	if source is ArrayMesh: return source
	var packets: Array=[]
	for surface: int in range(source.get_surface_count()):
		var packet: Dictionary=RenderingServer.mesh_get_surface(source.get_rid(),surface)
		packet.material=source.surface_get_material(surface)
		packet.aabb=source.get_aabb()
		packets.append(packet)
	var result:=ArrayMesh.new()
	result.set("_surfaces",packets)
	result.custom_aabb=source.get_aabb()
	return result

func reduced(source: Mesh, surfaces: Dictionary) -> ArrayMesh:
	var original: ArrayMesh=packed_mesh(source)
	var packets: Array=original.get("_surfaces").duplicate(true)
	for surface_text: String in surfaces:
		var surface: int=int(surface_text)
		var packet: Dictionary=packets[surface]
		var arrays: Array=source.surface_get_arrays(surface)
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if indices.is_empty():
			for index: int in range(arrays[Mesh.ARRAY_VERTEX].size()): indices.append(index)
		var removed: Dictionary={}
		for index: float in surfaces[surface_text]: removed[int(index)]=true
		var keep:=PackedInt32Array()
		for triangle: int in range(indices.size()/3):
			if not removed.has(triangle): keep.append_array(indices.slice(triangle*3,triangle*3+3))
		assert(not keep.is_empty())
		var stride: int=2 if int(packet.vertex_count)<=65536 else 4
		var raw:=PackedByteArray()
		raw.resize(keep.size()*stride)
		for at: int in range(keep.size()):
			if stride==2: raw.encode_u16(at*stride,keep[at])
			else: raw.encode_u32(at*stride,keep[at])
		packet.index_data=raw;packet.index_count=keep.size()
		packet.format=int(packet.format)|Mesh.ARRAY_FORMAT_INDEX
		packet.erase("lods")
	var result:=ArrayMesh.new()
	result.set("_surfaces",packets)
	result.custom_aabb=source.get_aabb()
	return Compact.new().compact(result)

func export_group(group: Dictionary) -> void:
	if contexts.has(group.code): return
	var rows: Array=[]
	for entry: Dictionary in group.entries:
		var part: MeshInstance3D=entry.part
		var mesh: Mesh=part.mesh
		var surfaces: Array=[]
		for surface: int in range(mesh.get_surface_count()):
			var arrays: Array=mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			for at: int in range(vertices.size()): vertices[at]=entry.pose*vertices[at]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			if indices.is_empty():
				for at: int in range(vertices.size()): indices.append(at)
			var vertex_offset: int=geometry_file.get_position()
			geometry_file.store_buffer(vertices.to_byte_array())
			var index_offset: int=geometry_file.get_position()
			geometry_file.store_buffer(indices.to_byte_array())
			surfaces.append({"vertex_offset":vertex_offset,"vertex_count":vertices.size(),"index_offset":index_offset,"index_count":indices.size()})
		var physical_frame: Node3D=Detail.frame_for(current_car,part,false)
		var role: String="body" if physical_frame==current_car.body else "wheel" if physical_frame in current_car.rolling_wheels or physical_frame in current_car.front_wheels or physical_frame in current_car.rear_wheels else str(physical_frame.name)
		var shared: String=var_to_bytes([group.vehicle,entry.source,role,Detail.relative_pose(physical_frame,part)]).hex_encode().sha256_text()
		rows.append({"ordinal":rows.size(),"code":entry.code,"source":entry.source,"shared":shared,"path":str(current_car.get_path_to(part)),"kind":mesh.get_class(),"frame":group.code,"surfaces":surfaces,"opaque":entry.opaque,"cull_mode":int(entry.state[0][2]) if entry.opaque else 0,"cast_shadow":part.cast_shadow,"layers":part.layers,"morphs":mesh.get_blend_shape_count() if mesh is ArrayMesh else 0,"triangles":mesh.get_faces().size()/3,"protected":entry.protected})
	contexts[group.code]={"vehicle":group.vehicle,"code":group.code,"parts":rows}

func stage_group(group: Dictionary) -> void:
	if contexts.has(group.code) or not proposals.has(group.code): return
	contexts[group.code]=true
	var changes: Dictionary=proposals[group.code]
	var parts: Dictionary={}
	for entry: Dictionary in group.entries:
		if not changes.has(entry.code): continue
		assert(not entry.protected and entry.opaque)
		var row: Dictionary=changes[entry.code]
		var part: MeshInstance3D=entry.part
		assert(part.mesh.get_faces().size()/3==int(row.before))
		if row.hidden:
			parts[entry.code]={"source":entry.source,"hidden":true}
			continue
		var result: ArrayMesh=reduced(part.mesh,row.surfaces)
		if result.get_aabb()!=part.mesh.get_aabb(): printerr("DETAIL_BOUNDS ",part.name," ",part.mesh.get_class()," before=",part.mesh.get_aabb()," after=",result.get_aabb())
		assert(result.get_aabb()==part.mesh.get_aabb())
		assert(result.get_faces().size()/3==int(row.after))
		result.set_meta("car_detail_source",entry.source)
		# Active finishes belong to each instance. A valid inert fallback also
		# keeps engine shader-parameter introspection safe during mesh replacement.
		for surface: int in range(result.get_surface_count()): result.surface_set_material(surface,StandardMaterial3D.new())
		var file: String=group.vehicle+"_"+entry.source+"_"+Detail.mesh_key(result).left(20)+".res"
		assert(ResourceSaver.save(result,stage_directory.path_join(file),ResourceSaver.FLAG_COMPRESS)==OK)
		parts[entry.code]={"source":entry.source,"mesh":file}
	var recipe: Dictionary={"schema":Detail.SCHEMA,"context":group.code,"parts":parts}
	var file: String=stage_directory.path_join(group.vehicle+"_"+group.code+".json")
	FileAccess.open(file,FileAccess.WRITE).store_string(JSON.stringify(recipe,"\t"))
	observations.append({"vehicle":group.vehicle,"context":group.code,"changed_parts":parts.size()})

func collect(group: Dictionary) -> void:
	if publish: stage_group(group)
	else: export_group(group)

func run() -> void:
	publish="--stage" in OS.get_cmdline_user_args()
	var selected: PackedStringArray=[]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--stage-dir="): stage_directory=argument.trim_prefix("--stage-dir=")
		if argument.begins_with("--vehicles="): selected=argument.trim_prefix("--vehicles=").split(",")
	assert(stage_directory.begins_with(WORK+"/staged"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(stage_directory))
	if publish: proposals=JSON.parse_string(FileAccess.get_file_as_string(WORK.path_join("proposals.json")))
	else: geometry_file=FileAccess.open(WORK.path_join("geometry.bin"),FileAccess.WRITE)
	preload("res://vehicle/modular_car_base.gd").enabled=false
	preload("res://vehicle/modular_car_kits.gd").enabled=false
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	preload("res://ui/garage_car_cache.gd").enabled=false
	Detail.offline=collect
	for id: String in VehicleCatalog.IDS:
		if not selected.is_empty() and id not in selected: continue
		for editable: bool in [false,true]:
			var car:=CarVisual.new()
			current_car=car
			car.vehicle_id=id;car.editable_kits=editable;car.cache_rest_pose=false
			car.livery=VehicleLivery.defaults(id)
			root.add_child(car)
			while not car.model_ready: await process_frame
			if editable:
				for category: String in VehicleCustomisation.CATEGORIES:
					for option: Array in VehicleCustomisation.options(category,id).slice(1):
						var selection: Dictionary=car.customisation.duplicate()
						selection[category]=option[0]
						car.change_kit_parts(selection)
					var stock: Dictionary=car.customisation.duplicate()
					stock[category]="stock"
					car.change_kit_parts(stock)
			car.free();await process_frame
		print("DETAIL_CONTEXTS ",id," stage=",publish," count=",contexts.size())
	Detail.offline=Callable()
	if not publish:
		geometry_file.close()
		FileAccess.open(WORK.path_join("contexts.json"),FileAccess.WRITE).store_string(JSON.stringify(contexts))
	else: FileAccess.open(OUT.path_join("recipes.json"),FileAccess.WRITE).store_string(JSON.stringify(observations,"\t"))
	print("DETAIL_CONTEXTS_COMPLETE stage=",publish," contexts=",contexts.size())
	quit()
