extends Node
## Observes real driving and navigation. Never supplies input or changes simulation state.
const Progress = preload("res://tutorial/tutorial_progress.gd")
const Overlay = preload("res://tutorial/tutorial_overlay.gd")
const Carousel = preload("res://ui/track_carousel.gd")
const PageSwipe = preload("res://ui/menu_page_swipe.gd")
const HALL_GOALS: Array[Vector2] = [Vector2(-32,-18),Vector2(-24,-4),Vector2(-24,8)]
const TOPIC_CARDS: Dictionary = {
	"garage": [["Your garage", "Choose a car, then explore Customise, Care and Tuning. Test drive opens the untimed parking hall.", "GarageTestDrive"]],
	"rivalry": [["Weekly Rivalry", "Open a track, then Race. Your best verified time on each track earns points; more attempts let you improve it.", "RivalryTracksPanel"]],
	"challenges": [["Race together", "Open an invitation to race its tracks. You can also create a challenge here or from a finished race result.", ""]],
	"creator": [["Build your own track", "Start with Road. Join road pieces into a closed loop; the driving route is generated from the connected road.", ""], ["Set the start", "Place a Start line and check its direction. Open the issues list to find anything that needs fixing.", ""], ["Try your track", "Practice opens an untimed drive. Edit here returns to your track; finish a valid practice lap before publishing.", "PracticeTrack"]],
	"rewind": [["Choose a moment", "Slide back within the last 10 seconds. Cancel returns without spending a resume. Confirming Resume uses the allowance shown here, up to three times per race.", ""]],
}
var app: Node
var progress: RefCounted
var view: Control
var lesson_track: NativeTrack
var _layer: CanvasLayer
var _floor: Control
var _scope: String = ""
var _offer_pending: bool = false
var _running: bool = false
var _launching: bool = false
var _entered: bool = false
var _replay: bool = false
var _controls_open: bool = false
var _practising: bool = false
var _context_allowed: bool = false
var _backgrounded: bool = false
var _hall_id: int = 0
var _last_tick: int = 0
var _steered: bool = false
var _stopped_ticks: int = 0
var _idle: float = 0.0
var _closest: float = INF
var _screen: String = ""
var _screen_time: float = 0.0
var _topic: String = ""
var _topic_index: int = 0
var _topic_screen: String = ""
var _result_id: int = 0
var _bound_root: int = 0
var _bound_navigation: int = -1

func _ready() -> void:
	name = "FirstPlayTutorial"
	progress = Progress.new(app.profile_root.path_join("tutorial.json"))
	progress.load_progress(app._tutorial_existing_save or Progress.has_played(app.records) or Progress.has_played(app.guest_records))
	_scope = app.lifecycle.scope()
	_entered = progress.status in ["active","completed","skipped"]
	_layer = CanvasLayer.new()
	_layer.layer = 26
	add_child(_layer)
	view = Overlay.new()
	_layer.add_child(view)
	_layer.hide()
	view.visibility_changed.connect(_sync_layer)
	var floor_layer := CanvasLayer.new()
	floor_layer.layer = 0
	add_child(floor_layer)
	_floor = Control.new()
	_floor.name = "TutorialFloorMarker"
	_floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	floor_layer.add_child(_floor)
	_floor.draw.connect(view.draw_floor.bind(_floor))
	view.visibility_changed.connect(_floor.queue_redraw)
	view.primary_pressed.connect(_primary)
	view.secondary_pressed.connect(_secondary)
	view.skip_pressed.connect(skip)
	get_tree().node_added.connect(_bind_input_node)

func offer() -> void:
	if app.lifecycle.scope() != _scope: _reset_scope(app.lifecycle.scope())
	if progress.status in ["new","active"]: _offer_pending = true
	if progress.status == "new": progress.save()
	_entered = progress.status != "existing"

func replay() -> void:
	if is_instance_valid(app.game) or is_instance_valid(app.race_loading): return
	_replay = true
	_offer_pending = true
	_entered = true
	_topic = ""
	view.clear()

func show_help(topic: String) -> void:
	if topic not in TOPIC_CARDS: return
	_topic = topic
	_topic_index = 0
	_topic_screen = app.screen
	_show_topic()

func authorizes(track: NativeTrack) -> bool:
	# Only the exact native document explicitly opened by First race can bypass discovery.
	return track != null and track == lesson_track and _scope == app.lifecycle.scope()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		_backgrounded = true
		if is_instance_valid(view): view.hide()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]: _backgrounded = false

func _sync_layer() -> void:
	_layer.layer = 26
	_layer.set_meta("menu_input_passthrough",view.mode != "welcome")
	_layer.visible = view.visible

func owns_card_input(event: InputEvent) -> bool:
	if not is_instance_valid(view) or not view.is_visible_in_tree(): return false
	if not (event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag): return false
	return view.mode == "welcome" or view.card.get_global_rect().has_point(event.position)

func _bind_input_node(node: Node) -> void:
	if node.get_script() != Carousel and node.get_script() != PageSwipe: return
	if is_instance_valid(app.root_ui) and app.root_ui.is_ancestor_of(node): node.input_exclusion = owns_card_input

func _bind_menu_input(node: Node) -> void:
	if node is SubViewport or node is Node3D: return
	_bind_input_node(node)
	for child: Node in node.get_children(): _bind_menu_input(child)

func _process(delta: float) -> void:
	if not app.startup_complete: return
	if view.visible or view.floor_target.is_finite(): _floor.queue_redraw()
	var scope: String = app.lifecycle.scope()
	if scope != _scope:
		_reset_scope(scope)
	if app.screen != _screen:
		_screen = app.screen
		_screen_time = 0.0
		_context_allowed = true
		if _topic_screen != _screen: _topic = ""
	else: _screen_time += delta
	if _controls_open and app.screen != "settings":
		_controls_open = false
		_offer_pending = true
	if _backgrounded or _launching or is_instance_valid(app.race_loading) or _has_dialog():
		view.hide()
		return
	var game: Node = app.game
	if is_instance_valid(game):
		if not game.preparation_complete:
			view.hide()
			return
		if _running and progress.step == 4 and game.track_session.finished and app.root_ui.visible:
			_finish(game)
			return
		if _result_id == game.get_instance_id():
			var result: Control = app.root_ui.find_child("RaceResults",true,false)
			if result != null and result.is_visible_in_tree():
				var retry: Control = result.find_child("RetryRace",true,false)
				var needs_scroll: bool = retry != null and retry.get_global_rect().end.y > get_viewport().get_visible_rect().end.y
				_present("result_scroll" if needs_scroll else "result", "Your first benchmark", "Your race time is your next target. Scroll down to Race Again to try for a personal best." if needs_scroll else "Your race time is your next target. Race Again to try for a personal best.", "Got it", "", "results", false)
				_highlight(["ResultTime","RetryRace"])
				view.avoid_rects.clear()
				var banner: Control = app.achievement_notification.find_child("AchievementBanner",true,false)
				if banner != null and banner.is_visible_in_tree(): view.avoid_rects.append(banner.get_global_rect())
				view.bottom_limit = retry.get_global_rect().position.y-12 if retry != null else INF
				view._layout()
				return
			_result_id = 0
		if is_instance_valid(game.rewind_panel):
			if _entered and not progress.seen.has("rewind"):
				if _topic != "rewind":
					_topic = "rewind"
					_topic_index = 0
					_topic_screen = app.screen
				_show_topic()
			else: view.clear()
			return
		if _topic == "rewind": _topic = ""
		if game.paused or not game.hud.visible:
			view.hide()
			return
		if _running and game.free_drive_mode and progress.step <= 3 and game.get_instance_id() == _hall_id:
			_hall(game,delta)
		elif _running and progress.step == 4 and game.production_mode and not game.editor_test:
			_race(game)
		else: view.clear()
		return
	if not app.root_ui.visible or app.screen in ["account","restoring","challenge_create"]:
		view.hide()
		return
	if _offer_pending:
		if not app._queued_track_link.is_empty() or not app.challenge_queued_invitation.is_empty() or not app.challenge_invitation.is_empty():
			_offer_pending = false
			view.clear()
			return
		var continuing: bool = progress.status == "active" and not _replay
		_present("welcome", "Let's get you driving", "A short drive to learn the controls, then your first five-lap race. You can skip at any time.", "Continue tutorial" if continuing else "Start tutorial", "Controls", "welcome")
		return
	if _running and app.screen == "garage" and progress.step <= 3:
		_ready_card() if progress.step == 3 else _present("resume", "Keep learning", "Continue your driving lesson in the parking hall.", "Continue", "Later")
		return
	if _running and progress.step == 4 and app.screen in ["garage","tracks"]:
		_present("resume_race", "Your first race", "Continue with five laps on the tutorial circuit.", "First race", "Later")
		return
	if not _topic.is_empty():
		_show_topic()
		return
	if _entered and _context_allowed and progress.status in ["completed","skipped"] and _screen_time >= 0.8:
		var topic: String = "creator" if app.screen == "create" else app.screen
		if topic in TOPIC_CARDS and topic != "rewind" and not progress.seen.has(topic):
			# An invitation owns its first entry; do not cover its accept/race decision.
			if app.screen == "challenges" and not app.challenge_invitation.is_empty(): return
			_topic = topic
			_topic_index = 0
			_topic_screen = app.screen
			_show_topic()
			return
	view.clear()

func _reset_scope(scope: String) -> void:
	_scope = scope
	_running = false
	_offer_pending = false
	_launching = false
	_topic = ""
	_controls_open = false
	_practising = false
	lesson_track = null
	_result_id = 0
	_hall_id = 0
	view.clear()

func _has_dialog() -> bool:
	for window: Window in get_viewport().get_embedded_subwindows():
		if window.visible: return true
	return false

func _present(id: String, title: String, instruction: String, action: String = "", alternative: String = "", placement: String = "hall", skippable: bool = true) -> void:
	if view.key != id:
		view.outlines.clear()
		view.avoid_rects.clear()
		view.bottom_limit = INF
		view.floor_target = Vector2.INF
		view.camera = null
		view.present(id,title,instruction,action,alternative,placement,skippable,progress.last_error != OK)
	else: view.show()
	_sync_layer()
	if _bound_root != app.root_ui.get_instance_id() or _bound_navigation != app._navigation_generation:
		_bound_root = app.root_ui.get_instance_id()
		_bound_navigation = app._navigation_generation
		_bind_menu_input(app.root_ui)

func _hall(game: Node, delta: float) -> void:
	if progress.step == 3:
		_ready_card()
		_avoid_driving_controls(game)
		return
	var tick: int = game.sim.state.tick
	var elapsed: int = clampi(tick-_last_tick,0,120)
	_last_tick = tick
	var position: Vector2 = game.sim.state.position
	var speed: float = game.sim.state.velocity.length()
	_idle += delta
	var distance: float = position.distance_to(HALL_GOALS[progress.step])
	if distance < _closest-1.0:
		_closest = distance
		_idle = 0
	if game.frame.steer != 0 and speed > 0.5: _steered = true
	var reached: bool = position.distance_to(HALL_GOALS[progress.step]) < (9.0 if progress.step == 2 else 6.0)
	var complete: bool = reached and game.frame.throttle > 0 if progress.step == 0 else reached and _steered if progress.step == 1 else false
	if progress.step == 2:
		# Judge the actual stop. A brake tap can end between presentation frames,
		# and coasting or the handbrake must not leave a stopped player stranded.
		_stopped_ticks = _stopped_ticks+elapsed if reached and speed < 0.8 else 0
		complete = _stopped_ticks >= 24
	if complete:
		progress.advance(progress.step+1)
		_steered = false
		_stopped_ticks = 0
		_idle = 0
		_closest = INF
		view.clear()
		if progress.step == 3:
			_release_input()
			_ready_card()
			_avoid_driving_controls(game)
			return
	var stage: int = progress.step
	var titles: Array[String] = ["1 / 3  ·  Get moving", "2 / 3  ·  Make a turn", "3 / 3  ·  Come to a stop"]
	var touch: TouchControls = game.hud.touch
	var instructions: Array[String] = ["Hold the highlighted accelerator and drive into the gold circle.", "Use the highlighted arrows to steer towards the next gold circle. Ease off the accelerator before turning.", "Use the highlighted brake to slow down. Release it and stop inside the gold circle."]
	if touch.analog_controls():
		instructions = ["Touch the highlighted pedal and slide up to accelerate into the gold circle.", "Touch the highlighted steering control and slide left or right towards the next gold circle.", "Slide down on the highlighted pedal to brake, then lift your finger and stop inside the gold circle."]
	_present("hall_%d_%s_%s" % [stage,str(touch.layout.steering_type),str(_idle>25)],titles[stage],instructions[stage],"Reset car" if _idle>25 else "")
	view.camera = game.camera
	view.floor_target = HALL_GOALS[stage]
	view.floor_radius = 9.0 if stage == 2 else 6.0
	view.outlines.clear()
	var groups: Dictionary = touch.group_rects()
	var controls: Array[String] = []
	if stage == 1: controls.assign([str(touch.layout.steering_type)] if touch.analog_controls() else ["steer_left","steer_right"])
	else: controls.append("brake" if stage == 2 and not touch.analog_controls() else "accelerator")
	for control: String in controls: view.outlines.append(touch.get_global_transform_with_canvas()*groups[control])
	_avoid_driving_controls(game)

func _avoid_driving_controls(game: Node) -> void:
	view.avoid_rects.clear()
	var touch: TouchControls = game.hud.touch
	var groups: Dictionary = touch.group_rects()
	if not groups.is_empty():
		for control: String in ControlLayout.active_keys(touch.layout): view.avoid_rects.append(touch.get_global_transform_with_canvas()*groups[control])
	for target_name: String in ["RaceActions","SpeedCard","RaceCard","TimingCard"]:
		var target: Control = game.hud.find_child(target_name,true,false)
		if target != null and target.is_visible_in_tree(): view.avoid_rects.append(target.get_global_rect())
	view._layout()

func _ready_card() -> void:
	if _practising: _present("ready_compact", "", "", "First race")
	else: _present("ready", "Ready for a race", "Try five laps on a gentle daylight circuit. Your time stays on this device; online racing is available from Race.", "First race", "Practise more")

func _race(game: Node) -> void:
	var session: TrackSession = game.track_session
	if game.countdown_ticks > 0:
		_present("race_start", "Five laps. Your first benchmark.", "Follow the track in the marked direction. The timer starts at GO.", "", "", "race")
	elif session.missed_checkpoint >= 0:
		_present("race_checkpoint", "Return to the marker", "A checkpoint was missed. Go back to the marked section, then continue your lap.", "", "", "race")
	elif session.completed_laps == 0:
		_present("race_lap", "Find your rhythm", "Stay on the road and brake before corners. Complete every checkpoint to count the lap.", "", "", "race")
	elif session.completed_laps == 1 and session.elapsed_ticks-int(session.lap_start_time*session.tick_rate) < session.tick_rate*5:
		_present("race_progress", "One lap down", "Keep going. The lap counter shows your progress towards five laps.", "", "", "race")
		_highlight_hud(game,"RaceCard")
	else: view.clear()
	if view.visible: _avoid_driving_controls(game)

func _finish(game: Node) -> void:
	var result: Control = app.root_ui.find_child("RaceResults",true,false)
	if result == null or not result.is_visible_in_tree():
		view.clear()
		return
	progress.advance(5)
	_context_allowed = false
	_running = false
	_result_id = game.get_instance_id()
	view.clear()

func _show_topic() -> void:
	var cards: Array = TOPIC_CARDS[_topic]
	var item: Array = cards[_topic_index]
	var multiple: bool = cards.size() > 1
	_present("topic_%s_%d" % [_topic,_topic_index],item[0],item[1],"Next" if _topic_index+1 < cards.size() else "Got it","Dismiss" if multiple else "","context",false)
	_highlight([str(item[2])])

func _highlight(names: Array[String]) -> void:
	view.outlines.clear()
	for target_name: String in names:
		if target_name.is_empty(): continue
		var target: Control = app.root_ui.find_child(target_name,true,false)
		if target != null and target.is_visible_in_tree(): view.outlines.append(target.get_global_rect())

func _highlight_hud(game: Node, target_name: String) -> void:
	var target: Control = game.hud.find_child(target_name,true,false)
	view.outlines.clear()
	if target != null: view.outlines.append(target.get_global_rect())

func _primary() -> void:
	var key: String = view.key
	if key == "welcome":
		_offer_pending = false
		progress.begin(_replay)
		_replay = false
		_practising = false
		_running = true
		_entered = true
		if progress.step >= 3: _start_first_race()
		else: _start_hall()
	elif key in ["ready","ready_compact","resume_race"]: _start_first_race()
	elif key == "resume": _start_hall()
	elif key.begins_with("hall_") and is_instance_valid(app.game):
		app.game.restart()
		_last_tick = 0
		_steered = false
		_stopped_ticks = 0
		_idle = 0
		_closest = INF
	elif key.begins_with("result"):
		_result_id = 0
		view.clear()
	elif key.begins_with("topic_"):
		_topic_index += 1
		if _topic_index >= TOPIC_CARDS[_topic].size(): _dismiss_topic()
		else: _show_topic()

func _secondary() -> void:
	if view.key == "welcome":
		_offer_pending = false
		_controls_open = true
		app._show_screen("settings")
		view.clear()
	elif view.key.begins_with("topic_"): _dismiss_topic()
	elif view.key == "ready":
		_practising = true
		view.clear()
	else:
		_running = false
		view.clear()

func _dismiss_topic() -> void:
	progress.dismiss(_topic)
	_context_allowed = false
	_topic = ""
	view.clear()

func skip() -> void:
	progress.skip()
	_offer_pending = false
	_replay = false
	_running = false
	_entered = true
	_context_allowed = false
	_topic = ""
	_release_input()
	view.clear()

func _release_input() -> void:
	if is_instance_valid(app.game) and app.game.preparation_complete:
		app.game.driver.clear()
		app.game.hud.touch.release_all()

func _start_hall() -> void:
	if _launching or is_instance_valid(app.game) or is_instance_valid(app.race_loading): return
	_launching = true
	view.clear()
	var scope: String = app.lifecycle.scope()
	app._show_screen("garage")
	await get_tree().process_frame
	if app.lifecycle.scope() != scope or app.screen != "garage":
		_launching = false
		return
	await app._start_garage_free_drive()
	_launching = false
	if app.lifecycle.scope() != scope: return
	if is_instance_valid(app.game) and app.game.free_drive_mode:
		_hall_id = app.game.get_instance_id()
		_last_tick = app.game.sim.state.tick
		_idle = 0
		_closest = INF
		_steered = false
		_stopped_ticks = 0
		_running = true

func _start_first_race() -> void:
	if _launching or is_instance_valid(app.race_loading): return
	if is_instance_valid(app.game) and not app.game.free_drive_mode: return
	_launching = true
	view.clear()
	_release_input()
	if is_instance_valid(app.game): app._leave_garage_free_drive()
	var scope: String = app.lifecycle.scope()
	lesson_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	if lesson_track == null:
		_launching = false
		app._notice("The tutorial circuit could not be opened. You can keep playing from Race.")
		return
	progress.advance(4)
	_running = true
	await app._start_race(lesson_track,false,true)
	_launching = false
	if scope != app.lifecycle.scope(): return
	if not is_instance_valid(app.game):
		_running = false
		_offer_pending = true
