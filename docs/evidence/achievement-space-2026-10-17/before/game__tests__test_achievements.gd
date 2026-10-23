extends SceneTree
## Isolated persistence, account fencing, actual Trophy Room and native captures.
const Service = preload("res://backend/achievements_client.gd")
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/achievements-2026-10-17/headless"

class Backend extends Node:
	signal identity_changed
	var player: Dictionary = {"id":"fixture-alice"}
	var enabled: bool = true
	var delayed: bool = false
	var calls: Array[String] = []
	var data: Dictionary = {}
	func signed_in() -> bool: return enabled
	func base_url() -> String: return "http://fixture.invalid"
	func request_api(path: String, _method: int = 0, body: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		calls.append(path)
		var result: Dictionary = data.duplicate(true)
		if path.ends_with("/featured"):
			data.states.race.featured = body.families.duplicate()
			result = {"featured":body.families.duplicate()}
		while delayed: await get_tree().process_frame
		return {"ok":true,"status":200,"data":result}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func settle() -> void:
	await create_timer(0.45).timeout
	for tick: int in range(5): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func remote_state(metrics: Dictionary, scope: String) -> Dictionary:
	var data: Dictionary = {"metrics":metrics,"unlocked":{},"featured":[],"revision":1}
	for f: Dictionary in AchievementProgress.catalog().families:
		if f.scope != scope: continue
		for i: int in range(f.tiers.size()):
			if metrics.get(f.metric,0) >= f.tiers[i]: data.unlocked[f.id+"/"+str(i+1)] = 1792195200
	return data

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	root.theme = MenuStyle.theme()
	var folder: String = "user://achievements_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var records := LocalRecords.new(folder.path_join("records.json"))
	records.load_records()
	check(AchievementProgress.catalog().families.size() == 40,"forty achievement families")
	var unlocks: int = 0
	for f: Dictionary in AchievementProgress.catalog().families: unlocks += f.tiers.size()
	check(unlocks == 130,"130 permanent tier and prestige unlocks")
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/"+BuiltinTracks.ids()[0]+".json")
	var laps: Array[float] = [10.0,10.0,10.0,10.0,10.0]
	var facts: Dictionary = {"complete":true,"total":50.0,"previous":60.0,"previous_lap":12.0,"flying":10.0,"incident_free":true,"first_track":true}
	for i: int in range(10):
		track.metadata.theme = AchievementProgress.BIOMES[i%5]
		AchievementProgress.race(records,track,VehicleCatalog.IDS[i%5],laps,facts)
	check(records.save_records() == OK,"race progress commits atomically")
	var local: Dictionary = AchievementProgress.read(records)
	check(local.metrics.races == 10 and local.metrics.tracks == 1,"a repeated circuit counts ten races and one track")
	for key: String in ["races/1","clean/1","untouchable/1","seasons/1","full_grid/1","perfectionist/1","pb_streak/3"]:
		check(local.unlocked.has(key),"local milestone "+key)
	facts.incident_free = false
	facts.previous = 0.0
	AchievementProgress.race(records,track,"compact",laps,facts)
	check(records.save_records() == OK,"broken streak commits")
	check(AchievementProgress.read(records).unlocked.has("untouchable/1") and AchievementProgress.read(records).metrics.clean_streak == 0,"permanent award survives a broken streak")
	var saved_path: String = records.path
	var prior: Dictionary = records.settings.duplicate(true)
	records.path = folder.path_join("missing/records.json")
	AchievementProgress.customise(records,"compact")
	check(records.save_records() != OK and records.settings == prior,"failed save rolls back achievement progress with the appearance")
	records.path = saved_path
	var reload := LocalRecords.new(saved_path)
	reload.load_records()
	check(reload.settings == records.settings,"achievement progress round trips without damaging old profile settings")
	var bad: Dictionary = local.duplicate(true)
	bad.metrics.races = -1
	check(not AchievementProgress.valid(bad),"negative achievement counters rejected")
	bad = local.duplicate(true)
	bad.unlocked["invented/1"] = 1
	check(not AchievementProgress.valid(bad),"unknown achievement unlocks rejected")
	var backend := Backend.new()
	backend.data = {"schema":1,"tracking":"since_launch","states":{
		"race":remote_state({"races":128,"distance_m":285000,"clean":26,"precision":10,"race_pb":13,"lap_pb":17,"tracks":18,"cars":2,"biomes":5,"clean_biomes":5,"clean_streak_best":11,"rivalry_wins":1,"rivalry_podiums":3,"pb_streak_best":5},"race"),
		"creator":remote_state({"publications":3,"creator_plays":735,"creator_reach":215},"creator")},
		"rarity":{"eligible":99,"minimum":100,"unlocks":{},"definition":"Fixture eligible registered drivers"}}
	backend.data.states.race.featured = ["king","seasons","races"]
	root.add_child(backend)
	var service := Service.new()
	service.client = backend
	service.records = records
	service.directory = folder.path_join("cache")
	root.add_child(service)
	service.sync_identity()
	check(backend.calls.is_empty(),"service creation and identity sync make no backend request")
	await service.refresh()
	check(backend.calls.size() == 1 and service.valid(service.snapshot),"explicit collection entry accepts the bounded backend contract")
	await service.refresh()
	check(backend.calls.size() == 1,"repeated entries share a sixty-second cache")
	check(service.source(AchievementProgress.catalog().families[0]).metrics.races == 128,"verified progress is used for signed-in racing")
	check(service.source(AchievementProgress.catalog().families[28]).get("metrics",{}).get("customised",0) == 0,"local garage source remains separate")
	await service.toggle_feature("clean")
	check(service.featured().has("clean") and backend.calls.size() == 2,"feature choice saves through account API")
	await service.toggle_feature("precision")
	await service.toggle_feature("tracks")
	check(service.featured().size() == 5 and backend.calls.size() == 3,"sixth featured achievement is bounded without a request")
	backend.delayed = true
	service._attempt_at = -60000
	service.refresh()
	await process_frame
	backend.player = {"id":"fixture-bob"}
	service.sync_identity()
	backend.delayed = false
	await process_frame
	check(service.snapshot.is_empty(),"late Alice response cannot enter Bob's collection")
	backend.player = {"id":"fixture-alice"}
	service.sync_identity()
	await service.refresh()
	check(service.snapshot.states.race.metrics.races == 128,"account cache restores the correct account")
	VehicleCatalog.selected = "compact"
	var page := GaragePage.new()
	page.records = records
	page.achievements = service
	root.add_child(page)
	MenuStyle.fill(page)
	await settle()
	var requests: int = backend.calls.size()
	page._show_section("trophies")
	await settle()
	check(is_instance_valid(page.find_child("GarageAchievements",true,false)),"Trophy Room exposes the achievement collection")
	check(backend.calls.size() == requests,"viewing the Trophy Room does not issue backend work")
	var wall: Node = page.showroom.find_child("GarageTrophyWall",true,false)
	check(wall.find_children("FeaturedMedal_*","Node3D",true,false).size() == 5,"actual garage wall displays five earned featured medals")
	check(wall.find_children("EarnedTrophy_*","Node3D",true,false).size() <= 6,"major physical trophies retain the six-slot bound")
	capture("trophy-room")
	page._show_section("achievements")
	await settle()
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1720,914)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await settle()
		var album: Node = page.find_child("AchievementsMenu",true,false)
		check(album != null,"album exists at "+str(dimensions))
		check(not page.preview.visible,"album suspends live showroom presentation")
		check(album.grid.get_child_count() == 40,"all families are browsable at "+str(dimensions))
		check(album.get_global_rect().encloses(album.find_child("AchievementDetail",true,false).get_global_rect()),"selected achievement and feature control fit "+str(dimensions))
		check(album.find_child("AchievementScroll",true,false).size.y >= 100,"achievement scroll has usable height "+str(dimensions))
		capture("collection-"+str(dimensions.x))
	var album: Node = page.find_child("AchievementsMenu",true,false)
	var categories: OptionButton = album.find_child("AchievementCategories",true,false)
	for i: int in range(categories.item_count):
		if categories.get_item_text(i) == "Rivalry":
			categories.select(i)
			categories.item_selected.emit(i)
	await settle()
	check(album.grid.get_child_count() == 5,"category selection filters the actual families locally")
	(album.find_child("Achievement_king",true,false) as Button).pressed.emit()
	await settle()
	check(album.selected == "king" and album.detail.get_child(0).text.contains("finalized rivalry"),"selected category card presents its own unlock requirement")
	check(album.find_child("AchievementRarity",true,false).text.contains("100 eligible"),"small rarity populations do not fabricate percentages")
	check(backend.calls.size() == requests,"category and detail browsing issue no backend reads")
	capture("rivalry-category")
	page._show_section("care")
	await settle()
	var dirty: Dictionary = page.showroom.weathering.snapshot()
	dirty.dirt = 0.80
	check(VehicleCondition.save(records,"compact",dirty) == OK,"seed an actually dirty isolated car")
	page._show_section("care")
	page._toggle_wash()
	page.showroom.weathering.wash_image.fill(Color.WHITE)
	page.showroom.weathering.slow_wash_image.fill(Color.WHITE)
	page._toggle_wash()
	check(AchievementProgress.read(records).metrics.get("washes",0) == 1,"finishing a dirty-to-clean wash earns one profile milestone")
	page._toggle_wash()
	page._toggle_wash()
	check(AchievementProgress.read(records).metrics.get("washes",0) == 1,"opening wash mode on a clean car earns no duplicate")
	page._show_section("customise")
	page.draft.colors.body = "175b73"
	page._save()
	check(AchievementProgress.read(records).metrics.get("customised",0) == 1,"first saved appearance earns Personal Touch")
	page.queue_free()
	await settle()
	backend.enabled = false
	service.sync_identity()
	check(service.source(AchievementProgress.catalog().families[0]).metrics.races == 11,"sign-out returns to isolated local progress")
	check(service.snapshot.is_empty(),"sign-out removes verified account achievements from memory")
	check(service.erase_account("http://fixture.invalid","fixture-alice"),"account removal erases scoped achievement cache")
	service.queue_free()
	backend.queue_free()
	await process_frame
	print("ACHIEVEMENTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
