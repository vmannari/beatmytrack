extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var base: Script=load("res://vehicle/modular_car_base.gd")
	var validation: Script=load("res://vehicle/prepared_asset_sources.gd")
	var rows: Array=[]
	for id: String in ["compact","kart","forklift","electric","hovercraft"]:
		var car: Node=load("res://vehicle/car_visual.gd").new()
		car.vehicle_id=id
		var scene: PackedScene=load(base.path_for(car))
		var holder: Node=scene.instantiate()
		var data: Dictionary=holder.get_meta("modular_car_base",{})
		var saved: Dictionary=validation.runtime_projection(data.get("sources",{}))
		var current: Dictionary=validation.runtime_hashes(id)
		var changed: Array=[]
		for path: String in current:
			if saved.get(path)!=current[path]: changed.append(path)
		for path: String in saved:
			if not current.has(path): changed.append(path)
		var row: Dictionary={"id":id,"key_matches":data.key==base.key_for(car),"complete_sources_match":data.sources==base.source_hashes(id),"saved_revision":data.key[2],"current_revision":base.key_for(car)[2],"source_differences":changed}
		rows.append(row);print("CAR_LIVE_AUDIT ",JSON.stringify(row))
		holder.free();car.free()
	FileAccess.open("res://../docs/evidence/car-loading-improvements-2026-11-13/live-audit.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	quit()
