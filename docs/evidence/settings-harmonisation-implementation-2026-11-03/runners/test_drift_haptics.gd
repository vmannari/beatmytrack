extends SceneTree
## Real state observations, bounded pulses, recoverable preferences and scene gates.
const DriftHaptics = preload("res://platform/drift_haptics.gd")
var checks: int = 0
var failures: int = 0
var pulses: Array = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func capture(strength: float, duration: int) -> void:
	pulses.append([strength, duration])

func state_at(slip_degrees: float, speed: float = 12.0) -> VehicleState:
	var state := VehicleState.new()
	state.tick = 100
	state.velocity = Vector2(sin(deg_to_rad(slip_degrees)), cos(deg_to_rad(slip_degrees)))*speed
	return state

func run() -> void:
	_check_pulses()
	_check_simulation()
	await _check_worker()
	await _check_preferences()
	await _check_scene()
	print("DRIFT_HAPTICS_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check_pulses() -> void:
	var feedback := DriftHaptics.new()
	feedback.feedback = capture
	var state := state_at(25.0)
	for quiet: VehicleState in [state_at(0.0), state_at(8.0), state_at(25.0, 3.9)]:
		for i: int in range(30): feedback.present(1.0/60.0, quiet, true, true)
	check(pulses.is_empty(), "straight driving, small slip and low speed remain silent")
	feedback.present(0.03, state, true, true)
	check(pulses.is_empty(), "brief transient slip does not buzz")
	feedback.present(0.03, state, true, true)
	check(pulses.size() == 1 and pulses[0][1] == 20, "sustained drift produces a short pulse")
	var light: float = pulses[0][0]
	feedback.present(0.01, state_at(-35.0, 20.0), true, true)
	check(pulses.size() == 1, "opposite slide respects the shared pulse interval")
	feedback.present(0.10, state_at(-35.0, 20.0), true, true)
	check(pulses.size() == 2 and pulses[1][0] > light and pulses[1][0] <= 0.225, "faster stronger drift stays within the lighter feedback bound in either direction")
	feedback.present(0.02, state_at(8.0), true, true)
	check(feedback.sliding, "slip hysteresis holds an established slide through small fluctuations")
	feedback.present(0.02, state_at(6.0), true, true)
	check(not feedback.sliding, "feedback ends as the tyres regain grip")
	for condition: String in ["disabled", "inactive", "airborne", "bridge_airborne", "rolling"]:
		feedback.reset()
		pulses.clear()
		state = state_at(25.0)
		if condition == "airborne": state.jump_height = 0.05
		if condition == "bridge_airborne": state.bridge_airborne = true
		if condition == "rolling": state.roll_ticks = 12
		for i: int in range(30): feedback.present(1.0/60.0, state, condition != "disabled", condition != "inactive")
		check(pulses.is_empty() and not feedback.sliding, condition+" suppresses drift feedback")
	for rate: int in [30, 60, 120, 240]:
		feedback.reset()
		pulses.clear()
		for i: int in range(rate*2): feedback.present(1.0/float(rate), state_at(25.0), true, true)
		check(pulses.size() >= 19 and pulses.size() <= 20, "two seconds stays bounded at 10 pulses/second at %d fps" % rate)
	var before: int = pulses.size()
	feedback.present(5.0, state_at(25.0), true, true)
	check(pulses.size() <= before+1, "long frames never replay a vibration backlog")
	feedback.reset()
	pulses.clear()
	for delta: float in [0.0, -1.0, NAN, INF]: feedback.present(delta, state_at(25.0), true, true)
	check(pulses.is_empty(), "zero and invalid frame durations remain silent")

func _check_simulation() -> void:
	pulses.clear()
	var handling: HandlingConfig = VehicleCatalog.config("compact", HandlingSelection.ORIGINAL_PLUS_INDEX)
	var observed := VehicleSimulation.new(handling)
	var reference := VehicleSimulation.new(handling)
	var feedback := DriftHaptics.new()
	feedback.feedback = capture
	var yard := PlaygroundData.new()
	for i: int in range(1200):
		var frame: DriveFrame = DriveFrame.sample(0.65 if i > 180 else 0.0, 1.0, 0.0)
		observed.step(frame, yard)
		reference.step(frame, yard)
		feedback.present(1.0/120.0, observed.state, true, true)
	check(observed.state.snapshot() == reference.state.snapshot(), "1200 real driving steps are exact with and without drift feedback")
	check(not pulses.is_empty(), "real driving inputs produce drift feedback during the parity check")

func _check_worker() -> void:
	var platform = preload("res://platform/steering_haptics.gd")
	var gate := Semaphore.new()
	platform._submit(func() -> void: gate.wait())
	var pending: int = platform.pending_task
	check(not WorkerThreadPool.is_task_completed(pending), "slow vibration service returns control without blocking driving")
	for i: int in range(100): platform._submit(func() -> void: pass)
	check(platform.pending_task == pending, "busy vibration worker drops 100 extra requests without queue growth")
	gate.post()
	while not WorkerThreadPool.is_task_completed(pending): await process_frame
	platform._submit(func() -> void: pass)
	check(platform.pending_task != pending, "completed vibration worker accepts fresh feedback")
	WorkerThreadPool.wait_for_task_completion(platform.pending_task)
	platform.pending_task = -1

func _check_preferences() -> void:
	var folder: String = "C:/Codes/Godot/Beat my track/docs/evidence/settings-harmonisation-implementation-2026-11-03/fixtures/test_drift_haptics/drift_haptics_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var store := LocalRecords.new(folder.path_join("records.json"))
	store.settings = {"favorites":["ellipse"], "steering_haptics":0.0}
	check(store.save_records() == OK, "old profile without drift preference remains valid")
	var page := SettingsPage.new()
	page.records = store
	page.section = "haptics"
	root.add_child(page)
	check(page.draft_drift_haptics, "old profiles default to enabled drift feedback")
	var toggle: CheckButton = page.find_child("DriftHaptics", true, false)
	toggle.button_pressed = false
	check(not page.draft_drift_haptics and not store.settings.has("drift_haptics"), "toggle stages changes before Apply")
	page._show_section("controls")
	page._show_section("haptics")
	check(not page.draft_drift_haptics, "section navigation retains staged toggle")
	check(page._apply(), "disabled drift preference applies")
	var reloaded := LocalRecords.new(store.path)
	reloaded.load_records()
	check(reloaded.settings.drift_haptics == false and reloaded.settings.steering_haptics == 0.0, "drift toggle persists independently of steering feedback")
	page._reset()
	check(page.draft_drift_haptics and not store.settings.drift_haptics, "haptics reset is staged")
	var saved_path: String = store.path
	store.path = folder.path_join("missing/records.json")
	check(not page._apply() and not store.settings.drift_haptics and page.draft_drift_haptics, "failed save retains draft and rolls back committed drift preference")
	store.path = saved_path
	check(page._apply(), "failed save can be retried")
	store.settings.drift_haptics = "false"
	check(store.save_records() == ERR_INVALID_DATA and store.settings.drift_haptics == true, "malformed drift preference is rejected with recoverable rollback")
	check(store.settings.favorites == ["ellipse"], "drift edits preserve unrelated preferences")
	page.queue_free()
	await process_frame
	for filename: String in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder.path_join(filename))
	DirAccess.remove_absolute(folder)

func _check_scene() -> void:
	var store := LocalRecords.new("C:/Codes/Godot/Beat my track/docs/evidence/settings-harmonisation-implementation-2026-11-03/fixtures/test_drift_haptics/unused_drift_scene.json")
	store.settings.drift_haptics = false
	var game: Node = load("res://core/game.tscn").instantiate()
	game.preference_records = store
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	# Prevent scene teardown from writing condition to this in-memory fixture.
	game.preference_records = null
	game.drift_haptics.feedback = capture
	game.sim.state.velocity = state_at(25.0).velocity
	game.sim.state.tick = 100
	pulses.clear()
	game._present_drift_haptics(0.10)
	check(pulses.is_empty() and not game.drift_haptics_enabled, "race reads the saved disabled preference")
	game.drift_haptics_enabled = true
	game._present_drift_haptics(0.10)
	check(pulses.size() == 1, "actual driving scene emits drift feedback")
	for condition: String in ["paused", "countdown", "finish", "rewind", "resume", "ai", "demo"]:
		pulses.clear()
		if condition == "paused": game.paused = true
		if condition == "countdown": game.countdown_ticks = 120
		if condition == "finish": game.finish_sim = VehicleSimulation.new(game.handling)
		if condition == "rewind": game.rewind_panel = CanvasLayer.new()
		if condition == "resume": game.rewind_return.remaining = 12
		if condition == "ai": game.ai_enabled = true
		if condition == "demo": game.demo_capture = true
		game._present_drift_haptics(0.10)
		check(pulses.is_empty() and not game.drift_haptics.sliding, "scene suppresses feedback during "+condition)
		game.paused = false
		game.countdown_ticks = 0
		game.finish_sim = null
		if game.rewind_panel != null: game.rewind_panel.free()
		game.rewind_panel = null
		game.rewind_return.reset()
		game.ai_enabled = false
		game.demo_capture = false
	game._present_drift_haptics(0.10)
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	pulses.clear()
	game._present_drift_haptics(0.10)
	check(game.paused and pulses.is_empty(), "losing application focus suppresses drift feedback")
	game.restart()
	check(not game.drift_haptics.sliding and game.drift_haptics.cooldown == 0.0, "restart clears feedback state")
	game.queue_free()
	await process_frame
