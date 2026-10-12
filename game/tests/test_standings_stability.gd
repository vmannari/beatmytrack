extends SceneTree
## Row geometry is measured within the table, independent of carousel translation.
var app: Node
var checks: int = 0
var failures: int = 0
var evidence: String = ""

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)

func snapshot() -> Dictionary:
	var drivers: Array = []
	for index: int in range(20):
		drivers.append({"id":"you" if index == 19 else "driver_"+str(index),"name":"You" if index == 19 else "Driver "+str(index+1),"rank":index+1,"points":100-index,"completed":5})
	var value: Dictionary = {"state":"active","group_id":"stability-fixture","self_id":"you","vehicle_id":"compact","week":41,"ends_at":604800,"server_now":0,"standings":drivers,"tracks":[]}
	var document: Dictionary = TrackDocument.create_default()
	for slot: int in range(5):
		var entries: Array = drivers.duplicate(true)
		for row: Dictionary in entries: row.ms = 80000+int(row.rank)*1000
		value.tracks.append({"board_id":"board_"+str(slot),"entries":entries,"entry":{"name":"Circuit "+str(slot+1),"theme":"pine","creator":"Beat my track","track_id":"track_"+str(slot),"version_id":"version_"+str(slot),"content_hash":"a".repeat(64),"points":document.points}})
	return value

func table_state(page: Control) -> Dictionary:
	var scroll: ScrollContainer = page.find_child("RivalryStandingsScroll",true,false)
	var row: Control = page.find_child("Driver_you",true,false)
	return {"offset":scroll.scroll_vertical,"position":row.get_global_position()-scroll.get_global_position(),"size":row.size,"viewport":scroll.size}

func same_table(before: Dictionary, after: Dictionary) -> bool:
	# Moving global float coordinates may subtract with subpixel rounding error.
	return before.offset == after.offset and before.position.distance_to(after.position) < 0.01 and before.size.distance_to(after.size) < 0.01 and before.viewport.distance_to(after.viewport) < 0.01

func settle() -> void:
	for _frame: int in range(5): await process_frame
	while app.menu_page_motion != null: await process_frame

func capture(id: String, dimensions: Vector2i) -> void:
	if evidence.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(id+"-%dx%d.png" % [dimensions.x,dimensions.y])) == OK,"save "+id)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	evidence = OS.get_environment("BMT_STANDINGS_STABILITY_CAPTURE_DIR")
	if not evidence.is_empty(): DirAccess.make_dir_recursive_absolute(evidence)
	var directory: String = "user://standings_stability_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory.path_join("tracks"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		app._show_screen("tracks")
		await settle()
		app.rivalry_standings_view.clear()
		app.rivalry.model.apply_snapshot(snapshot())
		app._show_screen("rivalry")
		var page: WeeklyRivalryPage = app.content.find_child("WeeklyRivalryPage",true,false)
		check(app.menu_page_motion != null and not app.menu_page_motion.is_running(),"incoming carousel waits for the table's initial layout and player reveal")
		while not page.standings_ready: await process_frame
		var incoming_motion: Tween = app.menu_page_motion
		incoming_motion.pause()
		var incoming_state: Dictionary = table_state(app.content)
		for frame: int in range(5):
			await process_frame
			incoming_motion.custom_step(0.03)
			check(same_table(incoming_state,table_state(app.content)),"incoming rows stay fixed within their table at frame "+str(frame))
		await capture("arriving",dimensions)
		incoming_motion.play()
		await settle()
		var own: Control = app.content.find_child("Driver_you",true,false)
		var scroll: ScrollContainer = app.content.find_child("RivalryStandingsScroll",true,false)
		check(scroll.get_global_rect().grow(1).encloses(own.get_global_rect()),"initial entry still reveals the twentieth-place player")
		var before: Dictionary = table_state(app.content)
		var outgoing: Control = app.menu_body
		app._open_free_race()
		check(same_table(before,table_state(outgoing)),"departing table keeps its geometry while being reparented")
		var motion: Tween = app.menu_page_motion
		motion.pause()
		for frame: int in range(6):
			await process_frame
			motion.custom_step(0.03)
			var after: Dictionary = table_state(outgoing)
			check(same_table(before,after),"departing rows retain their table-relative positions at frame %d: before=%s after=%s" % [frame,before,after])
		await capture("departing",dimensions)
		app._finish_menu_page_slide()
		await settle()
		app._show_screen("rivalry")
		await settle()
		scroll = app.content.find_child("RivalryStandingsScroll",true,false)
		scroll.scroll_vertical = 160
		await process_frame
		var manual: Dictionary = table_state(app.content)
		app.rivalry.changed.emit()
		for frame: int in range(5):
			if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
			else:
				await process_frame
				await process_frame
			check(same_table(manual,table_state(app.content)),"refresh shows the remembered rows from rendered frame "+str(frame))
		await settle()
		check(same_table(manual,table_state(app.content)),"ordinary refresh retains the user's scroll and row geometry")
		app._open_free_race()
		await settle()
		app._show_screen("rivalry")
		await settle()
		check(same_table(manual,table_state(app.content)),"returning to Rivalry retains the same standings rows")
		await capture("returned",dimensions)
		var other: Dictionary = snapshot()
		other.group_id = "another-group"
		app.rivalry.model.apply_snapshot(other)
		app._rivalry()
		await settle()
		own = app.content.find_child("Driver_you",true,false)
		scroll = app.content.find_child("RivalryStandingsScroll",true,false)
		check(scroll.get_global_rect().grow(1).encloses(own.get_global_rect()) and scroll.scroll_vertical != int(manual.offset),"a different championship gets its own initial player reveal")
	app.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("STANDINGS_STABILITY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
