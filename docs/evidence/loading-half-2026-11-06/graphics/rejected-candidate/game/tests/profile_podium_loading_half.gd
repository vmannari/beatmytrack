extends "res://tests/profile_loading_half.gd"
## Same actual-App workload, with image/native-world counts attached to timing.
func entry(page: String, cycle: int) -> void:
	if page != "rivalry":
		await super.entry(page,cycle)
		return
	var began: int = Time.get_ticks_usec()
	last_frame = began
	max_frame_ms = 0.0
	measuring = true
	await app._show_screen(page)
	var returned: int = Time.get_ticks_usec()
	await drawn()
	var first_draw: int = Time.get_ticks_usec()
	var deadline: int = Time.get_ticks_msec()+90000
	while not content_ready(page) and Time.get_ticks_msec()<deadline: await process_frame
	check(content_ready(page),"Rivalry content ready")
	while app.menu_page_motion != null and app.menu_page_motion.is_running(): await process_frame
	await drawn()
	var ready: int = Time.get_ticks_usec()
	# Both control and candidate cross the same four additional native draw
	# fences: the original three radiance refreshes and their final requested draw.
	for _i: int in range(4): await drawn()
	var settled: int = Time.get_ticks_usec()
	measuring = false
	rows.append({"page":page,"cycle":cycle,"dispatch_ms":(returned-began)/1000.0,"first_draw_ms":(first_draw-began)/1000.0,"ready_ms":(ready-began)/1000.0,"settled_ms":(settled-began)/1000.0,"engine_to_settled_ms":settled/1000.0,"max_frame_ms":max_frame_ms})
	var native_podiums: int = 0
	for preview: Node in app.content.find_children("RivalryPodiumCar_*","",true,false):
		if preview.car != null: native_podiums += 1
	rows[-1].native_podiums = native_podiums
	rows[-1].car_graph_loaded = ResourceLoader.has_cached("res://vehicle/car_visual.gd")
	var pictures: Script = load("res://ui/rivalry_podium_pictures.gd")
	rows[-1].picture_hits = pictures.hits
	rows[-1].picture_writes = pictures.writes
	print("PODIUM_LOADING_ROW ",JSON.stringify(rows[-1]))
	if cycle == 0 and DisplayServer.get_name() != "headless":
		check(root.get_texture().get_image().save_png(output.path_join("rivalry.png")) == OK,"capture settled Rivalry")
