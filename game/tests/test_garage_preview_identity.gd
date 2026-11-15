extends SceneTree
## Exercise per-car and legacy revisions without modifying generated build identity.
const Real = preload("res://ui/garage_preview_cache.gd")
const Build = preload("res://core/build_identity.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ",label)

func run() -> void:
	var source: String = FileAccess.get_file_as_string("res://ui/garage_preview_cache.gd")
	var fake := GDScript.new()
	fake.source_code = source.replace("res://core/build_identity.gd","res://tests/fixtures/garage_picture_build_identity.gd")
	check(fake.reload() == OK,"load the unchanged preview source with synthetic build identity")
	var cache: Node = fake.new()
	var car := CarShowroom.new()
	car.simple_model = false
	car.vehicle_id = "electric"
	car.livery = VehicleLivery.for_car({},car.vehicle_id)
	car.customisation = VehicleCustomisation.defaults()
	var input_hashes: Array[String]=[]
	for path: String in ["res://vehicle/electric_reference_mesh.gd","res://vehicle/electric_kits.gd","res://vehicle/electric_body_kits.gd"]:
		input_hashes.append(FileAccess.get_sha256(path))
	var electric_revision: String = "electric-fixture:volt-source-1:"+":".join(input_hashes)
	var expected: String = JSON.stringify([cache.VERSION,electric_revision,car.vehicle_id,car.livery,{},car.customisation]).sha256_text()
	check(cache.identity(car) == expected,"known car uses its own visual revision")
	var previous: String = JSON.stringify([cache.VERSION,"electric-fixture",car.vehicle_id,car.livery,{},car.customisation]).sha256_text()
	check(cache.identity(car) != previous,"new Volt mesh set cannot reuse an older saved picture")
	car.vehicle_id = "pickup"
	car.livery = VehicleLivery.for_car({},car.vehicle_id)
	expected = JSON.stringify([cache.VERSION,"shared-fixture",car.vehicle_id,car.livery,{},car.customisation]).sha256_text()
	check(cache.identity(car) == expected,"missing car revision falls back to the conservative shared revision")
	var real: Node = Real.new()
	var build_script: Script = Build
	var revisions: Dictionary = build_script.get_script_constant_map().get("GARAGE_PREVIEW_VEHICLE_SHA256",{})
	var revision: String = str(revisions.get(car.vehicle_id,Build.GARAGE_PREVIEW_SHA256))
	expected = JSON.stringify([real.VERSION,revision,car.vehicle_id,car.livery,{},car.customisation]).sha256_text()
	check(real.identity(car) == expected,"actual generated or legacy build identity is supported")
	car.simple_model=true
	expected = JSON.stringify([real.VERSION,revision,car.vehicle_id,car.livery,{},car.customisation,"reduced-garage-1"]).sha256_text()
	check(real.identity(car)==expected,"production reduced identity stays distinct from the reference model")
	car.free(); cache.free(); real.free()
	print("GARAGE_PREVIEW_IDENTITY: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
