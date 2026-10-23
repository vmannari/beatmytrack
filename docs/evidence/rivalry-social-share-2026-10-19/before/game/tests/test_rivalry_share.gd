extends "res://tests/test_rivalry_awards.gd"
## Exercise the real Share action, copied payload, scroll reachability and dismissal.
const ShareDialog = preload("res://ui/rivalry_share_dialog.gd")

class NativeShare extends RefCounted:
	var payloads: Array[String] = []
	func shareChallenge(value: String) -> void: payloads.append(value)

func current_dialog() -> AcceptDialog:
	for child: Node in app.root_ui.get_children():
		if child is AcceptDialog: return child
	return null

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/rivalry-share-polish-2026-10-19/final")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="): evidence = argument.trim_prefix("--evidence=")
	evidence = ProjectSettings.globalize_path(evidence)
	DirAccess.make_dir_recursive_absolute(evidence)
	var folder: String = "user://rivalry_share_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.records.settings.vehicle_liveries = {"compact":{"version":1,"colors":{"body":"993d3d","accent":"e4ba59"}}}
	for dimensions: Vector2i in [Vector2i(1848,937),Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		for kind: String in ["unranked","perfect"]:
			var snapshot: Dictionary = awarded_snapshot(kind)
			if kind == "unranked":
				for slot: int in range(5): snapshot.tracks[slot].entry.name = ["Infinity","Sightseeing","Looper","Curvy","Starter Circuit"][slot]
			else:
				for slot: int in range(5): snapshot.tracks[slot].entry.name = "Snow Castle Championship Circuit - Long Route %d" % (slot+1)
			app.rivalry.model.apply_snapshot(snapshot)
			app.rivalry.snapshot_scope = app.rivalry.scope()
			app.rivalry.busy = false
			app.rivalry.cached_snapshot = false
			app.rivalry_section = "overview"
			app._show_screen("rivalry")
			await settle()
			var share: Button = app.content.find_child("RivalryShareResults",true,false)
			share.grab_focus()
			var payload: String = app.rivalry.model.finale_share_text()
			var original: String = JSON.stringify([app.rivalry.model.tracks,app.rivalry.model.server_standings,app.records.settings])
			share.pressed.emit()
			await settle()
			var dialog: AcceptDialog = current_dialog()
			check(dialog != null and dialog.visible,"real completed-week Share opens its copied confirmation")
			if dialog == null: continue
			if DisplayServer.get_name() != "headless":
				check(DisplayServer.clipboard_get().replace("\r\n","\n") == payload,"clipboard retains every exact result, rank, time and point")
			check(dialog is ShareDialog,"sharing uses a dedicated championship presentation")
			if not dialog is ShareDialog: continue
			var confirm: Button = dialog.confirm_button
			check(dialog.share_text == payload,"structured confirmation preserves the exact copied summary")
			check(root.get_visible_rect().encloses(Rect2(Vector2(dialog.position),Vector2(dialog.size))),"confirmation fits the viewport")
			check(confirm.size.y >= 52 and Rect2(Vector2.ZERO,Vector2(dialog.size)).encloses(confirm.get_global_rect()),"OK remains visible with a full touch target")
			var scroll: ScrollContainer = dialog.copy_scroll
			check(dialog.heading.get_global_rect().end.y+10 <= dialog.get_node("ShareSurface/ShareResults/ShareMetrics").get_global_rect().position.y,"heading stays clear of the summary figures")
			check(scroll.get_global_rect().end.y+12 <= confirm.get_global_rect().position.y,"results viewport stays clear of Done")
			check(dialog.result_rows.size() == 5,"all five actual tracks appear as structured result rows")
			check(not dialog.get_label().visible and not dialog.get_ok_button().visible,"native duplicate text and buttons remain hidden")
			for slot: int in range(dialog.result_rows.size()):
				var row: Control = dialog.result_rows[slot]
				var name_label: Label = row.find_child("TrackName",true,false)
				var time: Label = row.find_child("TrackTime",true,false)
				var points: Label = row.find_child("TrackPoints",true,false)
				var own: Dictionary = dialog.summary.results[slot].own
				if row.get_global_rect().end.y > scroll.get_global_rect().end.y+1:
					print("SHARE_ROW_LAYOUT: ",slot," row=",row.get_global_rect()," viewport=",scroll.get_global_rect()," right=",dialog.right.size)
				check(row.get_global_rect().position.y >= scroll.get_global_rect().position.y-1 and row.get_global_rect().end.y <= scroll.get_global_rect().end.y+1,"all five rows fit before scrolling, including long track names")
				check(name_label.text == str(app.rivalry.model.tracks[slot].name) and row.tooltip_text == name_label.text,"full actual track names remain available")
				check(time.text == ("—" if own.get("ms") == null else MenuStyle.time_text(float(own.ms)/1000.0)) and points.text == str(int(own.get("points",0))),"track time and points match the authoritative snapshot")
				check(name_label.get_global_rect().end.x+10 <= time.get_global_rect().position.x and time.get_global_rect().end.x+10 <= points.get_global_rect().position.x,"names, times and points never overlap")
			check(dialog.vehicle.car.vehicle_id == app.rivalry.model.vehicle_id and dialog.vehicle.car.livery == VehicleLivery.for_car(app.records.settings,app.rivalry.model.vehicle_id),"hero renders the actual event car and local paint")
			check(dialog.copied.get_global_rect().end.x+16 <= confirm.get_global_rect().position.x,"quiet copied status stays clear of Done")
			check(dialog.hero_heading.get_global_rect().end.y <= dialog.identity.get_global_rect().position.y,"award heading stays clear of player identity")
			check((dialog.find_child("SharePerfectWeek",true,false) != null) == (kind == "perfect"),"Perfect Week treatment appears only for five actual outright victories")
			if DisplayServer.get_name() != "headless": await capture("share-"+kind,dimensions)
			if kind == "unranked": confirm.pressed.emit()
			else:
				var close: Button = dialog.close_button
				close.pressed.emit()
			await settle()
			check(current_dialog() == null,"OK and X both remove the owned share dialog")
			check(share.has_focus(),"closing the confirmation returns focus to Share results")
			check(JSON.stringify([app.rivalry.model.tracks,app.rivalry.model.server_standings,app.records.settings]) == original,"sharing preserves scores, tracks and local settings")
	app._share_rivalry_results()
	await settle()
	var compact: AcceptDialog = current_dialog()
	compact.size = Vector2i(820,560)
	await settle()
	check(compact.result_rows[-1].get_global_rect().end.y <= compact.copy_scroll.get_global_rect().end.y+1,"minimum-size card keeps all five results visible")
	check(compact.copy_scroll.get_global_rect().end.y+12 <= compact.confirm_button.get_global_rect().position.y,"minimum-size results stay clear of Done")
	if DisplayServer.get_name() != "headless": await capture("share-compact",Vector2i(820,560))
	compact.close_button.pressed.emit()
	await settle()
	var native := NativeShare.new()
	app.challenge_links._native = native
	var payload: String = app.rivalry.model.finale_share_text()
	app._share_rivalry_results()
	check(native.payloads == [payload] and current_dialog() == null,"native share receives the exact summary once without a copied dialog")
	for blocked: String in ["busy","cached","active","scope"]:
		app.rivalry.busy = blocked == "busy"
		app.rivalry.cached_snapshot = blocked == "cached"
		app.rivalry.model.completed = blocked != "active"
		app.rivalry.snapshot_scope = "another-account" if blocked == "scope" else app.rivalry.scope()
		app._share_rivalry_results()
		check(native.payloads.size() == 1 and current_dialog() == null,"sharing remains guarded for "+blocked+" state")
	app.challenge_links._native = null
	app.queue_free()
	await process_frame
	print("RIVALRY_SHARE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
