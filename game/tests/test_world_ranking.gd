extends SceneTree
## Isolated delayed-service UI checks; no production/account/device access.
const Adapter = preload("res://backend/world_ranking_client.gd")
var checks: int = 0
var failures: int = 0
var received: Array[Dictionary] = []

class EntryApp extends "res://core/app.gd":
	var circuit_opened: bool = false
	func _open_rivalry() -> void: circuit_opened = true

class Achievements extends Node:
	func featured() -> Array: return []
	func source(_family: Dictionary) -> Dictionary: return {"metrics":{},"unlocked":{}}

class Safety extends Node:
	signal changed
	func is_blocked(_id: String) -> bool: return false

class Service extends Node:
	signal identity_changed
	var player: Dictionary = {"id":"you"}
	var _capabilities: Dictionary = {"world_ranking_version":1,"world_ranking_launch_week":1792972800}
	var safety: Safety
	var calls: int = 0
	var delay: bool = false
	var paths: Array[String] = []
	signal reply
	func _ready() -> void:
		safety = Safety.new()
		add_child(safety)
	func base_url() -> String: return "http://ranking-fixture"
	func signed_in() -> bool: return true
	func server_now() -> int: return 1793577600
	func request_api(path: String, _method: int, _payload: Dictionary, _key: String, _auth: bool) -> Dictionary:
		calls += 1
		paths.append(path)
		if delay: await reply
		if path.begins_with("/rivalry/current"):
			return {"ok":true,"data":{"state":"not_joined","week":44,"ends_at":1793577600,"server_now":1792972800}}
		if path == "/ranking/me" or path.begins_with("/ranking/players/"):
			return {"ok":true,"data":{"state":"published","world_rank":1284,"points":2480,"movement":36,
				"earned":195,"net_change":135,"points_at_risk":20,"snapshot_id":1,
				"results":[{"week_start":1792972800,"points":195,"weekly_place":2,"counting":true}],
				"career":{"peak_rank":1200,"peak_week":1792972800,"peak_field":20000,"weeks_top100":0,"weeks_no1":0,"victories":2,"season_titles":0}}}
		var items: Array = []
		for index: int in range(9 if "around=true" in path else 50):
			items.append({"player_id":"you" if index == 0 else "", "name":"Driver %d" % index,
				"rank":index+1,"world_rank":index+1,"points":1000-index,"season_points":500-index})
		return {"ok":true,"data":{"state":"published","snapshot_id":1,"published_at":1793577600,
			"ranked_count":1000000,"items":items,"next_cursor":"fixture-next" if not "cursor=" in path else ""}}

func _initialize() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)

func frames(count: int = 12) -> void:
	for _i: int in range(count): await process_frame

func capture_profile(adapter: Node, target: String) -> void:
	received.append(await adapter.profile(target))

func run() -> void:
	var viewport: PackedStringArray = OS.get_environment("BMT_WORLD_VIEWPORT").split("x")
	if viewport.size() != 2: viewport = PackedStringArray(["1280","800"])
	if viewport.size() == 2:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		root.content_scale_size = Vector2i.ZERO
		root.size = Vector2i(int(viewport[0]),int(viewport[1]))
	var client := Service.new()
	root.add_child(client)
	var adapter: Node = Adapter.for_client(client)
	var response: Dictionary = await adapter.profile()
	check(response.ok and int(response.data.points) == 2480,"profile decoded")
	check(Adapter.valid_profile(response.data),"valid profile bounds")
	var oversized: Dictionary = response.data.duplicate(true)
	for _i: int in range(26): oversized.results.append(oversized.results[0])
	check(not Adapter.valid_profile(oversized),"reject oversized result history")
	var cached: Dictionary = await adapter.profile()
	check(cached.ok and client.calls == 1,"repeated summary reads use bounded cache")
	client.identity_changed.emit()
	await adapter.profile()
	check(client.calls == 2,"identity refresh invalidates cached profile")
	var original_vehicle: String = VehicleCatalog.selected
	VehicleCatalog.selected = "pickup"
	var rivalry: Node = preload("res://backend/weekly_rivalry_client.gd").new()
	rivalry.client = client
	var app := EntryApp.new()
	app.rivalry = rivalry
	app._open_world_circuit()
	check(app.circuit_opened and rivalry.vehicle() == "compact" and VehicleCatalog.selected == "pickup","official entry retains Garage car")
	root.add_child(rivalry)
	await rivalry.refresh()
	check("vehicle_id=compact" in client.paths.back(),"official entry fetches Compact")
	rivalry.set_circuit_mode(false)
	check(rivalry.vehicle() == "pickup" and VehicleCatalog.selected == "pickup","return to car Rivalry retains selection")
	app.rivalry = null
	app.free()
	rivalry.queue_free()
	VehicleCatalog.selected = original_vehicle
	client.delay = true
	var calls: int = client.calls
	capture_profile(adapter,"delayed")
	capture_profile(adapter,"delayed")
	await frames()
	check(client.calls == calls+1 and received.is_empty(),"concurrent summary reads coalesce")
	adapter.reset()
	await frames()
	check(received.size() == 1 and not received[0].ok,"identity reset releases coalesced waiter")
	client.reply.emit()
	await frames()
	check(received.size() == 2 and not received[1].ok,"late profile is fenced")
	client.delay = false
	var showroom := CarShowroom.new()
	showroom.garage_mode = true
	showroom.size = Vector2(640,360)
	root.add_child(showroom)
	var achievements := Achievements.new()
	root.add_child(achievements)
	showroom.set_meta("world_ranking_honors",{"season_titles":2,"weeks_no1":1,"weeks_top100":3})
	preload("res://ui/achievement_display.gd").update(showroom,achievements)
	var wall: Node = showroom.find_child("GarageTrophyWall",true,false)
	check(wall.find_children("EarnedTrophy_world_*","Node3D",true,false).size() == 3,"published career facts produce three Garage honors")
	check(wall.find_children("EarnedTrophy_*","Node3D",true,false).size() <= 6,"World honors share bounded trophy slots")
	showroom.set_meta("world_ranking_honors",{"peak_rank":1,"season_titles":0,"weeks_no1":0,"weeks_top100":0})
	preload("res://ui/achievement_display.gd").update(showroom,achievements)
	check(wall.find_children("EarnedTrophy_world_*","Node3D",true,false).is_empty(),"small-field peak or corrected facts do not retain prestige trophies")
	showroom.queue_free()
	achievements.queue_free()
	await frames()
	var host := Control.new()
	root.add_child(host)
	var popup: Node = preload("res://ui/world_ranking.gd").open(host,client)
	await frames()
	check(popup.list.get_child_count() == 50,"one fifty-row page retained")
	check(popup.size.x <= root.size.x and popup.size.y <= root.size.y,"ranking dialog fits viewport %s in %s" % [popup.size,root.size])
	check("1284" in popup.summary.text and "2480" in popup.summary.text,"world summary shown")
	popup._forward()
	await frames()
	check(popup._history.size() == 1 and popup.list.get_child_count() == 50,"next replaces rows")
	popup._previous()
	await frames()
	check(popup._history.is_empty(),"previous restores cursor")
	popup._around = true
	popup._load_page()
	await frames()
	check(popup.list.get_child_count() == 9,"around-player response bounded")
	popup.selector.select(4)
	popup._load_page()
	check(popup.list.get_child_count() == 1,"results uses at most twenty-six rows")
	check("Circuit wins" in popup.status.text,"permanent career facts visible")
	popup.selector.select(0)
	popup._around = false
	popup._load_page()
	await frames()
	if DisplayServer.get_name() != "headless":
		await process_frame
		RenderingServer.force_draw(true)
		var image: Image = root.get_texture().get_image()
		var target: String = OS.get_environment("BMT_WORLD_EVIDENCE")
		if target.is_empty(): target = "res://../docs/evidence/world-ranking-implementation-2026-10-23/native.png"
		check(image.save_png(target) == OK,"native ranking capture saved")
	client.player = {"id":"other"}
	client.identity_changed.emit()
	await frames()
	check(not is_instance_valid(popup),"account switch closes ranking popup")
	client.delay = true
	adapter.reset()
	var delayed: Node = preload("res://ui/world_ranking.gd").open(host,client)
	await frames()
	check(delayed._busy and not delayed.get_ok_button().disabled,"close stays active during slow network")
	delayed.canceled.emit()
	await frames()
	check(not is_instance_valid(delayed),"slow request does not delay close")
	client.reply.emit()
	client.delay = false
	await frames()
	host.queue_free()
	client.queue_free()
	await frames(8)
	print("WORLD_RANKING checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
