extends SceneTree
const Base = preload("res://vehicle/modular_car_base.gd")
const Kits = preload("res://vehicle/modular_car_kits.gd")
const D = preload("res://vehicle/car_detail_reduction.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("VFD_PREPARED_FAIL ", label)

func signature(car: CarVisual) -> Array:
	var codes: Array = []
	for part: MeshInstance3D in car.find_children("*", "MeshInstance3D", true, false):
		codes.append(var_to_bytes([D.mesh_key(part.mesh), D.relative_pose(car, part), part.cast_shadow]).hex_encode().sha256_text())
	codes.sort()
	return codes

func run() -> void:
	preload("res://ui/garage_car_cache.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	for simple: bool in [false, true]:
		for editable: bool in [false, true]:
			var signatures: Array = []
			for prepared: bool in [true, false]:
				Base.enabled = prepared
				Kits.enabled = prepared
				preload("res://vehicle/prepared_car_cache.gd").enabled = prepared
				var before: int = Base.hits
				var car := CarVisual.new()
				car.vehicle_id = "electric"
				car.simple_model = simple
				car.editable_kits = editable
				car.cache_rest_pose = false
				root.add_child(car)
				while not car.model_ready: await process_frame
				check(Base.hits > before if prepared else Base.hits == before, "Actual prepared/source entry point")
				signatures.append(signature(car))
				car.free()
				await process_frame
			check(signatures[0] == signatures[1], "Every prepared mesh stream and transform equals current source")
	print("VFD_PREPARED ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
