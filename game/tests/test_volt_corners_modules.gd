extends SceneTree
## Compare prepared cars to the procedural constructors without owner data.
## Optional: --vehicle=<id>, --all-kits, --profile. Run after the assets are baked.

const Base = preload("res://vehicle/modular_car_base.gd")
const Kits = preload("res://vehicle/modular_car_kits.gd")
const Rest = preload("res://vehicle/prepared_car_cache.gd")
const Garage = preload("res://ui/garage_car_cache.gd")
const TriangleCompare = preload("res://tests/modular_triangle_compare.gd")

var checks: int = 0
var failures: int = 0
var only_vehicle: String = ""
var all_kits: bool = false
var profile: bool = false
var rollback_only: bool = false

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)

func value_key(value: Variant) -> Variant:
	if value is Texture2D:
		var image: Image = value.get_image()
		# PackedScene rehomes embedded ImageTextures into its own subresource
		# paths. Compare their complete image identity, not that storage address.
		var path: String = "embedded-image" if value is ImageTexture and value.resource_path.contains("::") else value.resource_path
		return [value.get_class(),path,image.get_size() if image != null else Vector2i.ZERO,image.get_format() if image != null else -1,image.has_mipmaps() if image != null else false,image.get_data().hex_encode().sha256_text() if image != null else "no-image"]
	if value is Resource:
		return [value.get_class(),value.resource_path]
	return value

func material_key(material: Material) -> String:
	if material == null: return "null"
	var result: Array = [material.get_class()]
	if material is ShaderMaterial:
		result.append(material.shader.code if material.shader != null else "")
		if material.shader != null:
			for uniform: Dictionary in material.shader.get_shader_uniform_list():
				result.append([uniform.name,value_key(material.get_shader_parameter(uniform.name))])
	else:
		for property: Dictionary in material.get_property_list():
			if int(property.usage)&PROPERTY_USAGE_STORAGE and not str(property.name).begins_with("resource_") and property.name != "next_pass":
				result.append([property.name,value_key(material.get(property.name))])
	result.append(material_key(material.next_pass))
	return var_to_bytes(result).hex_encode().sha256_text()

func show_difference(label: String, key: String, left: Variant, right: Variant) -> void:
	if key != "materials":
		print("DETAIL ",label," ",key," ",left," / ",right)
		return
	var all_keys: Dictionary = {}
	for item: Variant in left: all_keys[item] = true
	for item: Variant in right: all_keys[item] = true
	for item: Variant in all_keys:
		if left.get(item,0) != right.get(item,0):
			print("DETAIL ",label," material ",item," ",left.get(item,0)," / ",right.get(item,0))

func mesh_geometry(mesh: Mesh) -> Array:
	var faces: PackedVector3Array = mesh.get_faces()
	var digest_sum: int = 0
	var digest_xor: int = 0
	for triangle: int in range(faces.size()/3):
		var points: Array[Vector3] = []
		for corner: int in range(3): points.append(faces[triangle*3+corner].snapped(Vector3.ONE*0.00001))
		points.sort()
		var digest: int = hash(points) & 0x7fffffff
		digest_sum += digest
		digest_xor ^= digest
	return [faces.size(),digest_sum,digest_xor]

func shape(car: CarVisual, roots: Array = []) -> Dictionary:
	var inverse: Transform3D = car.global_transform.affine_inverse()
	var result: Dictionary = {"triangles":0,"shadow_triangles":0,"caster_triangles":0,"caster_sum":0,"caster_xor":0,"proxy_sum":0,"proxy_xor":0,"bounds":AABB(),"has_bounds":false,"triangle_sum":0,"triangle_xor":0,"attribute_sum":0,"attribute_xor":0,"materials":{}}
	var keys: Dictionary = {}
	for node: MeshInstance3D in TriangleCompare.meshes(car,roots):
		if node.mesh == null or not node.is_visible_in_tree(): continue
		var pose: Transform3D = inverse * node.global_transform
		var proxy: bool = node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var normal_transform: Basis = pose.basis.inverse().transposed()
			var count: int = indices.size() if not indices.is_empty() else vertices.size()
			if proxy: result.shadow_triangles += count / 3
			else:
				result.triangles += count / 3
				if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: result.caster_triangles += count / 3
				var material: Material = node.get_active_material(surface)
				var id: int = material.get_instance_id() if material != null else 0
				if not keys.has(id): keys[id] = material_key(material)
				var finish: String = keys[id]
				result.materials[finish] = int(result.materials.get(finish,0)) + count / 3
			for triangle: int in range(count / 3):
				var points: Array[Vector3] = []
				var attributes: Array[int] = []
				for corner: int in range(3):
					var index: int = triangle * 3 + corner
					var vertex_index: int = indices[index] if not indices.is_empty() else index
					var point: Vector3 = (pose * vertices[vertex_index]).snapped(Vector3.ONE * 0.00001)
					points.append(point)
					if proxy: continue
					var detail: Array = [point]
					if vertex_index < normals.size(): detail.append((normal_transform*normals[vertex_index]).normalized().snapped(Vector3.ONE*0.00001))
					if vertex_index < uv.size(): detail.append(uv[vertex_index].snapped(Vector2.ONE*0.00001))
					if vertex_index < colours.size(): detail.append(colours[vertex_index])
					attributes.append(hash(detail))
					if not result.has_bounds:
						result.bounds = AABB(point,Vector3.ZERO)
						result.has_bounds = true
					else: result.bounds = result.bounds.expand(point)
				points.sort()
				var digest: int = hash(points) & 0x7fffffff
				if proxy:
					result.proxy_sum += digest
					result.proxy_xor ^= digest
				else:
					result.triangle_sum += digest
					result.triangle_xor ^= digest
					attributes.sort()
					var detail_digest: int = hash(attributes) & 0x7fffffff
					result.attribute_sum += detail_digest
					result.attribute_xor ^= detail_digest
					if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
						var caster_digest: int = hash([points,node.cast_shadow]) & 0x7fffffff
						result.caster_sum += caster_digest
						result.caster_xor ^= caster_digest
	return result

func check_attributes(control: CarVisual, prepared: CarVisual, a: Dictionary, b: Dictionary, label: String, left_roots: Array = [], right_roots: Array = []) -> void:
	if a.attribute_sum == b.attribute_sum and a.attribute_xor == b.attribute_xor:
		check(true,label+" vertex attributes are exact")
		return
	# SurfaceTool rebatching introduces a measured sub-0.015 degree normal
	# difference; still pair each triangle and require exact UV and color.
	var difference: Dictionary = TriangleCompare.compare(TriangleCompare.collect(control,left_roots),TriangleCompare.collect(prepared,right_roots))
	print("ATTRIBUTE_TOLERANCE ",label," ",JSON.stringify(difference))
	check(difference.unmatched_geometry == 0,label+" attribute triangles correspond")
	check(difference.unmatched_uv_color == 0,label+" vertex UVs and colors are exact")
	check(difference.max_normal_degrees <= 0.02,label+" normal difference stays below 0.02 degrees")

func make_car(id: String, simple: bool, editable: bool, parts: Dictionary, modular: bool) -> CarVisual:
	Base.enabled = modular
	Kits.enabled = modular
	Rest.enabled = modular
	Rest.entries.clear()
	var car := CarVisual.new()
	car.vehicle_id = id
	car.simple_model = simple
	car.editable_kits = editable
	car.customisation = parts.duplicate(true)
	car.livery = VehicleLivery.defaults(id)
	root.add_child(car)
	while not car.model_ready: await process_frame
	for node: Node3D in car.front_wheels+car.rear_wheels+car.rolling_wheels+car.brake_lights:
		check(is_instance_valid(node) and node.is_inside_tree(),id+" keeps every live wheel/light binding in the tree")
	return car

func exercise(id: String, simple: bool, editable: bool, parts: Dictionary, label: String) -> void:
	var control: CarVisual = await make_car(id,simple,editable,parts,false)
	var before: int = Base.hits
	var kit_before: int = Kits.hits
	var prepared: CarVisual = await make_car(id,simple,editable,parts,true)
	var fitted_count: int = 0
	for category: String in VehicleCustomisation.CATEGORIES:
		if parts[category] != "stock": fitted_count += 1
	if simple and fitted_count > 0:
		check(Base.hits>before and Kits.hits>=kit_before+fitted_count,label+" uses prepared reduced base and every fitted module")
		check(prepared.find_children("RaceShadowProxy","MeshInstance3D",true,false).is_empty(),label+" fitted silhouette retains actual casters")
	else:
		check(Base.hits > before,label+" uses the baked base")
		if fitted_count > 0: check(Kits.hits >= kit_before+fitted_count,label+" uses every selected module")
	var a: Dictionary = shape(control)
	var b: Dictionary = shape(prepared)
	for key: String in ["triangles","shadow_triangles","caster_triangles","caster_sum","caster_xor","proxy_sum","proxy_xor","triangle_sum","triangle_xor","materials"]:
		if a[key] != b[key]: show_difference(label,key,a[key],b[key])
		check(a[key] == b[key],label+" "+key+" agrees with procedural construction")
	check_attributes(control,prepared,a,b,label)
	check(a.has_bounds == b.has_bounds and a.bounds.is_equal_approx(b.bounds),label+" bounds agree")
	check(control.wheel_radii == prepared.wheel_radii and control.wheel_rest_positions == prepared.wheel_rest_positions,label+" wheel radii and rest positions agree")
	check(control.front_wheels.size() == prepared.front_wheels.size() and control.rear_wheels.size() == prepared.rear_wheels.size() and control.rolling_wheels.size() == prepared.rolling_wheels.size(),label+" steering and rolling pivots agree")
	if id == "hovercraft":
		for side: String in ["FanRotorLeft","FanRotorRight"]: check(prepared.body.find_child(side,true,false) != null,label+" keeps "+side)
	var paint: Dictionary = VehicleLivery.defaults(id)
	paint.colors.body = "824d31"
	for pattern: Dictionary in LiveryCatalog.patterns:
		if pattern.id != "plain":
			paint.pattern = pattern.id
			break
	prepared.apply_livery(paint)
	check(prepared.paint_materials.body.albedo_color.to_html(false) == "824d31",label+" can recolor body")
	check(control.paint_materials.body.albedo_color != prepared.paint_materials.body.albedo_color,label+" paint remains instance-local")
	check(not prepared.graphics.bindings.is_empty() and bool(prepared.graphics.bindings[0].finish.get_shader_parameter("graphics_enabled")),label+" livery graphics bind")
	var state := VehicleState.new()
	state.tick = 1
	state.steering = 0.4
	if id == "electric": state.velocity = Vector2(0,10)
	prepared.present(Vector2.ZERO,0.0,state,DriveFrame.sample(0,0,1))
	check(prepared.brake_material.albedo_color == Color("f17158"),label+" brake material responds")
	var wear := VehicleWeathering.new()
	wear.configure(prepared,"desert",VehicleCatalog.config(id))
	check(not wear.materials.is_empty(),label+" weathering binds")
	var decorated_wear: bool = false
	for material: ShaderMaterial in wear.materials:
		if material.get_shader_parameter("graphics_enabled") == true: decorated_wear = true
	check(decorated_wear,label+" weathering preserves livery graphics")
	wear.reset()
	if not editable:
		# A ghost first enabled mid-race must represent the rest pose, even when
		# modular restoration skipped the ordinary procedural rest-cache snapshot.
		var rest_mesh: ArrayMesh = PersonalGhost.mesh_for(control)
		prepared.body.rotation.z = 0.13
		if not prepared.front_wheels.is_empty(): prepared.front_wheels[0].rotation.y = 0.45
		if not prepared.rolling_wheels.is_empty(): prepared.rolling_wheels[0].rotation.x = 0.7
		var fan: Node3D = prepared.body.find_child("FanRotorLeft",true,false)
		if fan != null: fan.rotation.z = 0.9
		prepared.force_update_transform()
		for node: Node3D in prepared.find_children("*","Node3D",true,false): node.force_update_transform()
		PersonalGhost.prepared_meshes.clear()
		var ghost := PersonalGhost.new()
		ghost.configure(prepared)
		check(ghost.mesh != null and mesh_geometry(ghost.mesh) == mesh_geometry(rest_mesh),label+" ghost remains in rest pose after car articulation")
		ghost.free()
	control.free()
	prepared.free()
	await process_frame

func profile_car(id: String, parts: Dictionary, modular: bool) -> Dictionary:
	Base.enabled = modular
	Kits.enabled = modular
	Rest.enabled = modular
	Rest.entries.clear()
	var base_before: int = Base.hits
	var kits_before: int = Kits.hits
	var began: int = Time.get_ticks_usec()
	var car := CarVisual.new()
	car.vehicle_id = id
	car.customisation = parts.duplicate(true)
	car.cooperative_build = true
	root.add_child(car)
	var frames: int = 0
	while not car.model_ready:
		frames += 1
		await process_frame
	var result: Dictionary = {"vehicle":id,"parts":parts,"modular":modular,"wall_ms":float(Time.get_ticks_usec()-began)/1000.0,"frames":frames,"yields":car.model_yields,"max_slice_us":car.model_max_slice_us,"base_hits":Base.hits-base_before,"kit_hits":Kits.hits-kits_before}
	car.free()
	await process_frame
	return result

func exercise_replacement(id: String, simple: bool) -> void:
	var stock: Dictionary = VehicleCustomisation.defaults()
	var control: CarVisual = await make_car(id,simple,true,stock,false)
	var prepared: CarVisual = await make_car(id,simple,true,stock,true)
	var original_wheels: Array = prepared.rolling_wheels.duplicate()
	var parts: Dictionary = stock.duplicate(true)
	for category: String in VehicleCustomisation.CATEGORIES:
		parts[category] = VehicleCustomisation.options(category,id)[1][0]
	for selected: Dictionary in [parts,stock]:
		Base.enabled = false; Kits.enabled = false; Rest.enabled = false
		control.graphics.restore_originals()
		control.change_kit_parts(selected)
		Base.enabled = true; Kits.enabled = true; Rest.enabled = true
		var before: int = Kits.hits
		prepared.graphics.restore_originals()
		prepared.change_kit_parts(selected)
		if selected != stock: check(Kits.hits >= before+4,id+" "+str(simple)+" live kit change uses four modules")
		var a: Dictionary = shape(control)
		var b: Dictionary = shape(prepared)
		for key: String in ["triangles","shadow_triangles","caster_triangles","caster_sum","caster_xor","proxy_sum","proxy_xor","triangle_sum","triangle_xor","materials"]:
			if a[key] != b[key]: show_difference(id+" "+str(simple)+" replacement "+str(selected),key,a[key],b[key])
			check(a[key] == b[key],id+" "+str(simple)+" live replacement "+key+" "+str(selected == stock))
		check_attributes(control,prepared,a,b,id+" "+str(simple)+" live replacement")
		check(prepared.rolling_wheels == original_wheels,id+" "+str(simple)+" live replacement keeps rolling pivots")
	control.free()
	prepared.free()
	await process_frame

func kit_roots(car: CarVisual, category: String) -> Array:
	var result: Array = car.kit_frames.get(category,[]).duplicate()
	if car.vehicle_id == "hovercraft" and category == "rims":
		var fan: Node = car.body.get_node_or_null("FanRotor")
		if fan != null: result.append(fan)
	return result

func exercise_single_replacement(control: CarVisual, prepared: CarVisual, id: String, simple: bool, category: String, option: String) -> void:
	# Verify every independently replaceable module, including simple modules
	# which are used for live editing but not initial fitted race construction.
	var stock: Dictionary = VehicleCustomisation.defaults()
	var value: Dictionary = stock.duplicate(true)
	value[category] = option
	Base.enabled = false; Kits.enabled = false; Rest.enabled = false
	control.graphics.restore_originals()
	control.change_kit_parts(value)
	Base.enabled = true; Kits.enabled = true; Rest.enabled = true
	var before: int = Kits.hits
	prepared.graphics.restore_originals()
	prepared.change_kit_parts(value)
	var label: String = id+" "+str(simple)+" live "+category+"/"+option
	check(Kits.hits == before+1,label+" uses selected module")
	var left_roots: Array = kit_roots(control,category)
	var right_roots: Array = kit_roots(prepared,category)
	check(not left_roots.is_empty() and left_roots.size() == right_roots.size(),label+" preserves module frames")
	if left_roots.is_empty() or right_roots.is_empty():
		return
	var a: Dictionary = shape(control,left_roots)
	var b: Dictionary = shape(prepared,right_roots)
	for key: String in ["triangles","shadow_triangles","caster_triangles","caster_sum","caster_xor","proxy_sum","proxy_xor","triangle_sum","triangle_xor","materials"]:
		if a[key] != b[key]: show_difference(label,key,a[key],b[key])
		check(a[key] == b[key],label+" "+key)
	check_attributes(control,prepared,a,b,label,left_roots,right_roots)

func exercise_all_options(id: String, simple: bool) -> void:
	var stock: Dictionary = VehicleCustomisation.defaults()
	var control: CarVisual = await make_car(id,simple,true,stock,false)
	var base_before: int = Base.hits
	var prepared: CarVisual = await make_car(id,simple,true,stock,true)
	check(Base.hits > base_before,id+" "+str(simple)+" exhaustive options start from prepared base")
	for category: String in VehicleCustomisation.CATEGORIES:
		for option: Array in VehicleCustomisation.options(category,id).slice(1):
			print("MODULE_CASE ",id," ",simple," ",category,"/",option[0])
			exercise_single_replacement(control,prepared,id,simple,category,str(option[0]))
			await process_frame
		Base.enabled = false; Kits.enabled = false; Rest.enabled = false
		control.graphics.restore_originals(); control.change_kit_parts(stock)
		Base.enabled = true; Kits.enabled = true; Rest.enabled = true
		prepared.graphics.restore_originals(); prepared.change_kit_parts(stock)
	control.free()
	prepared.free()
	await process_frame

func profile_cars() -> void:
	# Interleave the same fixed workload; OS/driver/asset cache state is not cold.
	for id: String in VehicleCatalog.IDS:
		if not only_vehicle.is_empty() and id != only_vehicle: continue
		var parts: Dictionary = VehicleCustomisation.defaults()
		if VehicleCustomisation.supported(id):
			for category: String in VehicleCustomisation.CATEGORIES:
				parts[category] = VehicleCustomisation.options(category,id)[1][0]
		for repetition: int in range(3):
			for modular: bool in ([false,true] if repetition%2 == 0 else [true,false]):
				var result: Dictionary = await profile_car(id,parts,modular)
				result.repetition = repetition
				print("MODULAR_CAR_PROFILE ",JSON.stringify(result))
	print("MODULAR_CAR_PROFILE_DONE")
	quit()

func test_rejected_assets() -> void:
	var stock: Dictionary = VehicleCustomisation.defaults()
	var control: CarVisual = await make_car("compact",false,false,stock,false)
	var expected: Dictionary = shape(control)
	var source_before: Variant = Base._sources.get("compact")
	Base._sources["compact"] = {"invalid-source-revision":"test"}
	var hits_before: int = Base.hits
	var fallback: CarVisual = await make_car("compact",false,false,stock,true)
	check(Base.hits == hits_before,"stale base is rejected")
	var actual: Dictionary = shape(fallback)
	check(expected.triangles == actual.triangles and expected.triangle_sum == actual.triangle_sum and expected.triangle_xor == actual.triangle_xor and expected.materials == actual.materials,"stale base falls back to complete procedural geometry and materials")
	if source_before == null: Base._sources.erase("compact")
	else: Base._sources["compact"] = source_before
	control.free()
	fallback.free()
	await process_frame
	var editable: CarVisual = await make_car("compact",false,true,stock,true)
	var child_count: int = editable.get_child_count()
	var kit_hits: int = Kits.hits
	check(not Kits.apply(editable,"hood","nonexistent-option"),"unknown module is rejected")
	check(editable.get_child_count() == child_count and Kits.hits == kit_hits,"rejected module does not mutate the car")
	if FileAccess.file_exists("res://vehicle/car_visual.gd"):
		var selected: Dictionary = stock.duplicate(true)
		selected.hood = VehicleCustomisation.options("hood","compact")[1][0]
		var original_sources: Dictionary = Kits.source_hashes
		Kits.source_hashes = {"compact":{"invalid-source-revision":"test"}}
		check(not Kits.available(editable,selected),"stale module is rejected before fitting")
		Kits.source_hashes = original_sources
	editable.free()
	await process_frame
	await test_last_module_rollback()

func test_last_module_rollback() -> void:
	# Replace only the process-local cached resource, never the file. Three kit
	# modules must be applied before the deliberately invalid fourth is reached.
	var parts: Dictionary = VehicleCustomisation.defaults()
	for category: String in VehicleCustomisation.CATEGORIES:
		parts[category] = VehicleCustomisation.options(category,"compact")[1][0]
	var control: CarVisual = await make_car("compact",false,true,parts,false)
	var expected: Dictionary = shape(control)
	var descriptor := CarVisual.new()
	descriptor.vehicle_id = "compact"
	descriptor.simple_model = false # Match the full-quality control/fallback above.
	descriptor.editable_kits = true
	var path: String = Kits.path_for(descriptor,"body",str(parts.body))
	descriptor.free()
	var original: PackedScene = load(path) as PackedScene
	check(original != null,"rollback fixture finds the final module")
	if original == null:
		control.free()
		return
	var empty_holder := Node3D.new()
	var invalid := PackedScene.new()
	check(invalid.pack(empty_holder) == OK,"rollback fixture builds a temporary invalid resource")
	empty_holder.free()
	invalid.take_over_path(path)
	check(load(path) == invalid,"rollback fixture overrides only the in-memory resource cache")
	var base_before: int = Base.hits
	var kits_before: int = Kits.hits
	var fallback: CarVisual = await make_car("compact",false,true,parts,true)
	original.take_over_path(path)
	check(load(path) == original,"rollback fixture restores the resource cache")
	check(Base.hits == base_before+1 and Kits.hits == kits_before+3,"failed fourth module follows three successful attachments")
	var actual: Dictionary = shape(fallback)
	for key: String in ["triangles","shadow_triangles","caster_triangles","caster_sum","caster_xor","proxy_sum","proxy_xor","triangle_sum","triangle_xor","materials"]:
		if expected[key] != actual[key]: show_difference("last-module rollback",key,expected[key],actual[key])
		check(expected[key] == actual[key],"last-module rollback restores procedural "+key)
	check_attributes(control,fallback,expected,actual,"last-module rollback")
	check(fallback.wheel_rest_positions == control.wheel_rest_positions and fallback.rolling_wheels.size() == control.rolling_wheels.size(),"last-module rollback preserves articulation")
	check(fallback.kit_frames.keys() == control.kit_frames.keys(),"last-module rollback leaves no partial frame bindings")
	control.free(); fallback.free()
	await process_frame

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--vehicle="): only_vehicle = arg.trim_prefix("--vehicle=")
		if arg == "--all-kits": all_kits = true
		if arg == "--profile": profile = true
		if arg == "--rollback-only": rollback_only = true
	if not only_vehicle.is_empty() and only_vehicle not in VehicleCatalog.IDS:
		push_error("Unknown vehicle: "+only_vehicle)
		quit(1)
		return
	Garage.enabled = false
	if rollback_only:
		await test_last_module_rollback()
		print("MODULAR_CAR_ROLLBACK: ",checks," checks, ",failures," failures")
		quit(1 if failures else 0)
		return
	if profile:
		await profile_cars()
		return
	for id: String in VehicleCatalog.IDS:
		if not only_vehicle.is_empty() and id != only_vehicle: continue
		for simple: bool in [true]:
			var stock: Dictionary = VehicleCustomisation.defaults()
			await exercise(id,simple,false,stock,id+" "+str(simple)+" race stock")
			if VehicleCustomisation.supported(id):
				await exercise(id,simple,true,stock,id+" "+str(simple)+" editable stock")
				var fitted: Dictionary = stock.duplicate(true)
				for category: String in VehicleCustomisation.CATEGORIES:
					fitted[category] = VehicleCustomisation.options(category,id)[1][0]
				await exercise(id,simple,false,fitted,id+" "+str(simple)+" race fitted")
				await exercise(id,simple,true,fitted,id+" "+str(simple)+" editable fitted")
				await exercise_replacement(id,simple)
				if all_kits:
					await exercise_all_options(id,simple)
	if only_vehicle.is_empty() or only_vehicle == "compact": await test_rejected_assets()
	print("MODULAR_CAR_ASSETS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
