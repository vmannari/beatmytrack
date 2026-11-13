extends SceneTree
## Actual App: a consumed menu release must not strand saved-car photographs.
var app: Node
var checks: int=0
var failures: int=0
var output: String="res://../build/carousel-preview-20261107/delivery"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if "--old-relay" in OS.get_cmdline_user_args():
		var relay: Script=load("res://ui/preview_touch_input.gd")
		relay.source_code=FileAccess.get_file_as_string("res://../build/carousel-preview-20261107/before/preview_touch_input.gd")
		assert(relay.reload(true)==OK)
	run.call_deferred()

func check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		failures+=1
		print("FAIL: ",label)

func frames(count: int=4) -> void:
	for tick: int in range(count): await process_frame

func touch(at: Vector2,index: int,pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position=at; event.index=index; event.pressed=pressed
	root.push_input(event,true)

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"capture "+label)

func run() -> void:
	create_timer(140).timeout.connect(func() -> void: print("FAIL: delivery deadline"); quit(1))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size=Vector2i(1280,720)
	root.gui_embed_subwindows=true
	var folder: String="user://carousel-delivery-"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	app=load("res://core/app.tscn").instantiate()
	app.records=LocalRecords.new(folder.path_join("records.json"))
	app.records.settings.music_enabled=false
	app.library=TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override=folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	GameSoundtrack.instance().music_enabled=false
	GameSoundtrack.instance().menu_player.stop()
	GameSoundtrack.instance().menu_player.stream=null
	var paints: Dictionary={}
	for id: String in ["compact","electric"]:
		var paint: Dictionary=VehicleLivery.for_car({},id)
		paint.colors.body="ac5732" if id=="compact" else "372dbe"
		paints[id]=paint
	app.records.settings.vehicle_liveries=paints
	if "--tablet-appearance" in OS.get_cmdline_user_args():
		var settings: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../build/carousel-preview-20261107/tablet-appearance-private.json"))
		app.records.settings.merge(settings,true)
		for id: String in ["compact","electric"]: paints[id]=VehicleLivery.for_car(app.records.settings,id)
	check(app.records.save_records()==OK,"save private fixture cosmetics")
	app._garage_preloader.evict()
	app._show_screen("garage")
	await create_timer(0.4).timeout
	await frames()
	var page: Control=app._retained_garage
	while page.progressive_entry and page.showroom.preparing: await process_frame
	await frames()
	check(app.screen=="garage" and page.section=="cars","direct Garage entry reaches carousel")
	var service: Node=page._preview_service
	# Static heading accepts page swipes; a short drag claims intent but stays
	# on Garage. DOWN is unhandled while UP is handled by MenuPageSwipe.
	var swipe: Node=app.root_ui.get_node("MenuPageSwipe")
	# Exercise the no-modal gesture path independently of notification layers
	# and the dummy display's visible internal popup windows.
	var modal_scope := Node.new()
	swipe.add_child(modal_scope)
	swipe.modal_root=modal_scope
	var at: Vector2=page.heading.get_global_rect().get_center()
	check(not swipe._owns_gesture(swipe.menu,at),"heading belongs to menu-page gestures")
	touch(at,4,true)
	check(service._touches.has(4),"carousel worker observes menu-swipe press")
	var motion := InputEventScreenDrag.new()
	motion.index=4; motion.position=at+Vector2(10,0); motion.relative=Vector2(10,0)
	root.push_input(motion,true)
	check(swipe.dragging,"real menu gesture claims the drag")
	touch(motion.position,4,false)
	check(service._touches.is_empty(),"handled release reaches actual carousel worker")
	check(app._garage_preloader._touches.is_empty(),"handled release reaches actual preloader")
	await create_timer(0.85).timeout
	check(service._render_allowed(),"actual carousel rendering becomes eligible again")
	check(app.screen=="garage" and page.section=="cars","short swipe stays on Garage")
	await capture("after-swipe")
	if DisplayServer.get_name()!="headless":
		for offset: int in [0,10000]:
			page.gallery.scroll_horizontal=offset
			await frames()
			var deadline: int=Time.get_ticks_msec()+45000
			while Time.get_ticks_msec()<deadline:
				var missing: bool=false
				for card: Control in page.thumbnails.values():
					if service._on_screen(card) and card.displayed_key!=card.preview_key: missing=true
				if not missing: break
				await process_frame
			await capture("ready-"+str(offset))
		for id: String in VehicleCatalog.IDS:
			var card: Control=page.thumbnails[id]
			check(card.displayed_key==card.preview_key and card._image.texture!=null and not card._placeholder.visible,"exact car picture replaces loading "+id)
			check(card.car==null and card.showroom_viewport==null,"carousel retains photograph-only presentation "+id)
		# A swipe may cancel and restart an admitted capture; both exact misses
		# must finish regardless of when the first capture was admitted.
		check(service.renders>=2,"both custom cache misses receive native captures")
		check(page.thumbnails.compact.livery==paints.compact and page.thumbnails.electric.livery==paints.electric,"saved paints remain exact")
	# Parking disables ordinary callbacks; root release forwarding still clears
	# the hidden worker before the same retained page is opened again.
	service._touches[9]=true
	app._show_screen("profile")
	await frames()
	touch(Vector2(30,30),9,false)
	check(service._touches.is_empty(),"release clears the parked carousel worker")
	app._show_screen("garage")
	await frames()
	check(app._retained_garage==page and service._touches.is_empty(),"retained Garage reopens without stale touches")
	var result: Dictionary={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"renders":service.renders,"old_relay":"--old-relay" in OS.get_cmdline_user_args()}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	app.queue_free()
	await frames(8)
	print("CAROUSEL_PREVIEW_DELIVERY: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
