extends "res://../build/asset-review-2026-11-08/candidates.gd"
## Separate exact-position gate for packing; no GPU image budget is substituted.
func run()->void:
	output="res://../docs/evidence/asset-review-2026-11-08"
	for kind: String in ["tree","tyre_wall","fence"]:
		var model: NativeTrackVisual=await prop("winter",kind)
		var parts: Array=[];Metrics.collect(model,parts)
		for part: Dictionary in parts:verify_attributes(part.mesh,indexed(part.mesh))
		model.free()
	var doc: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/to_the_trees.json"));doc.theme="pine"
	var track: NativeTrack=TrackCompiler.compile(doc)
	var visual:=NativeTrackVisual.new();visual.cache_race_world=false;visual.cache_road_meshes=false;root.add_child(visual)
	await visual.build(track,BridgePresentation.new(track))
	var parts: Array=[];Metrics.collect(visual,parts)
	var rows: Array=[]
	for part: Dictionary in parts:
		if not part.node is MeshInstance3D:continue
		var material: Material=part.node.material_override
		var kind: String=""
		if material is ShaderMaterial:
			if material.shader.resource_path=="res://track/kerb.gdshader":kind="kerb"
			elif "road_color" in material.shader.code:kind="road"
		if kind.is_empty():continue
		var candidate: Mesh=indexed(part.mesh)
		verify_attributes(part.mesh,candidate)
		rows.append({"kind":kind,"path":str(visual.get_path_to(part.node)),"original":Metrics.mesh_info(part.mesh),"candidate":Metrics.mesh_info(candidate)})
	check(not rows.is_empty(),"actual kerbs and roads inspected")
	visual.free();await process_frame
	write("exact-positions.json",{"checks":checks,"failures":failures,"attribute_checks":observations,"road_and_kerb_rows":rows,"scope":"Every ordered position and triangle corner is checked. Tiny normal-codec round trips remain recorded separately."})
	print("EXACT_POSITION_REVIEW ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
