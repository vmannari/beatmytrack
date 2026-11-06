extends "res://tests/test_shared_graphics_first_laps.gd"
## Desktop observations, retaining the existing real first-lap assertions.
var samples: Array[float] = []
var draw_samples: Array[float] = []
var previous_usec: int = 0
var sampling: bool = false
var review_rows: Array = []

func observe() -> void:
	super.observe()
	var now: int = Time.get_ticks_usec()
	if sampling and is_instance_valid(app.game) and app.game.countdown_ticks == 0 and app.game.sim.state.tick > 0:
		if previous_usec > 0: samples.append((now-previous_usec)/1000.0)
		draw_samples.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	previous_usec = now

func first_emission(game: Node) -> void:
	samples.clear(); draw_samples.clear(); previous_usec = 0
	var cpu_before: Array = [game.profile_physics_total_us,game.profile_process_total_us]
	sampling = true
	await super.first_emission(game)
	sampling = false
	var sorted: Array[float] = samples.duplicate(); sorted.sort()
	draw_samples.sort()
	var row: Dictionary = lap_rows[-1].duplicate(true)
	row.frames = sorted.size()
	if not sorted.is_empty():
		row.frame_p50_ms = sorted[int(sorted.size()*0.50)]
		row.frame_p95_ms = sorted[mini(sorted.size()-1,int(sorted.size()*0.95))]
		row.frame_p99_ms = sorted[mini(sorted.size()-1,int(sorted.size()*0.99))]
		row.frame_max_ms = sorted[-1]
		row.over_33ms = sorted.filter(func(value: float) -> bool: return value > 33.333).size()
		row.draws_median = draw_samples[int(draw_samples.size()*0.5)]
	row.physics_callback_total_ms = (game.profile_physics_total_us-cpu_before[0])/1000.0
	row.presentation_callback_total_ms = (game.profile_process_total_us-cpu_before[1])/1000.0
	row.static_bytes = OS.get_static_memory_usage()
	row.observer_total_ms = game.hitch_diagnostics.observer_total_us/1000.0
	review_rows.append(row)
	print("REVIEW_DRIVING ",JSON.stringify(row))

func run() -> void:
	root.size = Vector2i(1280,720)
	Engine.max_fps = 60
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new("user://review-driving/records.json")
	app.records.settings.music_enabled = false
	app.library = TrackLibrary.new("user://review-driving/tracks")
	app.cloud_root_override = "user://review-driving/cloud"
	root.add_child(app)
	while not app.startup_complete: await process_frame
	check(not app.online.configured,"review stays offline")
	process_frame.connect(observe)
	for theme: String in TrackTheme.IDS: await race("compact",theme)
	process_frame.disconnect(observe)
	app.queue_free(); app = null
	for _frame: int in range(24): await process_frame
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":cases,"rows":review_rows},"  "))
	print("REVIEW_DRIVING_RESULT ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
