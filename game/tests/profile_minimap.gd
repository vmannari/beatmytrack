extends SceneTree
## Desktop draw-callback comparison. Baseline is a local pre-change script.
func _initialize() -> void: call_deferred("run")

func instrument(source: String) -> GDScript:
	var text: String = source.replace("class_name HUDRoadMap\n","")
	var start: int = text.find("\nfunc _draw() -> void:")
	var body: int = text.find("\n",start+1)+1
	var end: int = text.find("\nfunc configure",body)
	text = text.substr(0,end)+"\n\tdraw_usec += Time.get_ticks_usec()-begin_usec\n\tdraw_calls += 1\n"+text.substr(end)
	text = text.substr(0,body)+"\tvar begin_usec: int = Time.get_ticks_usec()\n"+text.substr(body)
	text += "\nvar draw_usec: int = 0\nvar draw_calls: int = 0\n"
	var script := GDScript.new()
	script.source_code = text
	var error: Error = script.reload()
	assert(error == OK)
	return script

func run() -> void:
	var document_path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--document="): document_path = argument.trim_prefix("--document=")
	var track: NativeTrack = TrackCompiler.compile(JSON.parse_string(FileAccess.get_file_as_string(document_path)))
	if track == null: quit(1); return
	root.size = Vector2i(1280,720)
	for path: String in ["res://../build/minimap-before.gd","res://ui/hud_road_map.gd"]:
		var script: GDScript = instrument(FileAccess.get_file_as_string(path))
		var map: Control = script.new()
		root.add_child(map)
		map.size = Vector2(104,84)
		map.call("configure",track,true)
		for i: int in range(5): await RenderingServer.frame_post_draw
		map.set("draw_usec",0)
		map.set("draw_calls",0)
		for i: int in range(180):
			map.set("player",Vector2(i*0.1,0))
			map.queue_redraw()
			await RenderingServer.frame_post_draw
		print("MINIMAP_PROFILE ",path," callbacks=",map.get("draw_calls")," total_us=",map.get("draw_usec")," mean_us=",float(map.get("draw_usec"))/maxi(1,int(map.get("draw_calls"))))
		if path.ends_with("hud_road_map.gd"):
			print("STATIC_ROAD_DRAWS ",map.get("road_layer").get("draw_count")," rebuilds=",map.get("rebuild_count"))
		map.queue_free()
		await process_frame
	quit()
