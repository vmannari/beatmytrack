extends "res://../build/asset-optimisation-2026-11-08/test_packing.gd"
const Metrics=preload("res://../build/asset-review-2026-11-08/metrics.gd")
var rows: Array=[]
func make(theme: String,packed: bool)->NativeTrackVisual:
	Packing.enabled=packed;WinterScenery.meshes.clear()
	var document: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/to_the_trees.json"));document.theme=theme
	var track: NativeTrack=TrackCompiler.compile(document)
	var before: Array=[track.cells.duplicate(),track.route.duplicate(),track.kerbs.triangles.duplicate(true)]
	var visual:=NativeTrackVisual.new();visual.cache_road_meshes=false;visual.cache_race_world=false;root.add_child(visual)
	await visual.build(track,BridgePresentation.new(track))
	check(visual.world_built and before==[track.cells,track.route,track.kerbs.triangles],"world and canonical data exact "+theme)
	return visual
func run()->void:
	for theme: String in ["pine","night_city","winter","storm","desert"]:
		var a: NativeTrackVisual=await make(theme,false)
		var old: Array=[];Metrics.collect(a,old)
		var signatures: Array=[];var old_bytes: int=0
		for part: Dictionary in old:
			if part.mesh is ArrayMesh:signatures.append(expanded(part.mesh))
			else:signatures.append(part.mesh.surface_get_arrays(0))
			old_bytes+=Metrics.mesh_info(part.mesh).raw_gpu_buffer_bytes
		a.free();await process_frame
		var b: NativeTrackVisual=await make(theme,true)
		var now: Array=[];Metrics.collect(b,now)
		check(old.size()==now.size(),"same draw nodes "+theme)
		var new_bytes: int=0
		for index: int in range(now.size()):
			var mesh: Mesh=now[index].mesh
			check(signatures[index]==(expanded(mesh) if mesh is ArrayMesh else mesh.surface_get_arrays(0)),"all expanded GPU bytes exact "+theme+"/"+str(index))
			new_bytes+=Metrics.mesh_info(mesh).raw_gpu_buffer_bytes
		check(new_bytes<=old_bytes,"no buffer growth "+theme)
		rows.append({"theme":theme,"before_bytes":old_bytes,"after_bytes":new_bytes})
		print("PACKED_WORLD ",theme," ",old_bytes," -> ",new_bytes)
		b.free();await process_frame
	Packing.enabled=true
	var folder: String="res://../docs/evidence/asset-optimisation-2026-11-08"
	FileAccess.open(folder.path_join("packing-structural.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"\t"))
	print("PACKING_INTEGRATION ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
