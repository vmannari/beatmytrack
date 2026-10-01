extends SceneTree
## Read-only local selection latency, with compiler-stage attribution.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var library := TrackLibrary.new()
	var browser := TrackBrowser.new()
	browser.library = library
	browser.records = LocalRecords.new("user://unused-menu-profile-records.json")
	browser.selected_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	browser.state = {"section":"all","page":0}
	browser.size = Vector2(1280,620)
	root.add_child(browser)
	while browser.loading: await process_frame
	for title: String in ["Speedy","Knot","Speedy"]:
		for entry: Dictionary in browser.catalog.entries:
			if entry.name != title: continue
			var start: int = Time.get_ticks_usec()
			browser._select(entry)
			var call_ms: float = (Time.get_ticks_usec()-start)/1000.0
			var hero_title: Label = browser.hero.find_child("HeroTrackTitle",true,false)
			if hero_title == null or hero_title.text != title.to_upper():
				push_error("Hero did not update synchronously for "+title)
				quit(1)
				return
			await RenderingServer.frame_post_draw
			var hero_frame_ms: float = (Time.get_ticks_usec()-start)/1000.0
			var last: int = Time.get_ticks_usec()
			var worst_ms: float = 0.0
			while browser.selecting:
				await process_frame
				var now: int = Time.get_ticks_usec()
				worst_ms = maxf(worst_ms,(now-last)/1000.0)
				last = now
			print("MENU_SELECTION ",title," call_ms=",call_ms," hero_frame_ms=",hero_frame_ms," ready_ms=",(Time.get_ticks_usec()-start)/1000.0," worst_frame_ms=",worst_ms)
			break
	# Instrument a session-local script copy; no timers in the production compiler.
	var source: String = FileAccess.get_file_as_string("res://editor/track_compiler.gd").replace("\r\n","\n").replace("class_name TrackCompiler\n","")
	source = source.replace("\tif not TrackDocument.validate(document)","\tvar profile_started: int = Time.get_ticks_usec()\n\tif not TrackDocument.validate(document)")
	for marker: String in ["var road_samples:","var raster_key:","var scenery_cells:","var scenery:","var surfaces:","var forward:"]:
		source = source.replace("\t"+marker,"\tprint(\"COMPILE_STAGE "+marker+" \", (Time.get_ticks_usec()-profile_started)/1000.0)\n\t"+marker)
	source = source.replace("\treturn NativeTrack.from_data", "\tprint(\"COMPILE_STAGE native_begin \",(Time.get_ticks_usec()-profile_started)/1000.0)\n\treturn NativeTrack.from_data")
	var instrumented := GDScript.new()
	instrumented.source_code = source
	if instrumented.reload() != OK: quit(1); return
	for id: String in ["track_3e26605a8a90165e","track_1e3936d025fe7c82"]:
		var start: int = Time.get_ticks_usec()
		var document: Dictionary = library.load_document(id)
		if document.is_empty():
			push_error("Menu profile requires saved Speedy and Knot tracks: missing "+id)
			quit(1)
			return
		print("COMPILE_DOCUMENT ",id," load_ms=",(Time.get_ticks_usec()-start)/1000.0)
		var track: NativeTrack = instrumented.call("compile",document)
		if track == null: push_error("Profile track cannot compile: "+id); quit(1); return
		print("COMPILE_TOTAL ms=",(Time.get_ticks_usec()-start)/1000.0," hash=",track.content_hash)
	browser.queue_free()
	await process_frame
	quit()
