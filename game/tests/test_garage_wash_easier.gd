extends SceneTree
## Faint film across upper panels, broad missed doors, and equal-time real strokes.
var checks: int = 0
var failures: int = 0
var checker: GDScript = preload("res://ui/garage_cleanliness.gd")
var brush: GDScript = preload("res://vehicle/vehicle_weathering.gd")
const BEFORE: String = "res://../docs/evidence/garage-wash-easier-2026-10-19/before/"

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",message)

func saved_script(path: String, class_label: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(path).replace("class_name "+class_label,"")
	assert(script.reload() == OK)
	return script

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	if "--before" in OS.get_cmdline_user_args():
		checker = saved_script(BEFORE+"game/ui/garage_cleanliness.gd","GarageCleanliness")
		brush = saved_script(BEFORE+"game/vehicle/vehicle_weathering.gd","VehicleWeathering")
	var old_brush: GDScript = saved_script(BEFORE+"game/vehicle/vehicle_weathering.gd","VehicleWeathering")
	for id: String in VehicleCatalog.IDS:
		var view := CarShowroom.new()
		view.vehicle_id = id
		root.add_child(view)
		await process_frame
		var inspector: RefCounted = checker.new()
		var effect: VehicleWeathering = view.weathering
		var wear: Dictionary = effect.snapshot()
		wear.dirt = 1.0
		wear.slow_dirt = 1.0
		var mask := PackedByteArray()
		mask.resize(VehicleCondition.CELLS)
		mask.fill(255)
		# Clean lower panels, faint slow film left on the upper body/roof.
		for y: int in range(8,16):
			for z: int in range(16):
				for x: int in range(16): mask[y*256+z*16+x] = 160
		wear.wash = Marshalls.raw_to_base64(mask)
		wear.slow_wash = wear.wash
		effect.restore(wear)
		check(inspector.is_clean(view),id+" washed body with light upper film is ready")
		check(inspector.description(view) == "Clean enough for company",id+" tolerates film without claiming spotless")
		var retained: Dictionary = effect.snapshot()
		inspector.description(view)
		check(effect.snapshot() == retained,id+" readiness leaves the actual saved dirt and masks exact")
		mask.fill(255)
		for y: int in range(16):
			for z: int in range(16):
				for x: int in range(8): mask[y*256+z*16+x] = 0
		wear.wash = Marshalls.raw_to_base64(mask)
		wear.slow_wash = wear.wash
		effect.restore(wear)
		check(not inspector.is_clean(view),id+" missed dirty half still requires washing")
		mask.fill(0)
		wear.wash = Marshalls.raw_to_base64(mask)
		wear.slow_wash = wear.wash
		effect.restore(wear)
		check(not inspector.is_clean(view),id+" unwashed car remains dirty")
		var previous: RefCounted = old_brush.new()
		previous.configure(view.car,"pine",VehicleCatalog.config(id))
		var current: RefCounted = brush.new()
		current.configure(view.car,"pine",VehicleCatalog.config(id))
		var contact: Vector3 = current.bounds.position + current.bounds.size * Vector3(1.0,0.25,0.6)
		previous.wash(contact,0.8)
		current.wash(contact,0.8)
		var old_clean: float = inspector._washed(contact,previous.bounds,previous.wash_image.get_data())
		var new_clean: float = inspector._washed(contact,current.bounds,current.wash_image.get_data())
		check(new_clean > old_clean * 1.25,id+" same short stroke removes at least 25% more at contact")
		var old_work: int = 0
		var new_work: int = 0
		for value: int in previous.wash_image.get_data(): old_work += value
		for value: int in current.wash_image.get_data(): new_work += value
		check(new_work > old_work * 1.5,id+" wider stroke reaches neighbouring wash cells")
		var opposite: Vector3 = contact
		opposite.x = current.bounds.position.x
		check(inspector._washed(opposite,current.bounds,current.wash_image.get_data()) == 0.0,id+" brush still leaves opposite side untouched")
		previous.reset()
		current.reset()
		view.queue_free()
		await process_frame
	print("EASIER_WASH: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
