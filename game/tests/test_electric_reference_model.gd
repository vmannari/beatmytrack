extends SceneTree
## Integration checks for the reference-based Electric car.
const M = preload("res://vehicle/electric_reference_mesh.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_warning("FAIL: "+label)

func run() -> void:
	preload("res://ui/garage_car_cache.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	var totals: Array[int] = []
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.batch_parts = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var total := 0
		var finite := true
		for node: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
			if node.mesh == null: finite = false; continue
			total += node.mesh.get_faces().size()/3
			for surface: int in range(node.mesh.get_surface_count()):
				var arrays: Array = node.mesh.surface_get_arrays(surface)
				for p: Vector3 in arrays[Mesh.ARRAY_VERTEX]: finite = finite and p.is_finite()
				if arrays[Mesh.ARRAY_NORMAL] != null:
					for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]: finite = finite and n.is_finite() and n.length_squared() > 0.5
		totals.append(total)
		check(finite,"finite mesh vertices and normals, simple="+str(simple))
		check(car.front_wheels.size()==2 and car.rolling_wheels.size()==4,"four rolling wheels and front steering, simple="+str(simple))
		for wheel: Node3D in car.front_wheels:
			check(wheel.get_node_or_null("BrakeAssembly") != null and wheel.get_node("WheelSpin").get_node_or_null("BrakeAssembly") == null,"brakes steer without rotating")
		var appearance: Dictionary = VehicleLivery.defaults("electric")
		appearance.colors.body = "638d86"
		car.apply_livery(appearance)
		check(car.paint_materials.body.albedo_color.is_equal_approx(Color("638d86")),"saved body colour applies")
		car.set_night_headlights(true)
		check(car.headlights != null and car.headlights.visible and car.headlights.find_child("ReferenceNightLightbar",true,false)!=null,"night light follows the new nose")
		car.rear_braking = true
		car._update_rear_lights()
		check(car.brake_material.emission_energy_multiplier > 2.0,"rear brake illumination responds")
		car.free()
	check(totals[1] < totals[0] and totals[0] < 170000 and totals[1] < 60000,"bounded simplified and detailed geometry")
	print("ELECTRIC_REFERENCE_MODEL: ",checks," checks, ",failures," failures; triangles ",totals)
	quit(1 if failures else 0)
