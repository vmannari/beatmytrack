extends "res://tests/measure_car_simplification.gd"
## Read-only second review: sharing, distance-index storage and static morph faces.
const DEST = "res://../docs/evidence/car-optimisation-review-round2-2026-11-13"
const IDS: Array[String] = ["compact","kart","forklift","electric","hovercraft"]
var records: Array = []
var cached_paths: Array[String] = []

func _initialize() -> void: study.call_deferred()

func storage_key(mesh: ArrayMesh) -> String:
	var data: Array = [mesh.get_blend_shape_count(),mesh.custom_aabb,mesh.get_aabb(),mesh.resource_name]
	if mesh.shadow_mesh!=null: return str(mesh.get_instance_id())
	for key: StringName in mesh.get_meta_list(): data.append([str(key),mesh.get_meta(key)])
	for surface: int in range(mesh.get_surface_count()):
		var packet: Dictionary = mesh.get("_surfaces")[surface].duplicate()
		packet.erase("material")
		data.append(packet)
	return var_to_bytes(data).hex_encode().sha256_text()

func share_candidates(car: CarVisual) -> Dictionary:
	var canonical: Dictionary = {}
	var changes: Dictionary = {}
	for node: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if not node.mesh is ArrayMesh or node.mesh.get_blend_shape_count()>0: continue
		var independent: bool = true
		for surface: int in range(node.mesh.get_surface_count()):
			if node.material_override==null and node.get_surface_override_material(surface)==null: independent=false
		if not independent: continue
		var key: String = storage_key(node.mesh)
		if canonical.has(key) and canonical[key]!=node.mesh: changes[node]=[node.mesh,canonical[key]]
		else: canonical[key]=node.mesh
	return changes

func prune_lods(source: Mesh) -> Mesh:
	if not source is ArrayMesh or source.get_blend_shape_count()>0: return source
	var packets: Array = source.get("_surfaces").duplicate(true)
	var changed: bool = false
	for packet: Dictionary in packets:
		var levels: Array = packet.get("lods",[])
		var previous: PackedByteArray = packet.get("index_data",PackedByteArray())
		var keep: Array = []
		for at: int in range(0,levels.size(),2):
			if levels[at+1]==previous: changed=true; continue
			keep.append(levels[at]); keep.append(levels[at+1]); previous=levels[at+1]
		if not levels.is_empty(): packet.lods=keep
	if not changed: return source
	var result := ArrayMesh.new()
	result.set("_surfaces",packets)
	result.custom_aabb=source.custom_aabb
	result.shadow_mesh=source.shadow_mesh
	return result

func inspect_buffers(car: CarVisual) -> Dictionary:
	var unique: Dictionary = {}
	var vertex_bytes: int = 0
	var lod_bytes: int = 0
	var indices: int = 0
	var details: Array = []
	for node: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if not node.mesh is ArrayMesh or unique.has(node.mesh): continue
		unique[node.mesh]=true
		for surface: int in range(node.mesh.get_surface_count()):
			var packet: Dictionary = node.mesh.get("_surfaces")[surface]
			var lods: Array = packet.get("lods",[])
			var stored: int = 0
			for at: int in range(1,lods.size(),2): stored+=lods[at].size()
			lod_bytes+=stored
			indices+=packet.get("index_data",PackedByteArray()).size()
			for field: String in ["vertex_data","attribute_data","skin_data","blend_shapes"]: vertex_bytes+=packet.get(field,PackedByteArray()).size()
			details.append({"path":str(car.get_path_to(node)),"surface":surface,"lod_count":lods.size()/2,"lod_bytes":stored,"master_bytes":packet.get("index_data",PackedByteArray()).size()})
	details.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return a.lod_bytes>b.lod_bytes)
	return {"vertex_attribute_morph_bytes":vertex_bytes,"master_index_bytes":indices,"lod_index_bytes":lod_bytes,"parts":details}

func rebuild_packet(source: ArrayMesh, surface: int, corners: PackedInt32Array, morph: bool) -> Dictionary:
	var original: Dictionary = source.get("_surfaces")[surface]
	var packet: Dictionary = original.duplicate(true)
	var count: int = packet.vertex_count
	var format: int = source.surface_get_format(surface)
	var ps: int = RenderingServer.mesh_surface_get_format_vertex_stride(format,count)
	var ns: int = RenderingServer.mesh_surface_get_format_normal_tangent_stride(format,count)
	var ats: int = RenderingServer.mesh_surface_get_format_attribute_stride(format,count)
	var unique := PackedInt32Array()
	var remap: Dictionary = {}
	for old: int in corners:
		if not remap.has(old): remap[old]=unique.size(); unique.append(old)
	var streams: Array = [packet.vertex_data]
	var shapes: PackedByteArray = packet.get("blend_shapes",PackedByteArray())
	if morph:
		assert(shapes.size()==source.get_blend_shape_count()*count*(ps+ns))
		for pose: int in range(source.get_blend_shape_count()): streams.append(shapes.slice(pose*count*(ps+ns),(pose+1)*count*(ps+ns)))
	var replacements: Array = []
	for stream: PackedByteArray in streams:
		var positions := PackedByteArray()
		var normals := PackedByteArray()
		for old: int in unique:
			positions.append_array(stream.slice(old*ps,(old+1)*ps))
			normals.append_array(stream.slice(count*ps+old*ns,count*ps+(old+1)*ns))
		positions.append_array(normals)
		replacements.append(positions)
	packet.vertex_data=replacements[0]
	packet.vertex_count=unique.size()
	var attrs := PackedByteArray()
	var source_attrs: PackedByteArray = packet.get("attribute_data",PackedByteArray())
	for old: int in unique:
		if ats: attrs.append_array(source_attrs.slice(old*ats,(old+1)*ats))
	if ats: packet.attribute_data=attrs
	var stride: int = 2 if unique.size()<=65536 else 4
	var indices := PackedByteArray()
	indices.resize(corners.size()*stride)
	for corner: int in range(corners.size()):
		if stride==2: indices.encode_u16(corner*stride,remap[corners[corner]])
		else: indices.encode_u32(corner*stride,remap[corners[corner]])
	packet.index_data=indices
	packet.index_count=corners.size()
	packet.erase("lods")
	packet.erase("blend_shapes")
	if morph:
		var combined := PackedByteArray()
		for at: int in range(1,replacements.size()): combined.append_array(replacements[at])
		packet.blend_shapes=combined
	return packet

func split_driver(source: ArrayMesh) -> Dictionary:
	var active: Array = []
	var fixed: Array = []
	var report: Array = []
	var fixed_material: Material
	for surface: int in range(source.get_surface_count()):
		var packet: Dictionary = source.get("_surfaces")[surface]
		var count: int = packet.vertex_count
		var format: int = source.surface_get_format(surface)
		var ps: int = RenderingServer.mesh_surface_get_format_vertex_stride(format,count)
		var ns: int = RenderingServer.mesh_surface_get_format_normal_tangent_stride(format,count)
		var raw: PackedByteArray = packet.vertex_data
		var poses: PackedByteArray = packet.blend_shapes
		var invariant: Array[bool] = []
		var static_vertices: int = 0
		for vertex: int in range(count):
			var same: bool = true
			for pose: int in range(source.get_blend_shape_count()):
				var start: int = pose*count*(ps+ns)
				if poses.slice(start+vertex*ps,start+(vertex+1)*ps)!=raw.slice(vertex*ps,(vertex+1)*ps): same=false; break
				if poses.slice(start+count*ps+vertex*ns,start+count*ps+(vertex+1)*ns)!=raw.slice(count*ps+vertex*ns,count*ps+(vertex+1)*ns): same=false; break
			invariant.append(same)
			if same: static_vertices+=1
		var indices: PackedInt32Array = source.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
		var moving_corners := PackedInt32Array()
		var fixed_corners := PackedInt32Array()
		for at: int in range(0,indices.size(),3):
			var frozen: bool = invariant[indices[at]] and invariant[indices[at+1]] and invariant[indices[at+2]]
			for offset: int in range(3):
				if frozen: fixed_corners.append(indices[at+offset])
				else: moving_corners.append(indices[at+offset])
		active.append(rebuild_packet(source,surface,moving_corners,true))
		if not fixed_corners.is_empty():
			fixed.append(rebuild_packet(source,surface,fixed_corners,false))
			fixed_material=source.surface_get_material(surface)
		report.append({"role":source.surface_get_material(surface).resource_name,"vertices":count,"static_vertices":static_vertices,"static_triangles":fixed_corners.size()/3,"dynamic_triangles":moving_corners.size()/3})
	var dynamic := ArrayMesh.new()
	dynamic.blend_shape_mode=source.blend_shape_mode
	for pose: int in range(source.get_blend_shape_count()): dynamic.add_blend_shape(source.get_blend_shape_name(pose))
	dynamic.set("_surfaces",active)
	dynamic.custom_aabb=source.get_aabb()
	var static_mesh := ArrayMesh.new()
	static_mesh.set("_surfaces",fixed)
	static_mesh.custom_aabb=source.get_aabb()
	check(source.get_faces().size()==dynamic.get_faces().size()+static_mesh.get_faces().size(),"split retains every driver triangle")
	return {"dynamic":dynamic,"static":static_mesh,"material":fixed_material,"surface_report":report,"before_bytes":payload(source),"after_bytes":payload(dynamic)+payload(static_mesh)}

func collect_paths(folder: String) -> void:
	for name: String in DirAccess.get_files_at(folder):
		if name.ends_with(".res"): cached_paths.append(folder.path_join(name))
	for name: String in DirAccess.get_directories_at(folder): collect_paths(folder.path_join(name))

func resident() -> Dictionary:
	var count: int = 0
	var bytes: int = 0
	var rows: Array = []
	var can_read: bool = ResourceLoader.has_method("get_cached_ref")
	if can_read:
		for path: String in cached_paths:
			if not ResourceLoader.has_cached(path): continue
			var resource: Resource = ResourceLoader.call("get_cached_ref",path)
			if not resource is ArrayMesh: continue
			count+=1; bytes+=payload(resource)
			rows.append({"path":path,"bytes":payload(resource)})
	return {"cached_external_meshes":count,"external_raw_bytes":bytes,"readable":can_read,"resources":rows,"engine_resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"engine_video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}

func swap(changes: Dictionary, on: bool) -> void:
	for part: MeshInstance3D in changes: part.mesh=changes[part][1 if on else 0]

func wait_view(view: CarShowroom) -> void:
	view.invalidate_render()
	for frame: int in range(12): await process_frame; await RenderingServer.frame_post_draw

func pixels(a: Image,b: Image) -> Dictionary:
	a.convert(Image.FORMAT_RGBA8); b.convert(Image.FORMAT_RGBA8)
	var x: PackedByteArray=a.get_data(); var y: PackedByteArray=b.get_data()
	var sum: int=0; var significant: int=0
	for at: int in range(0,x.size(),4):
		var peak: int=0
		for channel: int in range(3):
			var delta: int=absi(int(x[at+channel])-int(y[at+channel])); sum+=delta; peak=maxi(peak,delta)
		if peak>8: significant+=1
	return {"significant_pixels":significant,"rgb_mae_255":float(sum)/(a.get_width()*a.get_height()*3),"byte_exact":x==y}

func study() -> void:
	graphical=DisplayServer.get_name()!="headless"
	var mode: String=RenderingServer.get_current_rendering_method() if graphical else "headless"
	var output: String=DEST.path_join(mode)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	collect_paths("res://assets/vehicles")
	var first: Dictionary=resident()
	world=Node3D.new(); root.add_child(world)
	for id: String in IDS:
		var view: CarShowroom
		var car: CarVisual
		var before_hits: int=Base.hits
		if graphical:
			view=CarShowroom.new(); view.vehicle_id=id; view.read_only=true; view.simple_model=true
			view.size=Vector2(1000,760); view.livery=VehicleLivery.defaults(id)
			root.add_child(view)
			while not view.showroom_ready or not view.car.model_ready: await process_frame
			car=view.car
		else:
			car=CarVisual.new(); car.vehicle_id=id; car.cache_rest_pose=false; car.livery=VehicleLivery.defaults(id)
			world.add_child(car)
			while not car.model_ready: await process_frame
		var row: Dictionary={"vehicle":id,"baseline":inventory(car,false),"buffers":inspect_buffers(car),"base_hits":Base.hits-before_hits,"resident":resident(),"candidates":[]}
		var sharing: Dictionary=share_candidates(car)
		swap(sharing,true); var packed: Dictionary=inventory(car,false); swap(sharing,false)
		row.candidates.append({"mode":"share_exact_meshes","changed_instances":sharing.size(),"inventory":packed})
		var pruning: Dictionary={}
		for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
			if part.mesh==null: continue
			var candidate: Mesh=prune_lods(part.mesh)
			if candidate!=part.mesh: pruning[part]=[part.mesh,candidate]
		swap(pruning,true); var trimmed: Dictionary=inventory(car,false); swap(pruning,false)
		row.candidates.append({"mode":"remove_identical_lod_indices","changed_instances":pruning.size(),"inventory":trimmed})
		if id=="kart":
			var driver: MeshInstance3D=car.find_child("TomkartDriver",true,false)
			var split: Dictionary=split_driver(driver.mesh)
			row["driver_split"]={"surface_report":split.surface_report,"before_bytes":split.before_bytes,"after_bytes":split.after_bytes}
		if graphical: row["sharing_views"]=await capture_changes(view,sharing,id,"sharing",output)
		records.append(row)
		print("ROUND2_CASE ",id," bytes=",row.baseline.buffer_bytes," share=",packed.buffer_bytes," prune=",trimmed.buffer_bytes)
		if graphical: view.free()
		else: car.free()
		await process_frame
	world.free()
	FileAccess.open(output+"/inventory.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"baseline_resident":first,"rows":records},"\t"))
	print("CAR_OPTIMISATION_ROUND2 ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

func capture_changes(view: CarShowroom, changes: Dictionary, id: String, label: String, output: String) -> Array:
	var observations: Array=[]
	for shot: Array in [["front",-0.7,0.31],["rear",2.45,0.31],["overhead",-0.4,1.02]]:
		view.yaw=shot[1]; view.elevation=shot[2]; view.zoom=1.05 if id in ["compact","forklift"] else 0.85; view._orbit()
		await wait_view(view)
		var before: Image=view.showroom_viewport.get_texture().get_image()
		await wait_view(view)
		check(before.get_data()==view.showroom_viewport.get_texture().get_image().get_data(),"unchanged native repeat "+id)
		swap(changes,true); await wait_view(view)
		var after: Image=view.showroom_viewport.get_texture().get_image()
		swap(changes,false); await wait_view(view)
		var restored: Image=view.showroom_viewport.get_texture().get_image()
		var diff: Dictionary=pixels(before,after)
		check(diff.byte_exact,"exact sharing pixels "+id+str(shot[0]))
		check(pixels(before,restored).byte_exact,"exact restoration pixels "+id)
		if not changes.is_empty():
			before.save_png(output+"/"+id+"-"+label+"-"+shot[0]+"-before.png")
			after.save_png(output+"/"+id+"-"+label+"-"+shot[0]+"-candidate.png")
		observations.append({"view":shot[0],"difference":diff,"draws":view.showroom_viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)})
	return observations
