extends SceneTree
## Exercise palette activation and placement through actual viewport input.
var app: Node
var checks: int = 0
var failures: int = 0
var output: String

func _initialize() -> void: run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: ",label)

func frames(count: int = 4) -> void:
	for _index: int in range(count): await process_frame

func settle() -> void:
	var deadline: int = Time.get_ticks_msec()+45000
	await frames()
	while Time.get_ticks_msec()<deadline and (app.canvas.preparing or app.editor_preview_thread != null or app.editor_commits.unsettled() or app.editor_world._building): await process_frame
	check(not app.canvas.preparing and app.editor_preview_thread == null and not app.editor_commits.unsettled(),"editor preparation completes")
	await frames()

func input_at(point: Vector2, touch: bool) -> void:
	for down: bool in [true,false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.index = 0; event.position = point; event.pressed = down
			root.push_input(event,true)
		else:
			var event := InputEventMouseButton.new()
			event.position = point; event.global_position = point
			event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down
			root.push_input(event,true)
		await process_frame
	await frames()

func press(node_name: String, touch: bool) -> void:
	var control: Control = app.root_ui.find_child(node_name,true,false)
	check(is_instance_valid(control) and control.is_visible_in_tree(),"visible "+node_name)
	if not is_instance_valid(control): print("MISSING_CONTROL: ",node_name," property=",app.editor_object_property," mode=",app.canvas.mode," controls=",app.object_controls.get_children())
	if is_instance_valid(control): await input_at(control.get_global_rect().get_center(),touch)

func capture(name_value: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name_value+".png")) == OK,"native screenshot "+name_value)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	OS.set_environment("BMT_DEV_AUTH_KEY","")
	output = OS.get_environment("BMT_PALETTE_EVIDENCE")
	if output.is_empty() or not output.is_absolute_path():
		push_error("Set absolute BMT_PALETTE_EVIDENCE to an isolated output folder")
		quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720); root.content_scale_size = root.size
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(output.path_join("storage/tracks"))
	app.records = LocalRecords.new(output.path_join("storage/records.json"))
	app.cloud_root_override = output.path_join("storage/cloud")
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+45000
	while not app.startup_complete and Time.get_ticks_msec()<deadline: await process_frame
	check(app.startup_complete,"isolated app starts")
	if not app.startup_complete: quit(1); return
	for touch: bool in [true,false]: await default_rock_flow(touch)
	await variant_and_jump_flow()
	await fence_reselect_flow()
	app.queue_free(); await frames(5)
	GameSoundtrack.instance().queue_free(); await create_timer(0.2).timeout
	print("OBJECT_PALETTE_ACTIVATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func new_desert(theme: String = "desert") -> void:
	app.canvas = null
	app.editor_pending_tools.clear()
	app.editor_view = {}
	app.history.clear(); app.redo_history.clear()
	app.document = TrackDocument.create_blank()
	app.document.theme = theme
	app.document.id = "palette_"+TrackLibrary.unique_id()
	app.document["automatic_scenery"] = false
	app._show_screen("create")
	await settle()

func default_rock_flow(touch: bool) -> void:
	var label: String = "touch" if touch else "mouse"
	await new_desert()
	await press("EditorObjects",touch)
	var rock: Button = app.root_ui.find_child("Asset_rock",true,false)
	check(rock != null and rock.button_pressed and app.object_browser.current == "rock",label+" default Rock appears highlighted")
	check(app.canvas.mode == "objects" and app.document.objects.is_empty(),label+" initially starts in object selection mode")
	await press("Asset_rock",touch)
	check(app.canvas.mode == "place" and app.canvas.stamp_kind == "rock",label+" clicking highlighted Rock activates Rock placement")
	check(app.object_browser.current == "rock" and (app.root_ui.find_child("Asset_rock",true,false) as Button).button_pressed,label+" Rock remains visibly selected")
	check(app.document.objects.is_empty(),label+" activation alone does not edit the track")
	await capture(label+"-rock-selected")
	await input_at(app.canvas.to_screen(Vector2(-12,0)),touch)
	await settle()
	await input_at(app.canvas.to_screen(Vector2(12,0)),touch)
	await settle()
	check(app.document.objects.size() == 2,label+" two ground presses place two rocks")
	if app.document.objects.size() == 2:
		check(app.document.objects[0].kind == "rock" and app.document.objects[1].kind == "rock",label+" both placed objects are rocks")
	check(app.canvas.mode == "place",label+" repeated placement stays active")
	await capture(label+"-two-rocks")

func variant_and_jump_flow() -> void:
	await new_desert()
	await press("EditorObjects",true)
	await press("Asset_rock",true)
	var variant: OptionButton = app.root_ui.find_child("ObjectVariant",true,false)
	check(is_instance_valid(variant),"Rock variant control remains available")
	if is_instance_valid(variant): variant.select(1); variant.item_selected.emit(1)
	await frames(5)
	check(app.canvas.stamp_kind == "boulder","variant control selects Boulder")
	await press("ObjectSizeControl",true)
	await press("ObjectSize_2",true)
	await press("ObjectControlsBack",true)
	await press("ObjectOrientation",true)
	await press("ObjectIncrease",true)
	await press("ObjectControlsBack",true)
	check(is_equal_approx(app.canvas.stamp_scale,1.5) and is_equal_approx(app.canvas.stamp_rotation,22.5),"size and orientation controls work")
	await press("Asset_rock",true)
	check(app.canvas.mode == "place" and app.canvas.stamp_kind == "boulder","reselecting family preserves its chosen Boulder variant")
	check(is_equal_approx(app.canvas.stamp_scale,1.5) and is_equal_approx(app.canvas.stamp_rotation,22.5),"reselecting family preserves size and orientation")
	await input_at(app.canvas.to_screen(Vector2(0,0)),true)
	await settle()
	check(app.document.objects.size() == 1 and app.document.objects[0].kind == "boulder" and is_equal_approx(float(app.document.objects[0].get("scale",1.0)),1.5) and is_equal_approx(float(app.document.objects[0].rotation),22.5),"native touch places chosen Boulder with its settings")
	await capture("boulder-settings")
	await press("Category_Props",true)
	for asset: String in CreatorCatalog.JUMP_ASSETS:
		await press("Asset_"+asset,true)
		var profile: String = str(CreatorCatalog.JUMP_ASSETS[asset])
		check(app.canvas.mode == "place" and app.canvas.stamp_jump_profile == profile,asset+" selects exact jump")
		await press("Asset_"+asset,true)
		check(app.canvas.mode == "place" and app.canvas.stamp_jump_profile == profile,asset+" reselect keeps exact jump")

func fence_reselect_flow() -> void:
	await new_desert("pine")
	await press("EditorObjects",true)
	await press("Category_Barriers",true)
	await press("Asset_guardrail",true)
	await press("Placement_curve",true)
	check(app.canvas.mode == "run" and app.object_browser.placement == "curve","guardrail curve mode is active")
	await press("Asset_guardrail",true)
	check(app.canvas.mode == "run" and app.object_browser.placement == "curve","reselecting guardrail retains curve placement")
	check(app.canvas.run_shape == "curve" and app.canvas.stamp_kind == "guardrail","reselection preserves actual run shape and asset")
