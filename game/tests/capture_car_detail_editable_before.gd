extends SceneTree
## Original editable prepared bases are still untouched before the refresh.
const OUT: String="res://../docs/evidence/car-detail-reduction-2026-11-14"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var controls: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("before-controls.json")))
	var rows: Array=[]
	var failures: int=0
	for id: String in VehicleCatalog.IDS:
		var path: String="res://assets/vehicles/modular_car_bases_v1/"+id+"_simple_editable.scn"
		var holder: Node3D=load(path).instantiate()
		var data: Dictionary=holder.get_meta("modular_car_base",{})
		for file: String in ["game/vehicle/car_visual.gd","game/vehicle/racing_car_models.gd","game/vehicle/compact_rear_design.gd","game/vehicle/prepared_asset_dependencies.json"]:
			if id not in preload("res://vehicle/prepared_asset_sources.gd").vehicles_for(file): continue
			if data.get("sources",{}).get(file,"")!=controls.sources[file]:
				failures+=1;printerr("EDITABLE_BEFORE_SOURCE_MISMATCH ",id," ",file)
		root.add_child(holder)
		var triangles: int=0;var surfaces: int=0
		for part: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
			if part.mesh==null or not part.is_visible_in_tree() or part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
			triangles+=part.mesh.get_faces().size()/3;surfaces+=part.mesh.get_surface_count()
		rows.append({"vehicle":id,"triangles":triangles,"surfaces":surfaces,"scene_sha256":FileAccess.get_sha256(path),"recorded_before_sources_match":failures==0})
		print("EDITABLE_BEFORE ",id," triangles=",triangles," surfaces=",surfaces)
		holder.free()
	FileAccess.open(OUT.path_join("editable-before.json"),FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"rows":rows},"\t"))
	quit(1 if failures else 0)
