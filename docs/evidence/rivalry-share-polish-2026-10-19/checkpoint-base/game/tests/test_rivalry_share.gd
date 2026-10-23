extends "res://tests/test_rivalry_awards.gd"
## Exercise the real Share action, copied payload, scroll reachability and dismissal.
const Fault = preload("res://ui/fault_dialog.gd")

class NativeShare extends RefCounted:
	var payloads: Array[String] = []
	func shareChallenge(value: String) -> void: payloads.append(value)

func current_dialog() -> AcceptDialog:
	for child: Node in app.root_ui.get_children():
		if child is AcceptDialog: return child
	return null

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/rivalry-share-2026-10-19/final")
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
			var heading: Label = dialog.find_child("FaultHeading",true,false) if dialog is Fault else dialog.find_child("PopupHeading",true,false)
			var message: Label = dialog.find_child("FaultMessage",true,false) if dialog is Fault else dialog.find_child("PopupMessage",true,false)
			var confirm: Button = dialog.confirm_button if dialog is Fault else dialog.get_ok_button()
			check(heading.get_global_rect().end.y+10 <= message.get_global_rect().position.y,"copied heading never overlaps the results")
			check(message.text == payload,"confirmation preserves the exact copied summary")
			check(root.get_visible_rect().encloses(Rect2(Vector2(dialog.position),Vector2(dialog.size))),"confirmation fits the viewport")
			check(confirm.size.y >= 52 and Rect2(Vector2.ZERO,Vector2(dialog.size)).encloses(confirm.get_global_rect()),"OK remains visible with a full touch target")
			var scroll: ScrollContainer = dialog.find_child("FaultCopyScroll",true,false)
			check(scroll != null,"long results have a scrollable content area")
			if scroll != null:
				check(scroll.get_global_rect().end.y+12 <= confirm.get_global_rect().position.y,"results viewport stays clear of OK")
				scroll.scroll_vertical = 100000
				await settle()
				check(message.get_global_rect().end.y <= scroll.get_global_rect().end.y+1,"last track and Perfect Week line can be fully reached")
				check(message.size.x <= scroll.size.x+1,"wrapped long track names stay within the content width")
			else:
				check(message.get_global_rect().end.y+12 <= confirm.get_global_rect().position.y,"all unscrolled results must stay clear of OK")
			if DisplayServer.get_name() != "headless": await capture("share-"+kind,dimensions)
			if scroll != null:
				scroll.scroll_vertical = 0
				if DisplayServer.get_name() != "headless": await capture("share-"+kind+"-top",dimensions)
			if kind == "unranked": confirm.pressed.emit()
			else:
				var close: Button = dialog.close_button if dialog is Fault else dialog.find_child("PopupClose",true,false)
				close.pressed.emit()
			await settle()
			check(current_dialog() == null,"OK and X both remove the owned share dialog")
			check(share.has_focus(),"closing the confirmation returns focus to Share results")
			check(JSON.stringify([app.rivalry.model.tracks,app.rivalry.model.server_standings,app.records.settings]) == original,"sharing preserves scores, tracks and local settings")
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
