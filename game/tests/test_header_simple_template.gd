extends SceneTree
const Prepared=preload("res://ui/header_simple_cache.gd")
var checks: int=0
var failures: int=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func finish(material: Material) -> Array:
	if material==null: return []
	var result: Array=[material.get_class()]
	if material is ShaderMaterial:
		result.append(material.shader.code)
		for item: Dictionary in material.shader.get_shader_uniform_list():
			var value: Variant=material.get_shader_parameter(item.name)
			if value is Texture2D:
				var image: Image=value.get_image()
				value=[image.get_size(),image.get_data()] if image!=null else null
			result.append([item.name,value])
	else:
		for property: Dictionary in material.get_property_list():
			if int(property.usage)&PROPERTY_USAGE_STORAGE and not str(property.name).begins_with("resource_") and property.name!="next_pass":
				var value: Variant=material.get(property.name)
				if value is Texture2D:
					var image: Image=value.get_image()
					value=[image.get_size(),image.get_data()] if image!=null else null
				result.append([property.name,value])
	result.append(finish(material.next_pass))
	return result
func shape(car: CarVisual) -> Array:
	var value: Array=[car.wheel_radii,car.wheel_rest_positions,car.scale]
	for node: Node3D in car.find_children("*","Node3D",true,false):
		value.append([car.get_path_to(node),node.transform])
		if node is MeshInstance3D:
			value.append([node.layers,node.cast_shadow])
			for surface: int in range(node.mesh.get_surface_count()):
				value.append(node.mesh.surface_get_arrays(surface))
				value.append(finish(node.get_active_material(surface)))
	return value
func make(id: String,prepared: bool) -> CarVisual:
	var car: CarVisual = load("res://ui/rivalry_victory_car.gd").HeaderCarVisual.new() if prepared else CarVisual.new()
	car.vehicle_id=id
	car.livery=VehicleLivery.defaults(id)
	car.simple_model=true
	# HeaderCarVisual is selected above
	root.add_child(car)
	return car
func difference(a: Variant,b: Variant,path: String="") -> void:
	if a is Array and b is Array:
		if a.size()!=b.size(): print("DETAIL_LENGTH ",path," ",a.size()," ",b.size())
		for i: int in range(mini(a.size(),b.size())):
			if typeof(a[i])!=typeof(b[i]) or a[i]!=b[i]: difference(a[i],b[i],path+"/"+str(i));return
	else: print("DETAIL_VALUE ",path," ",a," / ",b)
func run() -> void:
	for id: String in ["compact"]:
		var reference: CarVisual=make(id,false)
		var original: Array=shape(reference)
		var before: int=Prepared.hits
		var restored: CarVisual=make(id,true)
		check(Prepared.hits==before+1,"prepared native resource used "+id)
		var packed: PackedScene=load("res://assets/menu/header_car_templates_v1/compact.scn")
		var holder: Node3D=packed.instantiate()
		var data: Dictionary=holder.get_meta("garage_rest",{})
		var template_bytes: int=preload("res://track/prepared_world_cache.gd")._resource_bytes(holder,{})+holder.find_children("*","MeshInstance3D",true,false).size()*2048
		check(template_bytes<=preload("res://vehicle/prepared_car_cache.gd").MAX_BYTES,"prepared template stays within the existing car-cache accounting limit")
		print("HEADER_TEMPLATE_ESTIMATED_BYTES ",template_bytes)
		var revision: String=str(data.get("revision",""))
		check(Prepared.valid_data(data,restored,revision),"matching revision, engine and construction key accepted")
		var stale: Dictionary=data.duplicate(true); stale.revision="0".repeat(64)
		check(not Prepared.valid_data(stale,restored,revision),"source revision mismatch rejected")
		stale=data.duplicate(true); stale.engine=["unexpected","hash"]
		check(not Prepared.valid_data(stale,restored,revision),"engine mismatch rejected")
		stale=data.duplicate(true); stale.key=[]
		check(not Prepared.valid_data(stale,restored,revision),"model construction mismatch rejected")
		stale=data.duplicate(true); stale.schema="old"
		check(not Prepared.valid_data(stale,restored,revision),"old schema rejected")
		holder.free()
		var rebuilt: Array=shape(restored)
		check(original==rebuilt,"all geometry, articulation and finish values match "+id)
		if original!=rebuilt:
			difference(original,rebuilt,id)
			if id=="electric":
				for instance: CarVisual in [reference,restored]:
					for mesh: Node in instance.find_children("*","MeshInstance3D",true,false):
						if str(instance.get_path_to(mesh)).begins_with("FrontLeftWheel"): print("EV_SURFACE ",instance.garage_template," ",instance.get_path_to(mesh)," ",mesh.mesh.get_surface_count())
			for i: int in range(mini(original.size(),rebuilt.size())):
				if original[i]!=rebuilt[i]: print("MODEL_DIFFERENCE ",id," index=",i," original=",str(original[i]).left(220)," restored=",str(rebuilt[i]).left(220));break
		var paint: Dictionary=VehicleLivery.defaults(id)
		paint.colors.body="c72d34"
		restored.apply_livery(paint)
		check(shape(reference)==original,"preview paint cannot mutate reference materials "+id)
		reference.apply_livery(paint)
		check(shape(restored)==shape(reference),"custom paint restores exact geometry and material state")
		reference.apply_livery(VehicleLivery.defaults(id))
		var other: CarVisual=make(id,true)
		check(shape(other)==original,"future instance retains native stock finish "+id)
		var fitted: CarVisual=load("res://ui/rivalry_victory_car.gd").HeaderCarVisual.new()
		fitted.vehicle_id=id; fitted.simple_model=true
		fitted.customisation=VehicleCustomisation.defaults(); fitted.customisation.hood="cowl"
		var last_hit: int=Prepared.hits
		root.add_child(fitted)
		check(Prepared.hits==last_hit,"fitted kit uses the procedural fallback")
		fitted.free()
		reference.free();restored.free();other.free()
		await process_frame
	print("HEADER_SIMPLE_TEMPLATE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
