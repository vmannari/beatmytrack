extends SceneTree
var mode: String = "thread"
var count: int = 1000
var document: Dictionary = {}
class Emitter extends RefCounted:
	signal changed
class Sink extends Node:
	var source: Emitter
	func receive() -> void: pass
	func wait_for_signal() -> void: await source.changed
	func wait_for_draw() -> void: await RenderingServer.frame_post_draw
var emitter := Emitter.new()
var churn: Dictionary = {}
func _initialize() -> void: run.call_deferred()
static func empty() -> int: return 1
static func work(_cancelled: Callable) -> int: return 1
static func compile_work(source: Dictionary) -> NativeTrack:
	var track: NativeTrack = TrackCompiler.compile(source)
	track._creator_query()
	return track
func sample(index: int) -> void:
	print("MICRO ",mode," ",index," ",OS.get_static_memory_usage()," ",int(Performance.get_monitor(Performance.OBJECT_COUNT)))
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		if arg.begins_with("--count="): count = int(arg.trim_prefix("--count="))
	if mode in ["compile","compile_thread"]: document = TrackDocument.create_default()
	if mode in ["compile_storm","compile_storm_thread"]:
		document = JSON.parse_string(FileAccess.get_file_as_string("res://resources/storm_tracks/storm_freight.json"))
		document.theme = "pine"; document.objects = []
	print("ACCESSIBILITY ",DisplayServer.get_name()," ",DisplayServer.has_feature(DisplayServer.FEATURE_ACCESSIBILITY_SCREEN_READER))
	sample(0)
	for index: int in range(count):
		match mode:
			"thread":
				var thread := Thread.new()
				thread.start(empty); thread.wait_to_finish()
			"work":
				var job: RefCounted = preload("res://editor/work_job.gd").start(work,self)
				while not job.done: await process_frame
			"accessibility":
				var node := Node.new(); root.add_child(node)
				node.queue_accessibility_update(); node.free()
			"node":
				var node := Node3D.new(); root.add_child(node); node.free()
			"resource":
				var material := StandardMaterial3D.new()
				material.albedo_color = Color.RED
			"label":
				var label := Label.new(); label.text = "stable"; root.add_child(label); label.free()
			"button", "button_wired":
				var button := Button.new(); root.add_child(button)
				if mode=="button_wired": GameSoundtrack.instance()._wire_button(button)
				button.free()
			"signal":
				var sink := Sink.new()
				emitter.changed.connect(sink.receive)
				sink.free()
			"await_signal", "await_draw":
				var sink := Sink.new(); sink.source = emitter
				if mode=="await_signal": sink.wait_for_signal()
				else: sink.wait_for_draw()
				sink.free()
			"frame":
				var frame := DriveFrame.new(); frame.throttle = 0
			"loading":
				var overlay: Node = load("res://ui/race_loading.gd").new()
				root.add_child(overlay)
				for _frame: int in range(2): await process_frame
				overlay.free()
			"viewport":
				var viewport := SubViewport.new()
				viewport.own_world_3d = true
				root.add_child(viewport)
				viewport.free()
			"viewport_camera":
				var viewport := SubViewport.new(); viewport.own_world_3d = true
				root.add_child(viewport)
				var camera := Camera3D.new(); viewport.add_child(camera); camera.current = true
				var _texture: ViewportTexture = viewport.get_texture()
				viewport.free()
			"dictionary":
				churn[str(index)] = index
				churn.erase(str(index))
			"tween":
				var node := Control.new(); root.add_child(node)
				var tween: Tween = node.create_tween()
				tween.tween_property(node,"modulate:a",0.0,0.1)
				node.free()
			"world":
				var world := World3D.new()
				var _scenario: RID = world.scenario
				var _space: RID = world.space
				var _navigation: RID = world.navigation_map
			"pack":
				var node := Node3D.new(); var mesh := MeshInstance3D.new(); mesh.mesh = BoxMesh.new()
				node.add_child(mesh); mesh.owner = node
				var scene := PackedScene.new(); scene.pack(node); node.free()
			"compile", "compile_storm":
				var track: NativeTrack = TrackCompiler.compile(document)
				track._creator_query()
				track = null
				if (index+1)%10==0: sample(index+1)
			"compile_thread", "compile_storm_thread":
				var thread := Thread.new()
				thread.start(compile_work.bind(document))
				var track: NativeTrack = thread.wait_to_finish()
				track = null
				if (index+1)%10==0: sample(index+1)
		if (index+1)%100 == 0:
			await process_frame; await process_frame
			sample(index+1)
	for _frame: int in range(8): await process_frame
	sample(count+1)
	if mode=="await_signal": emitter.changed.emit(); sample(count+2)
	if mode=="await_draw": RenderingServer.force_draw(false,0); sample(count+2)
	quit()
