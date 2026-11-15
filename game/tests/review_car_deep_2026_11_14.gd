extends "res://tests/review_car_optimisation_round2.gd"
## CDR01-CDR04: live inventories, source geometry and disposable candidates.
const DEEP_OUT: String="res://../docs/evidence/car-deep-review-2026-11-14"
const DEEP_WORK: String="res://../build/car-deep-review-2026-11-14"
const Coarse=preload("res://vehicle/car_coarse_reduction.gd")
const Static=preload("res://vehicle/car_static_reduction.gd")
var deep_rows: Array=[]
var source_rows: Array=[]
var source_mode: bool=false
var deep_lods=preload("res://vehicle/car_mesh_lods.gd").new()
var native_pairs: Array=[]

func _initialize() -> void:
	node_added.connect(func(node: Node)->void:
		if source_mode and node is CarVisual:
			node.batch_parts=false
			node.editable_kits=true)
	deep_review.call_deferred()

func configure_source(car: CarVisual) -> void:
	car.batch_parts=true
	if car.vehicle_id!="hovercraft": Static.apply(car)
	Coarse.apply(car)

func packed_mesh(source: Mesh) -> ArrayMesh:
	if source is ArrayMesh: return source
	var packets: Array=[]
	for surface: int in range(source.get_surface_count()):
		var packet: Dictionary=RenderingServer.mesh_get_surface(source.get_rid(),surface)
		packet.material=source.surface_get_material(surface)
		packets.append(packet)
	var result:=ArrayMesh.new()
	result.set("_surfaces",packets)
	result.custom_aabb=source.get_aabb()
	return result

func select_indices(source: Mesh, selected: Dictionary) -> Mesh:
	var array_mesh: ArrayMesh=packed_mesh(source)
	var packets: Array=array_mesh.get("_surfaces").duplicate(true)
	for surface: int in selected:
		var indices: PackedInt32Array=selected[surface]
		var packet: Dictionary=packets[surface]
		var stride: int=2 if int(packet.vertex_count)<=65536 else 4
		var raw:=PackedByteArray()
		raw.resize(indices.size()*stride)
		for at: int in range(indices.size()):
			if stride==2: raw.encode_u16(at*stride,indices[at])
			else: raw.encode_u32(at*stride,indices[at])
		packet.index_data=raw;packet.index_count=indices.size()
		packet.format=int(packet.format)|Mesh.ARRAY_FORMAT_INDEX
		packet.erase("lods")
	var result:=ArrayMesh.new()
	result.set("_surfaces",packets)
	result.custom_aabb=source.get_aabb()
	return preload("res://tests/support/car_static_reduction_bake.gd").new().compact(result)

func reduced_round(source: Mesh) -> Mesh:
	if source is CylinderMesh and maxf(source.top_radius,source.bottom_radius)<=0.06 and source.radial_segments>8:
		var result: CylinderMesh=source.duplicate()
		result.radial_segments=8
		result.custom_aabb=source.get_aabb()
		return result
	if source is ImmediateMesh and source.get_surface_count()==1:
		var arrays: Array=source.surface_get_arrays(0)
		if arrays[Mesh.ARRAY_VERTEX].size()!=576: return source
		var bounds: AABB=source.get_aabb()
		if bounds.size.y>0.00001: return source
		var radius: float=maxf(bounds.size.x,bounds.size.z)*0.5
		var step: int=4 if radius<=0.12 else 2
		var indices:=PackedInt32Array()
		for at: int in range(0,96,step):
			var begin: int=at*6
			var end: int=(at+step-1)*6
			indices.append_array(PackedInt32Array([begin,end+1,begin+2,begin,end+4,end+1]))
		return select_indices(source,{0:indices})
	return source

func reduced_axial(source: Mesh) -> Mesh:
	if not source is CylinderMesh or source.rings==0: return source
	var result: CylinderMesh=source.duplicate()
	result.rings=0
	check(result.rings==0,"pinned engine accepts zero axial subdivisions")
	result.custom_aabb=source.get_aabb()
	return result

func reduced_hardware(source: Mesh) -> Mesh:
	return reduced_axial(reduced_round(source))

func low_indices(source: ArrayMesh, budget: float) -> ArrayMesh:
	var prepared: ArrayMesh=deep_lods.prepare(source)
	var chosen: Dictionary={}
	for surface: int in range(source.get_surface_count()):
		var original: PackedInt32Array=source.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
		var packet: Dictionary=prepared.get("_surfaces")[surface]
		var stride: int=2 if int(packet.vertex_count)<=65536 else 4
		var raw: PackedByteArray=packet.get("index_data",PackedByteArray())
		var levels: Array=packet.get("lods",[])
		for at: int in range(0,levels.size(),2):
			if float(levels[at])<=budget and levels[at+1].size()<raw.size(): raw=levels[at+1]
		if raw.size()/stride<original.size():
			var indices:=PackedInt32Array()
			for at: int in range(0,raw.size(),stride): indices.append(raw.decode_u16(at) if stride==2 else raw.decode_u32(at))
			chosen[surface]=indices
	return select_indices(source,chosen) if not chosen.is_empty() else source

func frame_for(car: CarVisual, part: Node) -> String:
	var labels: Array[String]=[]
	var ancestor: Node=part.get_parent()
	while ancestor!=null and ancestor!=car:
		if ancestor==car.body: labels.append("body")
		if ancestor in car.rolling_wheels or ancestor in car.front_wheels or ancestor in car.rear_wheels: labels.append(str(car.get_path_to(ancestor)))
		if str(ancestor.name).begins_with("EditableKit_") or str(ancestor.name) in ["SteeringAssembly","FanRotorLeft","FanRotorRight","FanRotor"]: labels.append(str(car.get_path_to(ancestor)))
		ancestor=ancestor.get_parent()
	return "|".join(labels)

func export_source(car: CarVisual) -> Dictionary:
	var file:=FileAccess.open(DEEP_WORK.path_join(car.vehicle_id+"-geometry.bin"),FileAccess.WRITE)
	var parts: Array=[]
	var inverse: Transform3D=car.global_transform.affine_inverse()
	var ordinal: int=0
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.mesh==null or not part.is_visible_in_tree() or part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		var pose: Transform3D=inverse*part.global_transform
		var surfaces: Array=[]
		var opaque: bool=true
		var cull: int=0
		for surface: int in range(part.mesh.get_surface_count()):
			var arrays: Array=part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			for at: int in range(vertices.size()): vertices[at]=pose*vertices[at]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			if indices.is_empty():
				for at: int in range(vertices.size()): indices.append(at)
			var vertex_offset: int=file.get_position()
			file.store_buffer(vertices.to_byte_array())
			var index_offset: int=file.get_position()
			file.store_buffer(indices.to_byte_array())
			surfaces.append({"vertex_offset":vertex_offset,"vertex_count":vertices.size(),"index_offset":index_offset,"index_count":indices.size()})
			var material: Material=part.get_active_material(surface)
			if material is StandardMaterial3D:
				opaque=opaque and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and material.albedo_color.a==1.0
				cull=material.cull_mode
			else: opaque=false
		var row: Dictionary={"ordinal":ordinal,"path":str(car.get_path_to(part)),"name":str(part.name),"kind":part.mesh.get_class(),"frame":frame_for(car,part),"surfaces":surfaces,"opaque":opaque,"cull_mode":cull,"cast_shadow":part.cast_shadow,"layers":part.layers,"morphs":part.mesh.get_blend_shape_count() if part.mesh is ArrayMesh else 0,"triangles":part.mesh.get_faces().size()/3}
		if part.mesh is CylinderMesh: row.merge({"radius":maxf(part.mesh.top_radius,part.mesh.bottom_radius),"radial_segments":part.mesh.radial_segments,"rings":part.mesh.rings})
		parts.append(row)
		ordinal+=1
	file.close()
	return {"vehicle":car.vehicle_id,"triangles":inventory(car,false).triangles,"model_scale":car.scale.x,"parts":parts}

func prepared_case(id: String, fitted: bool) -> Dictionary:
	Base.enabled=true;Kits.enabled=true;Cache.enabled=true
	var car:=CarVisual.new()
	car.vehicle_id=id;car.cache_rest_pose=false;car.livery=VehicleLivery.defaults(id)
	car.customisation=VehicleCustomisation.defaults()
	if fitted:
		for category: String in VehicleCustomisation.CATEGORIES: car.customisation[category]=VehicleCustomisation.options(category,id)[-1][0]
	var base_hits: int=Base.hits
	var kit_hits: int=Kits.hits
	root.add_child(car)
	while not car.model_ready: await process_frame
	var baseline: Dictionary=inventory(car,false)
	var result: Dictionary={"vehicle":id,"fitted":fitted,"baseline":baseline,"base_hits":Base.hits-base_hits,"kit_hits":Kits.hits-kit_hits,"packing_saved_bytes":0,"compaction_saved_bytes":0,"sharing_saved_bytes":0,"identical_lod_saved_bytes":0,"ghost":{},"shadow_candidates":[]}
	result["selection"]=car.customisation.duplicate()
	check(Base.hits==base_hits+1,"actual prepared base "+id+str(fitted))
	if fitted: check(Kits.hits==kit_hits+4,"actual four fitted module hits "+id)
	var seen: Dictionary={}
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if not part.mesh is ArrayMesh or seen.has(part.mesh) or part.mesh.get_blend_shape_count()>0: continue
		seen[part.mesh]=true
		var packed: ArrayMesh=Packing.pack(part.mesh)
		result.packing_saved_bytes+=payload(part.mesh)-payload(packed)
		if packed!=part.mesh: check(fingerprint(part.mesh)==fingerprint(packed),"exact packing "+id)
		var compacted: ArrayMesh=preload("res://tests/support/car_static_reduction_bake.gd").new().compact(part.mesh)
		result.compaction_saved_bytes+=payload(part.mesh)-payload(compacted)
		if payload(compacted)<payload(part.mesh): check(fingerprint(part.mesh)==fingerprint(compacted),"exact unused-vertex compaction "+id)
		var pruned: Mesh=prune_lods(part.mesh)
		result.identical_lod_saved_bytes+=payload(part.mesh)-payload(pruned)
	var changes: Dictionary=share_candidates(car)
	for part: MeshInstance3D in changes:
		check(fingerprint(changes[part][0])==fingerprint(changes[part][1]),"exact shared mesh corners "+id)
	swap(changes,true)
	result.sharing_saved_bytes=baseline.buffer_bytes-inventory(car,false).buffer_bytes
	swap(changes,false)
	if not fitted:
		var ghost_instance:=PersonalGhost.new()
		ghost_instance.configure(car)
		var ghost: ArrayMesh=ghost_instance.mesh
		var candidates: Array=[]
		for budget: float in [0.02,0.05,0.1]:
			var ghost_low: ArrayMesh=low_indices(ghost,budget)
			candidates.append({"metric":budget,"triangles":ghost_low.get_faces().size()/3,"bytes":payload(ghost_low)})
		result.ghost={"before_triangles":ghost.get_faces().size()/3,"before_bytes":payload(ghost),"stored_lods":ghost.get("_surfaces")[0].get("lods",[]).size()/2,"candidates":candidates}
		ghost_instance.free()
		for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
			if part.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY or not part.mesh is ArrayMesh: continue
			var selected: ArrayMesh=low_indices(part.mesh,0.02)
			result.shadow_candidates.append({"path":str(car.get_path_to(part)),"before":part.mesh.get_faces().size()/3,"candidate":selected.get_faces().size()/3})
	car.free()
	await process_frame
	return result

func headless_study() -> void:
	for id: String in VehicleCatalog.IDS:
		for fitted: bool in [false,true]:
			var row: Dictionary=await prepared_case(id,fitted)
			deep_rows.append(row)
			print("DEEP_ACTIVE ",id," fitted=",fitted," triangles=",row.baseline.triangles," base_hits=",row.base_hits," pack=",row.packing_saved_bytes," compact=",row.compaction_saved_bytes," share=",row.sharing_saved_bytes)
	Base.enabled=false;Kits.enabled=false;Cache.enabled=false
	for id: String in VehicleCatalog.IDS:
		var car:=CarVisual.new()
		car.vehicle_id=id;car.batch_parts=false;car.editable_kits=true;car.cache_rest_pose=false;car.livery=VehicleLivery.defaults(id)
		root.add_child(car)
		while not car.model_ready: await process_frame
		configure_source(car)
		var row: Dictionary=export_source(car)
		var current: Dictionary={}
		for active: Dictionary in deep_rows:
			if active.vehicle==id and not active.fitted: current=active
		check(row.triangles==current.baseline.triangles,"source pieces match active stock master "+id)
		source_rows.append(row)
		var saved: int=0;var changed: int=0;var axial_saved: int=0;var hardware_saved: int=0
		for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
			if part.mesh==null: continue
			var reduced: Mesh=reduced_round(part.mesh)
			var axial: Mesh=reduced_axial(part.mesh)
			var combined: Mesh=reduced_hardware(part.mesh)
			axial_saved+=(part.mesh.get_faces().size()-axial.get_faces().size())/3
			hardware_saved+=(part.mesh.get_faces().size()-combined.get_faces().size())/3
			if reduced!=part.mesh:
				saved+=(part.mesh.get_faces().size()-reduced.get_faces().size())/3
				changed+=1
		row["round_candidate"]={"saved_triangles":saved,"changed_parts":changed}
		row["axial_candidate"]={"saved_triangles":axial_saved}
		row["hardware_candidate"]={"saved_triangles":hardware_saved}
		print("DEEP_SOURCE ",id," triangles=",row.triangles," parts=",row.parts.size()," round_saved=",saved)
		car.free()
		await process_frame
	FileAccess.open(DEEP_OUT.path_join("inventory.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"cases":deep_rows,"sources":source_rows},"\t"))

func source_parts(car: CarVisual) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D]=[]
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.mesh!=null and part.is_visible_in_tree() and part.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: result.append(part)
	return result

func apply_changes(changes: Dictionary, candidate: bool) -> void:
	for part: MeshInstance3D in changes:
		var entry: Array=changes[part]
		part.mesh=entry[1] if candidate else entry[0]
		part.visible=entry[4] if candidate else entry[3]
		for surface: int in range(part.mesh.get_surface_count()): part.set_surface_override_material(surface,entry[2][surface])

func geometry_changes(parts: Array[MeshInstance3D], proposal: Dictionary, mode: String) -> Dictionary:
	var result: Dictionary={}
	if mode in ["enclosed","zero_area"]:
		for row: Dictionary in proposal[mode]:
			var part: MeshInstance3D=parts[int(row.ordinal)]
			check(part.mesh.get_faces().size()/3==int(row.triangles),"proposal source triangle identity")
			var selected: Dictionary={}
			var whole: bool=int(row.removed)==int(row.triangles)
			if not whole:
				for surface_text: String in row.surfaces:
					var surface: int=int(surface_text)
					var removed: Dictionary={}
					for face: float in row.surfaces[surface_text]: removed[int(face)]=true
					var arrays: Array=part.mesh.surface_get_arrays(surface)
					var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
					if indices.is_empty():
						for index: int in range(arrays[Mesh.ARRAY_VERTEX].size()): indices.append(index)
					var keep:=PackedInt32Array()
					for triangle: int in range(indices.size()/3):
						if removed.has(triangle): continue
						keep.append_array(indices.slice(triangle*3,triangle*3+3))
					check(not keep.is_empty(),"partial surface remains nonempty")
					selected[surface]=keep
			result[part]=[part.mesh,part.mesh if whole else select_indices(part.mesh,selected),[],part.visible,not whole]
	else:
		for part: MeshInstance3D in parts:
			var target: Mesh=part.mesh
			var hidden: bool=false
			if mode=="round": target=reduced_round(part.mesh)
			if mode=="axial": target=reduced_axial(part.mesh)
			if mode=="hardware": target=reduced_hardware(part.mesh)
			if mode=="micro":
				for label: String in ["GaugeNeedle","PedalRib","SeatStitch","LEDOptic"]:
					if str(part.name).begins_with(label): hidden=true
			if target!=part.mesh or hidden: result[part]=[part.mesh,target,[],part.visible,not hidden]
	for part: MeshInstance3D in result:
		for surface: int in range(part.mesh.get_surface_count()): result[part][2].append(part.get_active_material(surface))
	return result

func image_crop(car: CarVisual, cam: Camera3D, size: Vector2i) -> Array:
	var low:=Vector2(INF,INF);var high:=Vector2(-INF,-INF)
	for part: MeshInstance3D in source_parts(car):
		for corner: int in range(8):
			var p: Vector2=cam.unproject_position(part.global_transform*part.mesh.get_aabb().get_endpoint(corner))
			low=low.min(p);high=high.max(p)
	var rectangle:=Rect2i(Vector2i(low.floor())-Vector2i(8,8),Vector2i((high-low).ceil())+Vector2i(17,17)).intersection(Rect2i(Vector2i.ZERO,size))
	return [rectangle.position.x,rectangle.position.y,rectangle.size.x,rectangle.size.y]

func settle_native(view: CarShowroom) -> void:
	view.invalidate_render()
	for frame: int in range(10): await process_frame;await RenderingServer.frame_post_draw

func pair_native(view: CarShowroom, changes: Dictionary, label: String, crop: Array, directory: String) -> Dictionary:
	apply_changes(changes,false)
	await settle_native(view)
	var before: Image=view.showroom_viewport.get_texture().get_image()
	var stable: bool=false
	var previous: Image=before
	for attempt: int in range(6):
		await settle_native(view)
		var repeat: Image=view.showroom_viewport.get_texture().get_image()
		previous=before
		stable=repeat.get_data()==before.get_data();before=repeat
		if stable: break
	check(stable,"stable deep reference "+label)
	var prior: int=view.showroom_viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	apply_changes(changes,true)
	await settle_native(view)
	var candidate: Image=view.showroom_viewport.get_texture().get_image()
	var current: int=view.showroom_viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	apply_changes(changes,false)
	await settle_native(view)
	var restored: Image=view.showroom_viewport.get_texture().get_image()
	for attempt: int in range(6):
		if before.get_data()==restored.get_data(): break
		await settle_native(view);restored=view.showroom_viewport.get_texture().get_image()
	var exact: bool=before.get_data()==restored.get_data()
	check(exact,"deep restoration "+label)
	check(before.save_png(directory.path_join(label+"-before.png"))==OK,"deep before capture")
	check(candidate.save_png(directory.path_join(label+"-candidate.png"))==OK,"deep candidate capture")
	if not stable: previous.save_png(directory.path_join(label+"-repeat.png"))
	if not exact: restored.save_png(directory.path_join(label+"-restored.png"))
	return {"label":label,"crop":crop,"before_image":label+"-before.png","candidate_image":label+"-candidate.png","repeat_image":label+"-repeat.png" if not stable else "","restoration_image":label+"-restored.png" if not exact else "","stable_reference":stable,"visible_primitives_before":prior,"visible_primitives_candidate":current,"restored_exact":exact}

func graphical_study() -> void:
	Engine.time_scale=0.0
	Base.enabled=false;Kits.enabled=false;Cache.enabled=false
	preload("res://ui/garage_car_cache.gd").enabled=false
	source_mode=true
	var shadow_hardware: bool="--shadow-hardware" in OS.get_cmdline_user_args()
	var directory: String=DEEP_OUT.path_join(RenderingServer.get_current_rendering_method()+("-shadows" if shadow_hardware else ""))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var proposals: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DEEP_WORK.path_join("proposals.json")))
	var source_inventory: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DEEP_OUT.path_join("inventory.json")))
	for id: String in VehicleCatalog.IDS:
		var view:=CarShowroom.new()
		view.vehicle_id=id;view.simple_model=true;view.read_only=true
		view.livery=VehicleLivery.defaults(id);view.size=Vector2(1000,760)
		root.add_child(view)
		while not view.showroom_ready or not view.car.model_ready: await process_frame
		configure_source(view.car)
		var expected: Dictionary={}
		for entry: Dictionary in source_inventory.sources:
			if entry.vehicle==id: expected=entry
		check(inventory(view.car,false).triangles==int(expected.triangles),"native source count "+id)
		var parts: Array[MeshInstance3D]=source_parts(view.car)
		check(parts.size()==expected.parts.size(),"native source part ordinals "+id)
		for part: MeshInstance3D in parts: part.lod_bias=100000.0
		var key: DirectionalLight3D=view.car.get_parent().find_child("StudioKey",true,false)
		var soft_shadow: Node3D=view.car.get_parent().find_child("PreparedStudioShadow",true,false)
		var modes: Array=["axial","hardware"] if "--hardware-only" in OS.get_cmdline_user_args() else ["zero_area","enclosed","round","micro"]
		for mode: String in modes:
			key.shadow_enabled=mode=="enclosed" or shadow_hardware
			soft_shadow.visible=not key.shadow_enabled
			var changes: Dictionary=geometry_changes(parts,proposals[id],mode)
			if changes.is_empty(): continue
			var before_count: int=inventory(view.car,false).triangles
			apply_changes(changes,true)
			var count: int=inventory(view.car,false).triangles
			apply_changes(changes,false)
			for shot: Array in [["front",-0.70,0.31,1.15],["rear",2.45,0.31,1.15],["race-distance",-0.4,1.02,3.1]]:
				view.yaw=shot[1];view.elevation=shot[2];view.zoom=shot[3];view._orbit()
				var crop: Array=image_crop(view.car,view.camera,view.showroom_viewport.size)
				var observation: Dictionary=await pair_native(view,changes,id+"-"+mode+"-"+shot[0],crop,directory)
				observation.merge({"vehicle":id,"mode":mode,"view":shot[0],"master_before":before_count,"master_candidate":count,"dynamic_shadow":key.shadow_enabled})
				native_pairs.append(observation)
		if "--hardware-only" in OS.get_cmdline_user_args():
			view.free();await process_frame
			print("DEEP_HARDWARE ",id," pairs=",native_pairs.size())
			continue
		var ghost:=PersonalGhost.new()
		key.shadow_enabled=false
		soft_shadow.hide()
		ghost.configure(view.car)
		view.car.get_parent().add_child(ghost)
		var ghost_source: ArrayMesh=ghost.mesh
		var metric: float=0.02
		var ghost_low: ArrayMesh=low_indices(ghost_source,metric)
		if ghost_low==ghost_source:
			metric=0.05;ghost_low=low_indices(ghost_source,metric)
		if ghost_low==ghost_source:
			metric=0.1;ghost_low=low_indices(ghost_source,metric)
		var ghost_changes: Dictionary={ghost:[ghost_source,ghost_low,[ghost.material_override],true,true]}
		for shot: Array in [["front",-0.70,0.31,1.15],["rear",2.45,0.31,1.15],["race-distance",-0.4,1.02,3.1]]:
			view.car.show();ghost.hide()
			view.yaw=shot[1];view.elevation=shot[2];view.zoom=shot[3];view._orbit()
			var crop: Array=image_crop(view.car,view.camera,view.showroom_viewport.size)
			view.car.hide();ghost.show()
			var observation: Dictionary=await pair_native(view,ghost_changes,id+"-ghost-"+shot[0],crop,directory)
			observation.merge({"vehicle":id,"mode":"ghost","view":shot[0],"master_before":ghost_source.get_faces().size()/3,"master_candidate":ghost_low.get_faces().size()/3,"metric":metric})
			native_pairs.append(observation)
		ghost.free();view.free()
		await process_frame
		print("DEEP_NATIVE ",id," pairs=",native_pairs.size())
	FileAccess.open(directory.path_join("hardware-comparisons.json" if "--hardware-only" in OS.get_cmdline_user_args() else "comparisons.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"pairs":native_pairs},"\t"))

func deep_review() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEEP_OUT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEEP_WORK))
	if DisplayServer.get_name()=="headless": await headless_study()
	else: await graphical_study()
	print("DEEP_COMPLETE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
