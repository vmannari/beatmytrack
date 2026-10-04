extends Node
## Opt-in, read-only menu timing on the attached device.
var frame_ms: Array[float] = []
var last_usec: int = 0
func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if last_usec != 0: frame_ms.append((now-last_usec)/1000.0)
	last_usec = now
func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var app: Node = get_parent()
	await get_tree().create_timer(2.0).timeout
	var options: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://menu_probe.json"))
	if options is Dictionary and options.get("quality_review", false):
		await _run_quality_review(app)
		return
	if options is Dictionary and options.get("page_swipes", false):
		await _run_page_swipes(app)
		return
	var started: int = Time.get_ticks_usec()
	app.call("_show_screen","tracks")
	var report: Dictionary = {"open_ms":(Time.get_ticks_usec()-started)/1000.0,"selections":[]}
	report.open_costs = app.get("menu_open_costs")
	var browser: TrackBrowser = app.get("root_ui").find_child("TrackBrowser",true,false)
	report.detail_costs = browser.detail_costs
	while browser.loading: await get_tree().process_frame
	report.index_ready_ms = (Time.get_ticks_usec()-started)/1000.0
	for title: String in ["Speedy","Knot","Speedy"]:
		await get_tree().create_timer(2.0).timeout
		if not is_instance_valid(browser):
			_abort()
			return
		for entry: Dictionary in browser.catalog.entries:
			if entry.name != title: continue
			started = Time.get_ticks_usec()
			frame_ms.clear()
			browser._select(entry)
			var sample: Dictionary = {"name":title,"call_ms":(Time.get_ticks_usec()-started)/1000.0}
			while is_instance_valid(browser) and browser.selecting: await get_tree().process_frame
			if not is_instance_valid(browser):
				_abort()
				return
			sample.ready_ms = (Time.get_ticks_usec()-started)/1000.0
			var previews: Array[Node] = browser.find_children("*","TrackShowroom",true,false)
			if not previews.is_empty():
				while is_instance_valid(previews[0]) and not previews[0].ready_for_display: await get_tree().process_frame
				if not is_instance_valid(previews[0]):
					_abort()
					return
			sample.preview_ms = (Time.get_ticks_usec()-started)/1000.0
			if not frame_ms.is_empty():
				frame_ms.sort()
				sample.frame_p99_ms = frame_ms[mini(frame_ms.size()-1,int(frame_ms.size()*0.99))]
				sample.frame_max_ms = frame_ms[-1]
			report.selections.append(sample)
			break
	await get_tree().create_timer(2.0).timeout
	print("MENU_PROBE ",JSON.stringify(report))
	var output := FileAccess.open("user://menu_probe_results.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	queue_free()

func _run_page_swipes(app: Node) -> void:
	# Opt-in debug measurement of actual viewport input/rendering on the phone.
	# No races, settings, records, downloads or persisted drafts are created here.
	app._show_screen("tracks")
	await get_tree().create_timer(1.0).timeout
	var report: Dictionary = {"page_swipes":[],"failures":[],"device":OS.get_model_name()}
	for direction: int in [1,1,-1,-1,1,1,-1,-1]:
		var pages: Array[String] = ["tracks","biome","garage"]
		var expected: String = pages[pages.find(app.screen)+direction]
		var neighbor: Control = app.menu_neighbors[direction].body
		var slot: Rect2 = app.menu_body_slot.get_global_rect()
		var origin: Vector2 = slot.position + Vector2(slot.size.x * 0.65, 20)
		var touch := InputEventScreenTouch.new()
		touch.position = origin
		touch.pressed = true
		get_viewport().push_input(touch,true)
		var drag := InputEventScreenDrag.new()
		drag.position = origin + Vector2(-2 * direction,9)
		get_viewport().push_input(drag,true)
		frame_ms.clear()
		var drag_max_usec: int = 0
		for step: int in range(1,31):
			await get_tree().process_frame
			drag.position = origin + Vector2(-direction * slot.size.x * 0.4 * step / 30.0,12)
			var began: int = Time.get_ticks_usec()
			get_viewport().push_input(drag,true)
			drag_max_usec = maxi(drag_max_usec,Time.get_ticks_usec()-began)
		if not neighbor.visible: report.failures.append("neighbor hidden during drag")
		var drag_frames: Array[float] = frame_ms.duplicate()
		drag_frames.sort()
		touch.position = drag.position
		touch.pressed = false
		var began: int = Time.get_ticks_usec()
		get_viewport().push_input(touch,true)
		var sample: Dictionary = {"destination":expected,"commit_call_ms":(Time.get_ticks_usec()-began)/1000.0,"drag_call_max_ms":drag_max_usec/1000.0}
		if not drag_frames.is_empty():
			sample.drag_frame_p95_ms = drag_frames[mini(drag_frames.size()-1,int(drag_frames.size()*0.95))]
			sample.drag_frame_max_ms = drag_frames[-1]
		if app.screen != expected or app.menu_body != neighbor: report.failures.append("prepared page not committed: " + expected)
		await get_tree().create_timer(0.35).timeout
		frame_ms.sort()
		if not frame_ms.is_empty():
			sample.frame_count = frame_ms.size()
			sample.frame_p50_ms = frame_ms[mini(frame_ms.size()-1,int(frame_ms.size()*0.5))]
			sample.frame_p95_ms = frame_ms[mini(frame_ms.size()-1,int(frame_ms.size()*0.95))]
			sample.frame_p99_ms = frame_ms[mini(frame_ms.size()-1,int(frame_ms.size()*0.99))]
			sample.frame_max_ms = frame_ms[-1]
		report.page_swipes.append(sample)
	print("MENU_PAGE_PROBE ",JSON.stringify(report))
	var output := FileAccess.open("user://menu_probe_results.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	queue_free()

func _abort() -> void:
	print("MENU_PROBE interrupted by navigation")
	var output := FileAccess.open("user://menu_probe_results.json",FileAccess.WRITE)
	output.store_string('{"interrupted":true}')
	queue_free()

func _sample_frames(count: int) -> Dictionary:
	frame_ms.clear()
	for frame: int in range(count): await get_tree().process_frame
	var ordered: Array[float] = frame_ms.duplicate()
	ordered.sort()
	if ordered.is_empty(): return {}
	return {"count":ordered.size(),"p50_ms":ordered[int((ordered.size()-1)*0.50)],"p95_ms":ordered[int((ordered.size()-1)*0.95)],"p99_ms":ordered[int((ordered.size()-1)*0.99)],"max_ms":ordered[-1]}

func _run_quality_review(app: Node) -> void:
	app._show_screen("tracks")
	await get_tree().create_timer(1.5).timeout
	var report: Dictionary = {"quality_review":true,"device":OS.get_model_name(),"catalog_count":app.track_catalog.entries.size(),"status_calls_ms":[],"tab_calls_ms":[],"tab_frames":[]}
	report.idle_frames = await _sample_frames(120)
	var browser: TrackBrowser = app.menu_body.find_child("TrackBrowser",true,false)
	var cards: Array[int] = []
	for card: Node in browser.grid.get_children(): cards.append(card.get_instance_id())
	frame_ms.clear()
	for iteration: int in range(30):
		await get_tree().process_frame
		var began: int = Time.get_ticks_usec()
		app.cloud.changed.emit()
		report.status_calls_ms.append((Time.get_ticks_usec()-began)/1000.0)
	var after: Array[int] = []
	for card: Node in browser.grid.get_children(): after.append(card.get_instance_id())
	report.status_retained_cards = cards == after
	var status_frames: Array[float] = frame_ms.duplicate()
	status_frames.sort()
	report.status_frame_max_ms = status_frames[-1] if not status_frames.is_empty() else 0.0
	# Exercise the real navigation callbacks, including Create's draft setup.
	for destination: String in ["biome","garage","tracks","garage","biome","tracks"]:
		var began: int = Time.get_ticks_usec()
		if destination == "biome": app._new_document()
		elif destination == "tracks": app._open_race_area()
		else: app.root_ui.find_child("Tab_garage",true,false).pressed.emit()
		report.tab_calls_ms.append({"destination":destination,"ms":(Time.get_ticks_usec()-began)/1000.0})
		report.tab_frames.append(await _sample_frames(45))
	app._show_screen("tracks")
	await get_tree().create_timer(0.7).timeout
	print("MENU_QUALITY_PROBE ",JSON.stringify(report))
	var output := FileAccess.open("user://menu_probe_results.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	queue_free()
