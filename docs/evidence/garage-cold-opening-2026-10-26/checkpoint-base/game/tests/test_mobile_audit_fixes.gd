extends SceneTree
## Actual App startup/cache/render lifecycle, exact compact controls and durable journals.
const InputRecord = preload("res://race/input_record.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
const Support = preload("res://diagnostics/support_report.gd")
var checks: int = 0
var failures: int = 0
var metrics: Dictionary = {}
var output: String = "res://../build/mobile-audit-fixes-2026-10-26"

class NativeFixture extends RefCounted:
	var calls: int = 0
	func getSupportExits() -> String:
		calls += 1
		return JSON.stringify([{"reason":5,"at":123,"frames":["libgodot_android.so@0x1abc#a123","/private/owner/token=secret","org.beatmytrack.signin.BmtGoogleSignIn.start(BmtGoogleSignIn.java:42)"],"token":"secret"},{"reason":99,"frames":[]}])

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)
func frames(count: int = 8) -> void:
	for _i: int in range(count):
		await process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func controls() -> void:
	var before: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var compact := PackedInt64Array()
	var evidence = preload("res://race/attempt_evidence.gd").new()
	for index: int in range(216000):
		var frame := DriveFrame.new()
		frame.steer = index % 255-127
		frame.throttle = index % 256
		frame.brake = (index*3) % 256
		frame.handbrake = (index*7) % 256
		if index == 0: frame.launch_start = 2
		evidence.append_input(compact,frame)
		if index % 997 == 0 or index == 0 or index == 215999:
			check(InputRecord.unpack(compact[-1],index) == frame.packed(),"all control channels decode exactly "+str(index))
	metrics.control_bytes = int(Performance.get_monitor(Performance.MEMORY_STATIC))-before
	check(compact.size()==216000 and compact[0] is int,"recording remains scalar at the existing cap")
	check(metrics.control_bytes < 8388608,"full control recording stays below 8 MiB")
	evidence.append_input(compact,DriveFrame.new())
	check(evidence.overflow and compact.size()==216000,"one overflow retains existing cap and recovery fence")
	check(InputRecord.unpack(128).is_empty() and InputRecord.unpack(3 << 32).is_empty() and InputRecord.unpack(compact[0],1).is_empty(),"invalid steer/launch values fail closed")
	var old: Array = [[0,0,0],[1,2,3,0]]
	check(InputRecord.legacy(old)==old,"old diagnostic row shape remains exact")
	var folder: String = "user://journal-"+TrackLibrary.unique_id()
	var ticket: Dictionary = {"ticket_id":"proof-ticket","_submit_key":"fixed-key","_race_proof":{"schema":"fixture","samples":[[1,2,3]]},"_race_ghost":{"fixture":true}}
	check(Cloud._queue_run_io(ticket,compact,"",[],folder,"fixture"),"new trajectory is durably saved at the cap")
	var directory: String = folder.path_join("players").path_join("fixture".sha256_text()).path_join("runs")
	var base: String = directory.path_join("proof-ticket".sha256_text())
	var job: Dictionary = Cloud._read_file(base+".job.json")
	var saved: Dictionary = Cloud._read_file(base+".replay.json")
	var bytes: String = FileAccess.get_file_as_string(base+".replay.json")
	check(not saved.has("frames") and InputRecord.count(saved)==216000 and saved.race_proof==JSON.parse_string(JSON.stringify(ticket._race_proof)) and saved.ghost==ticket._race_ghost,"new journal stores count, proof and ghost without unused controls")
	check(job.key=="fixed-key" and bytes.sha256_text()==job.replay_hash,"journal preserves operation key and byte hash")
	check(Cloud._queue_run_io(ticket,compact,"",[],folder,"fixture") and FileAccess.get_file_as_string(base+".replay.json")==bytes,"retry preserves journal bytes")
	compact.resize(compact.size()-1)
	check(not Cloud._queue_run_io(ticket,compact,"",[],folder,"fixture"),"same ticket cannot replace its saved input count")
	ticket.ticket_id = "legacy-ticket"
	ticket.erase("_race_proof")
	ticket.erase("_race_ghost")
	check(Cloud._queue_run_io(ticket,old,"",[],folder,"fixture"),"legacy input-only journal remains writable")
	base = directory.path_join("legacy-ticket".sha256_text())
	saved = Cloud._read_file(base+".replay.json")
	check(saved.frames==JSON.parse_string(JSON.stringify(old)) and InputRecord.count(saved)==2,"legacy journal remains readable")
	check(InputRecord.count({"schema":"bmt-local-trajectory-v1","race_proof":{},"input_count":1.5})==0,"fractional input count is rejected")

func teardown_and_support() -> void:
	for _index: int in range(32):
		var pause: Control = preload("res://ui/race_pause_menu.gd").new()
		var hud := PlaygroundHUD.new()
		pause.hud = hud
		root.add_child(pause)
		pause.free() # Deferred callbacks must belong to the destroyed button.
		hud.free()
	await frames(2)
	check(true,"immediate pause destruction completes without freed-capture errors")
	var native := NativeFixture.new()
	check(native.calls==0,"diagnostics do not read native traces before the explicit action")
	var source: String = Support.capture(native)
	var report: Dictionary = JSON.parse_string(source)
	check(native.calls==1 and report.exits.size()==1 and report.exits[0].frames.size()==2,"explicit guest diagnostic action retains only validated first-party sites")
	check(not source.contains("secret") and not source.contains("/private") and source.to_utf8_buffer().size()<=Support.MAX_BYTES,"support export is bounded and redacted")
	check(report.has("build") and report.has("source_sha256") and not report.has("player"),"support sites have build mapping without account data")

func run() -> void:
	create_timer(150).timeout.connect(func() -> void: print("FAIL: audit-fix deadline"); quit(1))
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	controls()
	await teardown_and_support()
	root.size = Vector2i(1280,720)
	var app: Node = load("res://core/app.tscn").instantiate()
	var folder: String = "user://audit-fixes-"+TrackLibrary.unique_id()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.records.settings.music_enabled = false
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	var began: int = Time.get_ticks_usec()
	root.add_child(app)
	while not app.startup_complete: await process_frame
	metrics.startup_ms = (Time.get_ticks_usec()-began)/1000.0
	check(app.screen=="account" and not is_instance_valid(app._retained_garage),"fresh guest reaches Account without constructing Garage")
	app._show_screen("tracks")
	await frames(12)
	check(not is_instance_valid(app._retained_garage),"Race neighbors do not secretly construct a cold Garage")
	began = Time.get_ticks_usec()
	app._show_screen("garage")
	while app.screen != "garage": await process_frame
	await frames(12)
	metrics.first_garage_ms = (Time.get_ticks_usec()-began)/1000.0
	var page: GaragePage = app._retained_garage
	var view: CarShowroom = page.showroom
	check(page.cached_carousel and page.thumbnails.size()==7,"production App uses all seven cached native cards")
	metrics.garage_viewports = page.find_children("*","SubViewport",true,false).size()
	check(metrics.garage_viewports==3,"retained Garage owns only main and two reflection viewports")
	check(page._preview_service.renders==0 and page._preview_service.cache_hits==7,"all factory previews load without building a workshop")
	for id: String in page.thumbnails:
		var card: CarShowroom = page.thumbnails[id]
		check(card._image.texture != null and card.car==null and card.showroom_viewport==null,"cached card has an image and no native world "+id)
	if DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_png(output.path_join("garage-cached.png"))
		var music: GameSoundtrack = GameSoundtrack.instance()
		var silence := AudioStreamWAV.new()
		silence.mix_rate = 22050
		silence.loop_mode = AudioStreamWAV.LOOP_FORWARD
		silence.loop_end = 44100
		var data := PackedByteArray(); data.resize(44100); silence.data = data
		music.music_enabled = true
		music.mode = "menu"
		music.menu_player.stream = silence
		music.menu_player.play()
		await frames(12)
		var before: PackedInt64Array = view.reflections.draw_requests.duplicate()
		var rotation_before: float = view.record_vinyl.rotation.y
		await frames(24)
		metrics.vinyl_reflection_draws = [view.reflections.draw_requests[0]-before[0],view.reflections.draw_requests[1]-before[1]]
		check(view.record_vinyl.rotation.y!=rotation_before and view.reflections.draw_requests[0]>before[0],"playing vinyl still animates with its room reflection")
		check(view.reflections.draw_requests[1]==before[1],"playing vinyl never redraws unchanged car-only reflection")
		view.rotate_view(Vector2(20,0))
		await frames(8)
		check(view.reflections.draw_requests[1]>before[1],"camera movement refreshes car reflections")
		music.music_enabled = false
		music.menu_player.stop()
		# A changed finish renders once, caches by exact appearance, then reuses it.
		var card: CarShowroom = page.thumbnails.compact
		var factory_pixels: PackedByteArray = card._image.texture.get_image().get_data()
		var paint: Dictionary = card.livery.duplicate(true)
		paint.colors.body = "c72d34"
		card.apply_livery(paint)
		paint.colors.body = "d23735"
		card.apply_livery(paint) # Supersede the queued first finish before it renders.
		var deadline: int = Time.get_ticks_msec()+30000
		while card.displayed_key!=card.preview_key and Time.get_ticks_msec()<deadline: await frames(1)
		check(card.displayed_key==card.preview_key and page._preview_service.renders==1,"custom appearance is rendered once by one temporary showroom")
		var custom_image: Image = card._image.texture.get_image()
		var colours: Dictionary = {}
		for y: int in range(8):
			for x: int in range(16): colours[custom_image.get_pixel(x*128+64,y*64+32).to_html()] = true
		check(custom_image.get_data()!=factory_pixels and colours.size()>20,"custom cache contains a detailed changed native image")
		check(card.livery.colors.body=="d23735" and card.preview_key==page._preview_service.identity(card),"superseded finish cannot publish a stale preview")
		await frames(3)
		check(page._preview_service.renderer==null,"temporary native renderer is released after capture")
		var hits: int = page._preview_service.cache_hits
		page._preview_service.request(card)
		while page._preview_service.worker != null or not page._preview_service.queued.is_empty(): await frames(1)
		check(page._preview_service.cache_hits==hits+1,"exact custom appearance reuses owned disk cache")
		metrics.preview_readback_us = page._preview_service.readback_us
		metrics.preview_file_io_us = page._preview_service.file_io_us
		# Corrupt files fall back; hiding during render retires the temporary world.
		paint.colors.body = "c93037"
		card.livery = paint.duplicate(true)
		var corrupt_key: String = page._preview_service.identity(card)
		var corrupt := FileAccess.open(page._preview_service.directory.path_join(corrupt_key+".png"),FileAccess.WRITE)
		corrupt.store_string("invalid PNG fixture"); corrupt.close()
		card.refresh_thumbnail()
		deadline = Time.get_ticks_msec()+30000
		while page._preview_service.renderer==null and Time.get_ticks_msec()<deadline: await frames(1)
		check(page._preview_service.renderer!=null,"corrupt customized cache falls back to native rendering")
		app._show_screen("settings")
		await frames(4)
		check(page._preview_service.renderer==null,"hidden Garage retires unfinished native preview")
		app._show_screen("garage")
		deadline = Time.get_ticks_msec()+30000
		while card._image.texture==null and Time.get_ticks_msec()<deadline: await frames(1)
		check(card._image.texture!=null and card.preview_key==page._preview_service.identity(card),"returning Garage publishes only its current saved appearance")
	var retained: CarShowroom = view
	app._show_screen("settings")
	check(view.reflections.views.all(func(capture: SubViewport) -> bool: return capture.render_target_update_mode==SubViewport.UPDATE_DISABLED),"hidden retained Garage stops both reflection captures")
	var settings: SettingsPage = app.root_ui.find_child("SettingsPage",true,false)
	settings._show_section("help")
	await frames(4)
	var copy: Button = settings.find_child("CopyDiagnosticReport",true,false)
	check(copy!=null and not copy.disabled and copy.size.y>=48,"guest Help exposes a normal diagnostic action")
	if DisplayServer.get_name()!="headless":
		var analytics_before: bool = bool(app.records.settings.get("optional_analytics",false))
		var clipboard_before: String = DisplayServer.clipboard_get()
		copy.pressed.emit()
		var exported: Variant = JSON.parse_string(DisplayServer.clipboard_get())
		check(exported is Dictionary and exported.get("schema")=="bmt-support-v1","actual Help action copies the local report")
		check(bool(app.records.settings.get("optional_analytics",false))==analytics_before and not analytics_before,"support export does not change guest analytics consent")
		DisplayServer.clipboard_set(clipboard_before)
		await frames(2)
		root.get_texture().get_image().save_png(output.path_join("settings-help-diagnostics.png"))
	app._show_screen("garage")
	await frames()
	check(app._retained_garage==page and page.showroom==retained,"warm Settings round trip retains exact main showroom")
	app.records = LocalRecords.new(folder.path_join("other-records.json"))
	app._rebuild_profile_menu("account")
	await frames()
	check(not is_instance_valid(app._retained_garage) and app.screen=="account","owner change releases previews without constructing another Garage")
	app._show_screen("garage")
	app._show_screen("tracks")
	await frames(8)
	check(app.screen=="tracks" and is_instance_valid(app._retained_garage),"immediate navigation leaves the directly opened Garage retained")
	app.queue_free()
	await frames(3)
	metrics.checks = checks; metrics.failures = failures
	var file := FileAccess.open(output.path_join("focused-"+DisplayServer.get_name()+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"  "))
	print("MOBILE_AUDIT_FIXES: ",checks," checks, ",failures," failures ",JSON.stringify(metrics))
	quit(1 if failures else 0)
