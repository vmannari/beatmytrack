extends SceneTree
## Actual affected controls, all packaged locales, retained views and local fixtures.
const CODES: Array[String] = ["en","fr","es","de","pt_BR","ja","ko","nl","it","fi","sv","nb"]
const ChallengeFixture = preload("res://tests/test_results_challenge_setup.gd")
const StoreFixture = preload("res://tests/test_store_reference.gd")
const Detail = preload("res://ui/achievement_detail.gd")
var checks: int = 0
var failures: int = 0
var language: Node
var output: String = ""
var stage: PanelContainer

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+TranslationServer.get_locale()+" / "+message)

func settle() -> void:
	for frame: int in range(6): await process_frame

func text(control: Control) -> String:
	var value: String = str(control.get("text"))
	return value if control.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED else control.tr(value)

func texts(node: Node) -> String:
	var value: String = text(node) if node is Label or node is Button else ""
	for child: Node in node.get_children(): value += "\n"+texts(child)
	return value

func present(control: Control, filename: String = "") -> void:
	for child: Control in stage.get_children(): child.hide()
	if control.get_parent() == null: stage.add_child(control)
	control.show()
	await settle()
	if output.is_empty() or filename.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(filename+".png")) == OK,"native capture "+filename)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = ProjectSettings.globalize_path(argument.trim_prefix("--evidence-root="))
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	root.theme = MenuStyle.theme()
	var folder: String = "user://translation_gaps_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	language = root.get_node("Language")
	language.configure(folder.path_join("language.json"))
	var records := LocalRecords.new(folder.path_join("records.json"))
	records.load_records()
	records.settings.achievements = AchievementProgress.empty()
	records.settings.achievements.metrics.washes = 10
	records.settings.achievements.unlocked["washes/1"] = 1792627200
	records.settings.achievements.unlocked["washes/2"] = 1792627200
	var service: Node = preload("res://backend/achievements_client.gd").new()
	service.records = records
	service.directory = folder.path_join("achievements")
	root.add_child(service)
	service.sync_identity()
	stage = PanelContainer.new()
	stage.add_theme_stylebox_override("panel",MenuStyle.card(18))
	root.add_child(stage)
	MenuStyle.fill(stage)
	var settings := SettingsPage.new()
	settings.records = records
	stage.add_child(settings)
	var music: Control = preload("res://ui/garage_records_menu.gd").new()
	music.records = records
	stage.add_child(music)
	var shelf: Control = preload("res://ui/garage_parts_list.gd").new()
	stage.add_child(shelf)
	var biomes := HBoxContainer.new()
	stage.add_child(biomes)
	for id: String in TrackTheme.IDS: biomes.add_child(preload("res://ui/biome_badge.gd").view(id))
	var biome_owner: Node = load("res://core/app.tscn").instantiate()
	biome_owner.document = TrackDocument.create_blank()
	var biome_picker := VBoxContainer.new()
	stage.add_child(biome_picker)
	biome_owner._choose_biome(biome_picker,true)
	var part: Button = preload("res://ui/garage_part_option.gd").new()
	part.setup(1,VehicleCustomisation.OPTIONS.hood[1],VehicleCustomisation.label("hood"),func() -> void: pass)
	shelf.cards.add_child(part)
	var album: Control = preload("res://ui/achievements_menu.gd").new()
	album.service = service
	stage.add_child(album)
	var store_service := StoreFixture.Service.new()
	root.add_child(store_service)
	var store: Control = preload("res://ui/store_page.gd").new()
	store.client = store_service
	stage.add_child(store)
	while store.working: await process_frame
	var client := ChallengeFixture.StubClient.new()
	root.add_child(client)
	var cloud: Node = preload("res://backend/cloud_tracks.gd").new()
	cloud.client = client
	cloud.root_override = folder.path_join("cloud")
	root.add_child(cloud)
	var adapter := ChallengesClient.new()
	adapter.client = client
	adapter.cloud = cloud
	root.add_child(adapter)
	adapter.reset()
	var challenge := ChallengeCreate.new()
	challenge.adapter = adapter
	challenge.records = records
	stage.add_child(challenge)
	var entry: Dictionary = {"version_id":"fixture-version","name":"Language","theme":"pine"}
	var reads: int = store_service.reads
	var rivalry := WeeklyRivalry.new(true)
	rivalry.status = "active"
	var rivalry_page := WeeklyRivalryPage.new()
	rivalry_page.model = rivalry
	rivalry_page.signed_in = true
	stage.add_child(rivalry_page)
	for code: String in CODES:
		check(language.choose(code) == OK,"locale applies")
		await settle()
		var catalog: Translation = TranslationServer.get_translation_object(code)
		for source: String in CameraProfile.TITLES+CameraProfile.DESCRIPTIONS+PersonalGhostRun.TITLES+PersonalGhostRun.DESCRIPTIONS:
			check(not catalog.get_message(source).is_empty(),"packaged settings copy: "+source)
		settings._show_section("camera")
		await present(settings,"camera-"+code if code in ["fi","ja"] else "")
		for source: String in CameraProfile.TITLES+CameraProfile.DESCRIPTIONS:
			check(texts(settings.body).contains(GameText.message(source)),"camera control renders "+source)
		settings._show_section("ghosts")
		await present(settings,"ghosts-fi" if code == "fi" else "")
		for source: String in PersonalGhostRun.TITLES+PersonalGhostRun.DESCRIPTIONS:
			check(texts(settings.body).contains(GameText.message(source)),"ghost control renders "+source)
		rivalry.remaining_seconds = 3*86400+5*3600
		rivalry.received_msec = Time.get_ticks_msec()
		check(rivalry.countdown() == GameText.message("{days}d {hours}h remaining",{"days":3,"hours":5}),"countdown preserves server duration")
		(rivalry_page.get_node("RivalryCountdownTimer") as Timer).timeout.emit()
		check(text(rivalry_page.clock_label) == rivalry.countdown(),"actual Rivalry clock renders the localized countdown")
		await present(rivalry_page,"rivalry-fi" if code == "fi" else "")
		rivalry.status = "settling"
		check(rivalry.countdown() == GameText.message("Final results being verified"),"settling state translates")
		rivalry.status = "active"
		if code != "en": check(not rivalry.countdown().contains("remaining"),"countdown has no English suffix")
		for index: int in TrackTheme.IDS.size():
			check(texts(biomes.get_child(index)).strip_edges() == GameText.message(TrackTheme.title(TrackTheme.IDS[index])).to_upper(),"retained biome badge "+TrackTheme.IDS[index])
		await present(biomes,"biomes-fi" if code == "fi" else "")
		for id: String in TrackTheme.IDS:
			biome_owner._update_creation_biome(biome_picker,id)
			check(text(biome_picker.find_child("BiomeSummaryTitle",true,false)) == GameText.message(TrackTheme.title(id)).to_upper(),"selected creator biome "+id)
			var card: Control = biome_picker.find_child("Biome_"+id,true,false)
			check(text(card.find_child("BiomeTitle",true,false)) == GameText.message(TrackTheme.title(id)).to_upper(),"creator biome card "+id)
		await present(biome_picker,"creator-biomes-fi" if code == "fi" else "")
		for category: String in VehicleCustomisation.CATEGORIES:
			check(not catalog.get_message(VehicleCustomisation.LABELS[category]).is_empty(),"part category "+category)
			for option: Array in VehicleCustomisation.OPTIONS[category]:
				check(not catalog.get_message(str(option[1])).is_empty(),"part option "+str(option[1]))
		shelf.show_choice("Twin louvres",true,true,0,1,10,"hood")
		check(shelf.selected_title == GameText.message("Twin louvres"),"selected part translates before casing")
		check(text(part.title) == GameText.message("Twin louvres").to_upper(),"actual part option caption")
		await present(shelf,"part-fi" if code == "fi" else "")
		records.settings.music_enabled = true
		music._refresh()
		var title: String = preload("res://soundtrack/record_library.gd").selected(records.settings).title
		check(text(music.status) == GameText.message("Playing · {title}",{"title":title}),"playing status keeps the release title")
		await present(music,"playing-fi" if code == "fi" else "")
		records.settings.music_enabled = false
		music._refresh()
		check(text(music.status) == GameText.message("Paused · {title}",{"title":title}),"paused status keeps the release title")
		store.entitlements = store_service.entitlements()
		store._access_summary()
		check(text(store.summary).contains(GameText.message("Ads enabled")),"ads state translates inside slot summary")
		check(text(store.summary).contains("3"),"slot count retained")
		await present(store,"store-fi" if code == "fi" else "")
		challenge.initial_ticket = ""
		challenge._step = ChallengeCreate.FORMAT
		challenge.selected_format = "duel"
		challenge._update()
		check(text(challenge._rule_title) == GameText.message("One-to-one").to_upper(),"challenge format title")
		await present(challenge,"challenge-formats-fi" if code == "fi" else "")
		challenge._step = ChallengeCreate.TRACKS
		challenge.selected_format = "three"
		challenge._chosen_entries = [entry,entry]
		challenge._refresh_tracks()
		challenge._update()
		check(text(challenge._rule_details) == GameText.plural("{selected} / {count} track selected","{selected} / {count} tracks selected",3,{"selected":2}),"selected-track count uses a whole translated message")
		challenge._open_rules()
		check(texts(challenge._rules_fields).contains(GameText.message("Challenge duration")),"custom rule heading translates")
		await present(challenge,"challenge-rules-fi" if code == "fi" else "")
		challenge._chosen_entries = [entry]
		challenge.selected_format = "custom"
		challenge.custom_track_count = 1
		challenge.initial_ticket = "fixture-ticket"
		challenge.attempt_limit = 1
		challenge._source = {"status":"verified","ms":110000}
		challenge._step = ChallengeCreate.CAR
		challenge._update()
		check(text(challenge._rule_details).contains(GameText.plural("{count} try per driver","{count} tries per driver",1)),"singular try in car summary")
		challenge.attempt_limit = 3
		challenge._update()
		check(text(challenge._rule_details).contains(GameText.plural("{count} try per driver","{count} tries per driver",3)),"plural tries in car summary")
		challenge._step = ChallengeCreate.TRACKS
		challenge._update()
		check(text(challenge._rule_details) == "Language","authored track name matching a translation key stays exact")
		album._rebuild()
		album._show_achievement("washes")
		await present(album,"achievement-fi" if code == "fi" else "")
		var family: Dictionary
		for item: Dictionary in AchievementProgress.catalog().families:
			if item.id == "washes": family = item
		var level: int = AchievementProgress.tier(family,service.source(family))
		check(level > 0,"fixture has an earned tier")
		check(text(album.find_child("AchievementEarnedState",true,false)) == GameText.message(["","Bronze earned","Silver earned","Gold earned","Platinum earned"][level]).to_upper(),"earned tier heading translates")
		check(not texts(album._sheet_eyebrow).contains("ACHIEVEMENT") if code != "en" else true,"small category heading translates")
		album._close_sheet()
		if code in ["fi","de","ja","ko"]:
			root.size = Vector2i(960,540)
			settings._show_section("camera")
			await present(settings,"camera-"+code+"-960")
			var scroll: ScrollContainer = settings.find_child("SettingsScroll",true,false)
			check(scroll.get_h_scroll_bar().max_value <= scroll.size.x+1,"compact camera has no horizontal overflow")
			settings._show_section("ghosts")
			await present(settings,"ghosts-"+code+"-960")
			check(scroll.get_h_scroll_bar().max_value <= scroll.size.x+1,"compact ghosts have no horizontal overflow")
			root.size = Vector2i(1280,720)
	check(store_service.reads == reads and store_service.posts == 0,"locale changes only reformat cached store access")
	check(language.choose("en") == OK,"restore English")
	stage.queue_free()
	biome_owner.free()
	adapter.queue_free()
	cloud.queue_free()
	client.queue_free()
	service.queue_free()
	store_service.queue_free()
	await settle()
	print("TRANSLATION_GAPS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
