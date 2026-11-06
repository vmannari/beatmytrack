extends SceneTree
const PROBE = preload("res://tests/probe_shader_variant_consolidation.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

# The sampler-budget follow-up changes only these three unreachable declarations.
# The first-use pass also removes proven inactive bodies. Its parsing and scope
# contract is tested separately; retain the prior sharing/binding/cache checks.
func sampler_contract(source: String) -> String:
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		var names: Array[String] = SurfaceShaderVariants.FLAGS.duplicate()
		for flag: String in SurfaceShaderVariants.MATERIAL_FLAGS: names.append("fixed_"+flag)
		source = preload("res://track/surface_shader_pruning.gd").reduce(source,names)
	for name: String in ["painted_grass_texture","snow_road_sources","road_mask"]:
		var declaration := RegEx.new()
		declaration.compile("(?m)^(uniform sampler2D "+name+"\\b[^;]*;|#define "+name+" surface_factors)\\r?$")
		source = declaration.sub(source,"// sampler contract: "+name,true)
	return source

func run() -> void:
	var baseline: GDScript = PROBE.generator([])
	check(baseline != null,"task-start generator loads independently")
	if baseline == null: quit(1); return
	var validated := GDScript.new()
	validated.source_code = FileAccess.get_file_as_string("res://tests/fixtures/shader_consolidation_gl_candidate.gd.txt").replace("class_name SurfaceShaderVariants\n","")
	check(validated.reload() == OK,"measured Compatibility candidate loads independently")
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	var counts: Dictionary = {}
	for theme: String in ["pine","winter","desert","storm","night_city"]:
		doc.theme = theme
		var track: NativeTrack = TrackCompiler.compile(doc)
		var visual := NativeTrackVisual.new()
		visual.persist_road_meshes = false
		visual.cache_road_meshes = false
		root.add_child(visual)
		await visual.build(track,BridgePresentation.new(track))
		var old_hashes: Dictionary = {}
		var new_hashes: Dictionary = {}
		var originals: Array[ShaderMaterial] = PROBE.materials(visual)
		check(not originals.is_empty(),theme+" exercises real surface materials")
		for actual: ShaderMaterial in originals:
			var dynamic: ShaderMaterial = actual.get_meta("surface_dynamic_material")
			var control: ShaderMaterial = dynamic.duplicate()
			baseline.specialize(control)
			var measured: ShaderMaterial = dynamic.duplicate()
			validated.specialize(measured)
			var expected: ShaderMaterial = measured if RenderingServer.get_current_rendering_method() == "gl_compatibility" else control
			check(sampler_contract(actual.shader.code) == sampler_contract(expected.shader.code),theme+" retains validated source after audited sampler and inactive-body passes")
			old_hashes[sampler_contract(control.shader.code).sha256_text()] = true
			new_hashes[sampler_contract(actual.shader.code).sha256_text()] = true
			var bindings_equal: bool = true
			for uniform: Dictionary in control.shader.get_shader_uniform_list():
				if uniform.name in ["painted_grass_texture","snow_road_sources","road_mask"] and actual.shader.code.contains("#define "+uniform.name+" surface_factors"): continue
				bindings_equal = bindings_equal and actual.get_shader_parameter(uniform.name) == control.get_shader_parameter(uniform.name)
			check(bindings_equal,theme+" retains every material binding and texture identity")
			var prepared: ShaderMaterial = dynamic.duplicate()
			var hits: int = SurfaceShaderVariants.prepared_hits
			SurfaceShaderVariants.specialize(prepared)
			check(prepared.shader == actual.shader and SurfaceShaderVariants.prepared_hits == hits+1,theme+" prepared signature reuses the correct shared shader")
			var uncached: ShaderMaterial = dynamic.duplicate()
			SurfaceShaderVariants.specialize(uncached,false)
			check(uncached.shader == actual.shader,theme+" fresh preparation agrees with cached preparation")
		if theme in ["pine","winter"] or RenderingServer.get_current_rendering_method() != "gl_compatibility":
			check(new_hashes == old_hashes,theme+" original shader sources stay exact")
		else:
			check(new_hashes.size() == old_hashes.size()-1,theme+" removes exactly one source on the Star fixture")
		counts[theme] = {"before":old_hashes.size(),"after":new_hashes.size()}
		visual.free()
		await process_frame
	check(SurfaceShaderVariants.cache.size() <= 64 and SurfaceShaderVariants.prepared_keys.size() <= 64,"original cache bounds remain")
	print("CONSOLIDATION_SOURCES ",JSON.stringify(counts))
	print("SHADER_CONSOLIDATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
