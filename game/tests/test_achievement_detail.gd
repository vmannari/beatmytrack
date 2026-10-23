extends SceneTree
## Actual achievement sheets, isolated progress, native layout and input checks.
const Service = preload("res://backend/achievements_client.gd")
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/achievement-detail-2026-10-22/compatibility"
var baseline: bool = false
var album: Control
var service: Node

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func settle() -> void:
	await create_timer(0.22).timeout
	for i: int in range(4): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func earned_state(scope: String, mastered: bool = false) -> Dictionary:
	var state: Dictionary = AchievementProgress.empty()
	for f: Dictionary in AchievementProgress.catalog().families:
		if f.scope != scope: continue
		var level: int = f.tiers.size() if mastered else (1 if f.id in ["races","washes","king"] else 0)
		if level > 0: state.metrics[f.metric] = maxi(int(state.metrics.get(f.metric,0)),int(f.tiers[level-1]))
		for i: int in range(level): state.unlocked[f.id+"/"+str(i+1)] = 1792627200
	return state

func texts(node: Node) -> String:
	var result: String = str(node.get("text")) if node is Label or node is Button else ""
	for child: Node in node.get_children(): result += " "+texts(child)
	return result

func show(id: String) -> void:
	album._show_achievement(id)
	await settle()
	check(root.get_visible_rect().encloses(album._sheet_panel.get_global_rect()),"sheet stays inside viewport: "+id)
	check(album._sheet_panel.size.y <= get_root().size.y-32,"sheet stays within available height: "+id)
	var close: Button = album.find_child("AchievementDetailClose",true,false)
	check(close.size.x >= 52 and close.size.y >= 52,"close retains touch target: "+id)
	if baseline: return
	var copy: String = texts(album._sheet_panel).to_lower()
	for phrase: String in ["saved on this profile","local collection","global rarity","verified account","eligible","track identity","observed outright","revisions"]:
		check(not copy.contains(phrase),"player copy excludes "+phrase+": "+id)
	var requirement: Label = album.find_child("AchievementRequirement",true,false)
	var content: ScrollContainer = album.find_child("AchievementDetailScroll",true,false)
	check(content.get_global_rect().encloses(requirement.get_global_rect()),"objective is visible without scrolling: "+id)
	var feature: Button = album.find_child("AchievementFeature",true,false)
	check(album._sheet_panel.get_global_rect().encloses(feature.get_global_rect()) and feature.size.y >= 52,"feature action stays visible and touch sized: "+id)
	var count: Label = album.find_child("AchievementDetailCount",true,false)
	if count != null:
		check(count.autowrap_mode == TextServer.AUTOWRAP_OFF and count.size.x >= count.get_minimum_size().x,"progress count has readable unwrapped width: "+id)
		check(content.get_global_rect().encloses(count.get_global_rect()),"progress count is visible: "+id)

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
		if arg == "--baseline": baseline = true
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	root.theme = MenuStyle.theme()
	var folder: String = "user://achievement_detail_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var records := LocalRecords.new(folder.path_join("records.json"))
	records.load_records()
	records.settings.achievements = earned_state("local")
	service = Service.new()
	service.records = records
	service.directory = folder.path_join("cache")
	root.add_child(service)
	service.sync_identity()
	album = preload("res://ui/achievements_menu.gd").new()
	album.service = service
	root.add_child(album)
	MenuStyle.fill(album)
	await settle()
	await show("washes")
	capture("detailing-bronze-1280")
	if baseline:
		album._close_sheet()
		print("ACHIEVEMENT_DETAIL_BASELINE: %d checks, %d failures" % [checks,failures])
		quit(1 if failures > 0 else 0)
		return
	check(album.find_child("AchievementRequirement",true,false).text == "Wash a dirty car 5 times.","washing objective has direct player wording")
	check(album.find_child("AchievementNextTier",true,false).text == "NEXT MEDAL / SILVER","bronze medal clearly targets silver")
	check(album.find_child("AchievementDetailProgress",true,false).value == 1 and album.find_child("AchievementDetailProgress",true,false).max_value == 5,"progress uses actual next milestone")
	check(album.find_child("AchievementRarity",true,false) == null,"garage care does not show unavailable rarity")
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	root.push_input(tab,true)
	await process_frame
	check(album.find_child("AchievementFeature",true,false).has_focus(),"Tab reaches the modal action")
	root.push_input(tab,true)
	await process_frame
	check(album.find_child("AchievementDetailClose",true,false).has_focus(),"Tab stays inside the modal")
	var feature: Button = album.find_child("AchievementFeature",true,false)
	feature.pressed.emit()
	await settle()
	check(service.featured().has("washes") and album.find_child("AchievementFeature",true,false).text == "Remove from display","feature updates saved Trophy Room choice")
	album.find_child("AchievementFeature",true,false).pressed.emit()
	await settle()
	check(not service.featured().has("washes"),"remove from display persists")
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1720,914),Vector2i(740,360)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await settle()
		await show("washes")
		capture("detailing-bronze-"+str(dimensions.x))
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	await show("customise")
	check(album.find_child("AchievementFeature",true,false).disabled,"locked medal cannot be displayed")
	check(album.find_child("AchievementRequirement",true,false).text == "Customise 1 car.","singular objectives read naturally")
	capture("locked")
	for f: Dictionary in AchievementProgress.catalog().families:
		await show(str(f.id))
		if f.id == "comeback": capture("prestige-locked")
	var mastered: Dictionary = earned_state("local",true)
	records.settings.achievements = mastered
	service.changed.emit()
	await show("washes")
	check(album.find_child("AchievementNextTier",true,false).text == "COLLECTION COMPLETE","platinum has a completed state")
	check(album.find_child("AchievementDetailProgress",true,false).value == 100,"completed medal keeps full progress")
	capture("platinum")
	# Signed-in rarity uses the original minimum and real cached counts.
	var backend := preload("res://tests/test_achievements.gd").Backend.new()
	root.add_child(backend)
	backend.data = {"schema":1,"states":{"race":earned_state("race")},"rarity":{"eligible":99,"minimum":100,"unlocks":{"king/1":12}}}
	service.client = backend
	service.sync_identity()
	await service.refresh()
	await settle()
	var identity_requests: int = backend.calls.size()
	await show("king")
	check(album.find_child("AchievementRarity",true,false) == null,"small population does not invent rarity")
	service.snapshot.rarity.eligible = 100
	service.changed.emit()
	await settle()
	check(album.find_child("AchievementRarity",true,false).text == "Earned by 12.0% of drivers","eligible rarity uses exact cached ratio")
	capture("prestige-earned")
	service.snapshot.states.race = earned_state("race",true)
	service.snapshot.states.race.featured = ["races","clean","precision","tracks","king"]
	await show("fleet")
	check(album.find_child("AchievementFeature",true,false).disabled,"full five medal display disables a sixth addition")
	check(texts(album._sheet_footer).contains("Remove a medal to make room."),"full display gives a useful next action")
	capture("display-full")
	await show("king")
	check(not album.find_child("AchievementFeature",true,false).disabled,"full display still permits removal")
	service.busy = true
	service.changed.emit()
	await settle()
	check(album.find_child("AchievementFeature",true,false).disabled,"feature remains fenced while saving")
	service.busy = false
	service.changed.emit()
	await settle()
	check(backend.calls.size() == identity_requests,"detail browsing and resize use cached progress only: "+str(backend.calls))
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape,true)
	await settle()
	check(album._sheet_kind.is_empty(),"Escape dismisses the modal")
	check(root.gui_get_focus_owner() == album.find_child("Achievement_king",true,false),"closing restores collection focus")
	await show("washes")
	album.hide()
	await settle()
	check(album._sheet_kind.is_empty(),"navigation hiding releases the modal")
	print("ACHIEVEMENT_DETAIL: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)
