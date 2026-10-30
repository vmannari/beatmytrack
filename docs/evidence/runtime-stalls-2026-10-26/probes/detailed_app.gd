extends "res://core/app.gd"
## Read-only timing overrides; all production behavior delegates to the parent.
var trace_sink: SceneTree

func _open_race_loading(track: NativeTrack = null, practice: bool = false) -> RaceLoading:
	var began: int = Time.get_ticks_usec()
	trace_sink.mark("cover_open_begin")
	var result: RaceLoading = super._open_race_loading(track,practice)
	trace_sink.span("cover_setup",began,{"points":track.route.size() if track != null else 0})
	return result

func _present_race_loading() -> bool:
	var began: int = Time.get_ticks_usec()
	var context: Dictionary = trace_sink.context()
	trace_sink.mark("cover_present_begin")
	trace_sink.render_group()
	var result: bool = await super._present_race_loading()
	trace_sink.span("covered_draw_wait",began,{"drawn":result,"entry":context})
	return result

func _race_menu_visible(value: bool) -> void:
	var began: int = Time.get_ticks_usec()
	super._race_menu_visible(value)
	if trace_sink != null: trace_sink.span("menu_visibility",began,{"visible":value})

func _prepare_night_lighting(loading_id: int, prepared_game: Node) -> Dictionary:
	var began: int = Time.get_ticks_usec()
	var result: Dictionary = await super._prepare_night_lighting(loading_id,prepared_game)
	trace_sink.span("night_preparation",began,result)
	return result

func _close_race_loading(expected_id: int = 0) -> void:
	var began: int = Time.get_ticks_usec()
	super._close_race_loading(expected_id)
	if trace_sink != null: trace_sink.span("cover_close",began)

var trace_ablation_flags: PackedStringArray = OS.get_cmdline_user_args()

func _start_race(track: NativeTrack, from_editor: bool, offline_only: bool = false, rivalry_issued: Dictionary = {}, prepared_loading: RaceLoading = null) -> void:
	if cloud_starting or (is_instance_valid(race_loading) and race_loading != prepared_loading): return
	if track == null:
		_notice("Choose a track before starting a race.")
		return
	var tutorial_lesson: bool = tutorial != null and tutorial.authorizes(track)
	if cloud != null and is_instance_valid(online.client.get("safety")) and not online.client.safety.allows(track.metadata.get("cloud_entry",track.metadata)):
		_notice("This player is blocked. Manage blocked players in Settings > Privacy > Community safety.")
		return
	if track.metadata.get("metadata_only",false):
		await _prepare_metadata_race(track,from_editor,offline_only,rivalry_issued)
		return
	if not from_editor and not track.metadata.has("cloud_version") and cloud != null and not tutorial_lesson:
		_notice("Choose a published backend track from Race.")
		return
	var original_scope: String = lifecycle.scope()
	var navigation_generation: int = _navigation_generation
	var starting_screen: String = screen
	var selected_vehicle: String = VehicleCatalog.selected
	var attempt_vehicle: String = rivalry.model.vehicle_id if not rivalry_issued.is_empty() and not rivalry_issued.has("challenge_code") else selected_vehicle
	var starting_selection: NativeTrack = selected_track
	var loading: RaceLoading = prepared_loading if is_instance_valid(prepared_loading) else _open_race_loading(track, from_editor)
	var loading_id: int = loading.get_instance_id()
	cloud_starting = true
	if prepared_loading == null: await _present_race_loading()
	if not _race_loading_matches(loading_id): return
	if _race_preparation_changed(loading_id,original_scope,navigation_generation,starting_screen,selected_vehicle,starting_selection): return
	if not await _await_selected_preparation(track,loading_id,original_scope,navigation_generation,starting_screen,selected_vehicle,starting_selection): return
	cloud_ticket = {}
	if not offline_only and not from_editor and track.metadata.has("cloud_version") and online.client.signed_in():
		loading.stage("Connecting race…")
		var issued: Dictionary = await cloud.ticket(track,false,attempt_vehicle,null,rivalry_issued) if not rivalry_issued.is_empty() else await cloud.ticket(track)
		if not _race_loading_matches(loading_id): return
		if _race_preparation_changed(loading_id,original_scope,navigation_generation,starting_screen,selected_vehicle,starting_selection): return
		cloud_ticket = issued
		if not cloud_ticket.is_empty():
			cloud_ticket._owner_id = str(online.client.player.id)
			cloud_ticket._origin = str(online.client.base_url())
			if rivalry_issued.has("challenge_code"): challenges.result_ticket = str(cloud_ticket.ticket_id)
			elif not rivalry_issued.is_empty(): rivalry.result_ticket = str(cloud_ticket.ticket_id)
		if cloud_ticket.is_empty():
			cloud_starting = false
			_close_race_loading(loading_id)
			var failure: String = cloud.last_error if not cloud.last_error.is_empty() else "Could not connect the race. Check your connection and try again."
			if not rivalry_issued.is_empty():
				if rivalry_issued.has("challenge_code"):
					challenges.error = failure
					_challenges()
				else:
					rivalry.error = failure
					_rivalry()
				_notice(failure)
				return
			var offline_dialog := ConfirmationDialog.new()
			offline_dialog.title = "Online race unavailable"
			offline_dialog.dialog_text = failure+"\nRace offline with a local time? This attempt will not enter the online leaderboard."
			offline_dialog.ok_button_text = "Race offline"
			_own_dialog(offline_dialog)
			offline_dialog.confirmed.connect(func() -> void:
				if navigation_generation == _navigation_generation and screen == starting_screen and VehicleCatalog.selected == selected_vehicle and selected_track == starting_selection:
					_start_race(track,from_editor,true))
			offline_dialog.popup_centered()
			return
	loading.stage("Loading track…")
	await _present_race_loading()
	if not _race_loading_matches(loading_id): return
	if _race_preparation_changed(loading_id,original_scope,navigation_generation,starting_screen,selected_vehicle,starting_selection): return
	var prepared_roads: Dictionary = {}
	if NativeTrackVisual.race_roads_need_preparation(track):
		var road_job = preload("res://editor/road_preparation_job.gd").start(track,get_tree())
		while not road_job.done:
			await get_tree().process_frame
			if _race_preparation_changed(loading_id,original_scope,navigation_generation,starting_screen,selected_vehicle,starting_selection):
				preload("res://race/selected_track_preparation.gd").cancel(road_job,get_tree())
				return
		prepared_roads = road_job.result if road_job.result is Dictionary else {}
		var trace_at_publish_roads: int = Time.get_ticks_usec()
		trace_sink.mark("publish_roads:begin")
		NativeTrackVisual.ROAD_DISK_CACHE.publish_arrays(prepared_roads.get("receipt",{}))
		trace_sink.span("publish_roads",trace_at_publish_roads)
		prepared_roads.erase("receipt")
	returning_to_editor = from_editor
	challenge_racing = rivalry_issued.has("challenge_code")
	challenge_practice = offline_only and screen == "challenges" and not challenges.selected.is_empty()
	rivalry_racing = not rivalry_issued.is_empty() and not challenge_racing
	test_return_to_drafts = from_editor and screen == "drafts"
	test_document_snapshot = document.duplicate(true) if from_editor else {}
	if from_editor:
		test_library_snapshot = library
		test_scope_snapshot = lifecycle.scope() if lifecycle != null else ""
		test_vehicle_snapshot = VehicleCatalog.selected
	if not from_editor and not tutorial_lesson and records.settings.get("last_track","") != track.identity:
		var previous_track: String = str(records.settings.get("last_track",""))
		records.settings["last_track"] = track.identity
		if records.save_records() != OK:
			records.settings["last_track"] = previous_track
			pending_menu_notice = "This circuit could not be remembered for next time. Check available storage."
	if is_instance_valid(canvas):
		canvas.cancel_gesture()
		editor_view = {"zoom":canvas.zoom,"pan":canvas.pan,"mode":canvas.mode,"selected":canvas.selected,"selected_object":canvas.selected_object,"stamp_kind":canvas.stamp_kind,"stamp_scale":canvas.stamp_scale,"stamp_span":canvas.stamp_span,"stamp_container_color":canvas.stamp_container_color,"run_shape":canvas.run_shape,"free_run":canvas.free_run,"brush_surface":canvas.brush_surface,"brush_width":canvas.brush_width,"paint_mode":canvas.paint_mode,"brush_shape":canvas.brush_shape,"selected_piece":canvas.selected_piece}
	_stop_menu_page_motion()
	_practice_editor_context = {}
	if from_editor and screen == "create" and is_instance_valid(canvas) and canvas.document == document:
		_practice_editor_context = {"root":root_ui.get_instance_id(),"navigation":_navigation_generation,"mode":root_ui.process_mode}
	_race_menu_visible(false)
	var trace_at_instantiate_game: int = Time.get_ticks_usec()
	trace_sink.mark("instantiate_game:begin")
	game = GAME_SCENE.instantiate()
	trace_sink.span("instantiate_game",trace_at_instantiate_game)
	game.profile_enabled = race_profile_enabled
	game.set("vehicle_id",attempt_vehicle)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.cooperative_preparation = true
	game.preparation_current = _race_installation_current.bind(loading_id,original_scope,navigation_generation,starting_screen,selected_vehicle,starting_selection)
	game.set_meta("soundtrack_rivalry", rivalry_racing)
	game.set_meta("race_offline_only", offline_only)
	game.set_meta("tutorial_lesson", tutorial_lesson)
	if challenge_racing:
		game.set_meta("challenge_attempt",{"code":str(rivalry_issued.challenge_code),"stage":int(rivalry_issued.get("_challenge_stage",challenges.selected_stage)),"scope":challenges.scope()})
	game.set("initial_track", track)
	game.set("prepared_road_packet",prepared_roads)
	game.set("production_mode", true)
	game.set("resume_client",null if tutorial_lesson else online.client)
	game.set("resume_ticket_id",str(cloud_ticket.get("ticket_id","")))
	game.set("rating_records", null if tutorial_lesson or track.metadata.has("cloud_version") else records)
	game.set("preference_records", records)
	game.set("editor_test", from_editor)
	var trace_at_prepare_rating: int = Time.get_ticks_usec()
	trace_sink.mark("prepare_rating:begin")
	_prepare_race_rating(track)
	trace_sink.span("prepare_rating",trace_at_prepare_rating)
	game.connect("exit_requested", _leave_race)
	game.connect("edit_here_requested", _edit_here)
	game.connect("race_completed", _results)
	game.connect("practice_lap_completed", _complete_draft_test,CONNECT_DEFERRED)
	game.connect("retry_requested", _retry_race)
	var trace_at_attach_game: int = Time.get_ticks_usec()
	trace_sink.mark("attach_game:begin")
	add_child(game)
	trace_sink.span("attach_game",trace_at_attach_game)
	var prepared_game: Node = game
	while is_instance_valid(prepared_game) and game == prepared_game and not prepared_game.preparation_complete:
		await get_tree().process_frame
		if _race_preparation_changed(loading_id,original_scope,navigation_generation,starting_screen,selected_vehicle,starting_selection):
			_discard_preparing_game(prepared_game)
			return
	if not is_instance_valid(prepared_game) or game != prepared_game: return
	if is_instance_valid(prepared_game.world_render_preparation):
		loading.stage("Preparing graphics...")
		var stage_current: Callable = _race_installation_current.bind(loading_id,original_scope,navigation_generation,starting_screen,selected_vehicle,starting_selection)
		if not await prepared_game.world_render_preparation.prepare(_present_race_loading,stage_current):
			if is_queued_for_deletion(): return
			_race_preparation_changed(loading_id,original_scope,navigation_generation,starting_screen,selected_vehicle,starting_selection)
			if is_instance_valid(prepared_game): _discard_preparing_game(prepared_game)
			_close_race_loading(loading_id)
			return
	if rivalry_racing:
		game.ghost_mode = "race" if not rivalry_recording.is_empty() else "off"
		game.ghost_bests = {"race":rivalry_recording} if not rivalry_recording.is_empty() else {}
	elif challenge_racing or (offline_only and screen == "challenges"):
		game.ghost_mode = "race" if not challenge_recording.is_empty() else "off"
		game.ghost_bests = {"race":challenge_recording} if not challenge_recording.is_empty() else {}
	var trace_at_personal_ghost: int = Time.get_ticks_usec()
	trace_sink.mark("personal_ghost:begin")
	game.call("_prepare_personal_ghost")
	trace_sink.span("personal_ghost",trace_at_personal_ghost)
	var hud: PlaygroundHUD = game.get("hud")
	if tutorial_lesson and hud.rewind_button != null: hud.rewind_button.hide()
	hud.touch.control_scale = ui_touch_scale
	hud.touch.left_handed = ui_left_handed
	hud.touch.haptic_strength = float(records.settings.get("steering_haptics",0.2))
	hud.touch.layout = ControlLayout.from_settings(records.settings)
	hud.touch.show_labels = bool(records.settings.get("control_labels", true))
	# Render the prepared world once with the countdown/input still frozen.
	var trace_at_initial_presentation: int = Time.get_ticks_usec()
	trace_sink.mark("initial_presentation:begin")
	game.call("_process", 0.0)
	trace_sink.span("initial_presentation",trace_at_initial_presentation)
	loading.stage("Preparing start…")
	var prepared_finish: VehicleWeathering = game.get("car_weathering")
	var trace_at_finish_begin: int = Time.get_ticks_usec()
	trace_sink.mark("finish_begin:begin")
	var finish_warmed: bool = false if "--skip-finish" in trace_ablation_flags else prepared_finish.begin_render_warmup()
	trace_sink.span("finish_begin",trace_at_finish_begin)
	var prepared_personal_ghost: PersonalGhost = game.get("personal_ghost")
	var ghost_pose: Transform3D = Transform3D.IDENTITY
	var ghost_visible: bool = false
	if is_instance_valid(prepared_personal_ghost) and prepared_personal_ghost.mesh != null:
		ghost_pose = prepared_personal_ghost.transform
		ghost_visible = prepared_personal_ghost.visible
		prepared_personal_ghost.position = game.get("car").position+Vector3.UP*0.05
		prepared_personal_ghost.rotation = game.get("car").rotation
		prepared_personal_ghost.show()
	var bridge_preparation = preload("res://track/bridge_render_preparation.gd")
	var prepared_bridges: Array[Dictionary] = []
	var trace_at_bridge_begin: int = Time.get_ticks_usec()
	trace_sink.mark("bridge_begin:begin")
	if DisplayServer.get_name() != "headless": prepared_bridges = bridge_preparation.begin(game.get("track_ground"), game.get("camera"))
	trace_sink.span("bridge_begin",trace_at_bridge_begin)
	var bridge_meshes: int = prepared_bridges.size()
	var prepared_hazards: Array[Dictionary] = []
	var trace_at_hazard_begin: int = Time.get_ticks_usec()
	trace_sink.mark("hazard_begin:begin")
	if DisplayServer.get_name() != "headless": prepared_hazards = bridge_preparation.begin_groups(game.get("track_ground"), game.get("camera"), ["race_hazard_rendering"])
	trace_sink.span("hazard_begin",trace_at_hazard_begin)
	var hazard_meshes: int = prepared_hazards.size()
	var trail_preparation = preload("res://vehicle/trail_render_preparation.gd")
	var trace_at_trail_begin: int = Time.get_ticks_usec()
	trace_sink.mark("trail_begin:begin")
	var prepared_trail: MultiMeshInstance3D = null if "--skip-trails" in trace_ablation_flags else trail_preparation.begin(game.get("trails"), game.get("camera"), track, game.get("sim").state)
	trace_sink.span("trail_begin",trace_at_trail_begin)
	var trail_warmed: bool = prepared_trail != null
	var effect_preparation = preload("res://vehicle/effect_render_preparation.gd")
	var trace_at_effects_begin: int = Time.get_ticks_usec()
	trace_sink.mark("effects_begin:begin")
	var prepared_effects: Dictionary
	if "--skip-effects" in trace_ablation_flags:
		prepared_effects = {"nodes":[],"restore":[],"particles":0,"batches":0,"damage_meshes":0,"canvas":0}
	elif "--stage-effects" in trace_ablation_flags:
		prepared_effects = await preload("res://../build/runtime-stall-investigation-2026-10-26/staged_effect_preparation.gd").begin(game.get_node("World"),game.get("sand_dust"),game.get("camera"),game.get("impact_cracks"),_present_race_loading)
	else:
		prepared_effects = effect_preparation.begin(game.get_node("World"),game.get("sand_dust"),game.get("camera"),game.get("impact_cracks"))
	trace_sink.span("effects_begin",trace_at_effects_begin)
	for effect_index: int in range(prepared_effects.nodes.size()-1,-1,-1):
		var effect_node: Node = prepared_effects.nodes[effect_index]
		if effect_node is GPUParticles3D and "--zero-preprocess" in trace_ablation_flags: effect_node.preprocess = 0.0
		if (effect_node is GPUParticles3D and "--skip-effect-particles" in trace_ablation_flags) or (effect_node is CanvasItem and "--skip-effect-canvas" in trace_ablation_flags):
			prepared_effects.nodes.remove_at(effect_index)
			if effect_node is GPUParticles3D: prepared_effects.particles -= 1
			if effect_node is CanvasItem: prepared_effects.canvas -= 1
			effect_node.free()

	var effect_counts: Dictionary = {"particles":prepared_effects.particles,"batches":prepared_effects.batches,"damage_meshes":prepared_effects.damage_meshes,"canvas":prepared_effects.canvas}
	var preparation_started: int = Time.get_ticks_usec()
	var finish_drawn: bool = await _present_race_loading()
	var night_preparation: Dictionary = {"drawn":false,"items":0,"contexts":0,"sets":0,"elapsed_ms":0.0,"truncated":0,"light_limit":false}
	if is_instance_valid(prepared_game) and game == prepared_game:
		night_preparation = await _prepare_night_lighting(loading_id, prepared_game)
	if is_instance_valid(prepared_personal_ghost) and prepared_personal_ghost.mesh != null:
		prepared_personal_ghost.transform = ghost_pose
		prepared_personal_ghost.visible = ghost_visible
	# Restore even if navigation or the loading deadline removed the game.
	var trace_at_bridge_end: int = Time.get_ticks_usec()
	trace_sink.mark("bridge_end:begin")
	bridge_preparation.end(prepared_bridges)
	trace_sink.span("bridge_end",trace_at_bridge_end)
	var trace_at_hazard_end: int = Time.get_ticks_usec()
	trace_sink.mark("hazard_end:begin")
	bridge_preparation.end(prepared_hazards)
	trace_sink.span("hazard_end",trace_at_hazard_end)
	var trace_at_trail_end: int = Time.get_ticks_usec()
	trace_sink.mark("trail_end:begin")
	if is_instance_valid(prepared_trail): trail_preparation.end(prepared_trail)
	trace_sink.span("trail_end",trace_at_trail_end)
	var trace_at_effects_end: int = Time.get_ticks_usec()
	trace_sink.mark("effects_end:begin")
	if "--keep-effects" in trace_ablation_flags:
		var delayed: Array = prepared_effects.nodes
		prepared_effects.nodes = []
		effect_preparation.end(prepared_effects)
		for node: Node in delayed:
			if node is Node3D or node is CanvasItem: node.hide()
	else:
		effect_preparation.end(prepared_effects)
	trace_sink.span("effects_end",trace_at_effects_end)
	var preparation_ms: float = (Time.get_ticks_usec() - preparation_started) / 1000.0
	# Always restore after the bounded draw wait, including cancellation/focus loss.
	var trace_at_finish_end: int = Time.get_ticks_usec()
	trace_sink.mark("finish_end:begin")
	prepared_finish.end_render_warmup()
	trace_sink.span("finish_end",trace_at_finish_end)
	if finish_warmed and night_preparation.contexts > 0:
		# Clean and weathered car materials can have separate shader RIDs.
		var clean_night: Dictionary = await _prepare_night_lighting(loading_id, prepared_game)
		night_preparation.drawn = night_preparation.drawn and clean_night.drawn
		night_preparation.contexts += clean_night.contexts
		night_preparation.sets += clean_night.sets
		night_preparation.elapsed_ms += clean_night.elapsed_ms
		night_preparation.truncated = maxi(night_preparation.truncated, clean_night.truncated)
		night_preparation.light_limit = night_preparation.light_limit or clean_night.light_limit
	if (finish_warmed or night_preparation.contexts > 0) and _race_loading_matches(loading_id) and is_instance_valid(prepared_game) and game == prepared_game:
		var trace_at_final_presentation: int = Time.get_ticks_usec()
		trace_sink.mark("final_presentation:begin")
		game.call("_process", 0.0)
		trace_sink.span("final_presentation",trace_at_final_presentation)
		# The exact clean/livery finish is visible before releasing the loading cover.
		await _present_race_loading()
	if not _race_loading_matches(loading_id):
		if is_instance_valid(prepared_game) and game == prepared_game and prepared_game.process_mode == Node.PROCESS_MODE_DISABLED:
			_leave_race()
		return
	if not is_instance_valid(prepared_game) or game != prepared_game:
		cloud_starting = false
		_close_race_loading(loading_id)
		return
	if _race_preparation_changed(loading_id,original_scope,navigation_generation,starting_screen,selected_vehicle,starting_selection):
		cloud_starting = false
		_close_race_loading(loading_id)
		_leave_race()
		return
	game.set("weathering_prepared", finish_drawn)
	game.set("bridge_prepared", finish_drawn and bridge_meshes > 0)
	game.set("bridge_preparation_meshes", bridge_meshes)
	game.set("hazards_prepared", finish_drawn and hazard_meshes > 0)
	game.set("hazard_preparation_meshes", hazard_meshes)
	game.set("trails_prepared", finish_drawn and trail_warmed)
	game.set("effects_prepared", finish_drawn and effect_counts.particles > 0)
	game.set("effect_preparation_counts",effect_counts)
	game.set("night_preparation",night_preparation)
	# This is the shared covered finish/bridge draw, not isolated bridge GPU time.
	game.set("bridge_preparation_ms", preparation_ms)
	game.preparation_current = Callable()
	game.process_mode = Node.PROCESS_MODE_INHERIT
	_telemetry_begin_attempt(track)
	if race_ad_breaks != null and not tutorial_lesson and not returning_to_editor and not bool(game.get("attempt_practice")): race_ad_breaks.prepare()
	cloud_starting = false
	_close_race_loading(loading_id)
