extends "res://tests/test_rivalry_result.gd"
## Player-specific native podiums, bounded static rendering and scoped sync.
const Adapter = preload("res://backend/weekly_rivalry_client.gd")

class AppearanceClient extends Node:
	var player: Dictionary = {"id":"alice"}
	var calls: Array[Dictionary] = []
	var accepted: bool = true
	var pending: bool = false
	func base_url() -> String: return "http://fixture.invalid"
	func signed_in() -> bool: return not player.is_empty()
	func new_operation_key() -> String: return "fixture-ticket"
	func request_api(path: String, method: int, value: Dictionary, _key: String, _authenticated: bool) -> Dictionary:
		calls.append({"path":path,"method":method,"value":value.duplicate(true)})
		if path.ends_with("/tickets"): return {"ok":true,"data":{"marker":"fresh-race"}}
		if pending: await get_tree().process_frame
		return {"ok":accepted,"data":value.duplicate(true)}

func appearance(index: int, id: String = "compact") -> Dictionary:
	var livery: Dictionary = VehicleLivery.defaults(id)
	livery.colors.body = ["c43c28","247995","819c55"][index]
	livery.pattern = str(LiveryCatalog.patterns[[33,40,12][index]].id)
	livery.stickers.hood.id = str(LiveryCatalog.stickers[12+index].id)
	livery.stickers.hood.rotation = -90.0
	var parts: Dictionary = VehicleCustomisation.defaults()
	if id == "compact":
		parts.hood = ["cowl","louvres","scoop"][index]
		parts.aero = ["splitwing","whale","drag"][index]
		parts.rims = ["mesh","five","rallydisc"][index]
		parts.body = ["wide","street","gravel"][index]
	return {"vehicle_id":id,"livery":livery,"customisation":parts}

func run() -> void:
	var evidence_root: String = OS.get_environment("BMT_RIVALRY_CARS_EVIDENCE_DIR")
	if evidence_root.is_empty(): evidence_root = "res://../docs/evidence/rivalry-custom-cars-2026-10-14"
	evidence = ProjectSettings.globalize_path(evidence_root.path_join(RenderingServer.get_current_rendering_method()))
	DirAccess.make_dir_recursive_absolute(evidence)
	var snapshot: Dictionary = fixture()
	for index: int in range(3): snapshot.standings[index].appearance = appearance(index)
	var original: String = JSON.stringify(snapshot)
	var model := WeeklyRivalry.new()
	model.apply_snapshot(JSON.parse_string(original))
	check(VehicleLivery.normalize(model.standing()[0].appearance.livery,"compact") == appearance(0).livery,"remote JSON pigments, wrap and panel sticker survive model mapping")
	check(JSON.stringify(snapshot) == original,"appearance projection retains source standings and scoring")
	await sync_checks()
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,720)]:
		root.size = dimensions
		var page := WeeklyRivalryPage.new()
		page.model = model
		page.signed_in = true
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(page)
		for _frame: int in range(12): await process_frame
		check_podium_alignment(page)
		for index: int in range(3):
			var car: Control = page.find_child("RivalryPodiumCar_"+str(index+1),true,false)
			check(car != null,"all three ranked players get their own native car")
			check(car.car.simple_model,"podium uses the existing simpler 3D model")
			check(car.podium_presentation,"podium applies its independent reflection studio")
			var camera: Camera3D = car.viewport.find_children("*","Camera3D",true,false)[0]
			check((car.car.global_basis*Vector3.FORWARD).dot(camera.global_position-car.car.global_position) > 0.0,"podium turns 180 degrees with its front toward the viewer")
			check(car.viewport.size.x <= 1536 and car.viewport.size.y <= 768,"display-density podium targets retain their bounded resolution")
			check(car.car.vehicle_id == "compact" and car.car.livery == appearance(index).livery,"podium uses that player's complete paint, livery and stickers")
			check(car.car.customisation == appearance(index).customisation,"podium uses that player's four fitted part IDs")
			check(car.condition.is_empty(),"remote podium never receives local dirt or washing")
			check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(car.get_global_rect()),"native cars remain within the smaller hub bounds")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			for index: int in range(3):
				var car: Control = page.find_child("RivalryPodiumCar_"+str(index+1),true,false)
				check(car.viewport.render_target_update_mode <= SubViewport.UPDATE_ONCE,"podium requests only bounded one-shot draws")
			if dimensions.x == 1280:
				var static_draws: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
				for index: int in range(3): page.find_child("RivalryPodiumCar_"+str(index+1),true,false).viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
				for _frame: int in range(4): await process_frame
				await RenderingServer.frame_post_draw
				var live_draws: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
				check(live_draws > static_draws,"settled one-shot podiums omit the native car draw work")
				for index: int in range(3): page.find_child("RivalryPodiumCar_"+str(index+1),true,false).viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
				for _frame: int in range(4): await process_frame
				await RenderingServer.frame_post_draw
				check(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME) == static_draws,"static render work returns after bounded refresh")
				print("PODIUM_DRAW_WORK: static=%d live=%d" % [static_draws,live_draws])
			check(root.get_texture().get_image().save_png(evidence.path_join("hub-%dx%d.png" % [dimensions.x,dimensions.y])) == OK,"native hub evidence saved")
		page.free()
		await process_frame
	var own := WeeklyRivalryPage.new()
	own.model = model
	own.finale_livery = VehicleLivery.defaults("compact")
	own.finale_livery.colors.body = "4d2bb8"
	own.finale_customisation = VehicleCustomisation.defaults()
	own.finale_customisation.aero = "wing"
	own.finale_condition = {"dirt":1.0}
	root.add_child(own)
	var leaders: Array[Dictionary] = model.standing()
	for index: int in range(3):
		if leaders[index].id != WeeklyRivalry.SELF: continue
		var car: Control = own.find_child("RivalryPodiumCar_"+str(index+1),true,false)
		check(car.livery == own.finale_livery and car.customisation == own.finale_customisation,"self podium immediately reflects current local Garage edits")
		check(car.condition.is_empty(),"local dirt stays out of podium appearance payloads")
	own.free()
	var legacy: Dictionary = fixture()
	legacy.standings[0].appearance = {"vehicle_id":"pickup","livery":appearance(0).livery,"customisation":appearance(0).customisation}
	legacy.standings[1].appearance = {"vehicle_id":"compact","livery":{"colors":"malformed"},"customisation":{"aero":"unknown"}}
	model.apply_snapshot(legacy)
	var fallback := WeeklyRivalryPage.new()
	fallback.model = model
	root.add_child(fallback)
	for index: int in range(3):
		var car: Control = fallback.find_child("RivalryPodiumCar_"+str(index+1),true,false)
		check(car.livery.is_empty() and car.customisation.is_empty(),"missing, mismatched or malformed remote appearances safely retain stock models")
	fallback.free()
	var awards: Control = preload("res://ui/rivalry_victory_car.gd").new()
	root.add_child(awards)
	check(not awards.car.simple_model,"awards retain their existing detailed car by default")
	check(not awards.podium_presentation and is_zero_approx(awards.car.rotation.y),"awards retain their original lighting, orientation and compositing")
	awards.free()
	if DisplayServer.get_name() != "headless": await all_vehicle_views()
	print("RIVALRY_CUSTOM_CARS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func check_podium_alignment(page: Control) -> void:
	var winner: Control = page.find_child("RivalryPodium_1",true,false)
	var reference: Array[Rect2] = []
	for place: int in range(1,4):
		var suffix: String = str(place)
		var panel: Control = page.find_child("RivalryPodium_"+suffix,true,false)
		var identity: Control = page.find_child("RivalryPodiumIdentity_"+suffix,true,false)
		var rows: Array[Control] = [page.find_child("RivalryPodiumCar_"+suffix,true,false),identity,
			identity.get_node("PlayerCountryFlag"),page.find_child("RivalryPodiumName_"+suffix,true,false),
			page.find_child("RivalryPodiumPoints_"+suffix,true,false)]
		for row: int in range(rows.size()):
			var bounds: Rect2 = rows[row].get_global_rect()
			if place == 1: reference.append(bounds)
			else:
				check(is_equal_approx(bounds.position.y,reference[row].position.y) and is_equal_approx(bounds.size.y,reference[row].size.y),
					"podium car, identity, flag, name and points rows align across all three cards")
		if place != 1:
			check(winner.size.y > panel.size.y and winner.get_global_rect().position.y < panel.get_global_rect().position.y,
				"aligned podium rows retain the taller central winner card")
	print("PODIUM_ROW_BOUNDS: size=%s rows=%s" % [root.size,reference])

func all_vehicle_views() -> void:
	root.size = Vector2i(1280,720)
	for id: String in VehicleCatalog.IDS:
		var value: Dictionary = fixture()
		value.vehicle_id = id
		for index: int in range(3): value.standings[index].appearance = appearance(index,id)
		var model := WeeklyRivalry.new()
		model.apply_snapshot(JSON.parse_string(JSON.stringify(value)))
		var page := WeeklyRivalryPage.new()
		page.model = model
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(page)
		for _frame: int in range(12): await process_frame
		await RenderingServer.frame_post_draw
		for index: int in range(3):
			var car: Control = page.find_child("RivalryPodiumCar_"+str(index+1),true,false)
			check(car.car.vehicle_id == id and car.car.livery == appearance(index,id).livery,id+" renders each player's actual chassis and livery")
			check(car.car.simple_model,id+" podium uses its actual simpler geometry")
			var picture: Image = car.viewport.get_texture().get_image()
			var occupied: int = 0
			for y: int in range(picture.get_height()):
				for x: int in range(picture.get_width()):
					if picture.get_pixel(x,y).a > 0.5: occupied += 1
			check(occupied > picture.get_width()*picture.get_height()*0.02,id+" native car appears in the bounded render")
		check(root.get_texture().get_image().save_png(evidence.path_join("car-"+id+".png")) == OK,id+" native podium evidence saved")
		page.free()
		await process_frame

func sync_checks() -> void:
	var client := AppearanceClient.new()
	root.add_child(client)
	var adapter: Node = Adapter.new()
	adapter.client = client
	var current: Dictionary = appearance(0)
	adapter.appearance_provider = func(_id: String) -> Dictionary: return current.duplicate(true)
	root.add_child(adapter)
	await adapter._sync_appearance()
	await adapter._sync_appearance()
	check(client.calls.size() == 1 and client.calls[0].value == current,"unchanged appearance sync is reused within its authenticated scope")
	check(client.calls[0].method == HTTPClient.METHOD_PUT and client.calls[0].path == "/rivalry/appearance","cosmetics use the dedicated self-only endpoint")
	check(not client.calls[0].value.has("condition"),"network appearance contains no dirt, washing or canonical tuning")
	current.customisation.aero = "whale"
	await adapter._sync_appearance()
	check(client.calls.size() == 2,"a changed fitted part is uploaded")
	client.player.id = "bob"
	await adapter._sync_appearance()
	check(client.calls.size() == 3,"account switching cannot reuse another player's sync")
	client.accepted = false
	current.livery.colors.body = "000001"
	await adapter._sync_appearance()
	client.accepted = true
	await adapter._sync_appearance()
	check(client.calls.size() == 5,"failed or older-server sync can retry without claiming it was saved")
	client.pending = true
	current.livery.colors.body = "000002"
	adapter._sync_appearance()
	adapter.reset()
	await process_frame
	check(adapter._synced_appearance.is_empty(),"late response after reset cannot seed the next session")
	client.player = {}
	await adapter._sync_appearance()
	check(client.calls.size() == 6,"signed-out local cosmetics never upload")
	client.player = {"id":"bob"}
	current.livery.colors.body = "000003"
	adapter.model.status = "active"
	adapter.snapshot_scope = adapter.scope()
	var ticket: Dictionary = await adapter.ticket(0)
	check(ticket.get("marker") == "fresh-race","cosmetic sharing never delays fresh race authorization")
	await process_frame
	adapter.free()
	client.free()
