extends SceneTree
## Committed local grants, authoritative snapshots, input, lifecycle and native views.
const Service = preload("res://backend/achievements_client.gd")
const Banner = preload("res://ui/achievement_notification.gd")
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/achievement-overlay-2026-10-22/headless"
var baseline: bool = false
var grants: Array[Dictionary] = []

class Backend extends Node:
	var player: Dictionary = {"id":"overlay-alice"}
	var enabled: bool = false
	var calls: int = 0
	var hold: bool = false
	var ok: bool = true
	var data: Dictionary = {"schema":1,"states":{},"rarity":{"eligible":0,"minimum":100,"unlocks":{}}}
	func signed_in() -> bool: return enabled
	func base_url() -> String: return "http://overlay.invalid"
	func request_api(_path: String, _method: int = 0, _body: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		calls += 1
		var result: Dictionary = data.duplicate(true)
		while hold: await get_tree().process_frame
		return {"ok":ok,"status":200 if ok else 503,"data":result}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func settle() -> void:
	for frame: int in range(5): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func state(id: String, tier: int) -> Dictionary:
	var result: Dictionary = AchievementProgress.empty()
	for family: Dictionary in AchievementProgress.catalog().families:
		if family.id != id: continue
		result.metrics[family.metric] = int(family.tiers[tier-1])
		for i: int in range(tier): result.unlocked[id+"/"+str(i+1)] = 1792627200
	return result

func service_checks(folder: String) -> void:
	var records := LocalRecords.new(folder.path_join("records.json"))
	check(records.save_records() == OK,"initial isolated profile commits")
	var backend := Backend.new()
	root.add_child(backend)
	var service := Service.new()
	service.records = records
	service.client = backend
	service.directory = folder.path_join("cache")
	root.add_child(service)
	service.sync_identity()
	service.unlocked.connect(func(item: Dictionary) -> void: grants.append(item))
	AchievementProgress.wash(records)
	check(grants.is_empty(),"editing progress before saving announces nothing")
	check(records.save_records() == OK and grants.size() == 1 and grants[0].family == "washes" and grants[0].tier == 1,"committed wash grants exactly its earned bronze medal")
	records.save_records()
	check(grants.size() == 1,"unchanged saves never repeat an unlock")
	var original: String = records.path
	records.path = folder.path_join("missing/records.json")
	records.settings.achievements = state("washes",2)
	check(records.save_records() != OK and grants.size() == 1,"failed save rolls back without a silver notification")
	records.path = original
	records.settings.achievements = state("washes",4)
	records.save_records()
	check(grants.size() == 2 and grants.back().tier == 4,"multi-tier grant announces the highest medal once")
	backend.enabled = true
	backend.data.states.race = state("races",1)
	service.sync_identity()
	await service.refresh() # The app requests the sign-in baseline explicitly.
	await settle()
	check(backend.calls == 1 and grants.size() == 2,"first account snapshot establishes history without replaying old awards")
	# Client guesses cannot award an authenticated player's race medals.
	records.settings.achievements = state("races",4)
	records.save_records()
	check(grants.size() == 2,"account race awards ignore local unverified progress")
	backend.data.states.race = state("races",3)
	service.refresh_after_activity()
	service.refresh_after_activity()
	service.refresh_after_activity()
	await create_timer(1.15).timeout
	check(backend.calls == 2 and grants.size() == 3 and grants.back().family == "races" and grants.back().tier == 3,"coalesced verified activity reads once and announces authoritative gold")
	await service.refresh(true)
	check(grants.size() == 3,"repeated server snapshots never repeat awards")
	backend.ok = false
	backend.data.states.race = state("races",4)
	await service.refresh(true)
	check(grants.size() == 3,"failed response never announces an award")
	backend.ok = true
	backend.hold = true
	service.refresh(true)
	backend.player.id = "overlay-bob"
	service.sync_identity()
	backend.hold = false
	await settle()
	check(grants.size() == 3 and service.scope.ends_with("overlay-bob") and service.snapshot.is_empty(),"late response cannot award or leak the previous account")
	await service.refresh() # Establish Bob's own collection before his next grant.
	backend.data.states.creator = state("published",1)
	# Resolve the actual creator family, keeping this fixture independent of IDs.
	for family: Dictionary in AchievementProgress.catalog().families:
		if family.scope == "creator":
			backend.data.states.creator = state(str(family.id),1)
			break
	await service.refresh(true)
	check(grants.size() == 4 and grants.back().scope == service.scope,"fresh authoritative creator medal is announced in its own account")
	service.free()
	backend.free()

func input_passthrough(banner: Control) -> void:
	var button := Button.new()
	button.position = banner._card.position
	button.size = banner._card.size
	var hits: Array[int] = [0]
	button.pressed.connect(func() -> void: hits[0] += 1)
	root.add_child(button)
	root.move_child(button,0)
	var point: Vector2 = button.get_global_rect().get_center()
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event,true)
	check(hits[0] == 1,"mouse clicks pass through the whole visible banner")
	for pressed: bool in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 4
		event.position = point
		event.pressed = pressed
		root.push_input(event,true)
	check(hits[0] == 2,"touch taps pass through the whole visible banner")
	button.free()

func app_checks(folder: String) -> void:
	var app: Node
	if baseline:
		var old := GDScript.new()
		old.source_code = FileAccess.get_file_as_string("res://../docs/evidence/achievement-overlay-2026-10-22/before/game/core/app.gd")
		check(old.reload() == OK,"preserved original app compiles")
		app = old.new()
	else:
		app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("app/records.json"))
	DirAccess.make_dir_recursive_absolute(app.records.path.get_base_dir())
	app.records.settings.achievements = AchievementProgress.empty()
	app.records.settings.achievements.metrics.races = 9
	app.records.save_records()
	app.library = TrackLibrary.new(folder.path_join("app/tracks"))
	app.cloud_root_override = folder.path_join("app/cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("tracks")
	var banner: Control = app.get("achievement_notification")
	check(is_instance_valid(banner),"real app installs the achievement overlay")
	var document: Dictionary = TrackDocument.create_default()
	document.id = "achievement_overlay_fixture"
	var track: NativeTrack = TrackCompiler.compile(document)
	app.selected_track = track
	track.metadata.cloud_version = "isolated-achievement-overlay-fixture"
	await app._start_race(track,false,true)
	check(is_instance_valid(app.game),"real app starts the isolated driving scene")
	if not is_instance_valid(app.game): app.free(); return
	track.metadata.erase("cloud_version")
	app.game.set_physics_process(false)
	app.game.countdown_ticks = 0
	app.game.race_cues.hide()
	app._publishing_slots_foreground = true # Native capture windows need not own OS focus.
	if baseline:
		AchievementProgress.wash(app.records)
		app.records.save_records()
		await settle()
		capture("original-driving-no-award-overlay")
		app.free()
		return
	check(app.cloud.race_verified.is_connected(app.achievements.refresh_after_activity),"accepted race receipts feed the actual achievement client")
	check(app.lifecycle.publication_accepted.is_connected(app.achievements.refresh_after_activity),"accepted publication receipts feed the actual achievement client")
	AchievementProgress.wash(app.records)
	app.records.save_records()
	await settle()
	check(not banner.current.is_empty() and banner.current.family == "washes" and banner._card.visible,"committed award appears over the real driving scene")
	banner.set_process(false)
	banner.elapsed = 0.0
	banner._process(0.12)
	banner.set_process(false)
	await settle()
	capture("driving-entrance")
	banner._process(0.55)
	banner.set_process(false)
	await settle()
	capture("driving-bronze-1280")
	check(banner._title.text == "Detailing Expert" and banner._tier.text == "BRONZE","earned name and metal match the actual grant")
	await input_passthrough(banner)
	var before: float = banner.elapsed
	app.game.countdown_ticks = 120
	banner._process(1.0)
	check(not banner._card.visible and banner.elapsed == before,"countdown defers the banner without consuming its lifetime")
	app.game.countdown_ticks = 0
	app.game.paused = true
	banner._process(1.0)
	check(not banner._card.visible and banner.elapsed == before,"pause screen defers without consuming its lifetime")
	app.game.paused = false
	app._publishing_slots_foreground = false
	banner._process(1.0)
	check(not banner._card.visible and banner.elapsed == before,"background suspension retains the pending award")
	app._publishing_slots_foreground = true
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1720,914),Vector2i(1280,720)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await settle()
		app._publishing_slots_foreground = true
		banner._process(0.01)
		banner.set_process(false)
		await settle() # Capture the shown banner after the resized frame is drawn.
		check(banner._card.visible,"award remains visible during resized capture "+str(dimensions))
		check(root.get_visible_rect().encloses(banner._card.get_global_rect()),"banner stays inside "+str(dimensions))
		var hud: Node = app.game.hud
		for label: String in ["RaceCard","TimingCard"]:
			var card: Control = hud.find_child(label,true,false)
			check(not banner._card.get_global_rect().intersects(card.get_global_rect()),"banner clears "+label+" at "+str(dimensions))
		check(banner._description.get_line_count() <= 2,"requirement fits at "+str(dimensions))
		if DisplayServer.get_name() != "headless":
			var sample: Color = root.get_texture().get_image().get_pixelv(Vector2i(banner._card.position+Vector2(banner._card.size.x-12,20)))
			check(absf(sample.r-12.0/255.0) < 0.02 and absf(sample.g-25.0/255.0) < 0.02 and absf(sample.b-34.0/255.0) < 0.02,"rendered capture includes the actual award panel "+str(dimensions))
		capture("driving-bronze-"+str(dimensions.x))
	banner.clear()
	for tier: int in [1,2,3,4]:
		banner.enqueue({"scope":app.achievements.scope,"family":"races","tier":tier})
	check(banner.pending.size() == 1 and banner.pending[0].tier == 4,"queued upgrades coalesce to one highest medal")
	banner._process(0.5)
	banner.set_process(false)
	check(banner.current.tier == 4 and banner._tier.text == "PLATINUM","coalesced tier displays the correct platinum art")
	await settle()
	capture("driving-platinum")
	banner.enqueue({"scope":app.achievements.scope,"family":"king","tier":1})
	banner._process(Banner.ENTER+Banner.HOLD+Banner.EXIT)
	check(banner.current.is_empty() and not banner._card.visible,"award exits automatically")
	banner._process(Banner.GAP+0.01)
	banner.set_process(false)
	check(banner.current.family == "king" and banner._tier.text == "PRESTIGE","next award follows with its actual prestige treatment")
	await settle()
	capture("driving-prestige")
	banner.clear()
	# Completing a real app session commits the threshold and queues race awards.
	var session: TrackSession = app.game.track_session
	session.finished = true
	session.completed_laps = RaceRules.LAPS
	session.elapsed_ticks = 6000
	session.lap_start_time = 50.0
	session.lap_times.assign([10.0,10.0,10.0,10.0,10.0])
	app.game.attempt_practice = false
	app.game.paused = true
	app._results()
	await settle()
	check(AchievementProgress.read(app.records).unlocked.has("races/1"),"completed app session actually grants Born to Race")
	if banner.current.is_empty() or banner.current.get("family") != "races":
		print("RESULT_OVERLAY_STATE: ",{"current":banner.current,"pending":banner.pending,"allowed":banner._allowed(),"scope":app.achievements.scope,"known":app.achievements._known,"screen":app.screen,"foreground":app._publishing_slots_foreground})
	check(not banner.current.is_empty() and banner.current.family == "races","real results grant is shown above the result screen")
	var result_panel: RaceResults = app.root_ui.find_child("RaceResults",true,false)
	check(result_panel != null and result_panel.saved,"the result grant comes from a successfully saved completed race")
	banner.set_process(false)
	banner.elapsed = 0.7
	banner._process(0.01)
	banner.set_process(false)
	await settle()
	capture("results-earned")
	var queued: int = banner.pending.size()
	app._results()
	check(banner.pending.size() == queued,"repeated result callback creates no duplicate notifications")
	banner.enqueue({"scope":"another-account","family":"races","tier":4})
	check(banner.pending.size() == queued,"foreign account grant cannot enter the overlay")
	app.achievements.scope = "another-account"
	app.achievements.changed.emit()
	check(banner.pending.is_empty() and banner.current.is_empty() and not banner._card.visible,"identity change immediately clears current and pending awards")
	# Every actual objective and every possible medal fits the bounded queue.
	app.root_ui.hide()
	for family: Dictionary in AchievementProgress.catalog().families:
		for i: int in range(family.tiers.size()):
			banner.enqueue({"scope":"another-account","family":str(family.id),"tier":i+1})
	check(banner.pending.size() == 40 and banner._seen.size() == Banner.CAPACITY,"all 130 distinct grants remain bounded and coalesce into forty families")
	var total: int = banner.pending.size()
	banner.enqueue({"scope":"another-account","family":"unknown","tier":1})
	banner.enqueue({"scope":"another-account","family":"races","tier":5})
	check(banner.pending.size() == total,"malformed awards cannot enter the presentation queue")
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1720,914)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await settle()
		for item: Dictionary in banner.pending:
			banner._begin(item)
			check(banner._description.get_line_count()*banner._description.get_line_height() <= banner._description.size.y+1,"complete objective fits "+str(item.family)+" at "+str(dimensions))
			check(banner._card.size.y <= 160,"long honor retains a compact banner "+str(item.family)+" at "+str(dimensions))
	banner.clear()
	app.free()
	await settle()

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="): output = argument.trim_prefix("--evidence=")
		if argument == "--baseline":
			baseline = true
			output = "res://../docs/evidence/achievement-overlay-2026-10-22/original"
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	create_timer(150).timeout.connect(func() -> void: print("FAIL: achievement overlay deadline"); quit(1))
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var folder: String = "user://achievement_overlay_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	if baseline:
		var old := GDScript.new()
		old.source_code = FileAccess.get_file_as_string("res://../docs/evidence/achievement-overlay-2026-10-22/before/game/backend/achievements_client.gd")
		check(old.reload() == OK,"preserved original client compiles")
		var original: Node = old.new()
		check(original.has_signal("unlocked"),"achievement grants have a notification signal")
		original.free()
	else:
		await service_checks(folder)
	await app_checks(folder)
	print("ACHIEVEMENT_NOTIFICATION: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
