extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var doc: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	doc.theme="winter"
	var track: NativeTrack=TrackCompiler.compile(doc)
	var visual:=NativeTrackVisual.new()
	visual.cache_race_world=true
	root.add_child(visual)
	await visual.build(track,BridgePresentation.new(track),true)
	var rows: Array=[]
	for child: Node in visual.get_children():
		rows.append({"name":str(child.name),"class":child.get_class(),"bytes":visual.PREPARED_WORLDS._resource_bytes(child,{})})
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"world_bytes":visual.PREPARED_WORLDS.bytes_used(),"cells":track.cells.size()*16},"  "))
	visual.free()
	visual.PREPARED_WORLDS.trim_cache()
	quit()
