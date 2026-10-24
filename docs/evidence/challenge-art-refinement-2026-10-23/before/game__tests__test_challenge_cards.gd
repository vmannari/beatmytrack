extends SceneTree
## Native card input, optional rules transactions, exact receipts and bounded layout.
var checks: int = 0
var failures: int = 0
var output: String
var raced: Dictionary = {}

class StubClient extends Node:
	signal sources_released
	var hold_sources: bool = false
	var player: Dictionary = {"id":"card-fixture"}
	var _capabilities: Dictionary = {"challenge_discovery_version":1,"challenge_series_version":1}
	var answer: Dictionary = {"ok":true,"data":{"status":"verified","run_id":"exact-finish","ms":88900}}
	var payload: Dictionary = {}
	var paths: Array[String] = []
	func base_url() -> String: return "http://card-fixture"
	func signed_in() -> bool: return true
	func new_operation_key() -> String: return "card-fixture-operation"
	func cancel_public_reads(_owner: int) -> void: pass
	func request_api(path: String, _method: int, value: Dictionary, _key: String, _auth: bool) -> Dictionary:
		paths.append(path)
		payload = value.duplicate(true)
		var response: Dictionary = answer.duplicate(true)
		if hold_sources and path.begins_with("/challenges/sources?"): await sources_released
		return response

func _initialize() -> void: run.call_deferred()
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+detail)

func entry() -> Dictionary:
	return {"version_id":"00000000-0000-0000-0000-000000000001","track_id":"00000000-0000-0000-0000-000000000002","content_hash":"a".repeat(64),"name":"Forest Run","creator":"Fixture driver","theme":"pine","points":[[0,0],[100,0],[120,70],[40,90],[-10,30]]}

func invitation(group: bool = false) -> Dictionary:
	return {"id":"cards-created","code":"AB12CD34EF56AB78","mode":"group" if group else "beat","state":"active","visibility":"private","creator_id":"card-fixture","creator":"Fixture driver","self_id":"card-fixture","joined":true,"vehicle_id":"compact","created_at":0,"ends_at":259200,"server_now":0,"attempt_limit":3,"attempts_used":1,"attempts_remaining":2,"target_ms":null if group else 88900,"target_ticks":null if group else 10668,"manifest":{"laps":5,"tick_rate":120},"entry":entry(),"share_url":"https://fixture/c/AB12CD34EF56AB78","standings":[{"id":"card-fixture","name":"Fixture driver","rank":1,"ticks":10668,"ms":88900,"run_id":"exact-finish"}]}

func settle() -> void:
	for frame: int in range(6): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(-50,-50)
	root.push_input(motion,true)
	await settle()
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func inside(node: Control, detail: String) -> void:
	var rect: Rect2 = node.get_global_rect()
	var visible: Rect2 = root.get_visible_rect()
	check(rect.position.x >= -1 and rect.end.x <= visible.end.x+1 and rect.position.y >= -1 and rect.end.y <= visible.end.y+1,detail+" is inside viewport")

func car_layout(page: ChallengeCreate) -> Array[Rect2]:
	return [page._car_stage.get_global_rect(),page._car_scroll.get_global_rect(),(page.find_child("ChallengeCreateActions",true,false) as Control).get_global_rect()]

func card_positions(page: ChallengeCreate) -> PackedFloat64Array:
	var result := PackedFloat64Array()
	for card: Button in page._car_cards: result.append(card.get_global_rect().position.x)
	return result

func entire_row_shifted(page: ChallengeCreate, before: PackedFloat64Array, shift: float) -> bool:
	var after: PackedFloat64Array = card_positions(page)
	for index: int in range(after.size()):
		if not is_equal_approx(after[index]-before[index],shift): return false
	return true

func edge_gesture(page: ChallengeCreate, index: int, distance: float, label: String, wheel: bool = false) -> void:
	var gallery: ScrollContainer = page._car_scroll
	var before: PackedFloat64Array = card_positions(page)
	var selected: String = page._vehicle_id()
	var point: Vector2 = page._car_cards[index].get_global_rect().get_center()
	if wheel:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_WHEEL_LEFT if distance > 0 else MOUSE_BUTTON_WHEEL_RIGHT
		event.pressed = true
		root.push_input(event,true)
		gallery.get("snap_tween").pause()
	else:
		var down := InputEventScreenTouch.new()
		down.index = 7
		down.position = point
		down.pressed = true
		root.push_input(down,true)
		var drag := InputEventScreenDrag.new()
		drag.index = 7
		drag.position = point+Vector2(distance,0)
		drag.relative = Vector2(distance,0)
		root.push_input(drag,true)
	var edge: float = float(gallery.get("overscroll_offset"))
	check(absf(edge) > 1 and entire_row_shifted(page,before,edge),"edge effect moves every car together: "+label)
	await capture("edge-"+label)
	if not wheel:
		var up := InputEventScreenTouch.new()
		up.index = 7
		up.position = point+Vector2(distance,0)
		root.push_input(up,true)
		gallery.get("snap_tween").pause()
	var motion: Tween = gallery.get("snap_tween")
	motion.custom_step(0.12)
	check(entire_row_shifted(page,before,float(gallery.get("overscroll_offset"))),"spring return keeps the complete row aligned: "+label)
	motion.custom_step(0.5)
	await settle()
	check(entire_row_shifted(page,before,0.0) and is_zero_approx(float(gallery.get("overscroll_offset"))),"spring restores all original car positions: "+label)
	check(page._vehicle_id() == selected,"scrolling never selects a car: "+label)

func carousel_edges(page: ChallengeCreate) -> void:
	for index: int in range(VehicleCatalog.IDS.size()):
		await edge_gesture(page,index,100,"wide-left-"+VehicleCatalog.IDS[index])
		await edge_gesture(page,index,-100,"wide-right-"+VehicleCatalog.IDS[index])
	root.size = Vector2i(390,844)
	await settle()
	page._car_scroll.scroll_horizontal = 0
	await settle()
	await edge_gesture(page,0,100,"narrow-left-touch")
	await edge_gesture(page,0,100,"narrow-left-wheel",true)
	page._car_scroll.call("settle_cards",1)
	var motion: Tween = page._car_scroll.get("snap_tween")
	motion.pause()
	motion.custom_step(0.5)
	await settle()
	check(page._car_scroll.scroll_horizontal == int(page._car_scroll.get("snap_stride")),"ordinary narrow carousel scrolling still advances one complete card")
	page._car_scroll.scroll_horizontal = roundi(page._car_scroll.get_h_scroll_bar().max_value-page._car_scroll.get_h_scroll_bar().page)
	await settle()
	await edge_gesture(page,4,-100,"narrow-right-touch")
	await edge_gesture(page,4,-100,"narrow-right-wheel",true)
	root.size = Vector2i(1280,720)
	page._car_scroll.scroll_horizontal = 0
	await settle()

func click(button: Button) -> void:
	var point: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
	await settle()

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.content_scale_size = Vector2i.ZERO
	var capture_root: String = OS.get_environment("BMT_CHALLENGE_CAPTURE_DIR")
	if capture_root.is_empty(): capture_root = "res://../docs/evidence/challenge-flow-polish-2026-10-23"
	output = ProjectSettings.globalize_path(capture_root.path_join(DisplayServer.get_name()+"-"+RenderingServer.get_current_rendering_method()))
	DirAccess.make_dir_recursive_absolute(output)
	var client := StubClient.new()
	root.add_child(client)
	var cloud: Node = load("res://backend/cloud_tracks.gd").new()
	cloud.client = client
	cloud.root_override = "user://challenge-flow-"+TrackLibrary.unique_id()
	root.add_child(cloud)
	var adapter := ChallengesClient.new()
	adapter.client = client
	adapter.cloud = cloud
	root.add_child(adapter)
	adapter.reset()
	adapter.creation_visibility = "private"
	var tracks: Array[Dictionary] = []
	for index: int in range(5):
		var track: Dictionary = entry().duplicate(true)
		track.version_id = "00000000-0000-0000-0000-00000000000"+str(index)
		track.track_id = "10000000-0000-0000-0000-00000000000"+str(index)
		track.name = ["Forest Run","Dune Runner","Winter Loop","Alpine Circuit","Night Shift"][index]
		track.theme = ["pine","desert","winter","pine","night_city"][index]
		tracks.append(track)
	var page := ChallengeCreate.new()
	page.adapter = adapter
	page.entries = tracks
	page.records = LocalRecords.new(cloud.root_override.path_join("records.json"))
	var paint: Dictionary = VehicleLivery.defaults("compact")
	paint.colors.body = "8b4242"
	var parts: Dictionary = VehicleCustomisation.defaults()
	parts.hood = "scoop"
	page.records.settings.vehicle_liveries = {"compact":paint}
	page.records.settings.vehicle_customisation = {"compact":parts}
	root.add_child(page)
	MenuStyle.fill(page)
	check(page._car_art == null and page._car_models.is_empty(),"format page defers all car worlds until the car step")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(960,540),Vector2i(390,844),Vector2i(844,390)]:
		root.size = dimensions
		await settle()
		check(page._formats.get_child_count() == 3,"exactly three challenge formats")
		check(page.get_ok_button().text == "Next" and not page._track_page.is_visible_in_tree(),"format advances with Next before track selection")
		check(page._custom_button.is_visible_in_tree(),"custom remains a separate secondary action")
		inside(page.find_child("ChallengeCreateActions",true,false),"format dock "+str(dimensions))
		var scroll: ScrollContainer = page.find_child("ChallengeCreationScroll",true,false)
		check(scroll.get_h_scroll_bar().max_value <= scroll.size.x+1,"format has no horizontal overflow")
		if DisplayServer.get_name() != "headless" and dimensions.x >= 960:
			var frame: Image = root.get_texture().get_image()
			var diagrams: Array[PackedByteArray] = []
			for card: Button in page._format_buttons:
				var area := Rect2i(card.get_global_position()+Vector2(12,45),Vector2(card.size.x-24,card.size.y-130))
				var graphic: Image = frame.get_region(area)
				graphic.resize(128,96,Image.INTERPOLATE_NEAREST)
				diagrams.append(graphic.get_data())
			check(diagrams[0] != diagrams[1] and diagrams[0] != diagrams[2] and diagrams[1] != diagrams[2],"duel, group and series use visually distinct native diagrams")
		await capture("formats-"+str(dimensions.x)+"x"+str(dimensions.y))
	root.size = Vector2i(1280,720)
	await settle()
	await click(page.find_child("ChallengeFormat_three",true,false))
	await click(page.get_ok_button())
	check(page._step == ChallengeCreate.TRACKS and page._chosen_entries.is_empty(),"3×3 opens track selection without filling slots")
	check(page._browser is TrackBrowser and page._browser.selection_only,"challenge uses the actual Free Race browser")
	for identity: String in ["RandomTrack","RaceFilters","RaceSearch","RefreshTracks"]: check(page._browser.find_child(identity,true,false) != null,"shared Free Race control "+identity)
	check(not page._browser.race_button.is_visible_in_tree(),"track browser cannot launch a race before car selection")
	await settle()
	var card: Button = page._browser.list_grid.get_child(0) as Button
	await click(card)
	check(page._chosen_entries.size() == 1,"native Free Race card selects the first slot")
	page._select_track(tracks[1])
	page._select_track(tracks[1])
	check(page._chosen_entries.size() == 2,"duplicate tracks cannot fill another slot")
	page._select_track(tracks[2])
	await settle()
	check(page._chosen_entries.size() == 3 and page.get_ok_button().text == "Next" and not page.get_ok_button().disabled,"three tracks enable Next only")
	for slot: Button in page._slot_row.get_children(): check(slot.get_theme_stylebox("normal").bg_color != MenuStyle.ACCENT,"functional slot tabs avoid a solid yellow decorative button")
	await capture("three-tracks-1280")
	await click(page.get_ok_button())
	check(page._step == ChallengeCreate.CAR and page._car_page.is_visible_in_tree(),"track confirmation opens the dedicated car page")
	check(page._car_art.car is CarVisual and page._car_art.car.vehicle_id == "compact","hero uses the actual race model")
	check(page._car_art.car.livery == paint and page._car_art.car.customisation == parts,"hero retains the saved paint and body options")
	check(page._car_models.size() == VehicleCatalog.IDS.size(),"all five selectable cards use 3D model views")
	check(page.find_child("ChallengeCarFacts",true,false) == null,"car preview has no right-hand label or description panel")
	var hero: CarShowroom = page._car_art
	var camera_pose: Transform3D = hero.camera.transform
	var environment: Node = hero.camera.get_parent().find_child("GarageArchitecture",true,false)
	var viewport: SubViewport = hero.showroom_viewport
	for id: String in VehicleCatalog.IDS:
		var model: CarShowroom = page._car_models[id]
		check(model.car is CarVisual and model.car.vehicle_id == id and model.read_only and model.mouse_filter == Control.MOUSE_FILTER_IGNORE,"card model matches its vehicle and passes input to "+id)
		check(not model.is_processing(),"card model has no continuous frame work for "+id)
	await carousel_edges(page)
	check(page._share.is_visible_in_tree() and page.get_ok_button().text == "Create & race","group offers sharing and immediate racing on the car page")
	(page.find_child("ChallengeCar_pickup",true,false) as Button).pressed.connect(func() -> void: hero.car_motion.pause(),CONNECT_ONE_SHOT)
	await click(page.find_child("ChallengeCar_pickup",true,false))
	check(page._vehicle_id() == "pickup" and page._car_art.car.vehicle_id == "pickup","native car selection updates the 3D hero and actual vehicle")
	check(page._car_art == hero and hero.showroom_viewport == viewport and environment == hero.camera.get_parent().find_child("GarageArchitecture",true,false),"car selection retains the same hero viewport and environment")
	check(hero.camera.transform.is_equal_approx(camera_pose),"changing to the pickup preserves the exact camera position")
	check(hero.car_motion != null and hero.incoming_reveal != null and hero.outgoing_reveal != null and hero.is_processing(),"challenge uses the garage light-sweep transition with bounded active rendering")
	hero.car_motion.pause()
	hero.car_motion.custom_step(CarShowroom.CAR_HIDE_SECONDS*0.5)
	hero.invalidate_render()
	check(hero.outgoing_reveal.visibility > 0 and hero.outgoing_reveal.visibility < 1 and not hero.turntable.visible,"outgoing car disappears before the incoming car is shown")
	await capture("transition-disappearing")
	hero.car_motion.custom_step(CarShowroom.CAR_HIDE_SECONDS)
	hero.invalidate_render()
	check(hero.turntable.visible and hero.incoming_reveal.visibility > 0 and hero.incoming_reveal.visibility < 1,"incoming car uses the same garage reveal")
	await capture("transition-appearing")
	hero.car_motion.custom_step(CarShowroom.CAR_REVEAL_SECONDS)
	await settle()
	check(hero.car_motion == null and hero.outgoing_pedestal == null and not hero.is_processing(),"completed transition releases the outgoing car and returns to one-shot rendering")
	var retained_model: CarShowroom = page._car_art
	var render_requests: int = retained_model.render_requests
	page._update()
	await settle()
	check(page._car_art == retained_model and retained_model.render_requests == render_requests,"unchanged source status retains the hero without requesting a new render")
	for id: String in VehicleCatalog.IDS:
		await click(page.find_child("ChallengeCar_"+id,true,false))
		check(page._vehicle_id() == id and page._car_art.car.vehicle_id == id,"native card selection keeps the 3D hero in sync for "+id)
		check(hero.camera.transform.is_equal_approx(camera_pose) and hero.showroom_viewport == viewport,"camera and environment stay fixed for "+id)
		hero.finish_car_transition()
		await capture("model-"+id+"-1280x720")
	await click(page.find_child("ChallengeCar_pickup",true,false))
	hero.finish_car_transition()
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(390,844),Vector2i(844,390)]:
		root.size = dimensions
		await settle()
		inside(page.find_child("ChallengeCreateActions",true,false),"car dock "+str(dimensions))
		var slots: int = clampi(floori((page._car_scroll.size.x+12.0)/228.0),1,5)
		var covered: float = 12.0*(slots-1)
		for index: int in range(slots): covered += page._car_cards[index].size.x
		check(absf(covered-page._car_scroll.size.x) <= 1,"visible car cards occupy the entire width at "+str(dimensions)+" (cards="+str(covered)+", available="+str(page._car_scroll.size.x)+")")
		check(absf(page._car_stage.size.x-page._car_page.size.x) <= 1,"hero occupies the full available page width at "+str(dimensions))
		await capture("cars-"+str(dimensions.x)+"x"+str(dimensions.y))
	# A successful final action carries its race intent through the actual adapter.
	var receipt: Dictionary = {}
	page.created_callback = func() -> void: receipt["race"] = page.start_after_create
	client.answer = {"ok":true,"data":invitation(true)}
	await page._create(true)
	check(receipt.get("race",false) and client.payload.vehicle_id == "pickup","successful creation carries the selected car and explicit race intent")
	page.show()
	client.answer = {"ok":true,"data":{"status":"verified","run_id":"exact-finish","ms":88900}}
	root.size = Vector2i(1280,720)
	page._back()
	page._back()
	await settle()
	check(page._step == ChallengeCreate.FORMAT and page._chosen_entries.size() == 3,"Back preserves tracks and selected car")
	check(page._car_art.showroom_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,"leaving the car step disables its hero viewport")
	for model: CarShowroom in page._car_models.values(): check(model.showroom_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,"leaving the car step disables the card viewport")
	await click(page._custom_button)
	check(page._step == ChallengeCreate.RULES and page._custom_page.is_visible_in_tree(),"custom rules occupy the main page")
	check(not page.find_children("*","Window",true,false).any(func(node: Node) -> bool: return (node as Window).visible),"custom rules create no visible popup window")
	(page.find_child("ChallengeTries_1",true,false) as Button).pressed.emit()
	page._back()
	check(page.selected_format == "three" and page.attempt_limit == 3,"Back cancels the whole rules draft")
	page._open_rules()
	(page.find_child("ChallengeTries_5",true,false) as Button).pressed.emit()
	(page.find_child("ChallengeCustomMode_0",true,false) as Button).pressed.emit()
	(page.find_child("ChallengeDuration_86400",true,false) as Button).pressed.emit()
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(390,844)]:
		root.size = dimensions
		await settle()
		inside(page.find_child("ChallengeCreateActions",true,false),"custom dock "+str(dimensions))
		var scroll: ScrollContainer = page.find_child("ChallengeCreationScroll",true,false)
		check(scroll.get_h_scroll_bar().max_value <= scroll.size.x+1,"full-page custom has no horizontal overflow")
		await capture("custom-"+str(dimensions.x)+"x"+str(dimensions.y))
	root.size = Vector2i(1280,720)
	page._advance()
	check(page._step == ChallengeCreate.TRACKS and page.attempt_limit == 5 and page.duration == 86400 and page._chosen_entries.size() == 1,"Next commits the custom rules and opens one-track selection")
	check(not page._slot_row.is_visible_in_tree(),"single-track selection has no redundant top selection button")
	client.answer = {"ok":true,"data":{"status":"not_set","run_id":null,"ms":null}}
	page._advance()
	await settle()
	check(page._step == ChallengeCreate.CAR and page._race.is_visible_in_tree() and page.get_ok_button().disabled,"missing target offers the source drive only after car choice")
	page.race_to_set_requested.connect(func(value: Dictionary, car: String, seconds: int, limit: int, config: Dictionary) -> void: raced = {"entry":value,"car":car,"duration":seconds,"limit":limit,"configuration":config})
	page._race_to_set()
	check(raced.car == "pickup" and raced.limit == 5 and raced.configuration.step == ChallengeCreate.CAR,"source drive remembers car, rules and return page")
	page.queue_free()
	await settle()
	# Both ordinary formats can seed their actual selected track/car with a verified PB.
	for format_id: String in ["duel","group"]:
		client.answer = {"ok":true,"data":{"status":"verified","run_id":"personal-best-"+format_id,"ms":88900}}
		var best_page := ChallengeCreate.new()
		best_page.adapter = adapter
		best_page.entries = tracks
		best_page.initial_configuration = {"tracks":[tracks[0]],"format":format_id,"mode":0 if format_id == "duel" else 1,"step":ChallengeCreate.CAR}
		root.add_child(best_page)
		MenuStyle.fill(best_page)
		await settle()
		var use_best: Button = best_page.get_ok_button() if format_id == "duel" else best_page._share
		check(use_best.text == "Use personal best" and not use_best.disabled,"verified PB is an explicit choice for "+format_id)
		check(best_page._time.text == MenuStyle.time_text(88.9),"personal best time is shown in the action dock for "+format_id)
		for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(390,844),Vector2i(844,390)]:
			root.size = dimensions
			await settle()
			var original_layout: Array[Rect2] = car_layout(best_page)
			client.hold_sources = true
			best_page._select_car("pickup" if best_page._vehicle_id() == "compact" else "compact")
			await settle()
			check(best_page._checking and use_best.disabled,"pending selected-car PB cannot be used for "+format_id)
			check(not best_page._status.is_visible_in_tree(),"ordinary time lookup adds no temporary status row for "+format_id)
			check(car_layout(best_page) == original_layout,"pending car lookup keeps hero/cards/action dock exact at "+format_id+str(dimensions))
			check(best_page.get_ok_button().is_visible_in_tree(),"pending source keeps its action slot for "+format_id)
			best_page._car_art.finish_car_transition()
			await capture("checking-"+format_id+"-"+str(dimensions.x)+"x"+str(dimensions.y))
			client.hold_sources = false
			client.sources_released.emit()
			await settle()
			check(not best_page._checking and not use_best.disabled,"resolved selected-car PB enables its action for "+format_id)
			check(car_layout(best_page) == original_layout,"completed car lookup preserves the same exact layout at "+format_id+str(dimensions))
		root.size = Vector2i(1280,720)
		await settle()
		await capture("personal-best-"+format_id)
		client.answer = {"ok":true,"data":invitation(format_id == "group")}
		await click(use_best)
		check(client.payload.get("source_run_id") == "personal-best-"+format_id and not best_page.start_after_create,"personal best creation does not require a new race for "+format_id)
		best_page.queue_free()
		await settle()
	client.answer = {"ok":true,"data":{"status":"verified","run_id":"exact-finish","ms":88900}}
	var finished := ChallengeCreate.new()
	finished.adapter = adapter
	finished.entries = tracks
	finished.initial_ticket = "exact-slower-ticket"
	finished.initial_vehicle = "compact"
	finished.result_context = {"entry":tracks[0],"total":88.9,"scope":adapter.scope()}
	root.add_child(finished)
	MenuStyle.fill(finished)
	finished._choose_format("three")
	finished._advance()
	finished._select_track(tracks[1])
	finished._select_track(tracks[2])
	finished._advance()
	await settle()
	check(finished._step == ChallengeCreate.CAR and finished._time.text == MenuStyle.time_text(88.9),"exact slower opening time reaches the car page")
	finished._select_car("pickup")
	check(finished._vehicle_id() == "compact" and not finished._car_scroll.is_visible_in_tree(),"finished race pins the exact car")
	check(finished._car_art.car.vehicle_id == "compact" and finished._car_models.is_empty(),"finished race shows its exact 3D car and prepares no alternative card models")
	client.answer = {"ok":false,"error":"Fixture offline"}
	await finished._create(true)
	check(client.payload.mode == "3x3" and client.payload.version_ids == [tracks[0].version_id,tracks[1].version_id,tracks[2].version_id] and client.payload.source_ticket_id == "exact-slower-ticket","creation retains all three tracks and the exact opening receipt")
	check(finished.start_after_create and finished._notice.is_visible_in_tree(),"race intent survives creation and failures remain visible")
	client.player.id = "changed-account"
	finished._update()
	check(finished.get_ok_button().disabled and finished._share.disabled,"account changes fence both final actions")
	finished.queue_free()
	adapter.queue_free()
	cloud.queue_free()
	client.queue_free()
	await settle()
	print("CHALLENGE_CARDS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)
