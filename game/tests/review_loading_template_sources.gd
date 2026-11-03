extends SceneTree
const BASE = preload("res://vehicle/modular_car_base.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var rows: Array = []
	for id: String in VehicleCatalog.IDS:
		var current: Dictionary = BASE.source_hashes(id)
		var before: Dictionary = current.duplicate()
		for file: String in ["effect_render_preparation.gd","effect_preparation_pool.gd"]:
			before["vehicle/"+file] = FileAccess.get_sha256("res://../docs/evidence/race-loading-implementation-2026-11-02/before/game/vehicle/"+file)
		for simple: bool in [false,true]:
			for editable: bool in [false,true]:
				var car := CarVisual.new(); car.vehicle_id = id; car.simple_model = simple; car.editable_kits = editable
				var path: String = BASE.path_for(car)
				if ResourceLoader.exists(path):
					var scene: PackedScene = load(path)
					var holder: Node = scene.instantiate()
					var data: Dictionary = holder.get_meta("modular_car_base",{})
					var changed: Array = []
					for source: String in current:
						if data.get("sources",{}).get(source,"") != current[source]: changed.append(source)
					rows.append({"path":path,"key_matches":data.get("key",[]) == BASE.key_for(car),"sources_before_match":data.get("sources",{}) == before,"sources_after_match":data.get("sources",{}) == current,"differences":changed})
					holder.free()
				car.free()
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify({"templates":rows},"  "))
	print("LOADING_TEMPLATE_SOURCES ",JSON.stringify(rows))
	quit()
