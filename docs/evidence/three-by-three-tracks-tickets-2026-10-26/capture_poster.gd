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
	if OS.get_environment("BMT_POSTER_BASELINE") == "1":
		page._format_buttons[2].scenery = load("res://assets/menu/challenges/three-by-three-v6.png") as Texture2D
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
			check(diagrams[0] != diagrams[1] and diagrams[0] != diagrams[2] and diagrams[1] != diagrams[2],"duel, group and series use visually distinct illustrations")
		await capture("formats-"+str(dimensions.x)+"x"+str(dimensions.y))
	root.size = Vector2i(1280,720)
	await settle()
	page._choose_format("three")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(960,540),Vector2i(390,844),Vector2i(844,390)]:
		root.size = dimensions
		await settle()
		var scroll: ScrollContainer = page.find_child("ChallengeCreationScroll",true,false)
		scroll.scroll_vertical = ceili(scroll.get_v_scroll_bar().max_value)
		await settle()
		await capture("formats-selected-three-"+str(dimensions.x)+"x"+str(dimensions.y))
	page.queue_free()
	adapter.queue_free()
	cloud.queue_free()
	client.queue_free()
	await settle()
	print("CHALLENGE_POSTER: %d existing format checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)
