extends RefCounted
## CLV02: load offline hidden-face recipes only for an exact articulation frame.
## Construction and kit replacement supply complete fresh frames before batching.
const ROOT: String="res://assets/vehicles/car_detail_v1"
const SCHEMA: String="car-detail-frame-1"
const LIMIT: int=256
static var enabled: bool=true
static var offline: Callable
static var recipes: Dictionary={}
static var meshes: Dictionary={}
static var geometry_keys: Dictionary={}
static var hits: int=0

static func mesh_key(mesh: Mesh) -> String:
	var instance: int=mesh.get_instance_id()
	if geometry_keys.has(instance): return geometry_keys[instance]
	var hash:=HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for surface: int in range(mesh.get_surface_count()):
		var packet: Dictionary=RenderingServer.mesh_get_surface(mesh.get_rid(),surface)
		hash.update(var_to_bytes([packet.format,packet.primitive,packet.vertex_count,packet.get("index_count",0)]))
		for field: String in ["vertex_data","attribute_data","skin_data","index_data","blend_shapes"]:
			var bytes: PackedByteArray=packet.get(field,PackedByteArray())
			if not bytes.is_empty(): hash.update(bytes)
	var code: String=hash.finish().hex_encode()
	if geometry_keys.size()>=LIMIT*4: geometry_keys.clear()
	geometry_keys[instance]=code
	return code

static func frame_for(car: CarVisual, part: Node3D, split_kits: bool=true) -> Node3D:
	var ancestor: Node3D=part.get_parent() as Node3D
	while ancestor!=null and ancestor!=car:
		if ancestor.top_level or ancestor==car.body or ancestor in car.rolling_wheels or ancestor in car.front_wheels or ancestor in car.rear_wheels: return ancestor
		var label: String=str(ancestor.name)
		if (split_kits and label.begins_with("EditableKit_")) or label in ["SteeringAssembly","FanRotor","FanRotorLeft","FanRotorRight","Rudder","RudderLeft","RudderRight"]: return ancestor
		ancestor=ancestor.get_parent() as Node3D
	return car

static func relative_pose(frame: Node3D, part: Node3D) -> Transform3D:
	var pose: Transform3D=part.transform
	var ancestor: Node3D=part.get_parent() as Node3D
	while ancestor!=frame:
		pose=ancestor.transform*pose
		ancestor=ancestor.get_parent() as Node3D
	return pose

static func material_state(part: MeshInstance3D) -> Array:
	var state: Array=[]
	for surface: int in range(part.mesh.get_surface_count()):
		var material: Material=part.get_active_material(surface)
		if material is StandardMaterial3D:
			state.append(["standard",material.transparency,material.cull_mode,material.albedo_color.a,material.grow,material.grow_amount,material.proximity_fade_enabled,material.distance_fade_mode,material.no_depth_test,material.billboard_mode,material.next_pass!=null,material.heightmap_enabled])
		else:
			# Shader displacement/coverage is outside the opaque-solid proof.
			state.append(["other",material.get_instance_id() if material!=null else 0])
	return state

static func opaque_state(state: Array) -> bool:
	if state.is_empty(): return false
	for value: Array in state:
		if value[0]!="standard" or value[1]!=BaseMaterial3D.TRANSPARENCY_DISABLED or value[2]==BaseMaterial3D.CULL_FRONT or value[3]!=1.0 or value[4] or value[6] or value[7]!=BaseMaterial3D.DISTANCE_FADE_DISABLED or value[8] or value[9]!=BaseMaterial3D.BILLBOARD_DISABLED or value[10] or value[11]: return false
	return true

static func groups(car: CarVisual, holders: Variant=null) -> Array:
	var parts: Array=[]
	if holders==null: parts=car.find_children("*","MeshInstance3D",true,false)
	else:
		for holder: Node in holders: parts.append_array(holder.find_children("*","MeshInstance3D",true,false))
	var frames: Dictionary={}
	for part: MeshInstance3D in parts:
		if part.mesh==null or not part.is_visible_in_tree() or part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		var frame: Node3D=frame_for(car,part)
		var pose: Transform3D=relative_pose(frame,part)
		var state: Array=material_state(part)
		# Unknown shader identity is not a cross-process key. It remains a
		# protected context member with a stable shader/parameter description.
		for surface: int in range(state.size()):
			if state[surface][0]!="other": continue
			var material: Material=part.get_active_material(surface)
			state[surface]=["other",material.resource_path if material!=null else "",material.get_class() if material!=null else "none"]
			if material is ShaderMaterial and material.shader!=null:
				state[surface].append(material.shader.code.sha256_text())
		var source: String=mesh_key(part.mesh)
		var protected_part: bool=part.top_level or part in car.brake_lights or part in car.front_wheels or part in car.rear_wheels or part in car.rolling_wheels
		protected_part=protected_part or frame.global_transform.basis.determinant()<=0.0 or part.visibility_range_begin!=0.0 or part.visibility_range_end!=0.0
		var path: String=str(car.get_path_to(part))
		for label: String in ["Driver","Helmet","SteeringAssembly"]:
			if label in path: protected_part=true
		if part.mesh is ArrayMesh and part.mesh.get_blend_shape_count()>0: protected_part=true
		var member: Array=[source,pose,part.layers,part.cast_shadow,state,protected_part]
		var member_key: String=var_to_bytes(member).hex_encode().sha256_text()
		if not frames.has(frame): frames[frame]=[]
		frames[frame].append({"part":part,"pose":pose,"source":source,"state":state,"code":member_key,"protected":protected_part,"opaque":opaque_state(state)})
	var result: Array=[]
	for frame: Node3D in frames:
		var entries: Array=frames[frame]
		var codes: Array=[]
		for entry: Dictionary in entries: codes.append(entry.code)
		codes.sort()
		var context: String=var_to_bytes([SCHEMA,car.vehicle_id,codes]).hex_encode().sha256_text()
		result.append({"vehicle":car.vehicle_id,"code":context,"entries":entries})
	return result

static func recipe(id: String, context: String) -> Dictionary:
	var code: String=id+"_"+context
	if not recipes.has(code):
		if recipes.size()>=LIMIT: recipes.clear()
		var path: String=ROOT.path_join(code+".json")
		var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		recipes[code]=data if data is Dictionary and data.get("schema","")==SCHEMA and data.get("context","")==context else {}
	return recipes[code]

static func replacement(row: Dictionary, source: Mesh) -> Mesh:
	var file: String=str(row.get("mesh",""))
	if file.is_empty() or file.get_file()!=file or not file.ends_with(".res"): return null
	if not meshes.has(file):
		if meshes.size()>=LIMIT: meshes.clear()
		meshes[file]=load(ROOT.path_join(file)) if ResourceLoader.exists(ROOT.path_join(file)) else null
	var mesh: Mesh=meshes[file]
	if mesh==null or mesh.get_meta("car_detail_source","")!=mesh_key(source) or mesh.get_surface_count()!=source.get_surface_count() or mesh.get_aabb()!=source.get_aabb(): return null
	return mesh

static func apply_group(group: Dictionary) -> void:
	var data: Dictionary=recipe(group.vehicle,group.code)
	if data.is_empty(): return
	# Validate the entire frame before touching any live member.
	var changes: Array=[]
	for entry: Dictionary in group.entries:
		var row: Dictionary=data.get("parts",{}).get(entry.code,{})
		if row.is_empty(): continue
		if row.get("source","")!=entry.source or entry.protected or not entry.opaque: return
		var mesh: Mesh=null if row.get("hidden",false) else replacement(row,entry.part.mesh)
		if mesh==null and not row.get("hidden",false): return
		changes.append([entry.part,mesh,row.get("hidden",false)])
	for change: Array in changes:
		var part: MeshInstance3D=change[0]
		if change[2]: part.hide()
		else:
			var materials: Array[Material]=[]
			for surface: int in range(part.mesh.get_surface_count()): materials.append(part.get_active_material(surface))
			if part.material_override!=null:
				# An existing instance finish already covers every surface. Avoid
				# creating redundant surface overrides on nodes about to be batched.
				part.mesh=change[1]
			elif materials.size()==1:
				part.material_override=materials[0]
				part.mesh=change[1]
			else:
				part.material_override=materials[0]
				part.mesh=change[1]
				for surface: int in range(materials.size()): part.set_surface_override_material(surface,materials[surface])
				part.material_override=null
		hits+=1

static func apply(car: CarVisual, holders: Variant=null) -> void:
	# The complete stock/kit study finds no removable Hover faces. Avoid
	# hashing that model during construction when no recipe can improve it.
	if not enabled or not car.simple_model or not car.batch_parts or car.vehicle_id not in VehicleCatalog.IDS or car.vehicle_id=="hovercraft": return
	for group: Dictionary in groups(car,holders):
		if offline.is_valid(): offline.call(group)
		else: apply_group(group)
	load("res://vehicle/car_surface_reduction.gd").apply(car,holders,load("res://vehicle/car_detail_reduction.gd"))
