extends SceneTree
## Real native controls with an isolated version-two service; no live accounts or saves.
const Adapter = preload("res://backend/world_ranking_client.gd")
const Fixture = preload("res://tests/test_world_ranking.gd")
var checks: int = 0
var failures: int = 0
var output: String

class PaperHost extends Control:
	var section: String = "news"
	var tools: VBoxContainer

class Service extends Fixture.Service:
	func _ready() -> void:
		super._ready()
		_capabilities.world_ranking_version = 2
	func request_api(path: String, _method: int, _payload: Dictionary, _key: String, _auth: bool) -> Dictionary:
		calls += 1
		paths.append(path)
		var car: String = path.get_slice("vehicle_id=",1).get_slice("&",0)
		if car.is_empty(): car = "overall"
		if delay: await reply
		if path.begins_with("/rivalry/current"):
			return {"ok":true,"data":{"state":"not_joined","week":44,"ends_at":1793577600,"server_now":1792972800}}
		var data: Dictionary = {"policy":"multi-car-circuit-v2","car":car,"state":"published",
			"snapshot_id":1,"week_start":1792972800,"published_at":1793577600,"ranked_count":12000,
			"circuit_cars":VehicleCatalog.IDS.duplicate(),"circuit_weights":{"compact":12000,"electric":11500,"kart":10800,"forklift":10000,"hovercraft":10000,"super_rally":10000}}
		var totals: Dictionary = {"compact":18000,"electric":17000,"kart":16000,"forklift":15000,"hovercraft":14000,"super_rally":13000}
		if path.begins_with("/ranking/me") or path.begins_with("/ranking/players/"):
			data.merge({"world_rank":7,"country_rank":3,"points":27200 if car == "overall" else totals[car],
				"movement":2,"earned":1500,"net_change":200,"points_at_risk":50,"season_points":5000,"season_rank":8,
				"participation_bps":11500,"results":[],"career":{},"cars":[]})
			for id: String in ["compact","electric","kart","forklift","hovercraft","super_rally"]:
				var weight: int = 100 if id == "compact" else 40 if id == "electric" else 15 if id == "kart" else 0
				data.cars.append({"vehicle_id":id,"points":totals[id],"world_rank":3,"counting_weight":weight,
					"contribution_hundredths":int(totals[id])*weight})
			if car != "overall":
				var remaining: int = int(totals[car])
				for index: int in range(12):
					var points: int = mini(1500,remaining)
					remaining -= points
					data.results.append({"week_start":1792972800-index*604800,"points":points,"weekly_place":1,"counting":true})
		else:
			data.items = []
			data.next_cursor = "next-page" if not "cursor=" in path else ""
			for index: int in range(9 if "around=true" in path else 50):
				data.items.append({"player_id":"you" if index == 6 else "","name":"Driver %d" % index,"rank":index+1,
					"world_rank":index+1,"points":(27200 if car == "overall" else int(totals[car]))-index,"season_points":5000-index})
		return {"ok":true,"data":data}

func _initialize() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)

func frames(count: int = 35) -> void:
	for _index: int in range(count): await process_frame

func capture(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	RenderingServer.force_draw(true)
	check(root.get_texture().get_image().save_png(output.path_join(id+".png")) == OK,"capture "+id)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	output = ProjectSettings.globalize_path("res://../docs/evidence/multi-car-world-ranking-2026-11-07").path_join(RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(output)
	var client := Service.new()
	root.add_child(client)
	var adapter: Node = Adapter.for_client(client)
	var response: Dictionary = await adapter.profile()
	check(response.ok and Adapter.valid_profile(response.data) and int(response.data.points) == 27200,"v2 overall accepts bounded scores above v1 ceiling")
	var invalid: Dictionary = response.data.duplicate(true)
	invalid.cars.append(invalid.cars[0])
	check(not Adapter.valid_profile(invalid),"duplicate car rejected")
	invalid = response.data.duplicate(true)
	invalid.cars[0].contribution_hundredths += 1
	check(not Adapter.valid_profile(invalid),"inconsistent contribution rejected")
	invalid = response.data.duplicate(true)
	invalid.points = 27901
	check(not Adapter.valid_profile(invalid),"overall overflow rejected")
	var volt: Dictionary = await adapter.profile("",false,"electric")
	check(volt.ok and int(volt.data.points) == 17000 and "vehicle_id=electric" in client.paths.back(),"car-scoped profile uses separate cache identity")
	var before: int = client.calls
	await adapter.profile()
	check(client.calls == before,"overall cache survives reading a car")
	var host := Control.new()
	root.add_child(host)
	var popup: Node = preload("res://ui/world_ranking.gd").open(host,client)
	await frames()
	check(popup.car_selector.visible and popup.car_selector.item_count == VehicleCatalog.IDS.size()+1,"overall and every playable car offered")
	check("27200" in popup.summary.text and popup.list.get_child_count() == 50,"overall summary and bounded page displayed")
	check(popup.size.x <= root.size.x and popup.size.y <= root.size.y,"overall dialog fits viewport")
	await capture("overall-1280x720")
	popup.selector.select(4)
	popup.selector.item_selected.emit(4)
	await frames()
	check(popup.list.get_child_count() == VehicleCatalog.IDS.size(),"overall results explain all car contributions")
	await capture("contributions-1280x720")
	popup.car_selector.select(4)
	popup.car_selector.item_selected.emit(4)
	await frames()
	check(popup.vehicle_id == "electric" and "17000" in popup.summary.text,"changing car refreshes matching summary")
	check("participation bonus" in popup.detail.text and "15.0%" in popup.detail.text,"announced current-week bonus shown")
	check(popup.list.get_child_count() == 12,"selected-car history remains bounded")
	await capture("volt-results-1280x720")
	popup.car_selector.select(6)
	popup.car_selector.item_selected.emit(6)
	await frames()
	check(popup.vehicle_id == "super_rally" and "13000" in popup.summary.text,"new car has a distinct selectable circuit and summary")
	await capture("super-rally-results-1280x720")
	var original_car: String = VehicleCatalog.selected
	VehicleCatalog.selected = "kart"
	var requested: Array = []
	adapter.circuit_requested.connect(func() -> void: requested.append(adapter.circuit_vehicle))
	popup.circuit_button.pressed.emit()
	await frames()
	check(requested == ["super_rally"] and VehicleCatalog.selected == "kart","selected Super rally Circuit preserves Garage selection")
	var rivalry: Node = preload("res://backend/weekly_rivalry_client.gd").new()
	rivalry.client = client
	root.add_child(rivalry)
	rivalry.set_circuit_mode(true,"electric")
	check(rivalry.vehicle() == "electric" and VehicleCatalog.selected == "kart","official adapter pins chosen car")
	rivalry.set_circuit_mode(false)
	check(rivalry.vehicle() == "kart","leaving Circuit restores ordinary selected-car Rivalry")
	var entry_app := Fixture.EntryApp.new()
	var account := preload("res://backend/account_controller.gd").new()
	account.add_child(account.client)
	account.client._capabilities = client._capabilities.duplicate()
	account.client._sample_time(1793577600)
	Adapter.for_client(account.client).circuit_vehicle = "electric"
	entry_app.online = account
	entry_app.rivalry = rivalry
	entry_app._open_world_circuit()
	check(entry_app.circuit_opened and rivalry.vehicle() == "electric" and VehicleCatalog.selected == "kart","actual App entry routes the chosen car without changing Garage")
	entry_app.online = null
	entry_app.rivalry = null
	entry_app.free()
	account.free()
	rivalry.queue_free()
	VehicleCatalog.selected = original_car
	var news: Node = preload("res://backend/news_client.gd").new()
	news.client = client
	root.add_child(news)
	var paper_host := PaperHost.new()
	root.add_child(paper_host)
	paper_host.tools = VBoxContainer.new()
	paper_host.tools.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	paper_host.add_child(paper_host.tools)
	var paper: Node = preload("res://ui/garage_news_menu.gd").new()
	paper.page = paper_host
	paper.service = news
	paper._tab = "ranking"
	paper_host.tools.add_child(paper)
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		paper_host.position = Vector2(180,80)
		paper_host.size = Vector2(dimensions)-Vector2(190,90)
		paper_host.tools.size = paper_host.size
		await frames(50)
		var ranking: Node = paper._ranking
		check(ranking.rows.get_child_count() == 50,"newspaper prints v2 page at "+str(dimensions))
		check(paper._paper.size.y <= paper._paper_host.size.y+1,"newspaper remains within allocated height at "+str(dimensions))
		check(paper._scroll.get_global_rect().encloses(ranking.rows.get_child(1).get_global_rect()),"two full standing rows are visible at "+str(dimensions))
		check(ranking.car_selector.get_theme_color("font_color").is_equal_approx(paper.INK),"car selector uses newspaper ink")
		await capture("newspaper-"+str(dimensions.x)+"x"+str(dimensions.y))
		if dimensions.x == 960:
			ranking.car_selector.select(4)
			ranking.car_selector.item_selected.emit(4)
			await frames()
			check(ranking.vehicle_id == "electric" and "17000" in ranking.summary.text,"newspaper car selection updates its own summary")
			await capture("newspaper-volt-960x540")
	paper_host.queue_free()
	news.queue_free()
	host.queue_free()
	client.queue_free()
	await frames(10)
	print("WORLD_RANKING_CARS checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
