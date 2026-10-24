extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var doc: Dictionary = TrackDocument.create_blank(); var piece: Dictionary = RoadPieces.create("hairpin",Vector2(-30,0),0.0,6.0); piece.radius = 16.0; doc.pieces = [piece]
	var track: NativeTrack = TrackCompiler.compile(doc)
	var visual := NativeTrackVisual.new(); visual.colors = TrackTheme.palette("pine"); await visual._build_creator_roads(track)
	var rows: Array = []
	for node: Node in visual.get_children():
		if not node is MeshInstance3D: continue
		var material: ShaderMaterial = node.material_override
		var original: ShaderMaterial = material.get_meta("surface_dynamic_material",material)
		rows.append({"shader_resource_path":material.shader.resource_path,"original_shader_resource_path":original.shader.resource_path,"asphalt_surface":original.get_shader_parameter("asphalt_surface"),"road_marking":original.get_shader_parameter("road_marking"),"vertices":node.mesh.surface_get_array_len(0)})
	print("ROAD_MATERIAL_DIAGNOSTIC ",JSON.stringify(rows))
	var file := FileAccess.open("res://../docs/evidence/track-editor-audit-2026-10-23/road-materials.json",FileAccess.WRITE); file.store_string(JSON.stringify(rows,"\t")); file.close()
	visual.free(); quit()
