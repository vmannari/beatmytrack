extends SceneTree
## Exercise the real Load track -> Edit track -> Test drive path, offline.
const IDS: Array[String] = ["storm_freight","storm_switchyard","storm_timber","storm_quarry","storm_floodgate"]
var OUTPUT: String = "res://../docs/evidence/storm-driving-variety-2026-10-26"
var checks: int = 0
var failures: int = 0
var app: Node
var folder: String

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func settle_editor() -> void:
	var deadline: int = Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline:
		if is_instance_valid(app.canvas) and app.editor_preview_thread==null and not app.canvas.preparing and not app.editor_commits.unsettled() and not app.editor_world._building: break
		await process_frame
	app._flush_editor_writes()
	app._update_editor_issues()
	await process_frame

func screenshot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for i: int in range(8): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+name+".png")==OK,name+" native screenshot")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): OUTPUT = argument.trim_prefix("--output=")
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	folder = OUTPUT+"/editor-"+RenderingServer.get_current_rendering_method()+("-headless" if DisplayServer.get_name()=="headless" else "")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var fixture: String = ProjectSettings.globalize_path("res://../build/storm-driving-variety-2026-10-26/editor-fixture-"+str(OS.get_process_id()))
	var library := TrackLibrary.new(fixture+"/tracks")
	library.owner_name = "Ville"
	for id: String in IDS:
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/storm_tracks/"+id+".json"))
		source.creator = "Ville"
		check(library.save_document(source)==OK,id+" saves as an ordinary Ville draft")
	app = preload("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(fixture+"/records.json")
	app.library = library
	app.cloud_root_override = fixture+"/cloud"
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.online.client.configure("")
	app.library.owner_name = "Ville"
	check(app.online.client.base_url().is_empty() and not app.online.client.signed_in(),"actual app uses no authentication or network service")
	for id: String in IDS:
		app._show_screen("drafts")
		var browser: VBoxContainer = app.root_ui.find_child("DraftBrowser",true,false)
		while browser.scanning or browser.scan!=null: await process_frame
		var found: Array = browser.entries.filter(func(item: Dictionary) -> bool: return str(item.id)==id)
		check(found.size()==1,id+" appears once in actual Load track")
		if found.is_empty(): continue
		browser.selection = found[0]
		browser.page = browser.entries.find(found[0])/4
		browser._refresh()
		var tile: TrackTile = browser.find_child("Draft_"+id,true,false)
		check(tile!=null and not tile.paths.is_empty(),id+" normal road-part thumbnail is present")
		await screenshot(id+"-draft")
		var edit: Button = browser.find_child("ContinueEditing",true,false)
		check(edit!=null and not edit.disabled,id+" real Edit track action is enabled")
		edit.pressed.emit()
		await settle_editor()
		check(app.screen=="create" and app.document.id==id,id+" actual editor opens the selected draft")
		check(app.document.layout.is_empty() and app.document.pieces.size()>=20,id+" editor has supported selectable road parts")
		check(app.editor_issues.is_empty() and app.editor_validation_errors.is_empty(),id+" actual editor reports no validation or open-road issues")
		check(app.test_button!=null and not app.test_button.disabled,id+" editor Test drive is enabled")
		app.canvas.selected_piece = 1
		app._editor_category("road")
		await screenshot(id+"-editor")
		app._show_screen("drafts")
		browser = app.root_ui.find_child("DraftBrowser",true,false)
		while browser.scanning or browser.scan!=null: await process_frame
		for item: Dictionary in browser.entries:
			if str(item.id)==id: browser.selection = item; browser.page = browser.entries.find(item)/4; break
		browser._refresh()
		var test: Button = browser.find_child("TestDraft",true,false)
		check(test!=null and not test.disabled,id+" real Load track Test drive action is enabled")
		test.pressed.emit()
		var deadline: int = Time.get_ticks_msec()+90000
		while (not is_instance_valid(app.game) or not app.game.preparation_complete or is_instance_valid(app.race_loading)) and Time.get_ticks_msec()<deadline: await process_frame
		check(is_instance_valid(app.game) and app.game.preparation_complete,id+" actual Test drive starts without a validation rejection")
		check(not is_instance_valid(app.race_loading),id+" loading cover closes before the visible practice review")
		if not is_instance_valid(app.game): break
		var game: Node = app.game
		game.set_physics_process(false)
		check(game.native_track.metadata.creator_document.pieces.size()>=20 and game.editor_test and game.attempt_practice,id+" game uses the authored road parts in untimed practice")
		check(game.native_track.finish_center.distance_to(Vector2(app.document.start_line.position[0],app.document.start_line.position[1]))<.05,id+" game uses the explicit start line")
		game.ai_enabled = true
		game.paused = false
		for tick: int in range(120): game._physics_process(1.0/120.0)
		check(game.sim.state.tick>=120 and not game.practice_validation_eligible,id+" actual game drives; diagnostic input cannot grant a publishable test receipt")
		game.paused = true
		await screenshot(id+"-practice")
		app._leave_race()
		await process_frame
		check(app.screen=="drafts",id+" returns to Load track")
	app.queue_free()
	await process_frame
	await process_frame
	var file := FileAccess.open(folder+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"network_configured":false,"mode":"isolated actual App editor and test flow"},"\t")); file.close()
	print("STORM_EDITOR_WORKFLOW: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
