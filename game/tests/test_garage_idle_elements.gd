extends SceneTree
## GIA01-GIA04: unchanged room elements, snow and idle washing draw costs.
var output: String = "res://../docs/evidence/garage-idle-audit-2026-11-01"
var baseline: bool = false
var checks: int = 0
var failures: int = 0
var report: Dictionary = {}
const Fixture = preload("res://tests/test_customisation_carousel.gd")

class CountedShowroom extends CarShowroom:
	var canvas_draws: int = 0
	func _draw() -> void:
		canvas_draws += 1
		super._draw()

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)
func frames(count: int = 12) -> void:
	for tick: int in range(count): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func sample(view: CountedShowroom,label: String) -> Dictionary:
	await frames()
	var draws: int = view.render_requests
	var canvas: int = view.canvas_draws
	var reflections: PackedInt64Array = view.reflections.draw_requests.duplicate()
	var snow: float = view.weathering.snow_amount
	var primitives: Array[float] = []
	for tick: int in range(30):
		await process_frame
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	primitives.sort()
	var row: Dictionary = {"requests":view.render_requests-draws,"canvas_draws":view.canvas_draws-canvas,"reflection_requests":[view.reflections.draw_requests[0]-reflections[0],view.reflections.draw_requests[1]-reflections[1]],"snow_before":snow,"snow_after":view.weathering.snow_amount,"primitives_median":primitives[15]}
	report[label] = row
	print("GARAGE_IDLE_SAMPLE ",label," ",JSON.stringify(row))
	return row

func section_audit() -> void:
	var page := GaragePage.new()
	page.cached_carousel = true
	page.records = LocalRecords.new("user://garage-idle-audit-"+TrackLibrary.unique_id()+".json")
	page.records.settings.music_enabled = false
	var shop := Fixture.Shop.new()
	root.add_child(shop)
	page.economy = shop
	root.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	while not page.showroom.showroom_ready: await process_frame
	var modes: Dictionary = {}
	for destination: String in ["cars","care","customise","tuning","trophies","records","news","achievements"]:
		page._show_section(destination)
		if destination == "customise": page._set_customise_tab("stickers")
		await create_timer(0.8).timeout
		while page._workbench_focus_pending or page._menu_motion != null: await process_frame
		await frames()
		var before: int = page.showroom.render_requests
		var reflection_before: PackedInt64Array = page.showroom.reflections.draw_requests.duplicate()
		await frames(20)
		modes[destination] = {"requests":page.showroom.render_requests-before,"reflections":[page.showroom.reflections.draw_requests[0]-reflection_before[0],page.showroom.reflections.draw_requests[1]-reflection_before[1]]}
		check(modes[destination].requests == 0,"actual Garage section idle: "+destination)
		if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(output.path_join("page-"+destination+".png"))
	report.sections = modes
	page.free(); shop.free()
	await frames(2)

func run() -> void:
	create_timer(180).timeout.connect(func() -> void: print("FAIL: Garage idle audit deadline"); quit(1))
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--baseline": baseline = true
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	if baseline:
		for relative: String in ["ui/car_showroom.gd","ui/garage_wash_effect.gd"]:
			var script: Script = load("res://"+relative)
			script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/garage-idle-audit-2026-11-01/before/game/"+relative)
			assert(script.reload(true) == OK)
	Engine.max_fps = 60
	root.size = Vector2i(1280,720)
	GameSoundtrack.instance().music_enabled = false
	GameSoundtrack.instance().menu_player.stop()
	var view := CountedShowroom.new()
	view.garage_mode = true
	root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	while not view.showroom_ready: await process_frame
	for destination: String in ["car","trophies","records"]:
		view.set_trophy_view(destination == "trophies")
		view.set_record_view(destination == "records")
		await create_timer(0.75).timeout
		var row: Dictionary = await sample(view,"clean_"+destination)
		check(row.requests == 0,"settled "+destination+" is idle")
	view.set_record_view(true)
	await frames()
	view.weathering.restore({"snow":0.9,"slow_snow":0.4})
	var snowy: Dictionary = await sample(view,"snow_off_camera")
	check(snowy.snow_after < snowy.snow_before,"off-camera snow continues melting")
	if not baseline: check(snowy.requests == 0,"off-camera snow does not redraw unchanged room")
	if DisplayServer.get_name() != "headless":
		view.set_process(false)
		var room_image: Image = view.showroom_viewport.get_texture().get_image()
		room_image.save_png(output.path_join("room-retained.png"))
		var retained_room: PackedByteArray = room_image.get_data()
		view._submit_render()
		await frames()
		view.showroom_viewport.get_texture().get_image().save_png(output.path_join("room-forced.png"))
		check(view.showroom_viewport.get_texture().get_image().get_data() == retained_room,"off-camera melt leaves room pixels unchanged")
		view.set_process(true)
	view.set_record_view(false)
	await create_timer(0.75).timeout
	var visible: Dictionary = await sample(view,"snow_visible")
	check(visible.requests > 0,"visible snow remains animated")
	# The real car is outside the main camera but visible below the floor.
	view.camera.fov = 10.0
	view.camera.position = Vector3(0,3,-9)
	view.camera.look_at(Vector3(0,-1.05,0))
	view.invalidate_render()
	if not baseline:
		check(not view.camera.is_position_in_frustum(Vector3(0,1,0)),"reflection-only fixture excludes direct car")
		check(view._weathering_visible(),"reflection-only car remains eligible for weather redraws")
	var mirrored: Dictionary = await sample(view,"snow_reflection_only")
	check(mirrored.requests > 0,"reflected snow keeps updating")
	view.camera.fov = 40.0
	view.reset_view()
	view.weathering.restore({"snow":0.0,"slow_snow":0.0,"dirt":0.0})
	view.invalidate_render()
	view.set_wash_mode(true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(460,330)
	view._wash_input(motion)
	var cursor: Dictionary = await sample(view,"stationary_wash_cursor")
	check(cursor.requests == 0,"stationary wash cursor does not redraw 3D")
	if not baseline: check(cursor.canvas_draws == 0,"stationary wash cursor does not redraw canvas")
	if DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_png(output.path_join("cursor-still.png"))
		var control_path: String = ProjectSettings.globalize_path("res://../docs/evidence/garage-idle-audit-2026-11-01/control/"+RenderingServer.get_current_rendering_method()+"/cursor-still.png")
		if not baseline:
			check(FileAccess.file_exists(control_path),"renderer-matched cursor control exists")
		if not baseline and FileAccess.file_exists(control_path):
			var retained: Image = root.get_texture().get_image()
			check(retained.get_data() == Image.load_from_file(control_path).get_data(),"stationary cursor pixels match original drawing")
		var before: int = view.canvas_draws
		motion.position += Vector2(80,20)
		view._wash_input(motion)
		await frames(2)
		check(view.canvas_draws > before,"moving wash cursor redraws")
		root.get_texture().get_image().save_png(output.path_join("cursor-moved.png"))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = Vector2(12,12)
	press.pressed = true
	check(view.pick_body_surface(press.position).is_empty(),"empty wash fixture misses the car")
	view._wash_input(press)
	var empty: Dictionary = await sample(view,"washing_empty_space")
	check(not view.wash_effect.visible,"empty wash has no visible feedback")
	if not baseline: check(empty.requests == 0,"holding wash over empty space submits no 3D draws")
	press.pressed = false
	view._wash_input(press)
	view.set_wash_mode(false)
	var tail: Dictionary = await sample(view,"washing_finished")
	check(tail.requests == 0 and tail.canvas_draws == 0,"finished washing has no residual drawing")
	view.hide()
	var hidden: Dictionary = await sample(view,"hidden_garage")
	check(hidden.requests == 0,"hidden Garage submits no draws")
	view.show()
	view.weathering.restore({"snow":0.6,"slow_snow":0.1})
	view.set_process(false)
	for id: String in VehicleCatalog.IDS:
		if id != view.vehicle_id:
			view.replace_car(id,VehicleLivery.defaults(id),{"snow":0.6})
			view.finish_car_transition()
		if not baseline:
			for zoom: float in [CarShowroom.MIN_ZOOM,1.0,CarShowroom.MAX_ZOOM]:
				view.set_zoom(zoom)
				check(view._weathering_visible(),"snow visibility follows "+id+" zoom "+str(zoom))
		view.reset_view()
		view.invalidate_render()
		await frames()
		if DisplayServer.get_name() != "headless":
			var snow_image: Image = view.showroom_viewport.get_texture().get_image()
			snow_image.save_png(output.path_join("snow-retained-"+id+".png"))
			var original: PackedByteArray = snow_image.get_data()
			view._submit_render()
			await frames()
			check(view.showroom_viewport.get_texture().get_image().get_data() == original,"retained snowy car equals forced drawing "+id)
			view.showroom_viewport.get_texture().get_image().save_png(output.path_join("snow-"+id+".png"))
	report.checks = checks
	report.failures = failures
	report.renderer = RenderingServer.get_current_rendering_method()
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	view.free()
	await section_audit()
	report.checks = checks
	report.failures = failures
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("GARAGE_IDLE_ELEMENTS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
