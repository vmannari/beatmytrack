extends SceneTree
## Real meshes, factory resets and unchanged Rally construction/handling controls.
var checks: int = 0
var failures: int = 0
var metrics: Array = []
const OUT: String = "res://../docs/evidence/super-rally-restraint-2026-11-09"
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func bounds(car: CarVisual) -> AABB:
	var result := AABB()
	var first: bool = true
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.mesh == null or part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		var relative: Transform3D = car.global_transform.affine_inverse()*part.global_transform
		var box: AABB = relative*part.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result

func triangles(car: CarVisual) -> int:
	var count: int = 0
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.mesh != null and part.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			count += part.mesh.get_faces().size()/3
	return count

func arch_width(car: CarVisual) -> float:
	var extent: float = 0.0
	for part: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
		if part.mesh == null or part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		var relative: Transform3D = car.global_transform.affine_inverse()*part.global_transform
		for surface: int in range(part.mesh.get_surface_count()):
			for vertex: Vector3 in part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = relative*vertex
				if p.y >= 0.65 and p.y <= 1.0 and absf(p.z) >= 1.03 and absf(p.z) <= 1.60: extent = maxf(extent,absf(p.x))
	return extent*2.0

func signature(car: CarVisual) -> String:
	var parts: Array[String] = []
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.mesh == null: continue
		for surface: int in range(part.mesh.get_surface_count()):
			var hash := HashingContext.new()
			hash.start(HashingContext.HASH_SHA256)
			hash.update(var_to_bytes([car.global_transform.affine_inverse()*part.global_transform,part.mesh.surface_get_arrays(surface),part.cast_shadow]))
			parts.append(hash.finish().hex_encode())
	parts.sort()
	return JSON.stringify(parts).sha256_text()

func make_car(id: String, reduced: bool, old: bool = false) -> CarVisual:
	var car: CarVisual = preload("res://tests/fixtures/super_rally_design_before/old_rally_visual.gd").new() if old else CarVisual.new()
	car.vehicle_id = id
	car.simple_model = reduced
	car.editable_kits = true
	car.batch_parts = false
	car.livery = VehicleLivery.defaults(id)
	root.add_child(car)
	while not car.model_ready: await process_frame
	return car

func run() -> void:
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/modular_car_kits.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	for reduced: bool in [false,true]:
		var rally: CarVisual = await make_car("compact",reduced)
		var control: CarVisual = await make_car("compact",reduced,true)
		CompactKits.simple_parts = not reduced # A previous car cannot select this roof's quality.
		var car: CarVisual = await make_car("super_rally",reduced)
		check(signature(rally) == signature(control),"normal Rally matches task-start construction exactly")
		var stock: AABB = bounds(car)
		var ordinary: AABB = bounds(rally)
		check(stock.position.z < ordinary.position.z-0.35,"C3-style long nose extends distinctly beyond the Rally hatchback")
		check(stock.end.y < ordinary.end.y-0.15,"C3 coupe cabin is distinctly lower than the Rally roof")
		check(car.brake_lights.size() == 4,"classic tail uses four independently retained round rear lamps")
		check(car.wheel_rest_positions == rally.wheel_rest_positions and car.wheel_radii == rally.wheel_radii,"exterior retains physical wheel contact locations and radii")
		check(car.model_id != rally.model_id and car.chassis_id == rally.chassis_id,"separate exterior cache identity retains Rally chassis")
		check(car.customisation == VehicleCustomisation.defaults(),"new factory shape requires no purchased fitted parts")
		var factory_triangles: int = triangles(car)
		check(factory_triangles <= triangles(rally)+(10000 if reduced else 25000),"competition body retains a bounded additional geometry cost")
		var finite: bool = true
		for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
			if part.mesh == null: continue
			for surface: int in range(part.mesh.get_surface_count()):
				var arrays: Array = part.mesh.surface_get_arrays(surface)
				for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]: finite = finite and vertex.is_finite()
		check(finite,"every generated exterior vertex is finite")
		var fitted: Dictionary = VehicleCustomisation.defaults()
		fitted.merge({"hood":"scoop","aero":"ducktail","rims":"five","body":"rally"},true)
		car.change_kit_parts(fitted)
		check(car.customisation == fitted,"existing Rally kits fit every replacement category")
		car.change_kit_parts(VehicleCustomisation.defaults())
		check(car.customisation == VehicleCustomisation.defaults() and bounds(car).is_equal_approx(stock),"Original/reset restores the complete Super rally silhouette")
		check(not car.kit_frames.aero.is_empty() and not car.kit_frames.body.is_empty(),"factory body and aero remain independently replaceable")
		metrics.append({"reduced":reduced,"rally_triangles":triangles(rally),"super_triangles":factory_triangles,"rally_bounds":str(ordinary),"super_bounds":str(stock)})
		rally.free(); control.free(); car.free()
	var cosmetics = preload("res://persistence/cosmetic_catalog.gd")
	var legacy := {"vehicle_customisation":{}}
	for id: String in ["compact","super_rally"]:
		legacy.vehicle_customisation[id] = VehicleCustomisation.defaults()
		legacy.vehicle_customisation[id].hood = "scoop"
	var owned: Array = cosmetics.legacy(legacy)
	check(owned.count("kit/compact/hood/scoop") == 1 and cosmetics.valid_owned(owned),"shared Rally ownership is deduplicated across the two saved cars")
	check(not cosmetics.items().has("kit/super_rally/hood/scoop"),"new exterior introduces no duplicate paid part identity")
	check(cosmetics.items() == preload("res://tests/fixtures/super_rally_design_before/old_cosmetic_catalog.gd").items(),"complete priced catalogue is identical to task-start five-car ownership")
	var file := FileAccess.open(OUT.path_join("geometry-acceptance.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t")); file.close()
	print("SUPER_RALLY_DESIGN: %d checks, %d failures; %s" % [checks,failures,JSON.stringify(metrics)])
	quit(1 if failures else 0)
