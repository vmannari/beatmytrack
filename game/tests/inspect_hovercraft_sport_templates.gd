extends SceneTree
## Read-only provenance of template regeneration in a shared workspace.
func _initialize() -> void: run.call_deferred()
func geometry(holder: Node3D) -> String:
	var rows: Array = []
	for node: Node3D in holder.find_children("*","Node3D",true,false):
		rows.append([holder.get_path_to(node),node.transform])
		if node is MeshInstance3D:
			rows.append([node.layers,node.cast_shadow])
			for surface: int in range(node.mesh.get_surface_count()): rows.append(node.mesh.surface_get_arrays(surface))
	return var_to_bytes(rows).hex_encode().sha256_text()
func run() -> void:
	var output: String = "res://../docs/evidence/hovercraft-sport-redesign-2026-10-29/template-context.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	var rows: Array = []
	var current_sources: Dictionary = {}
	for id: String in VehicleCatalog.IDS:
		var vehicle_sources: Dictionary = preload("res://ui/garage_car_cache.gd").geometry_sources(id)
		current_sources[id] = vehicle_sources
		var path: String = "res://assets/garage/cars_v1/"+id+".scn"
		var before_path: String = "res://../docs/evidence/hovercraft-sport-redesign-2026-10-29/before/game/assets/garage/cars_v1/"+id+".scn"
		var current: Node3D = (load(path) as PackedScene).instantiate()
		var before: Node3D = (load(before_path) as PackedScene).instantiate()
		var saved_sources: Dictionary = current.get_meta("garage_rest").sources
		var before_sources: Dictionary = before.get_meta("garage_rest").sources
		var mismatches: Array = []
		var before_mismatches: Array = []
		for key: String in vehicle_sources:
			if saved_sources.get(key,"") != vehicle_sources[key]: mismatches.append(key)
			if before_sources.get(key,"") != vehicle_sources[key]: before_mismatches.append(key)
		var row: Dictionary = {"vehicle":id,"before_geometry":geometry(before),"current_geometry":geometry(current),"before_source_guard_mismatches":before_mismatches,"source_guard_mismatches":mismatches,"saved_sources":saved_sources}
		row.geometry_unchanged = row.before_geometry == row.current_geometry
		rows.append(row)
		print("HOVERCRAFT_SPORT_TEMPLATE_CONTEXT ",id," geometry_unchanged=",row.geometry_unchanged," source_mismatches=",mismatches)
		current.free(); before.free()
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"current_sources":current_sources,"cars":rows},"\t"))
	file.close()
	quit()
