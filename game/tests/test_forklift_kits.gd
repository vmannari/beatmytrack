extends SceneTree

var failures: int = 0
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: "+message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://vehicle/modular_car_kits.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	check(VehicleCustomisation.label("body","forklift") == "Cabin frame","cabin category")
	for category: String in VehicleCustomisation.CATEGORIES:
		check(VehicleCustomisation.options(category,"forklift").size() == 14,"original, three retained and ten new choices "+category)
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "forklift"
		car.simple_model = simple
		car.editable_kits = true
		car.batch_parts = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var wheel: Node = car.rolling_wheels[0]
		var mast: Node = car.body.get_node("RaisedForkCarriage")
		var lamp: Node = car.body.find_children("WorkLampHousing*","MeshInstance3D",true,false)[0]
		var mirror: Node = car.body.find_children("MirrorHousing*","MeshInstance3D",true,false)[0]
		for category: String in VehicleCustomisation.CATEGORIES:
			var known: Dictionary = {}
			var stock_signature: String = signature(car.kit_frames[category])
			for choice: Array in VehicleCustomisation.options(category,"forklift"):
				var value: Dictionary = VehicleCustomisation.defaults()
				value[category] = choice[0]
				check(VehicleCustomisation.valid(value,"forklift"),"valid "+category+"/"+str(choice[0]))
				car.graphics.restore_originals()
				car.change_kit_parts(value)
				var frame: Node = car.kit_frames[category][0]
				check(frame.get_child_count() > 0,"replaceable original or visible fitting "+category+"/"+str(choice[0]))
				check(car.rolling_wheels[0] == wheel,"retains rolling wheel")
				check(car.body.get_node("RaisedForkCarriage") == mast and is_instance_valid(lamp) and is_instance_valid(mirror),"retains mast, lamps and mirrors")
				check(not VehicleCustomisation.description(category,choice[0],"forklift").is_empty(),"described option")
				var current: String = signature(car.kit_frames[category])
				check(not known.has(current),"distinct geometry "+category+"/"+str(choice[0])+" simple="+str(simple))
				known[current] = true
				if category == "body":
					check(car.body.find_children("SideGuard*","MeshInstance3D",true,false).is_empty(),"no side guard fittings")
					check(frame.find_children("GuardSideRail*","MeshInstance3D",true,false).is_empty() == (choice[0] != "stock"),"custom cabin replaces original roof")
			car.graphics.restore_originals()
			car.change_kit_parts(VehicleCustomisation.defaults())
			check(signature(car.kit_frames[category]) == stock_signature,"exact original geometry restored "+category)
		car.queue_free()
		await process_frame
	print("FORKLIFT_KITS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func signature(frames: Array) -> String:
	var parts: Array[String] = []
	for frame: Node3D in frames:
		for node: MeshInstance3D in frame.find_children("*","MeshInstance3D",true,false):
			var transform: Transform3D = frame.global_transform.affine_inverse()*node.global_transform
			for surface: int in range(node.mesh.get_surface_count()):
				parts.append(var_to_bytes([transform,node.mesh.surface_get_arrays(surface)]).hex_encode().sha256_text())
	parts.sort()
	return str(parts).sha256_text()
