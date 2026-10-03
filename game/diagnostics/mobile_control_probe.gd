extends Node
## Opt-in debug-only Android viewport multitouch regression; never changes player settings.
signal finished(report: Dictionary)
var report_path: String = "user://control_probe_report.json"
var failures: Array[String] = []
var checks: int = 0
var controls: TouchControls
func _ready() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func send_touch(finger: int, point: Vector2, pressed: bool = true, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger; event.position = point; event.pressed = pressed; event.canceled = canceled
	get_viewport().push_input(event,true)
func send_drag(finger: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = finger; event.position = point
	get_viewport().push_input(event,true)
func run() -> void:
	var app: Node = get_parent()
	if app.has_method("_show_screen"): app.get("root_ui").visible = false
	controls = TouchControls.new()
	controls.driver = DriverInput.new()
	add_child(controls)
	await get_tree().process_frame
	for method: String in ControlLayout.METHODS:
		for left: bool in [false,true]:
			controls.layout = ControlLayout.preset(left)
			controls.layout.steering_type = method
			var boxes: Array[Rect2] = controls.touch_zones()
			for rect: Rect2 in boxes: check(controls.usable_area().encloses(rect),"safe touch bounds")
			send_touch(2,boxes[0].get_center())
			send_touch(5,boxes[3].get_center())
			check(controls.driver.sample().steer < 0 and controls.driver.sample().throttle == 255,"steer+gas")
			send_touch(11,boxes[4].get_center())
			check(controls.driver.sample().handbrake == 255 and controls.driver.sample().throttle == 255,"independent handbrake with gas")
			send_touch(11,Vector2.ZERO,false,true)
			check(controls.driver.sample().handbrake == 0 and controls.driver.sample().throttle == 255,"canceled handbrake preserves gas")
			send_touch(7,boxes[2].get_center())
			check(controls.driver.sample().brake == 255,"third finger brake")
			send_touch(5,Vector2.ZERO,false)
			check(controls.driver.sample().throttle == 0 and controls.driver.sample().steer < 0 and controls.driver.sample().brake == 255,"independent release")
			send_touch(9,boxes[2].get_center())
			send_touch(7,Vector2.ZERO,false)
			check(controls.driver.sample().brake == 255,"brake handoff")
			send_drag(9,Vector2(boxes[2].get_center().x,boxes[2].end.y+4))
			check(controls.driver.sample().brake > 0 and controls.driver.sample().brake < 255,"analog excursion")
			send_touch(9,Vector2.ZERO,false,true)
			check(controls.driver.sample().brake == 0,"canceled brake")
			send_touch(2,Vector2.ZERO,false)
			check(controls.driver.sample().steer == 0,"steering releases")
			send_touch(4,boxes[3].get_center())
			controls.enabled = false
			check(controls.driver.sample().throttle == 0,"disabled release")
			controls.enabled = true
	var report: Dictionary = {"checks":checks,"failures":failures,"platform":OS.get_name(),"viewport":str(controls.size),"safe_area":str(controls.usable_area()),"scope":"Synthetic multi-finger events through Android Godot viewport, not physical touchscreen gestures"}
	var file := FileAccess.open(report_path,FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report,"\t")); file.close()
	print("ANDROID_CONTROL_PROBE: "+JSON.stringify(report))
	if app.has_method("_show_screen"): app.get("root_ui").visible = true
	finished.emit(report)
	controls.queue_free()
	queue_free()
