extends SceneTree
const PRUNE = preload("res://track/surface_shader_pruning.gd")
const PROBE = preload("res://tests/probe_first_use_comparison.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var reference := GDScript.new()
	reference.source_code = FileAccess.get_file_as_string("res://tests/fixtures/first_use_validated_pruning.gd.txt")
	if reference.reload() != OK: quit(1); return
	var baseline: GDScript = PROBE.generator([])
	var names: Array[String] = SurfaceShaderVariants.FLAGS.duplicate()
	for flag: String in SurfaceShaderVariants.MATERIAL_FLAGS: names.append("fixed_"+flag)
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	for theme: String in ["pine","winter","desert","storm","night_city"]:
		document.theme = theme
		var track: NativeTrack = TrackCompiler.compile(document)
		var world := NativeTrackVisual.new()
		world.persist_road_meshes = false; world.cache_road_meshes = false
		root.add_child(world)
		await world.build(track,BridgePresentation.new(track))
		var sources: Dictionary = {}
		for original: ShaderMaterial in PROBE.materials(world):
			var material: ShaderMaterial = original.get_meta("surface_dynamic_material").duplicate()
			baseline.specialize(material,false)
			sources[material.shader.code] = true
		var elapsed: int = 0
		for source: String in sources:
			var before: String = reference.reduce(source,names)
			var start: int = Time.get_ticks_usec()
			var after: String = PRUNE.reduce(source,names)
			elapsed += Time.get_ticks_usec()-start
			checks += 1
			if before != after: failures += 1; push_error(theme+" validated shader changed")
		print("FINAL_PRUNING_PARITY ",theme," sources=",sources.size()," cpu_ms=",elapsed/1000.0)
		world.free()
		await process_frame
	print("FINAL_PRUNING_PARITY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
