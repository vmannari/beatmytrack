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
	var started: int = Time.get_ticks_usec()
	app.call("_show_screen","tracks")
	var report: Dictionary = {"open_ms":(Time.get_ticks_usec()-started)/1000.0,"selections":[]}
	report.open_costs = app.get("menu_open_costs")
	var browser: TrackBrowser = app.get("root_ui").find_child("TrackBrowser",true,false)
	report.detail_costs = browser.detail_costs
	while browser.loading: await get_tree().process_frame
	report.index_ready_ms = (Time.get_ticks_usec()-started)/1000.0
	for title: String in ["Ajorata","Knot","Ajorata"]:
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

func _abort() -> void:
	print("MENU_PROBE interrupted by navigation")
	var output := FileAccess.open("user://menu_probe_results.json",FileAccess.WRITE)
	output.store_string('{"interrupted":true}')
	queue_free()
