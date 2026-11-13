extends "res://tests/test_rivalry_awards.gd"
## Real automatic modal, immutable facts, dismissal and membership/screen fencing.
const Completion = preload("res://tests/test_rivalry_week_completion.gd")
var service: Node

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/rivalry-empty-week-2026-10-26/ui")
	if RenderingServer.get_current_rendering_method() == "mobile": evidence += "/mobile"
	DirAccess.make_dir_recursive_absolute(evidence)
	var before: bool = "--summary-before" in OS.get_cmdline_user_args()
	var reference_before: bool = "--reference-before" in OS.get_cmdline_user_args()
	if reference_before:
		for source: String in ["res://ui/rivalry_summary_dialog.gd","res://core/app.gd"]:
			var original: GDScript = load(source)
			original.source_code = FileAccess.get_file_as_string("res://../docs/evidence/rivalry-summary-reference-2026-10-26/before/"+source.get_file())
			check(original.reload() == OK,"task-start popup source loads only in isolated memory")
	if before:
		var script: GDScript = load("res://core/app.gd")
		script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/rivalry-summary-popup-2026-10-26/before/app.gd")
		check(script.reload() == OK,"task-start app loads only in isolated process memory")
	var folder: String = "user://summary_popup_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	service = Completion.DelayedClient.new()
	root.add_child(service)
	app.rivalry.client = service
	if reference_before:
		await show_summary("champion","original-reference")
		var original: AcceptDialog = current()
		check(original != null,"task-start popup still opens")
		check(original.find_child("WeeklySummaryContinue",true,false) != null,"reference popup includes the explicit Continue action")
		check(original.find_child("WeeklySummaryRank",true,false) != null,"reference popup presents the oversized earned rank")
		check(original.find_child("WeeklySummaryOpponentPoints",true,false) != null,"reference popup compares actual runner-up points")
		await finish()
		return
	if before:
		await show_summary("champion","before")
		check(current() != null,"a completed week automatically opens its decorated summary")
		check(app.content.find_child("RivalryNextWeek",true,false) != null,"original results screen retains Continue")
		await finish()
		return
	if "--flow-only" in OS.get_cmdline_user_args():
		await lifecycle()
		await continue_flow()
		await finish()
		return
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720),Vector2i(1938,1282)]:
		root.size = dimensions
		for kind: String in ["champion","perfect","podium","middle","unranked","tied"]:
			await show_summary(kind,kind+str(dimensions))
			var dialog: AcceptDialog = current()
			check(dialog != null and dialog.visible,kind+" automatically presents the completed weekly summary")
			if dialog == null: continue
			var summary: Dictionary = app.rivalry.model.finale_summary()
			var values: Array[String] = ["%d / %d" % [int(summary.completed),summary.results.size()],str(int(summary.wins)),str(app.rivalry.model.personal_best_slots.size())]
			for index: int in range(3): check(dialog.metric_labels[index].text == values[index],kind+" metric uses actual final facts")
			check(dialog.ornament.tier == summary.tier,kind+" decorations match the earned achievement")
			check(dialog.perfect.visible == (kind == "perfect"),"Perfect Week requires the actual five outright victories")
			check(dialog.continue_button.is_visible_in_tree() and not dialog.continue_button.disabled,"reference sheet includes the explicit Continue action")
			check(dialog.player_points.text == "%d PTS" % int(summary.points),"points comparison uses the actual player's score")
			check(dialog.rank_label.text == ("—" if summary.rank == null else str(int(summary.rank))),"oversized position is the actual earned rank")
			check(dialog.field_label.text == GameText.message("OF %d DRIVERS") % int(summary.drivers),"final position identifies the actual field size")
			if summary.rank != null and not summary.champion:
				check(dialog.lead_label.text == GameText.message("%d PTS BEHIND") % absi(int(dialog.summary.lead)),"completed-week gap describes the final deficit")
			var empty_week: bool = summary.rank == null and int(summary.completed) == 0
			check(dialog.rank_label.visible == (not empty_week),"an empty week hides the oversized missing-rank dash")
			check(dialog.ornament.empty_week == empty_week,"an empty week omits the rank divider and finish decorations")
			check(dialog.no_results_label.visible == empty_week,"only an empty week explains that there are no completed races")
			if empty_week:
				check(dialog.no_results_label.text == GameText.message("No races completed").to_upper(),"empty-week copy describes the actual missing results")
				check(dialog.hero.get_global_rect().encloses(dialog.no_results_label.get_global_rect()),"empty-week explanation stays inside the banner")
			check(dialog.vehicle.vehicle_id == app.rivalry.model.vehicle_id and dialog.vehicle.livery == VehicleLivery.for_car(app.records.settings,app.rivalry.model.vehicle_id),"small car uses the actual vehicle and local cosmetics")
			var opponent: Dictionary = {}
			for row: Dictionary in app.rivalry.model.standing():
				if row.id != WeeklyRivalry.SELF: opponent = row; break
			check(dialog.opponent_points.text == "%d PTS" % int(opponent.points),"comparison uses the actual runner-up or leader score")
			if summary.champion: check(dialog.lead_label.text.contains(str(int(summary.points)-int(opponent.points))) if int(summary.points) != int(opponent.points) else dialog.lead_label.text == "TIED FOR LEAD","lead badge cannot invent a winning margin")
			check(dialog.find_children("*","ScrollContainer",true,false).is_empty(),"summary fits without a scrollbar")
			check_bounds(dialog,kind+str(dimensions))
			if dimensions == Vector2i(1280,720) and kind in ["champion","middle"]: print("REFERENCE_SHEET ",kind," title=",dialog.heading.get_global_rect()," font=",dialog.heading.get_theme_font_size("font_size")," name=",dialog.driver_label.get_global_rect())
			var page: Control = app.content.find_child("WeeklyRivalryPage",true,false)
			var rectangles: Dictionary = geometry(page)
			var state: String = model_state()
			var calls: int = service.calls.size()
			var next: Button = page.find_child("RivalryNextWeek",true,false)
			if DisplayServer.get_name() != "headless" and kind in ["champion","perfect","unranked"]: await capture(kind,dimensions)
			dialog.confirm_button.pressed.emit()
			await settle()
			check(current() == null,"View results dismisses the modal")
			check(service.calls.size() == calls and model_state() == state,"dismissal performs no acknowledgement, enrollment, score or save mutation")
			check(app.content.find_child("WeeklyRivalryPage",true,false) == page,"dismissal keeps the exact weekly results page")
			check(next.is_visible_in_tree() and not next.disabled,"Continue remains available on the results screen")
			check(geometry(page) == rectangles,"popup and dismissal do not move the weekly components")
			check(root.gui_get_focus_owner() == next,"dismissal restores the original results focus")
			app._rivalry()
			await settle()
			check(current() == null,"ordinary refresh cannot repeat a reviewed summary")
			if DisplayServer.get_name() != "headless" and kind == "champion": await capture("results",dimensions)
	for locale: String in ["en","de","fi","ja"]:
		TranslationServer.set_locale(locale)
		root.size = Vector2i(1280,720)
		await show_summary("champion","locale-"+locale)
		var translated: AcceptDialog = current()
		check(translated != null,"localized completed week presents its summary")
		if translated != null:
			check_bounds(translated,locale)
			if DisplayServer.get_name() != "headless": await capture("locale-"+locale,Vector2i(1280,720))
			await dismiss_weekly_summary()
	TranslationServer.set_locale("en")
	await lifecycle()
	await continue_flow()
	await finish()

func current() -> AcceptDialog:
	return app.root_ui.get_node_or_null("RivalrySummaryDialog") as AcceptDialog

func show_summary(kind: String, group: String, state: String = "complete", cached: bool = false) -> void:
	var snapshot: Dictionary = awarded_snapshot(kind)
	snapshot.group_id = "summary-"+group
	snapshot.state = state
	app.rivalry.model.sample = false
	app.rivalry.model.apply_snapshot(snapshot)
	app.rivalry.snapshot_scope = app.rivalry.scope()
	app.rivalry.cached_snapshot = cached
	app.rivalry.busy = false
	app.rivalry.error = ""
	app.rivalry_section = "overview"
	app._show_screen("rivalry")
	var next: Button = app.content.find_child("RivalryNextWeek",true,false)
	if next != null: next.grab_focus()
	await settle()

func model_state() -> String:
	return JSON.stringify([app.rivalry.model.tracks,app.rivalry.model.server_standings,app.rivalry.model.completed,app.rivalry.model.week,app.records.settings,app.rivalry._continue_key])

func geometry(page: Control) -> Dictionary:
	var values: Dictionary = {}
	for id: String in ["RivalryPodium","RivalryDriversPanel","RivalryTracksPanel","RivalrySectionNavigation"]:
		values[id] = (page.find_child(id,true,false) as Control).get_global_rect()
	return values

func check_bounds(dialog: AcceptDialog, context: String) -> void:
	var bounds := Rect2(Vector2.ZERO,Vector2(dialog.size))
	check(root.get_visible_rect().encloses(Rect2(Vector2(dialog.position),Vector2(dialog.size))),context+" popup fits its viewport")
	for label: Label in dialog.surface.find_children("*","Label",true,false):
		if label.is_visible_in_tree(): check(bounds.grow(0.5).encloses(label.get_global_rect()),context+" text fits: "+label.text)
	for button: Button in dialog.surface.find_children("*","Button",true,false):
		if button.is_visible_in_tree(): check(bounds.encloses(button.get_global_rect()) and button.get_global_rect().size.y >= 52,context+" button fits and keeps a touch target: "+button.name)
	check(bounds.encloses(dialog.confirm_button.get_global_rect()) and dialog.confirm_button.size.y >= 52,"review button remains visible and usable")
	var date: Label = dialog.find_child("WeeklySummaryWeek",true,false)
	check(date.text == GameText.message("WEEK %02d") % dialog.week and date.size.x >= date.get_theme_font("font").get_string_size(date.text,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x,"actual week remains readable in the popup header")
	check(dialog.hero.get_global_rect().end.y <= dialog.player_points.get_global_rect().position.y,"banner clears the points comparison")
	check(dialog.player_points.get_global_rect().end.y <= dialog.metrics.get_global_rect().position.y,"comparison clears the three result cards")
	check(dialog.heading.get_global_rect().end.x < dialog.rank_label.get_global_rect().position.x,"award title stays clear of the oversized rank")
	check(dialog.heading.get_global_rect().end.y <= dialog.driver_label.get_global_rect().position.y,"player name stays below the award title")
	check(bounds.encloses(dialog.continue_button.get_global_rect()) and dialog.continue_button.size.y >= 52,"Continue remains visible and usable")
	check(dialog.confirm_button.get_global_rect().end.x+8 <= dialog.continue_button.get_global_rect().position.x,"the two actions keep separate hit targets")
	if dialog.perfect.visible:
		check(dialog.driver_label.get_global_rect().end.x+6 <= dialog.perfect.global_position.x,"Perfect Week badge clears the player name")

func lifecycle() -> void:
	await show_summary("champion","active","active")
	check(current() == null,"active weeks cannot trigger a results popup")
	await show_summary("champion","cached","complete",true)
	check(current() == null,"cached results wait for authoritative refresh")
	app.rivalry.cached_snapshot = false
	app._rivalry()
	await settle()
	check(current() != null,"authoritative refresh presents the waiting summary")
	await dismiss_weekly_summary()
	await show_summary("perfect","resize")
	var resizing: AcceptDialog = current()
	for dimensions: Vector2i in [Vector2i(1938,1282),Vector2i(960,540),Vector2i(1280,720)]:
		root.size = dimensions
		await settle()
		check(current() == resizing,"resize keeps the same unreviewed summary")
		check_bounds(resizing,"live resize "+str(dimensions))
	await dismiss_weekly_summary()
	await show_summary("champion","other-popup","complete",true)
	var other := AcceptDialog.new()
	other.dialog_text = "Existing modal"
	app._own_dialog(other)
	other.popup_centered(Vector2i(360,200))
	app.rivalry.cached_snapshot = false
	app._rivalry()
	await settle()
	check(current() == null,"weekly summary waits for an existing popup")
	other.hide()
	await settle()
	check(current() != null,"weekly summary opens after the existing popup closes")
	await dismiss_weekly_summary()
	await show_summary("champion","busy-refresh")
	var dialog: AcceptDialog = current()
	app.rivalry.busy = true
	app._rivalry()
	await settle()
	check(current() == dialog and dialog.visible,"background refresh does not interrupt an open summary")
	check(dialog.continue_button.disabled,"background refresh disables the summary's Continue action")
	app.rivalry.busy = false
	app._rivalry()
	await settle()
	check(current() == dialog,"refresh never stacks a second summary")
	var key: String = dialog.receipt_key
	app.rivalry.snapshot_scope = "different-account"
	var stale_calls: int = service.calls.size()
	dialog.continue_button.pressed.emit()
	await settle()
	check(service.calls.size() == stale_calls,"a stale account's summary cannot advance a week")
	check(current() == null,"account scope invalidates the old summary")
	check(not app._reviewed_rivalry_summaries.has(key),"invalidated results are not marked as reviewed")
	app.rivalry.snapshot_scope = app.rivalry.scope()
	app._rivalry()
	await settle()
	check(current() != null,"returning to an unreviewed membership can show its summary")
	dialog = current()
	dialog.close_button.pressed.emit()
	await settle()
	check(current() == null and app._reviewed_rivalry_summaries.has(key),"close icon dismisses without advancing the week")
	await show_summary("champion","changed-results")
	dialog = current()
	var corrected: Dictionary = awarded_snapshot("perfect")
	corrected.group_id = "summary-changed-results"
	app.rivalry.model.apply_snapshot(corrected)
	app._rivalry()
	await settle()
	check(current() != null and current() != dialog and current().summary.perfect,"changed final facts replace a stale unreviewed summary")
	await dismiss_weekly_summary()
	await show_summary("champion","navigation")
	app._show_screen("tracks")
	await settle()
	check(app.root_ui.get_node_or_null("RivalrySummaryDialog") == null,"summary cannot follow navigation to another menu")
	app.rivalry_section = "overview"
	app._show_screen("rivalry")
	if app.menu_page_motion != null: app._finish_menu_page_slide()
	await settle()
	check(current() != null,"returning to unreviewed results presents the summary")
	await dismiss_weekly_summary()
	await show_summary("champion","detail")
	app.rivalry_section = "detail"
	app._rivalry()
	await settle()
	check(current() == null,"detail navigation invalidates the summary")
	await show_summary("champion","sample")
	app.rivalry.model.sample = true
	await settle()
	check(current() == null,"sample scores cannot retain an authoritative celebration")
	await show_summary("champion","input")
	dialog = current()
	var state: String = model_state()
	var calls: int = service.calls.size()
	var next: Button = app.content.find_child("RivalryNextWeek",true,false)
	for pressed: bool in [true,false]:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = pressed
		mouse.position = next.get_global_rect().get_center()
		root.push_input(mouse,true)
		await process_frame
	check(service.calls.size() == calls and current() == dialog,"modal blocks clicking Continue underneath it")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	dialog.push_input(escape,true)
	await settle()
	check(current() == null and model_state() == state and service.calls.size() == calls,"Escape returns to results without rollover")
	await show_summary("champion","enter")
	dialog = current()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	dialog.push_input(enter,true)
	await settle()
	enter.pressed = false
	root.push_input(enter,true)
	await settle()
	check(current() == null and service.calls.size() == calls,"Enter dismisses only the summary and cannot activate Continue on release")

func continue_flow() -> void:
	await show_summary("champion","explicit-continue")
	var dialog: AcceptDialog = current()
	var calls: int = service.calls.size()
	dialog.continue_button.grab_focus()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	dialog.push_input(enter,true)
	# An immediate second activation cannot submit a duplicate request.
	dialog.continue_button.pressed.emit()
	await settle()
	check(current() == null,"explicit Continue closes the sheet")
	check(service.calls.size() == calls+1 and service.pending_path.ends_with("/continue"),"summary Continue uses the existing single scoped acknowledgement")
	var operation: String = service.calls[-1].key
	var next: Button = app.content.find_child("RivalryNextWeek",true,false)
	check(next != null and next.disabled,"underlying Continue stays disabled while the summary's request is running")
	service.respond({"ok":false,"data":{},"error":"CONNECTION_FAILED"})
	await settle()
	check(current() == null and app.rivalry.model.completed and not app.rivalry.error.is_empty(),"failed summary Continue keeps the weekly results and existing retry error")
	next = app.content.find_child("RivalryNextWeek",true,false)
	check(next != null and not next.disabled,"failed rollover can be retried from the unchanged results screen")
	next.pressed.emit()
	check(service.calls[-1].key == operation,"main-screen retry reuses the popup's original operation key")
	service.respond({"ok":true,"data":{"acknowledged":true}})
	await settle()
	check(service.pending_path == "/rivalry/join" and app.rivalry.busy,"summary Continue keeps the existing acknowledgement then enrollment sequence")
	var active: Dictionary = fixture()
	active.group_id = "reference-next-week"
	active.week = 42
	service.respond({"ok":true,"data":active})
	await settle()
	check(app.rivalry.model.week == 42 and not app.rivalry.model.completed and current() == null,"successful enrollment returns to the normal populated weekly overview")

func finish() -> void:
	app.queue_free()
	service.queue_free()
	await process_frame
	print("RIVALRY_SUMMARY_POPUP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
