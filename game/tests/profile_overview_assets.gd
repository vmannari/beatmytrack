extends SceneTree
## Read-only cache qualification: explain fallback without bypassing its guards.
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var base: GDScript = load("res://vehicle/modular_car_base.gd")
	var validation: GDScript = load("res://vehicle/prepared_asset_sources.gd")
	var rows: Array = []
	for id: String in VehicleCatalog.IDS:
		var car := CarVisual.new()
		car.vehicle_id = id; car.simple_model = true
		car.customisation = VehicleCustomisation.defaults()
		var path: String = base.path_for(car)
		var scene: PackedScene = load(path)
		var holder: Node = scene.instantiate()
		var metadata: Dictionary = holder.get_meta("modular_car_base",{})
		var saved: Dictionary = validation.runtime_projection(metadata.get("sources",{}))
		var current: Dictionary = validation.runtime_hashes(id)
		var differences: Array = []
		for source: String in current:
			if saved.get(source) != current[source]: differences.append(source)
		for source: String in saved:
			if not current.has(source): differences.append(source)
		var row: Dictionary = {"car":id,"path":path,"key_matches":metadata.get("key",[])==base.key_for(car),"source_hashes_match":saved==current,"different_sources":differences}
		rows.append(row)
		print("PROFILE_ASSET ",JSON.stringify(row))
		holder.free(); car.free()
	var failures: int = rows.filter(func(row: Dictionary) -> bool: return not row.key_matches or not row.source_hashes_match).size()
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"failures":failures,"engine":Engine.get_version_info().string},"  "))
	quit(1 if failures else 0)
