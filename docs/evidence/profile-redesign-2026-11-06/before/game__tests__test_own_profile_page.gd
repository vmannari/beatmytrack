extends SceneTree
## Profile presentation with isolated services; no live account or save access.
var failures: int = 0
var checks: int = 0

class Safety extends Node:
	signal changed
	func allows(_entry: Dictionary) -> bool: return true
	func is_blocked(_id: String) -> bool: return false

class Client extends Node:
	signal identity_changed
	signal reply
	var player: Dictionary = {"id":"owner","display_name":"Driver","country_code":"FI"}
	var _capabilities: Dictionary = {"world_ranking_version":1}
	var safety: Node
	var signed: bool = true
	var delayed: bool = false
	var fail_tracks: bool = false
	func _ready() -> void:
		safety = Safety.new()
		add_child(safety)
	func base_url() -> String: return "http://profile-fixture"
	func signed_in() -> bool: return signed
	func request_api(path: String, _method: int, _payload: Dictionary, _key: String, _auth: bool) -> Dictionary:
		if delayed: await reply
		if path == "/ranking/me": return {"ok":true,"data":{"state":"published","world_rank":128,"points":2450,"results":[],"career":{}}}
		if fail_tracks: return {"ok":false}
		return {"ok":true,"data":{"items":[
			{"creator_id":"someone-else","track_id":"other","name":"Other"},
			{"creator_id":"owner","track_id":"one","name":"Forest Sprint","theme":"pine","points":[[0,0],[10,0],[10,10]],"rating_average":4.6,"rating_count":7}],"next_cursor":""}}

class Account extends Node:
	var client: Node
	func player_name() -> String: return str(client.player.get("display_name",""))

class Awards extends Node:
	signal changed
	var selected: Array = []
	func featured() -> Array: return selected
	func source(_family: Dictionary) -> Dictionary: return {"metrics":{"races":10},"unlocked":{}}

class Cloud extends Node:
	func show_uploads(_ui: Node) -> void: pass

class PictureView extends Node:
	var livery: Dictionary
	var customisation: Dictionary
	var condition: Dictionary
	var preview_key: String = "exact"

class Pictures extends Node:
	var warm_views: Dictionary = {}
	var texture: Texture2D
	func _remembered(_vehicle: String, _key: String) -> Texture2D: return texture

class Preloader extends Node:
	var picture_service: Node
	var picture_records: LocalRecords

class Host extends Node:
	var _garage_preloader: Node
	var online: Node
	var cloud: Node
	var records: LocalRecords
	var achievements: Node
	var root_ui: Node
	var action: String = ""
	func _open_account() -> void: action = "account"
	func _open_race_area() -> void: action = "race"
	func _new_document() -> void: action = "create"
	func _open_profile_tracks() -> void: action = "tracks"
	func _open_profile_achievements(family: String = "") -> void: action = "achievement:"+family
	func _open_published_track(entry: Dictionary) -> void: action = str(entry.get("track_id",""))

func _initialize() -> void: run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+description)

func settle() -> void:
	for i: int in range(12): await process_frame

func make_page(host: Host) -> Control:
	var page: Control = preload("res://ui/own_profile_page.gd").new()
	page.app = host
	page.theme = MenuStyle.theme()
	root.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return page

func run() -> void:
	root.size = Vector2i(1280,720)
	var host := Host.new()
	root.add_child(host)
	var client := Client.new()
	host.add_child(client)
	var account := Account.new()
	account.client = client
	host.online = account
	host.add_child(account)
	var awards := Awards.new()
	host.achievements = awards
	host.add_child(awards)
	var cloud := Cloud.new()
	host.cloud = cloud
	host.add_child(cloud)
	host.root_ui = host
	host.records = LocalRecords.new("user://profile-test-only.json")
	host.records.settings.achievements = AchievementProgress.empty()
	host.records.settings.achievements.metrics = {"races":42,"distance_m":186000,"tracks":18,"clean":12}
	awards.selected = ["races"]
	var page: Control = make_page(host)
	await settle()
	check(page.find_child("ProfilePlayerName",true,false).text == "Driver","identity shown")
	check(page.find_child("ProfilePlayerName",true,false).size.y >= 30,"identity has visible height")
	check(page.find_child("ProfileRacingStats",true,false) != null,"local race statistics shown")
	check("#128" in page.find_child("ProfileRankingStatus",true,false).text,"server ranking shown")
	check(page.find_child("ProfileTrack_one",true,false) != null and page.find_child("ProfileTrack_other",true,false) == null,"tracks use exact creator identity")
	check(page.find_child("ProfileBadge_races",true,false) != null,"featured achievement shown")
	var preloader := Preloader.new()
	host.add_child(preloader)
	host._garage_preloader = preloader
	preloader.picture_records = host.records
	var pictures := Pictures.new()
	preloader.add_child(pictures)
	preloader.picture_service = pictures
	var picture_view := PictureView.new()
	pictures.add_child(picture_view)
	picture_view.livery = VehicleLivery.for_car(host.records.settings,VehicleCatalog.selected)
	picture_view.customisation = VehicleCustomisation.for_car(host.records.settings,VehicleCatalog.selected)
	picture_view.condition = VehicleCondition.read(host.records,VehicleCatalog.selected)
	pictures.warm_views[VehicleCatalog.selected] = picture_view
	pictures.texture = ImageTexture.create_from_image(Image.create(4,4,false,Image.FORMAT_RGBA8))
	page.refresh_car()
	check(page.hero_photo.visible and page.hero_photo.texture == pictures.texture,"exact Garage picture is shown")
	picture_view.livery = {"stale":true}
	page.refresh_car()
	check(not page.hero_photo.visible and page.hero_car.visible,"stale appearance never shows as current car")
	host._garage_preloader = null
	var original_car: String = VehicleCatalog.selected
	VehicleCatalog.selected = "kart"
	page.refresh_car()
	check(page.find_child("ProfileSelectedCarName",true,false).text == VehicleCatalog.title("kart"),"car selection updates profile")
	VehicleCatalog.selected = original_car
	page.refresh_car()
	var capture_path: String = OS.get_environment("BMT_PROFILE_CAPTURE")
	if DisplayServer.get_name() != "headless" and not capture_path.is_empty():
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(capture_path) == OK,"profile capture saved")
	page.find_child("ProfileBadge_races",true,false).pressed.emit()
	check(host.action == "achievement:races","badge opens its achievement")
	page.find_child("ProfileTrack_one",true,false).pressed.emit()
	check(host.action == "one","track opens exact publication")
	page.size = Vector2(400,720)
	page._layout()
	check(page.overview.columns == 1 and page.track_grid.columns == 1,"narrow layout stacks sections")
	page.queue_free()
	await settle()
	client.signed = false
	host.records.settings.achievements = AchievementProgress.empty()
	awards.selected = []
	page = make_page(host)
	await settle()
	check(page.find_child("ProfilePlayerName",true,false).text == "Guest","guest identity shown")
	check(page.find_child("ProfileRacingStats",true,false) == null,"new player sees race empty state")
	check("Sign in" in page.find_child("ProfileRankingStatus",true,false).text,"guest ranking explains sign in")
	page.queue_free()
	await settle()
	client.signed = true
	client.fail_tracks = true
	page = make_page(host)
	await settle()
	check(page.track_action.text == "Retry","failed track read offers retry")
	client.fail_tracks = false
	page.track_action.pressed.emit()
	await settle()
	check(page.find_child("ProfileTrack_one",true,false) != null,"retry loads tracks")
	page.queue_free()
	await settle()
	client.delayed = true
	page = make_page(host)
	await settle()
	client.player.id = "different"
	client.identity_changed.emit()
	client.reply.emit()
	await settle()
	check(not page.visible and page.find_child("ProfileTrack_one",true,false) == null,"account change hides old profile and rejects delayed data")
	page.queue_free()
	host.queue_free()
	await settle()
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(960,540)
	var folder: String = "user://own_profile_integration_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var app: Node = (load("res://core/app.tscn") as PackedScene).instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder)
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+20000
	while not app.startup_complete and Time.get_ticks_msec() < deadline: await process_frame
	check(app.startup_complete,"isolated actual app starts")
	if app.startup_complete:
		app._show_screen("profile")
		await settle()
		if DisplayServer.get_name() != "headless" and not capture_path.is_empty():
			await create_timer(1.5).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(capture_path.get_basename()+"-app.png")
			root.size = Vector2i(1280,720)
			await settle()
			root.get_texture().get_image().save_png(capture_path.get_basename()+"-app-wide.png")
			root.size = Vector2i(960,540)
			await settle()
		check(app.root_ui.find_child("OwnProfilePage",true,false) != null,"actual app opens profile")
		check(app.root_ui.find_child("ProfilePlayerName",true,false).text == "Guest","actual guest profile shows identity")
		app.root_ui.find_child("ProfileChooseAchievements",true,false).pressed.emit()
		await settle()
		check(app.screen == "garage" and app._retained_garage.section == "achievements","profile opens the actual achievement collection")
		app._show_screen("profile")
		app.root_ui.find_child("ManageAccount",true,false).pressed.emit()
		check(app.screen == "account","profile account action opens account")
	app.queue_free()
	await settle()
	print("Own profile: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
