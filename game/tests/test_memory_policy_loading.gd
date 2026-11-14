extends SceneTree
## Fresh-process accounting must observe caches without loading their builders.
const COLD: Array[String] = ["res://track/native_track_visual.gd", "res://editor/road_preparation.gd", "res://track/creator_prop_visual.gd", "res://vehicle/car_visual.gd", "res://vehicle/compact_detail.gd", "res://editor/object_thumbnail.gd", "res://vehicle/effect_render_preparation.gd", "res://vehicle/visible_contact_audio.gd", "res://ui/garage_paint_icons.gd", "res://editor/editor_canvas.gd"]
var checks: int = 0
var failures: int = 0

class Session extends RefCounted:
	var primed: Dictionary = {}

class Owner extends Node:
	var canvas: Node
	var editor_preview_thread: Thread
	var editor_world: Node
	var editor_compiled_cache: Array = []
	var editor_raster_cache: Dictionary = {}
	var history: Array = []
	var redo_history: Array = []
	var editor_gesture_history: Array = []
	var editor_gesture_redo: Array = []
	var editor_session := Session.new()
	const EDITOR_COMPILED_BUDGET: int = 48*1024*1024

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("MEMORY_LOADING_FAIL ",label)

func cold(stage: String) -> void:
	for path: String in COLD:
		check(not ResourceLoader.has_cached(path),stage+" leaves "+path+" unloaded")

func run() -> void:
	cold("fixture")
	var path: String = "res://editor/editor_memory.gd"
	for option: String in OS.get_cmdline_user_args():
		if option.begins_with("--policy="): path = option.trim_prefix("--policy=")
	var began: int = Time.get_ticks_usec()
	var policy: Script = load(path)
	var load_us: int = Time.get_ticks_usec()-began
	check(policy != null and policy.can_instantiate(),"policy loads")
	cold("policy load")
	var owner := Owner.new()
	root.add_child(owner)
	began = Time.get_ticks_usec()
	var empty: Dictionary = policy.retained(owner)
	var retained_us: int = Time.get_ticks_usec()-began
	check(empty.retained_bytes == 0 and empty.optional_garage_bytes == 0,"uncreated caches have zero owned bytes")
	cold("accounting")
	var manager: RefCounted = policy.new()
	manager.pressure_requested = true
	manager.tick(owner)
	check(manager.trims == 1 and not manager.pressure_requested,"pressure completes on empty optional caches")
	cold("empty pressure")
	# Cache providers admitted later must become visible without a permanent
	# negative cache. This numeric cache has no presentation dependencies.
	var support: Script = load("res://track/road_support_cache.gd")
	support.write("policy-loading",{"value":PackedFloat32Array([1,2,3])},support.generation)
	check(support.bytes_used() > 0,"late fixture owns bytes")
	check(policy.retained(owner).other.road_support_bytes == support.bytes_used(),"late cache contributes its exact current allocation")
	manager.pressure_requested = true
	manager.next_sample = 0
	manager.tick(owner)
	check(support.bytes_used() == 0,"real pressure trims a late cache")
	cold("late cache pressure")
	# Simulate data owned by a worker: pressure must not clear it or pretend
	# the pending reclamation completed. No actual thread/join is necessary.
	var work: Script = load("res://editor/work_job.gd")
	work.pending.append(RefCounted.new())
	owner.editor_preview_thread = Thread.new()
	owner.editor_compiled_cache = [{"bytes":123,"value":"owned"}]
	owner.editor_raster_cache = {"prepared_bytes":456,"value":"owned"}
	manager.pressure_requested = true
	manager.next_sample = 0
	manager.tick(owner)
	check(owner.editor_compiled_cache == [{"bytes":123,"value":"owned"}] and owner.editor_raster_cache == {"prepared_bytes":456,"value":"owned"},"worker-owned caches remain exact under pressure")
	check(manager.pressure_requested,"unfinished reclamation remains pending")
	check(manager.telemetry.compiled_bytes == owner.EDITOR_COMPILED_BUDGET and manager.telemetry.raster_bytes == 24*1024*1024,"busy worker keeps conservative reservations")
	owner.editor_preview_thread = null
	work.pending.clear()
	manager.next_sample = 0
	manager.tick(owner)
	check(owner.editor_compiled_cache.is_empty() and owner.editor_raster_cache == {"enabled":true},"retired worker data can be reclaimed")
	check(not manager.pressure_requested,"completed reclamation clears pressure")
	cold("worker pressure")
	check(policy.RETAINED_BUDGET == 64*1024*1024 and policy.GARAGE_BUDGET == 96*1024*1024 and policy.PRESSURE_HISTORY == 2*1024*1024,"unchanged budgets")
	owner.free()
	print("MEMORY_LOADING_TIMING ",JSON.stringify({"policy":path,"load_us":load_us,"retained_us":retained_us}))
	print("MEMORY_LOADING ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
