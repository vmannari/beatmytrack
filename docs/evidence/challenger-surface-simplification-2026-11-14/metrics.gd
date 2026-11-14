extends SceneTree
func payload(mesh: Mesh) -> int:
	var bytes: int = 0
	for surface: Dictionary in mesh.get("_surfaces"):
		for field: String in ["vertex_data","attribute_data","skin_data","index_data","blend_shapes"]:
			bytes += surface.get(field,PackedByteArray()).size()
	return bytes
func _initialize() -> void:
	var rows: Array = []
	var prefix: String = "res://../docs/evidence/challenger-surface-simplification-2026-11-14/"
	for tier: String in ["simple","full"]:
		for stage: String in ["before","after"]:
			var base: String = prefix+"before/game/assets/vehicles/challenger_hellcat_v1/" if stage == "before" else SuperRallyModel.ROOT
			var path: String = base+tier+"_body_paint.res"
			var mesh: Mesh = load(path)
			rows.append({"tier":tier,"stage":stage,"triangles":mesh.get_faces().size()/3,"raw_bytes":payload(mesh),"disk_bytes":FileAccess.get_file_as_bytes(path).size(),"surfaces":mesh.get_surface_count()})
	var file := FileAccess.open(prefix+"metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"));file.close()
	print("SHELL_METRICS: ",JSON.stringify(rows))
	quit()
