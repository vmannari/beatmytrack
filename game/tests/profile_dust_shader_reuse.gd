extends SceneTree
## Interleaved emitter-construction microbenchmark with current code as its scalar control.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var before := GDScript.new()
	var source: String = FileAccess.get_file_as_string("res://vehicle/sand_dust.gd").replace("\r\n","\n").replace("class_name SandDust","")
	var early_reuse: String = "if cached != null: return _material_with_shader(mode,cached)"
	var snow_reuse: String = "var snow_shader: Shader = _snow_cloud_shader.get_ref() if _snow_cloud_shader != null else null"
	assert(source.contains(early_reuse) and source.contains(snow_reuse),"Control requires the known shared-shader code")
	before.source_code = source.replace(early_reuse,"if false: return _material_with_shader(mode,cached)").replace(snow_reuse,"var snow_shader: Shader = null")
	assert(before.reload() == OK)
	var track := NativeTrack.new(); track.metadata = {"theme":"winter"}
	var results := [[],[]]
	for iteration: int in range(14):
		for variant: int in ([0,1] if iteration % 2 == 0 else [1,0]):
			if variant == 0: before.get("prepared_emitters").clear()
			else: SandDust.prepared_emitters.clear()
			var start: int = Time.get_ticks_usec()
			var dust: Node3D = before.new() if variant == 0 else SandDust.new()
			root.add_child(dust); dust.prepare_track(track)
			var elapsed: int = Time.get_ticks_usec()-start
			dust.free()
			if iteration >= 4: results[variant].append(elapsed)
	results[0].sort(); results[1].sort()
	print("DUST_BUILD_AB before=",results[0]," after=",results[1])
	quit()
