extends SceneTree
## Read-only compilation and pre-countdown startup attribution; no player writes.
func _initialize() -> void: call_deferred("run")

func instrument(path: String, type_name: String, markers: Array[String]) -> GDScript:
	var source: String = FileAccess.get_file_as_string(path).replace("\r\n","\n").replace("class_name "+type_name+"\n","")
	for index: int in range(markers.size()):
		var marker: String = markers[index]
		assert(source.contains(marker), "Profiling marker changed: "+marker)
		var timer: String = "\tvar profile_start: int = Time.get_ticks_usec()\n" if index == 0 else "\tprint(\"LOAD_STAGE "+type_name+" "+str(index)+" ms=\",(Time.get_ticks_usec()-profile_start)/1000.0)\n"
		source = source.replace(marker,timer+marker)
	var script := GDScript.new()
	script.source_code = source
	assert(script.reload() == OK)
	return script

func run() -> void:
	NativeTrackVisual._road_mesh_cache.clear()
	if "--screen=cold" in OS.get_cmdline_user_args(): NativeTrackVisual.ROAD_DISK_CACHE.directory = ""
	print("LOAD_DISK_CACHE enabled=",not NativeTrackVisual.ROAD_DISK_CACHE.directory.is_empty())
	var native_script: GDScript = instrument("res://track/native_track.gd","NativeTrack",[
		"\tvar track := NativeTrack.new()", "\ttrack._build_route_distance()", "\ttrack._build_validation_route()",
		"\ttrack.kerbs.build(track)", "\ttrack.snow_banks.build(track)", "\treturn track"])
	var visual_script: GDScript = instrument("res://track/native_track_visual.gd","NativeTrackVisual",[
		"\t_menu_slices = menu_slices", "\tawait _build_terrain(track)", "\tawait _build_creator_roads(track)",
		"\tif track.metadata.get(\"creator_document\",{}).get(\"pieces\",[]).is_empty(): await _build_kerbs(track)",
		"\tawait _build_barriers(track)", "\tif editor_preview:\n", "\tbridge.build(self)", "\t_build_finish(track)", "\t_build_snow_banks(track)"])
	var original: String = visual_script.source_code
	var road_begin: int = original.find("func _build_creator_roads(")
	var road_end: int = original.find("\nfunc ",road_begin)
	var road_source: String = original.substr(road_begin,road_end-road_begin)
	var detail: String = road_source.replace("\tvar mask: Image = _creator_overlay_mask", "\tvar road_start: int = Time.get_ticks_usec()\n\tvar mask: Image = _creator_overlay_mask")
	for marker: String in ["\tvar winter_bank :=", "\tif winter_sections > 0:", "\tawait shoulder_mesh.emit", "\tset_meta(\"desert_clod_count\"", "\tif counts[0]:"]:
		assert(detail.contains(marker))
		detail = detail.replace(marker,"\tprint(\"LOAD_ROAD "+str(marker).replace("\t","").replace("\"", "'")+" ms=\",(Time.get_ticks_usec()-road_start)/1000.0)\n"+marker)
	visual_script.source_code = original.replace(road_source,detail)
	assert(visual_script.reload() == OK)
	var ids: Array[String] = ["track_3e26605a8a90165e","track_1e3936d025fe7c82"]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--track="): ids = [argument.trim_prefix("--track=").trim_prefix("creator_")]
	for id: String in ids:
		var document: Dictionary = TrackLibrary.new().load_document(id)
		if document.is_empty(): push_error("Profile track missing: "+id); quit(1); return
		for pass_index: int in range(2):
			print("LOAD_TRACK name=",document.name," pass=",pass_index)
			var begin: int = Time.get_ticks_usec()
			var track: NativeTrack = TrackCompiler.compile(document)
			if track == null: push_error("Compilation failed"); quit(1); return
			print("LOAD_COMPILE ms=",(Time.get_ticks_usec()-begin)/1000.0," grid=",track.grid_width,"x",track.grid_height," route=",track.route.size())
			var scene: PackedScene = load("res://core/game.tscn")
			begin = Time.get_ticks_usec()
			var race: Node = scene.instantiate()
			race.set("initial_track",track)
			race.set("production_mode",true)
			root.add_child(race)
			race.set("paused",true)
			print("LOAD_RACE_READY ms=",(Time.get_ticks_usec()-begin)/1000.0)
			await RenderingServer.frame_post_draw
			print("LOAD_FIRST_DRAW ms=",(Time.get_ticks_usec()-begin)/1000.0)
			root.remove_child(race)
			race.queue_free()
			await process_frame
			if "--screen=ready" in OS.get_cmdline_user_args(): continue
			var rebuilt: NativeTrack = native_script.call("from_data",track.metadata,track.content_hash)
			assert(rebuilt.cells == track.cells and rebuilt.route == track.route)
			var visual: Node3D = visual_script.new()
			# Attribute cold geometry work even after the real race warms its cache.
			visual.set("cache_road_meshes",false)
			root.add_child(visual)
			begin = Time.get_ticks_usec()
			visual.call("build",track,BridgePresentation.new(track))
			print("LOAD_VISUAL ms=",(Time.get_ticks_usec()-begin)/1000.0)
			visual.queue_free()
			await process_frame
	quit()
