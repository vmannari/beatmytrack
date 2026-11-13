extends SceneTree
func _initialize() -> void:
	var rows: Array = []
	for id: String in VehicleCatalog.IDS:
		var car := CarVisual.new(); car.vehicle_id = id
		var base = preload("res://vehicle/modular_car_base.gd")
		var sources: Dictionary = base.source_hashes(id)
		var packed: PackedScene = load(base.path_for(car))
		var holder: Node = packed.instantiate()
		var previous: Dictionary = holder.get_meta("modular_car_base").sources
		var differences: Array = []
		for key: String in sources:
			if sources[key] != previous.get(key): differences.append(key)
		for key: String in previous:
			if not sources.has(key): differences.append("removed:"+key)
		var row: Dictionary = {"vehicle":id,"source_count":sources.size(),"previous_count":previous.size(),"key_current":holder.get_meta("modular_car_base").key==base.key_for(car),"differences":differences}
		rows.append(row); print("SCENERY_SOURCE_DIFF ",JSON.stringify(row))
		holder.free(); car.free()
	var folder: String = "res://../docs/evidence/track-asset-optimization-2026-11-07/"
	FileAccess.open(folder+"prepared-source-probe.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t",true)+"\n")
	quit()
