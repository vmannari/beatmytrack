class_name ObjectPopulationPanel
extends Control
## Modal editor preview: the authored document remains untouched until Apply.
signal preview_changed(track: NativeTrack)
signal apply_requested(objects: Array)
signal cancel_requested

var source: Dictionary
var terrain: NativeTrack
var seed_value: int = 27
var density: float = 0.65
var roadside_reach: float = 22.0
var generated: Array = []
var population: ObjectPopulation
var worker: RefCounted
var revision: int = 0
var worker_revision: int = -1
var pending: bool = true
var debounce: float = 0.0
var ready_to_apply: bool = false
var status: Label
var apply_button: Button
var panel: PanelContainer
var navigation_canvas: EditorCanvas
var previous_mode: String = "objects"

func _ready() -> void:
	name = "ObjectPopulation"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	panel = PanelContainer.new()
	panel.name = "PopulationControls"
	panel.add_theme_stylebox_override("panel",EditorStyle.panel())
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -324; panel.offset_right = -16
	panel.offset_top = -171; panel.offset_bottom = 171
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	panel.add_child(column)
	column.add_child(MenuStyle.label("Populate",23))
	column.add_child(MenuStyle.label("Density",16))
	var density_slider := HSlider.new()
	density_slider.name = "PopulationDensity"
	density_slider.min_value = 0; density_slider.max_value = 1; density_slider.step = 0.05
	density_slider.value = density; density_slider.custom_minimum_size.y = 44
	column.add_child(density_slider)
	density_slider.value_changed.connect(func(value: float) -> void: density = value; request_preview())
	var reach_label: Label = MenuStyle.label("Roadside reach · %d m" % roadside_reach,16)
	reach_label.name = "PopulationReachLabel"
	column.add_child(reach_label)
	var reach_slider := HSlider.new()
	reach_slider.name = "PopulationReach"
	reach_slider.min_value = 16; reach_slider.max_value = 32; reach_slider.step = 1
	reach_slider.value = roadside_reach; reach_slider.custom_minimum_size.y = 44
	column.add_child(reach_slider)
	reach_slider.value_changed.connect(func(value: float) -> void:
		roadside_reach = value; reach_label.text = "Roadside reach · %d m" % value; request_preview())
	var shuffle: Button = EditorStyle.button("Shuffle",func() -> void: seed_value += 1; request_preview())
	shuffle.name = "PopulationShuffle"; shuffle.custom_minimum_size.y = 44
	column.add_child(shuffle)
	status = MenuStyle.label("Preparing scenery…",15,true)
	status.name = "PopulationStatus"; status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	var cancel: Button = EditorStyle.button("Cancel",func() -> void: cancel_requested.emit())
	cancel.name = "PopulationCancel"; cancel.custom_minimum_size.y = 44
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(cancel)
	apply_button = EditorStyle.button("Apply",func() -> void:
		if ready_to_apply: apply_requested.emit(generated.duplicate(true)))
	apply_button.name = "PopulationApply"; apply_button.custom_minimum_size.y = 44
	apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(apply_button)
	apply_button.disabled = true
	cancel.grab_focus()

func request_preview() -> void:
	revision += 1
	if worker != null: worker.cancel()
	pending = true; debounce = 0.18; ready_to_apply = false
	apply_button.disabled = true; status.text = "Preparing scenery…"; status.show()

func _gui_input(event: InputEvent) -> void:
	_forward_navigation(event)

func _input(event: InputEvent) -> void:
	# Finish a navigation gesture even if its finger/cursor crosses the panel.
	if not is_instance_valid(navigation_canvas) or navigation_canvas.active_pointer == -99: return
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag:
		_forward_navigation(event)
		get_viewport().set_input_as_handled()

func _forward_navigation(event: InputEvent) -> void:
	if not is_instance_valid(navigation_canvas): return
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		var local: InputEvent = event.duplicate()
		local.position = event.position+global_position-navigation_canvas.global_position
		navigation_canvas._gui_input(local)
		accept_event()

func _process(delta: float) -> void:
	debounce = maxf(0.0,debounce-delta)
	if worker != null and worker.done:
		var result: Dictionary = worker.result if worker.result is Dictionary else {}
		worker = null
		if worker_revision == revision and not result.is_empty():
			population = result.population
			generated = result.objects
			ready_to_apply = not generated.is_empty() and result.track != null
			apply_button.disabled = not ready_to_apply
			status.text = str(result.error)
			if status.text.is_empty() and not ready_to_apply: status.text = "No room for more objects."
			status.visible = not status.text.is_empty()
			if result.track != null: preview_changed.emit(result.track)
	if worker == null and pending and debounce <= 0.0:
		pending = false; worker_revision = revision
		worker = preload("res://editor/work_job.gd").start(preload("res://editor/population_job.gd").run.bind(source.duplicate(true),terrain,population,seed_value,density,roadside_reach),get_tree())
		if worker.thread == null:
			worker = null
			status.text = "Could not prepare scenery. Close and try again."

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		cancel_requested.emit()

func _exit_tree() -> void:
	if worker != null:
		worker.cancel()
		worker = null
