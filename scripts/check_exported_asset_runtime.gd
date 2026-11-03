extends SceneTree
## External harness: run against --main-pack from an otherwise empty directory.
const _NativeTrack = preload("res://track/native_track.gd")
const Prepared = preload("res://vehicle/prepared_car_cache.gd")
const Base = preload("res://vehicle/modular_car_base.gd")
const Kits = preload("res://vehicle/modular_car_kits.gd")
const Garage = preload("res://ui/garage_car_cache.gd")

var checks: int = 0
var failures: Array[String] = []
var metrics: Dictionary = {}

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL: ", label)

func car_for(id: String, simple: bool, garage: bool = false) -> CarVisual:
	var car := CarVisual.new()
	car.vehicle_id = id
	car.simple_model = simple
	car.editable_kits = VehicleCustomisation.supported(id)
	car.garage_template = garage
	car.livery = VehicleLivery.defaults(id)
	root.add_child(car)
	return car

func inspect(car: CarVisual) -> Array:
	var triangles: int = 0
	var meshes: int = 0
	for node: Node in car.find_children("*", "MeshInstance3D", true, false):
		if node.mesh == null: continue
		meshes += 1
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			triangles += (indices.size() if indices != null and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	return [meshes, triangles, car.front_wheels.size(), car.rear_wheels.size()]

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var inputs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	check(not FileAccess.file_exists("res://vehicle/car_visual.gd"), "compiled package has no physical source fallback")
	var loaded: int = 0
	for path: String in inputs.resources:
		check(ResourceLoader.exists(path), "resource exists " + path)
		var resource: Resource = load(path)
		check(resource != null, "resource loads " + path)
		loaded += 1
		if loaded % 100 == 0: await process_frame
	metrics.loaded_resources = loaded
	for id: String in VehicleCatalog.IDS:
		for simple: bool in [false, true]:
			var car: CarVisual = car_for(id, simple)
			check(car.model_ready and car.body != null, "stock model ready " + id + str(simple))
			metrics[id + "/stock/" + str(simple)] = inspect(car)
			check(int(metrics[id + "/stock/" + str(simple)][1]) > 0, "stock triangles " + id + str(simple))
			if VehicleCustomisation.supported(id):
				for category: String in VehicleCustomisation.CATEGORIES:
					for option: Array in VehicleCustomisation.options(category, id):
						var wanted: Dictionary = VehicleCustomisation.defaults()
						wanted[category] = str(option[0])
						car.change_kit_parts(wanted)
						check(car.body != null and not car.kit_frames.get(category, []).is_empty(), "kit frames " + id + "/" + category + "/" + str(option[0]) + str(simple))
						metrics[id + "/" + category + "/" + str(option[0]) + "/" + str(simple)] = inspect(car)
						await process_frame
			car.free()
			await process_frame
		var garage: CarVisual = car_for(id, false, true)
		check(garage.model_ready and garage.body != null, "Garage model ready " + id)
		metrics[id + "/garage"] = inspect(garage)
		garage.free()
		var sim := VehicleSimulation.new(VehicleCatalog.config(id))
		for tick: int in range(600): sim.step(DriveFrame.sample(sin(tick * 0.02) * 0.2, 0.8, 0.0))
		check(sim.state.position.is_finite() and sim.state.velocity.is_finite() and sim.state.position.length() > 0.1, "compiled race simulation advances " + id)
		metrics[id + "/simulation"] = sim.state.snapshot()
	# Force the ordinary constructors as well as the prepared assembly route.
	Prepared.enabled = false
	for id: String in VehicleCatalog.IDS:
		for simple: bool in [false, true]:
			var car: CarVisual = car_for(id, simple)
			check(car.model_ready and car.body != null, "procedural fallback ready " + id + str(simple))
			metrics[id + "/fallback/" + str(simple)] = inspect(car)
			car.free()
			await process_frame
	Prepared.enabled = true
	for path: String in inputs.posters:
		var texture: Texture2D = load(path)
		check(texture != null and texture.get_width() > 0, "current challenge poster loads " + path)
	for path: String in inputs.legal:
		check(not FileAccess.get_file_as_string(path).is_empty(), "legal notice readable " + path)
	metrics.prepared_base_hits = Base.hits
	metrics.prepared_kit_hits = Kits.hits
	metrics.prepared_garage_hits = Garage.hits
	var result: Dictionary = {"checks": checks, "failures": failures, "metrics": metrics}
	var output := FileAccess.open(args[1], FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	output.close()
	print("EXPORTED_ASSET_RUNTIME: %d checks, %d failures, %d resources, %d kit hits" % [checks, failures.size(), loaded, Kits.hits])
	quit(1 if not failures.is_empty() else 0)
