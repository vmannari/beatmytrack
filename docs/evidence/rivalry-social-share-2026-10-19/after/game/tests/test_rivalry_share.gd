extends "res://tests/test_rivalry_awards.gd"
## Exercise the real Share action, copied payload, scroll reachability and dismissal.
const ShareDialog = preload("res://ui/rivalry_share_dialog.gd")

class NativeShare extends RefCounted:
	var payloads: Array[String] = []
	var images: Array[PackedByteArray] = []
	var request_ids: Array[String] = []
	func shareResults(request_id: String, png: PackedByteArray, value: String) -> bool:
		request_ids.append(request_id)
		images.append(png)
		payloads.append(value)
		return true

class ImageGate extends RefCounted:
	signal release
	var calls: int = 0
	func render(_host: Node, _values: Dictionary) -> PackedByteArray:
		calls += 1
		await release
		return Image.create_empty(2,2,false,Image.FORMAT_RGBA8).save_png_to_buffer()

func test_image(_host: Node, _values: Dictionary) -> PackedByteArray:
	return Image.create_empty(2,2,false,Image.FORMAT_RGBA8).save_png_to_buffer()

func current_dialog() -> AcceptDialog:
	for child: Node in app.root_ui.get_children():
		if child is AcceptDialog and child.visible: return child
	return null

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	var manifest: String = preload("res://addons/bmt_challenges/export_plugin.gd").ChallengeExport.application_contents()
	check(manifest.contains('android:name="org.beatmytrack.challenges.RivalryShareProvider"'),"Android export registers the actual image provider")
	check(manifest.contains('android:authorities="${applicationId}.rivalry-share"') and manifest.contains('android:exported="false"') and manifest.contains('android:grantUriPermissions="true"'),"image provider stays private with package-specific temporary read grants")
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/rivalry-social-share-2026-10-19/final")
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
			check(confirm.size.y >= 52 and Rect2(Vector2.ZERO,Vector2(dialog.size)).encloses(confirm.get_global_rect()),"image action remains visible with a full touch target")
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
			check(confirm.text == "SAVE IMAGE" and not dialog.native_sharing,"desktop preview offers saving the card alongside copied text")
			dialog.close_button.pressed.emit()
			await settle()
			check(current_dialog() == null,"X removes the owned share dialog")
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
	var native_dialog: AcceptDialog = current_dialog()
	if DisplayServer.get_name() == "headless": native_dialog.image_renderer = test_image
	for frame: int in range(90):
		if not native.payloads.is_empty(): break
		await process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	check(native.payloads == [payload] and native.images.size() == 1,"first Share automatically hands the exact summary and image to native sharing")
	check(native_dialog.confirm_button.text == "SHARE" and native_dialog.status_label.text == "Ready to share","native preview offers Share again without claiming delivery or copying")
	check(not native.images.is_empty() and not native.images[0].is_empty(),"native sharing receives an actual PNG")
	if DisplayServer.get_name() != "headless" and not native.images.is_empty():
		var image := Image.new()
		check(image.load_png_from_buffer(native.images[0]) == OK and image.get_size() == Vector2i(1600,860),"share image decodes at the bounded full resolution")
		check(image.get_pixel(0,0).a < 0.05 and image.get_pixel(800,430).a > 0.95,"image contains the isolated card with no underlying menu")
		check(image.save_png(evidence.path_join("exported-results-card.png")) == OK,"save the actual native share image for review")
	var first_request: String = native.request_ids[0] if not native.request_ids.is_empty() else ""
	native_dialog.confirm_button.pressed.emit()
	await settle()
	check(native.images.size() == 2 and native.images[0] == native.images[1],"Share again reuses the exact prepared image")
	check(native.request_ids.size() == 2 and native.request_ids[1] != first_request,"each explicit share has a fresh native request identity")
	app.challenge_links.results_share_failed.emit(first_request,"Old request failed")
	check(native_dialog.status_label.text == "Ready to share","old native errors cannot replace a newer share state")
	app.challenge_links.results_share_failed.emit(native_dialog.request_id,"Couldn't open sharing. Try again.")
	check(native_dialog.status_label.text == "Couldn't open sharing. Try again." and not native_dialog.confirm_button.disabled,"native launch failure remains actionable in the same preview")
	native_dialog.set_sharing(false,"Results changed. Close and share again. ".repeat(4))
	await settle()
	check(native_dialog.copied.get_global_rect().end.x+16 <= native_dialog.confirm_button.get_global_rect().position.x,"long share errors stay clear of the primary action")
	native_dialog.close_button.pressed.emit()
	await settle()
	var calls_before: int = native.payloads.size()
	for blocked: String in ["busy","cached","active","scope"]:
		app.rivalry.busy = blocked == "busy"
		app.rivalry.cached_snapshot = blocked == "cached"
		app.rivalry.model.completed = blocked != "active"
		app.rivalry.snapshot_scope = "another-account" if blocked == "scope" else app.rivalry.scope()
		app._share_rivalry_results()
		check(native.payloads.size() == calls_before and current_dialog() == null,"sharing remains guarded for "+blocked+" state")
	await asynchronous_fences(native)
	app.challenge_links._native = null
	app.queue_free()
	await process_frame
	print("RIVALRY_SHARE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func asynchronous_fences(native: NativeShare) -> void:
	var selected: String = VehicleCatalog.selected
	var player: Dictionary = app.online.client.player.duplicate(true)
	for mode: String in ["double_click","closed","account","car","week","group","cached","snapshot","navigation"]:
		VehicleCatalog.selected = selected
		app.online.client.player = player.duplicate(true)
		app.rivalry.model.apply_snapshot(awarded_snapshot("perfect"))
		app.rivalry.snapshot_scope = app.rivalry.scope()
		app.rivalry.busy = false
		app.rivalry.cached_snapshot = false
		app.rivalry_section = "overview"
		app._show_screen("rivalry")
		await settle()
		var calls_before: int = native.payloads.size()
		app._share_rivalry_results()
		var dialog: AcceptDialog = current_dialog()
		var gate := ImageGate.new()
		dialog.image_renderer = gate.render
		await settle()
		check(gate.calls == 1 and dialog.sharing,"one bounded image preparation starts for "+mode)
		if mode == "double_click":
			app._share_rivalry_results()
			dialog.share_requested.emit()
			check(gate.calls == 1,"repeated inputs coalesce while preparing the image")
		elif mode == "closed":
			dialog.close_button.pressed.emit()
			await settle()
		elif mode == "account": app.online.client.player = {"id":"another-account"}
		elif mode == "car": VehicleCatalog.selected = "pickup" if selected != "pickup" else "kart"
		elif mode == "week": app.rivalry.model.week += 1
		elif mode == "group": app.rivalry.model.group_id = "another-group"
		elif mode == "cached": app.rivalry.cached_snapshot = true
		elif mode == "snapshot": app.rivalry.snapshot_scope = "another-owner"
		elif mode == "navigation": app._show_screen("tracks")
		gate.release.emit()
		await settle()
		check(native.payloads.size() == calls_before+(1 if mode == "double_click" else 0),"late image completion respects the "+mode+" fence")
		if is_instance_valid(dialog):
			check(not dialog.sharing,"cancelled image preparation releases its UI state: "+mode)
			dialog.close_button.pressed.emit()
			await settle()
	VehicleCatalog.selected = selected
	app.online.client.player = player
