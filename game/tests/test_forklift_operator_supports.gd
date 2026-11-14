extends SceneTree
## Floor-to-fitting connections, in model coordinates at both detail levels.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func bounds(car: CarVisual, part: MeshInstance3D) -> AABB:
	return car.body.global_transform.affine_inverse()*part.global_transform*part.mesh.get_aabb()

func run() -> void:
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "forklift"
		car.simple_model = simple
		car.batch_parts = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		if "--baseline" in OS.get_cmdline_user_args():
			car.graphics.restore_originals()
			for child: Node in car.body.get_children(): child.free()
			load("res://../docs/evidence/forklift-operator-supports-2026-11-13/before/forklift_model.gd").build(car)
		var floor_part: MeshInstance3D = car.find_child("OperatorFloor",true,false)
		var floor_box: AABB = bounds(car,floor_part)
		for pair: Array in [["SeatPlinth","SeatSuspension"],["DashboardPedestal","InstrumentConsole"],["HydraulicControlConsole","LeverGaiter"]]:
			var support: MeshInstance3D = car.find_child(pair[0],true,false)
			var fittings: Array[Node] = car.find_children(str(pair[1])+"*","MeshInstance3D",true,false)
			checks += 1
			if fittings.is_empty():
				failures += 1
				print("FAIL missing fitting ",pair[1])
			checks += 1
			if support == null:
				failures += 1
				print("FAIL missing support ",pair[0])
				continue
			var support_box: AABB = bounds(car,support)
			if not support_box.intersects(floor_box):
				failures += 1
				print("FAIL floor connection ",pair[0])
			for fitting: MeshInstance3D in fittings:
				checks += 1
				if not support_box.intersects(bounds(car,fitting)):
					failures += 1
					print("FAIL fitting connection ",fitting.name)
		var control: MeshInstance3D = car.find_child("HydraulicControlConsole",true,false)
		if control != null:
			for index: int in range(3):
				checks += 1
				if not bounds(car,control).has_point(Vector3(0.36+index*0.105,1.08,-0.10)):
					failures += 1
					print("FAIL control mounting ",index)
		car.free()
	print("FORKLIFT_OPERATOR_SUPPORTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
