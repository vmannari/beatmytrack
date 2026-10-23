extends "res://tests/test_rivalry_result.gd"
const Profile = preload("res://ui/player_profile.gd")
var output: String

class ProfileClient extends Node:
	signal identity_changed
	var player: Dictionary = {"id":"driver_2"}
	var session_path: String = ""
	var _capabilities: Dictionary = {}
	var safety: Node
	var calls: Array[Dictionary] = []
	var fail: bool = false
	var delay: bool = false
	var empty: bool = false
	func _ready() -> void:
		safety = preload("res://backend/community_safety.gd").new()
		safety.client = self
		add_child(safety)
		safety.identity_changed()
	func base_url() -> String: return "http://127.0.0.1:1"
	func signed_in() -> bool: return not player.is_empty()
	func request_api(path: String, method: HTTPClient.Method = HTTPClient.METHOD_GET, payload: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		calls.append({"path":path,"method":method,"payload":payload.duplicate(true)})
		if delay: await get_tree().process_frame
		if fail: return {"ok":false,"error":"NETWORK_ERROR"}
		if path.begins_with("/community/blocks/"):
			return {"ok":true,"data":{"player_id":path.get_file(),"blocked":method == HTTPClient.METHOD_PUT}}
		if path.begins_with("/tracks?"):
			if empty: return {"ok":true,"data":{"items":[],"next_cursor":null}}
			var second: bool = path.contains("cursor=")
			return {"ok":true,"data":{"items":[entry("Sunset circuit" if not second else "Alpine loop","driver_0","second" if second else "first"),entry("Another creator","other","other")],"next_cursor":null if second else "cursor with + /="}}
		return {"ok":false,"error":"UNEXPECTED_REQUEST"}
	func entry(title: String, creator: String, id: String) -> Dictionary:
		return {"name":title,"creator":"Driver 0","creator_id":creator,"track_id":id,"version_id":id,"theme":"desert" if id == "first" else "winter","rating_average":4.6,"rating_count":128,"points":[[0,0],[80,0],[100,40],[55,60],[0,0]]}

func settle() -> void:
	for _frame: int in range(8): await process_frame

func shot(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await settle()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(id+".png")) == OK,"native "+id+" capture")

func profile_on(page: Node) -> Node:
	return page.find_child("RivalryPlayerProfile",true,false)

func activate(label: Label) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	label.gui_input.emit(event)

func run() -> void:
	output = ProjectSettings.globalize_path("res://../docs/evidence/rivalry-profile-cars-2026-10-18/"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(output)
	root.gui_embed_subwindows = true
	var client := ProfileClient.new()
	root.add_child(client)
	var snapshot: Dictionary = fixture()
	var paint: Dictionary = VehicleLivery.defaults("compact")
	paint.colors.body = "247995"
	paint.pattern = str(LiveryCatalog.patterns[33].id)
	var parts: Dictionary = VehicleCustomisation.defaults()
	parts.hood = "cowl"
	parts.aero = "splitwing"
	for driver: Dictionary in snapshot.standings:
		if driver.id == "driver_0": driver.appearance = {"vehicle_id":"compact","livery":paint,"customisation":parts}
	var model := WeeklyRivalry.new()
	model.apply_snapshot(snapshot)
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1720,900)]:
		root.size = dimensions
		var page := WeeklyRivalryPage.new()
		page.model = model
		page.safety_client = client
		page.signed_in = true
		root.add_child(page)
		page.size = dimensions
		await settle()
		var label: Label = page.find_child("RivalryPlayerName_driver_0",true,false)
		check(label != null and label.tooltip_text == "View player","overall name offers the player profile")
		var before: int = client.calls.size()
		activate(label)
		await settle()
		var sheet: Node = profile_on(page)
		check(sheet != null,"selecting the actual overall name opens a profile")
		if sheet == null: quit(1); return
		check(sheet.preview.car.vehicle_id == "compact" and sheet.preview.car.livery == paint and sheet.preview.car.customisation == parts,"profile renders that player's actual shared car and fitted parts")
		check(sheet.preview.condition.is_empty(),"remote profile does not borrow local dirt")
		check(sheet.track_count == 1 and sheet.find_child("PlayerTrack_other",true,false) == null,"same-name results from other account IDs never appear")
		check(client.calls.size() == before+1 and client.calls.back().path.contains("creator=Driver%200") and client.calls.back().method == HTTPClient.METHOD_GET,"opening performs one bounded public catalog read")
		check(sheet.actions.get_popup().item_count == 2 and sheet.actions.text == "…","report and block live in the ellipsis menu")
		var close_button: Button = sheet.find_child("PopupClose",true,false)
		check(sheet.actions.get_parent() == close_button.get_parent() and is_equal_approx(sheet.actions.position.y,close_button.position.y),"ellipsis shares the X header row")
		check(sheet.actions.get_rect().end.x <= close_button.position.x and close_button.position.x-sheet.actions.get_rect().end.x <= 8,"ellipsis sits immediately left of X without overlap")
		check(sheet.actions.size.x >= 48 and sheet.actions.size.y >= 48,"header ellipsis keeps its full touch target")
		check(sheet.find_child("BlockPlayer",true,false) == null and sheet.find_child("ReportReason",true,false) == null,"profile body is car and tracks instead of the safety form")
		check(root.get_visible_rect().encloses(Rect2(sheet.position,sheet.size)),"profile fits "+str(dimensions))
		print("PROFILE_BOUNDS: viewport=%s visible=%s position=%s size=%s minimum=%s" % [dimensions,root.get_visible_rect(),sheet.position,sheet.size,sheet.get_contents_minimum_size()])
		check(sheet.tracks.size.x >= sheet.tracks.get_combined_minimum_size().x,"track rows fit their column")
		await shot("profile-%dx%d" % [dimensions.x,dimensions.y])
		if dimensions.x == 1280:
			sheet.actions.show_popup()
			await shot("player-options")
			sheet.actions.get_popup().hide()
			sheet._action(0)
			await settle()
			var report: Node = null
			for child: Node in sheet.get_children():
				if child is AcceptDialog: report = child
			check(report != null and report.title == "Report player" and report.target.reported_player_id == "driver_0","menu report targets the exact player")
			await shot("report-player")
			if report != null: report.queue_free()
			await settle()
		await sheet._load_tracks()
		check(sheet.track_count == 2 and not sheet.more.visible and client.calls.back().path.contains("cursor=cursor%20with%20%2B%20%2F%3D"),"More tracks preserves the encoded cursor and adds only matching tracks")
		sheet.queue_free()
		await settle()
		page.queue_free()
		await settle()
	# Actual per-track/result boards omit appearances: resolve their account in overall standings.
	root.size = Vector2i(1280,720)
	for section: String in ["detail","result"]:
		var page := WeeklyRivalryPage.new()
		page.model = model
		page.safety_client = client
		page.signed_in = true
		page.section = section
		root.add_child(page)
		page.size = root.size
		await settle()
		var list: Control = page.find_child("RivalryTrackStandingsScroll" if section == "detail" else "RivalryResultStandingsScroll",true,false)
		var label: Label = page.find_child("RivalryTrackDriver_driver_0",true,false).find_child("Name",true,false) if section == "detail" else page.find_child("RivalryResultName_driver_0",true,false)
		check(label != null and label.has_meta("player_profile_action"),section+" board exposes player profiles")
		activate(label)
		await settle()
		var sheet: Node = profile_on(page)
		check(sheet != null and sheet.preview.livery == paint,section+" board resolves the selected account's overall appearance")
		sheet.queue_free()
		await settle()
		if section == "detail":
			var touch := InputEventScreenTouch.new()
			touch.index = 0
			touch.position = label.get_global_rect().get_center()
			touch.pressed = true
			list._input(touch)
			check(profile_on(page) == null,"touch press does not open profile during a scroll")
			var drag := InputEventScreenDrag.new()
			drag.index = 0
			drag.position = touch.position-Vector2(0,40)
			list._input(drag)
			touch.pressed = false
			touch.position = drag.position
			list._input(touch)
			check(profile_on(page) == null,"scroll drag does not select the player")
			list.scroll_vertical = 0
			await settle()
			touch.position = label.get_global_rect().get_center()
			touch.pressed = true
			list._input(touch)
			touch.pressed = false
			list._input(touch)
			await settle()
			check(profile_on(page) != null,"stationary native touch opens the selected profile")
		page.queue_free()
		await settle()
	var row: Dictionary
	for driver: Dictionary in model.standing():
		if driver.get("driver_id") == "driver_0": row = driver
	client.fail = true
	var sheet: Node = Profile.open(root,client,row,"compact")
	await settle()
	check(sheet.track_status.text == "Could not load tracks." and sheet.more.text == "Retry","failed read exposes inline retry without losing car")
	client.fail = false
	client.empty = true
	await sheet._load_tracks()
	check(sheet.track_count == 0 and sheet.track_status.text == "No published tracks yet.","empty response has a truthful public-track state")
	client.empty = false
	await sheet._load_tracks()
	await sheet._action(1)
	check(client.safety.is_blocked("driver_0") and not sheet.preview.visible and sheet.tracks.get_child_count() == 0,"ellipsis block uses shared persistence and immediately hides public profile content")
	check(sheet.actions.get_popup().get_item_text(1) == "Unblock player","blocked profile keeps the reversible menu action")
	await sheet._action(1)
	await settle()
	check(not client.safety.is_blocked("driver_0") and sheet.preview.visible and sheet.track_count == 1,"unblocking restores the original car and reloads public tracks")
	client.player = {"id":"other-account"}
	client.identity_changed.emit()
	await settle()
	check(not is_instance_valid(sheet),"changing account closes the private action context")
	client.queue_free()
	await settle()
	var guest := ProfileClient.new()
	guest.player = {}
	root.add_child(guest)
	sheet = Profile.open(root,guest,row,"compact")
	await settle()
	check(sheet.track_count == 1,"guests can view public car and tracks")
	sheet._action(0)
	await settle()
	var sign_in: Node
	for child: Node in sheet.get_children():
		if child is AcceptDialog: sign_in = child
	check(sign_in != null and sign_in.body.get_child(0).text.contains("Sign in"),"guest report keeps the existing actionable sign-in guidance")
	sheet.queue_free()
	guest.queue_free()
	await settle()
	await artificial_cars()
	print("RIVALRY_PLAYER_PROFILE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func artificial_cars() -> void:
	const Cars = preload("res://ui/artificial_driver_appearance.gd")
	for vehicle: String in VehicleCatalog.IDS:
		var signatures: Dictionary = {}
		for index: int in range(150):
			var appearance: Dictionary = Cars.create("artificial-driver-"+str(index),vehicle)
			check(appearance.vehicle_id == vehicle and VehicleLivery.valid(appearance.livery) and VehicleCustomisation.valid(appearance.customisation),"every generated "+vehicle+" uses allowed cosmetics")
			check(appearance == Cars.create("artificial-driver-"+str(index),vehicle),"each "+vehicle+" appearance is stable across generation")
			if vehicle != "compact": check(appearance.customisation == VehicleCustomisation.defaults(),"fitted parts stay on their supported chassis")
			signatures[JSON.stringify(appearance)] = true
		check(signatures.size() == 150,"all 150 artificial "+vehicle+" cars have distinct combinations")
	var snapshot: Dictionary = fixture()
	for driver: Dictionary in snapshot.standings: driver.is_test_driver = driver.id != snapshot.self_id
	var original: String = JSON.stringify(snapshot)
	var model := WeeklyRivalry.new()
	model.apply_snapshot(snapshot)
	check(JSON.stringify(snapshot) == original,"cosmetic generation leaves the source snapshot and results exact")
	var generated: int = 0
	var selected: Dictionary
	for driver: Dictionary in model.standing():
		if driver.is_test_driver:
			generated += int(driver.has("appearance"))
			if driver.driver_id == "driver_0": selected = driver
		else: check(not driver.has("appearance"),"human drivers do not receive fabricated cosmetics")
	check(generated == 19,"every artificial driver receives their own car even outside the podium")
	check(model.tracks[0].entries.all(func(row: Dictionary) -> bool: return not row.has("appearance")),"track boards retain their original lightweight result projection")
	var shuffled: Dictionary = snapshot.duplicate(true)
	shuffled.standings.reverse()
	shuffled.week += 1
	for row: Dictionary in shuffled.standings: row.name = "Changed display name"
	var other := WeeklyRivalry.new()
	other.apply_snapshot(shuffled)
	for driver: Dictionary in other.standing():
		if driver.driver_id == selected.driver_id: check(driver.appearance == selected.appearance,"name, week and row order do not reroll an artificial car")
	var client := ProfileClient.new()
	root.add_child(client)
	var page := WeeklyRivalryPage.new()
	page.model = model
	page.safety_client = client
	page.signed_in = true
	root.add_child(page)
	page.size = root.get_visible_rect().size
	await settle()
	await shot("artificial-driver-podium")
	page._open_player(selected)
	await settle()
	var sheet: Node = profile_on(page)
	check(sheet.preview.livery == selected.appearance.livery and sheet.preview.customisation == selected.appearance.customisation,"profile and podium share the artificial driver's exact generated car")
	check(car_inside_preview(sheet.preview),"complete artificial car fits inside the profile render")
	await shot("artificial-driver-profile")
	sheet.queue_free()
	await settle()
	client.safety.blocked[selected.driver_id] = selected.name
	client.safety.mask_public(snapshot)
	model.apply_snapshot(snapshot)
	for driver: Dictionary in model.standing():
		if driver.driver_id == selected.driver_id: check(driver.name == "Blocked player" and not driver.has("appearance"),"generation cannot restore a blocked artificial driver's cosmetics")
	page.queue_free()
	await settle()
	client.safety.blocked.clear()
	for vehicle: String in VehicleCatalog.IDS:
		var driver: Dictionary = selected.duplicate(true)
		driver.appearance = Cars.create("profile-frame-check",vehicle)
		sheet = Profile.open(root,client,driver,vehicle)
		await settle()
		check(car_inside_preview(sheet.preview),"complete "+vehicle+" mesh bounds fit inside the profile preview")
		sheet.queue_free()
		await settle()
	client.queue_free()
	await settle()

func car_inside_preview(render: Control) -> bool:
	var camera: Camera3D = render.viewport.get_camera_3d()
	var area := Rect2(Vector2(2,2),Vector2(render.viewport.size)-Vector2(4,4))
	var mesh_count: int = 0
	for mesh: Node in render.car.find_children("*","MeshInstance3D",true,false):
		if not mesh.is_visible_in_tree() or mesh.mesh == null: continue
		mesh_count += 1
		var bounds: AABB = mesh.get_aabb()
		for x: float in [bounds.position.x,bounds.end.x]:
			for y: float in [bounds.position.y,bounds.end.y]:
				for z: float in [bounds.position.z,bounds.end.z]:
					var point: Vector3 = mesh.to_global(Vector3(x,y,z))
					if camera.is_position_behind(point) or not area.has_point(camera.unproject_position(point)):
						print("PROFILE_CAR_FRAME: vehicle=%s mesh=%s point=%s bounds=%s" % [render.vehicle_id,mesh.name,camera.unproject_position(point),area])
						return false
	return mesh_count > 0
