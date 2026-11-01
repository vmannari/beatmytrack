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
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "forklift"
		car.simple_model = simple
		car.editable_kits = true
		car.batch_parts = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var wheel: Node = car.rolling_wheels[0]
		for category: String in VehicleCustomisation.CATEGORIES:
			for choice: Array in VehicleCustomisation.options(category,"forklift"):
				var value: Dictionary = VehicleCustomisation.defaults()
				value[category] = choice[0]
				check(VehicleCustomisation.valid(value,"forklift"),"valid "+category+"/"+str(choice[0]))
				car.graphics.restore_originals()
				car.change_kit_parts(value)
				var frame: Node = car.kit_frames[category][0]
				check((frame.get_child_count() == 0) == (choice[0] == "stock"),"visible fitting "+category+"/"+str(choice[0]))
				check(car.rolling_wheels[0] == wheel,"retains rolling wheel")
			car.graphics.restore_originals()
			car.change_kit_parts(VehicleCustomisation.defaults())
		car.queue_free()
		await process_frame
	print("FORKLIFT_KITS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
