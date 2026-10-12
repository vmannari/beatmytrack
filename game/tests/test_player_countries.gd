extends SceneTree
## Isolated fixture evidence; no owner accounts, sessions, scores or drafts touched.
var checks: int = 0
var failures: int = 0
var app: Node
var evidence: String = ProjectSettings.globalize_path("res://../docs/evidence/player-countries-2026-10-07/ui")

class ScoreClient extends "res://backend/backend_client.gd":
	var last_path: String = ""
	func request_api(path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		last_path = path
		return {"ok":true,"status":200,"error":"","data":{"board_id":"fixture","population":3,"next_cursor":null,"next_offset":null,"items":[
			{"rank":1,"display_name":"Finland racer","country_code":"FI","time_ticks":10000},
			{"rank":2,"display_name":"Japan [b]racer[/b]","country_code":"JP","time_ticks":11000},
			{"rank":3,"display_name":"Country not selected","time_ticks":12000}]}}

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+description)

func settle() -> void:
	for _frame: int in range(5): await process_frame

func capture(label: String, dimensions: Vector2i) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join("%s-%dx%d.png" % [label,dimensions.x,dimensions.y])) == OK,"save "+label)

func fixture() -> WeeklyRivalry:
	var model := WeeklyRivalry.new(true)
	var codes: Array[String] = ["FI","GB","JP","DE","BR","US","SE"]
	for track: Dictionary in model.tracks:
		for driver: Dictionary in track.entries:
			driver.country_code = "FI" if driver.id == WeeklyRivalry.SELF else codes[int(str(driver.id).get_slice("_",1))%codes.size()]
	return model

func verify_flags(node: Node) -> void:
	if node.name == "PlayerCountryFlag":
		var view: TextureRect = node as TextureRect
		check(view.texture != null,"standing flag has a bundled texture")
		check(view.size.x >= 20 and view.size.y >= 15,"flag remains readable")
		check(not view.tooltip_text.is_empty(),"flag exposes the country name")
	for child: Node in node.get_children(): verify_flags(child)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	DirAccess.make_dir_recursive_absolute(evidence)
	check(PlayerCountry.countries().size() == 249,"offline country catalog includes all ISO countries/territories")
	check(PlayerCountry.valid_code("fi") == "FI" and PlayerCountry.valid_code("../fi") == "","codes normalize and cannot form arbitrary asset paths")
	check(PlayerCountry.valid_code("ZZ").is_empty() and PlayerCountry.country_name("") == "Country not selected","unknown country uses neutral fallback")
	var texture_bytes: int = 0
	for row: Dictionary in PlayerCountry.countries():
		var artwork: Texture2D = PlayerCountry.texture(str(row.code))
		check(artwork != null and artwork.get_width() <= 64 and artwork.get_height() <= 64,"mobile-sized flag loads: "+str(row.code))
		texture_bytes += artwork.get_image().get_data_size()
	check(texture_bytes < 5*1024*1024,"all picker flag textures stay below 5 MiB including mipmaps")
	print("COUNTRY_FLAG_TEXTURE_BYTES: ",texture_bytes)
	app = load("res://core/app.tscn").instantiate()
	var folder: String = "user://player_country_fixture_"+TrackLibrary.unique_id()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		app.rivalry.model = fixture()
		app.rivalry.model.status = "active"
		app.rivalry.error = ""
		for section: String in ["overview","standings","detail"]:
			app.rivalry_section = section
			app.rivalry_track = 2
			app._show_screen("rivalry")
			await settle()
			var player: Node = app.root_ui.find_child("Driver_you",true,false)
			check(player != null,"own player appears in "+section)
			var flag: TextureRect = player.find_child("PlayerCountryFlag",true,false)
			check(flag != null and flag.get_meta("country_code") == "FI","own country remains beside You in "+section)
			verify_flags(app.root_ui)
			await capture(section,dimensions)
			if section in ["overview","standings"]:
				var gap: Control = app.root_ui.find_child("RivalryPlayerGap_you",true,false)
				var name_label: Control = app.root_ui.find_child("RivalryPlayerName_you",true,false)
				check(flag.get_global_rect().end.x < name_label.get_global_rect().position.x,"flag leaves a clear gap before player name")
				check(name_label.get_global_rect().end.x < gap.get_global_rect().position.x,"name and score columns remain separate")
	var client := ScoreClient.new()
	root.add_child(client)
	client._access_token = "fixture-only"
	client.player = {"id":"fixture-player"}
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		var dialog := preload("res://ui/cloud_leaderboard.gd").new()
		dialog.client = client
		dialog.version = "fixture-version"
		dialog.vehicle = "compact"
		root.add_child(dialog)
		dialog.popup_centered()
		await settle()
		check(dialog.rows.get_parsed_text().contains("Japan [b]racer[/b]"),"player names remain literal alongside inline flags")
		check(dialog.rows.get_parsed_text().contains("Finland racer"),"high-score player names remain visible")
		await dialog.load_page(true)
		check(client.last_path.contains("/around-me"),"nearby standings use the same flag renderer")
		await settle()
		await capture("high-scores",dimensions)
		dialog.queue_free()
		await process_frame
	var picker := preload("res://ui/country_picker.gd").new()
	root.add_child(picker)
	picker.set_country("FI")
	picker._open()
	picker.search.text = "japan"
	picker.search.text_changed.emit(picker.search.text)
	await settle()
	check(picker.matches == ["JP"],"search finds country by name")
	check(picker.items.get_item_rect(0).size.y >= 48,"country choices have touch-sized rows")
	picker._choose(0)
	check(picker.country_code == "JP" and not picker.dialog.visible,"choosing a country closes picker and updates selection")
	picker._open()
	picker.search.text = "FI"
	picker.search.text_changed.emit(picker.search.text)
	check("FI" in picker.matches,"search accepts country code")
	await settle()
	await capture("country-picker",Vector2i(root.size))
	picker.queue_free()
	client.queue_free()
	app.queue_free()
	await process_frame
	print("PLAYER_COUNTRY_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
