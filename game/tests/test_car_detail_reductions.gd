extends "res://tests/test_car_simplification.gd"
## CLV01/CLV02: primitive shape, exact retained triangles, and frame rejection.
const Detail=preload("res://vehicle/car_detail_reduction.gd")
const DETAIL_OUT: String="res://../docs/evidence/car-detail-reduction-2026-11-14"
var current_car: CarVisual
var guards_done: Dictionary={}
var detail_rows: Array=[]
var verified_parts: int=0

func _initialize() -> void: verify_details.call_deferred()

func shape_checks() -> void:
	var holder:=Node3D.new()
	var part:=MeshInstance3D.new()
	var cylinder:=CylinderMesh.new()
	cylinder.radial_segments=12;cylinder.rings=3;cylinder.height=0.42
	cylinder.top_radius=0.23;cylinder.bottom_radius=0.31
	part.mesh=cylinder;holder.add_child(part)
	var endpoints: Dictionary={}
	for vertex: Vector3 in cylinder.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if absf(vertex.y)>0.20999: endpoints[vertex]=true
	RacingCarModels._reduce_primitives(holder,true)
	check(part.mesh.rings==0,"accepted car path removes cylinder height rows")
	check(part.mesh.radial_segments==12,"large cylinder outline sampling retained")
	check(part.mesh.top_radius==cylinder.top_radius and part.mesh.bottom_radius==cylinder.bottom_radius and part.mesh.height==cylinder.height,"taper and dimensions retained")
	var exact: bool=true
	for vertex: Vector3 in part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: exact=exact and endpoints.has(vertex)
	check(exact,"all reduced cylinder vertices are exact original cap/end-ring samples")
	check(part.mesh.cap_top==cylinder.cap_top and part.mesh.cap_bottom==cylinder.cap_bottom,"caps retained")
	var small:=CylinderMesh.new()
	small.top_radius=0.04;small.bottom_radius=0.02;small.radial_segments=12;small.rings=2
	part.mesh=small;RacingCarModels._reduce_primitives(holder,true)
	check(part.mesh.radial_segments==8 and part.mesh.rings==0,"small fitting uses eight sides and no height rows")
	part.mesh=cylinder;RacingCarModels._reduce_primitives(holder)
	check(part.mesh.rings==3,"generic helper default retains unrelated axial sampling")
	holder.free()
	for radius: float in [0.08,0.25]:
		var ring_root:=Node3D.new()
		var material:=StandardMaterial3D.new()
		VisualGeometry.ring(ring_root,Vector3(0.1,0.2,0.3),radius,0.01,material)
		var ring: Mesh=ring_root.get_child(0).mesh
		var selected: Mesh=RacingCarModels._reduce_ring(ring)
		check(selected.get_faces().size()/3==(48 if radius<0.12 else 96),"radius-aware ring count")
		check(selected.get_aabb()==ring.get_aabb(),"ring culling bounds retained")
		check(selected.surface_get_material(0)==material,"ring finish retained")
		var vertices: Dictionary={}
		for vertex: Vector3 in ring.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: vertices[vertex]=true
		var retained: bool=true
		for vertex: Vector3 in selected.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: retained=retained and vertices.has(vertex)
		check(retained,"ring retains original radial/profile samples")
		ring_root.free()
	var unrelated:=ImmediateMesh.new()
	unrelated.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex: int in range(576):
		unrelated.surface_set_normal(Vector3.UP)
		unrelated.surface_add_vertex(Vector3(vertex%7,0,vertex%13))
	unrelated.surface_end()
	check(RacingCarModels._reduce_ring(unrelated)==unrelated,"unrelated planar streams cannot be mistaken for round fittings")

func triangle_codes(mesh: ArrayMesh, surface: int) -> Dictionary:
	var packet: Dictionary=mesh.get("_surfaces")[surface]
	var count: int=packet.vertex_count
	var format: int=mesh.surface_get_format(surface)
	var ps: int=RenderingServer.mesh_surface_get_format_vertex_stride(format,count)
	var ns: int=RenderingServer.mesh_surface_get_format_normal_tangent_stride(format,count)
	var ats: int=RenderingServer.mesh_surface_get_format_attribute_stride(format,count)
	var raw: PackedByteArray=packet.vertex_data
	var attrs: PackedByteArray=packet.get("attribute_data",PackedByteArray())
	var corners: Array=[]
	for index: int in range(count):
		var corner: PackedByteArray=raw.slice(index*ps,(index+1)*ps)
		if ns: corner.append_array(raw.slice(count*ps+index*ns,count*ps+(index+1)*ns))
		if ats: corner.append_array(attrs.slice(index*ats,(index+1)*ats))
		corners.append(corner)
	var arrays: Array=mesh.surface_get_arrays(surface)
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	if indices.is_empty():
		for index: int in range(count): indices.append(index)
	var result: Dictionary={}
	for offset: int in range(0,indices.size(),3):
		var triangle: PackedByteArray=corners[indices[offset]].duplicate()
		triangle.append_array(corners[indices[offset+1]])
		triangle.append_array(corners[indices[offset+2]])
		result[triangle]=true
	return result

func states(group: Dictionary) -> Array:
	var result: Array=[]
	for entry: Dictionary in group.entries: result.append([entry.part,entry.part.mesh,entry.part.visible])
	return result

func unchanged(before: Array) -> bool:
	for row: Array in before:
		if row[0].mesh!=row[1] or row[0].visible!=row[2]: return false
	return true

func guard_checks(group: Dictionary, data: Dictionary) -> void:
	var original: Array=states(group)
	var code: String=group.vehicle+"_"+group.code
	var broken: Dictionary=data.duplicate(true)
	var first: String=broken.parts.keys()[0]
	broken.parts[first].source="wrong-source"
	Detail.recipes[code]=broken
	Detail.apply_group(group)
	check(unchanged(original),"corrupt source rejects entire frame before mutation "+group.vehicle)
	Detail.recipes[code]=data
	var selected: Dictionary=group.entries[0]
	var part: MeshInstance3D=selected.part
	var pose: Transform3D=part.transform
	part.position.x+=0.001
	for fresh: Dictionary in Detail.groups(current_car):
		var contains: bool=false
		for entry: Dictionary in fresh.entries: contains=contains or entry.part==part
		if not contains: continue
		check(fresh.code!=group.code,"relative pose changes frame proof key "+group.vehicle)
		Detail.apply_group(fresh)
	check(unchanged(original),"moved context retains original geometry "+group.vehicle)
	part.transform=pose
	var shadow: int=part.cast_shadow
	part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED if shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for fresh: Dictionary in Detail.groups(current_car):
		var contains: bool=false
		for entry: Dictionary in fresh.entries: contains=contains or entry.part==part
		if contains:
			check(fresh.code!=group.code,"shadow mode changes frame proof key "+group.vehicle)
			Detail.apply_group(fresh)
	check(unchanged(original),"shadow mismatch retains original geometry "+group.vehicle)
	part.cast_shadow=shadow

func verify_group(group: Dictionary) -> void:
	var data: Dictionary=Detail.recipe(group.vehicle,group.code)
	if data.is_empty(): return
	if not guards_done.has(group.vehicle):
		guard_checks(group,data)
		guards_done[group.vehicle]=true
	var original: Array=states(group)
	var materials: Dictionary={}
	for row: Array in original:
		materials[row[0]]=[]
		for surface: int in range(row[1].get_surface_count()): materials[row[0]].append(row[0].get_active_material(surface))
	Detail.apply_group(group)
	for row: Array in original:
		var part: MeshInstance3D=row[0]
		var source: Mesh=row[1]
		if part.mesh==source: continue
		check(part.mesh.get_surface_count()==source.get_surface_count(),"detail material slots "+group.vehicle)
		check(part.mesh.get_aabb()==source.get_aabb(),"detail exact culling bounds "+group.vehicle)
		var reference: ArrayMesh=packed_reference(source)
		for surface: int in range(source.get_surface_count()):
			var source_triangles: Dictionary=triangle_codes(reference,surface)
			var retained: Dictionary=triangle_codes(part.mesh,surface)
			var exact: bool=true
			for triangle: PackedByteArray in retained: exact=exact and source_triangles.has(triangle)
			check(exact,"detail retains exact encoded triangles and winding "+group.vehicle)
			check(part.get_active_material(surface)==materials[part][surface],"detail finish identity "+group.vehicle)
		verified_parts+=1

func packed_reference(source: Mesh) -> ArrayMesh:
	if source is ArrayMesh: return source
	var packets: Array=[]
	for surface: int in range(source.get_surface_count()):
		var packet: Dictionary=RenderingServer.mesh_get_surface(source.get_rid(),surface)
		packet.material=source.surface_get_material(surface);packet.aabb=source.get_aabb()
		packets.append(packet)
	var result:=ArrayMesh.new();result.set("_surfaces",packets)
	result.custom_aabb=source.get_aabb()
	return result

func verify_details() -> void:
	shape_checks()
	if "--shape-only" in OS.get_cmdline_user_args():
		print("DETAIL_SHAPES ",checks," checks, ",failures," failures")
		quit(1 if failures else 0);return
	Base.enabled=false;Kits.enabled=false;Cache.enabled=false
	preload("res://ui/garage_car_cache.gd").enabled=false
	Detail.offline=verify_group
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DETAIL_OUT.path_join("before.json")))
	var editable_before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DETAIL_OUT.path_join("editable-before.json")))
	var hover_control: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DETAIL_OUT.path_join("hover-reset-legacy.json")))
	for id: String in VehicleCatalog.IDS:
		var counts: Array=[]
		for editable: bool in [false,true]:
			var car:=CarVisual.new();current_car=car
			car.vehicle_id=id;car.editable_kits=editable;car.cache_rest_pose=false;car.livery=VehicleLivery.defaults(id)
			root.add_child(car)
			while not car.model_ready: await process_frame
			var inventory_row: Dictionary=inventory(car,false)
			counts.append(inventory_row.triangles)
			var baseline: Dictionary={}
			for row: Dictionary in before.rows:
				if row.vehicle==id and row.mode=="stock": baseline=row.inventory
			if editable:
				for row: Dictionary in editable_before.rows:
					if row.vehicle==id: baseline=row
			check(inventory_row.triangles<=int(baseline.triangles),"detail stock triangles do not increase "+id)
			check(inventory_row.surfaces<=int(baseline.surfaces),"detail visible surface budget "+id)
			if id!="hovercraft": check(inventory_row.triangles<int(baseline.triangles),"detail reduction is active "+id)
			if id=="compact":
				check(car.find_children("*","MeshInstance3D",true,false).filter(func(part: MeshInstance3D)->bool:return part.mesh is TextMesh).is_empty(),"production Rally uses printed plate without glyph geometry")
			if editable:
				for category: String in VehicleCustomisation.CATEGORIES:
					for option: Array in VehicleCustomisation.options(category,id).slice(1):
						var selection: Dictionary=car.customisation.duplicate()
						selection[category]=option[0];car.change_kit_parts(selection)
					var selection: Dictionary=car.customisation.duplicate()
					selection[category]="stock";car.change_kit_parts(selection)
				var restored: int=inventory(car,false).triangles
				if id=="hovercraft":
					check(inventory_row.triangles==int(hover_control.before.triangles) and restored==int(hover_control.after.triangles),"Hover kit reset matches exact pre-task source control")
				else: check(restored==inventory_row.triangles,"all kit replacements return to exact stock count "+id)
			detail_rows.append({"vehicle":id,"editable":editable,"inventory":inventory_row})
			car.free();await process_frame
		check(counts[0]==counts[1],"fixed/editable detail stock counts agree "+id)
	Detail.offline=Callable()
	check(verified_parts>0 and guards_done.size()>=3,"real recipes and mismatch guards exercised")
	check(Detail.meshes.size()<=Detail.LIMIT and Detail.recipes.size()<=Detail.LIMIT,"detail caches bounded")
	FileAccess.open(DETAIL_OUT.path_join("source-verification.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"verified_parts":verified_parts,"guards":guards_done.keys(),"rows":detail_rows},"\t"))
	print("DETAIL_SOURCE ",checks," checks, ",failures," failures; verified_parts=",verified_parts)
	quit(1 if failures else 0)
