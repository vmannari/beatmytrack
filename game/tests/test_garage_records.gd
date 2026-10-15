extends SceneTree
## Authored LP box: gestures, physical sleeve flips, placeholders and audio lifecycle.
const Library = preload("res://soundtrack/record_library.gd")
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/garage-lp-box-2026-10-14"
var page: GaragePage

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)
func settle() -> void:
	await create_timer(0.80).timeout
	for tick: int in range(5): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)
func delivered_audio(label: String) -> float:
	var bus: int = AudioServer.get_bus_index("Music")
	var recorder := AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	var slot: int = AudioServer.get_bus_effect_count(bus)
	AudioServer.add_bus_effect(bus,recorder)
	recorder.set_recording_active(true)
	await create_timer(0.35).timeout
	recorder.set_recording_active(false)
	var audio: AudioStreamWAV = recorder.get_recording()
	AudioServer.remove_bus_effect(bus,slot)
	check(audio!=null and audio.data.size()>4000,"actual audio samples: "+label)
	var peak: float = 0.0
	for offset: int in range(0,audio.data.size(),2): peak = maxf(peak,absf(audio.data.decode_s16(offset)/32768.0))
	audio.save_to_wav(output.path_join(label+".wav"))
	audio = null
	recorder = null
	await create_timer(0.1).timeout
	print("LP_AUDIO_PEAK ",label," ",peak)
	return peak
func _run() -> void:
	OS.set_environment("BMT_API_URL","")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	var folder: String = "user://lp_box_test_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var records := LocalRecords.new(folder.path_join("records.json"))
	var original: String = folder.path_join("keep-original.wav")
	var keep := FileAccess.open(original,FileAccess.WRITE)
	keep.store_string("Migration must preserve this owner file.")
	keep.close()
	var original_hash: String = FileAccess.get_sha256(original)
	var legacy_id: String = "a".repeat(64)
	records.settings = {"music_record":legacy_id,"music_records":[{"id":legacy_id,"title":"Old private LP","format":"wav"}],"music_volume":0.7,"music_enabled":true,"selected_car":"classic"}
	records.records["b".repeat(64)] = {"race_ms":12000,"flying_ms":2400}
	check(records.save_records()==OK,"prior import settings migrate through normal atomic save")
	var reload := LocalRecords.new(records.path)
	reload.load_records()
	check(reload.settings.music_record=="exploration" and not reload.settings.has("music_records"),"retired import metadata is discarded and selection falls back")
	check(reload.settings.selected_car=="classic" and reload.records==records.records,"migration preserves other settings and personal bests")
	check(FileAccess.get_sha256(original)==original_hash,"migration never deletes or rewrites owner music files")
	var library_script: GDScript = load("res://soundtrack/record_library.gd")
	var methods: Array = library_script.get_script_method_list().map(func(item: Dictionary) -> String: return item.name)
	check(not methods.has("import_file") and not methods.has("decode") and not methods.has("remove"),"catalogue exposes no private-music loading or importing API")
	check(Library.entries().size()==7,"Exploration plus six authored placeholder sleeves")
	var images: Array[PackedByteArray] = []
	for item: Dictionary in Library.entries():
		var art: Image = Library.cover(item.id).get_image()
		check(art.get_size()==Vector2i(256,256) and art.has_mipmaps(),"bounded mipmapped sleeve: "+item.id)
		check(not images.has(art.get_data()),"distinct authored cover: "+item.id)
		images.append(art.get_data())
		if item.id!="exploration":
			check(not Library.playable(item.id) and Library.stream(item)==null,"placeholder has no audio: "+item.id)
			check(Library.selected({"music_record":item.id}).id=="exploration","placeholder cannot become a fake playback selection: "+item.id)
	var music: GameSoundtrack = GameSoundtrack.instance()
	music._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	music.apply_settings(records.settings)
	music.show_menu()
	music._process(1.0)
	var stream: AudioStream = music.menu_player.stream
	check(music.menu_record=="exploration" and stream is AudioStreamOggVorbis,"current selected recording remains the original Exploration loop")
	root.size = Vector2i(1280,720)
	var holder := MarginContainer.new()
	holder.theme = MenuStyle.theme()
	MenuStyle.fill(holder)
	for side: String in ["left","top","right","bottom"]: holder.add_theme_constant_override("margin_"+side,20)
	root.add_child(holder)
	page = GaragePage.new()
	page.records = records
	holder.add_child(page)
	await settle()
	var view: CarShowroom = page.showroom
	var car: CarVisual = view.car
	var viewport: SubViewport = view.showroom_viewport
	view.set_zoom(0.83)
	view.rotate_view(Vector2(12,-2))
	var car_pose: Transform3D = view.camera.transform
	page._show_section("records")
	await settle()
	var menu: VBoxContainer = page.records_menu
	var box: Control = menu.crate
	check(view.record_view and view.record_sleeves.get_child_count()==7,"actual LP crate contains all seven native sleeves")
	check(page.find_child("GarageAddLP",true,false)==null and page.find_child("GarageLPFileDialog",true,false)==null and page.find_child("GarageRemoveLP",true,false)==null,"import/removal/file picker are absent from the garage")
	check(menu.find_child("GarageRecordScroll",true,false)==null and menu.find_children("*","GridContainer",true,false).is_empty(),"LP box replaces the card grid")
	check(box.focus_mode==Control.FOCUS_ALL,"record box supports keyboard focus")
	await capture("lp-box-exploration-1280")
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	box._gui_input(wheel)
	check(box.browse_index==1 and menu.browse_index==1 and page.record_browse_index==1,"mouse wheel flips to the next LP")
	box.motion.pause()
	box.motion.custom_step(0.12)
	await process_frame
	check(box.display_position>0 and box.display_position<1,"intermediate flip displays a continuous sleeve pose")
	check((view.record_sleeves.get_child(0) as Node3D).rotation.x<0.10,"native sleeve tilts with the actual UI flip")
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	await capture("lp-box-flip-mid")
	box.motion.custom_step(0.25)
	await settle()
	if DisplayServer.get_name()!="headless":
		box.flip_to(0)
		await settle()
		box.flip_to(1)
		box.motion.pause()
		var flip: Tween = box.motion
		for frame: int in range(13):
			if frame>0: flip.custom_step(0.32/12.0)
			await process_frame
			await RenderingServer.frame_post_draw
			await capture("flip-frame-%02d" % frame)
		flip.custom_step(0.001)
		await settle()
	check(menu.play_button.disabled and menu.play_button.text=="Music coming later","placeholder is visibly unavailable for playback")
	menu._play_browsed()
	check(music.menu_player.stream==stream and records.settings.music_record=="exploration","browsing/tapping placeholder retains existing recording without restarting it")
	await capture("lp-box-placeholder-1280")
	var touch := InputEventScreenTouch.new()
	touch.index = 2
	touch.position = box.size*0.5
	touch.pressed = true
	box._gui_input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 2
	drag.position = touch.position-Vector2(0,95)
	box._gui_input(drag)
	touch.pressed = false
	box._gui_input(touch)
	await settle()
	check(box.browse_index==2 and absf(box.display_position-2)<0.0001,"finger swipe flips to next sleeve")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_LEFT
	box._gui_input(key)
	await settle()
	check(box.browse_index==1,"keyboard arrow flips backward")
	menu.next_button.pressed.emit()
	await settle()
	check(box.browse_index==2,"native Next LP button flips forward")
	box.flip_to(6)
	box.flip_by(1)
	await settle()
	check(box.browse_index==6 and menu.next_button.disabled,"crate ends at last sleeve")
	box.flip_to(0)
	box.flip_by(-1)
	await settle()
	check(box.browse_index==0 and menu.previous_button.disabled,"crate starts at first sleeve")
	for index: int in range(1,7):
		box.flip_to(index)
		await settle()
		check(menu.play_button.disabled and music.menu_player.stream==stream,"every placeholder preserves playback: "+str(index))
		await capture("lp-sleeve-"+Library.CATALOG[index].id)
	for width: int in [960,1600]:
		root.size = Vector2i(width,540 if width==960 else 720)
		await settle()
		check(page.get_global_rect().encloses(menu.get_global_rect()),"LP box workbench fits "+str(width))
		await capture("lp-box-"+str(width))
	root.size = Vector2i(1280,720)
	box.flip_to(0)
	await settle()
	music._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	if music.output_enabled:
		check(await delivered_audio("playing-exploration")>0.001,"native Exploration music continues through LP browsing")
	menu._toggle_play()
	music._process(1.0)
	check(not music.music_enabled and music.menu_target==0 and (not music.output_enabled or music.menu_player.stream_paused),"stop control retains saved off behavior")
	if music.output_enabled:
		await create_timer(0.15).timeout
		check(await delivered_audio("stopped-lp")==0,"stop produces no delivered music after queued block drains")
	music._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	music._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(music.menu_target==0,"focus return preserves stopped music")
	menu._play_browsed()
	music._process(1.0)
	check(music.music_enabled and music.menu_record=="exploration","playable LP restores music")
	menu._preview_volume(31)
	box.flip_to(3)
	page._show_section("care")
	await settle()
	reload.load_records()
	check(reload.settings.music_volume==0.31,"leaving LP box flushes pending volume save")
	check(view.camera.transform.is_equal_approx(car_pose) and not view.record_view,"car camera and zoom return unchanged")
	check(view.car==car and view.showroom_viewport==viewport,"LP browsing retains actual car and viewport")
	page._show_section("records")
	await settle()
	check(page.records_menu.browse_index==3 and page.records_menu.crate.display_position==3,"return restores the browsed sleeve in this Garage session")
	page._show_section("trophies")
	page._show_section("records")
	page._show_section("cars")
	await settle()
	check(not view.trophy_view and not view.record_view and view.car==car,"rapid navigation cancels stale room-camera transitions")
	page._show_section("records")
	await settle()
	page.hide()
	check(page.records_menu.crate.motion==null and page.records_menu.crate.pointer==-2,"hiding settles flips and clears pointer ownership")
	page.show()
	await settle()
	page.records_menu.crate.flip_to(0)
	await settle()
	await capture("lp-box-final")
	page.queue_free()
	await process_frame
	music.apply_settings({})
	print("GARAGE_LP_BOX: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
