extends SceneTree
## Offline compiler-work probe. Fresh sampler names avoid reusing identical source;
## this is not an erased-driver-cache or end-to-end race-loading benchmark.
const PROBE = preload("res://tests/probe_shader_variant_consolidation.gd")
const SAMPLERS = preload("res://tests/test_sampler_pruning.gd")
var report: Dictionary = {"rows":[],"note":"Visible material grid, renamed shared sampler per trial, allocation through two draws and readback. Driver caches are not erased. No end-to-end/device claim."}

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var output: String = OS.get_environment("BMT_VARIANT_OUTPUT")
	if output.is_empty(): push_error("Explicit output required"); quit(1); return
	var flags: Array = Array(OS.get_environment("BMT_VARIANT_FLAGS").split(",",false))
	var candidate: GDScript = PROBE.generator([],false,true)
	if OS.get_environment("BMT_VARIANT_FINAL") == "1": candidate = PROBE.generator([],false,true)
	var baseline: GDScript = SAMPLERS.before_generator()
	if candidate == null or baseline == null: quit(1); return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.size = Vector2i(640,480)
	var stage := Node3D.new()
	root.add_child(stage)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 50.0
	camera.position = Vector3(0,35,10)
	camera.look_at(Vector3.ZERO)
	var sun := DirectionalLight3D.new()
	stage.add_child(sun)
	sun.rotation_degrees = Vector3(-65,-30,0)
	sun.shadow_enabled = true
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	var selected: PackedStringArray = OS.get_environment("BMT_VARIANT_THEMES").split(",",false)
	if selected.is_empty(): selected = ["pine","winter","desert","storm","night_city"]
	for theme: String in selected:
		doc.theme = theme
		var track: NativeTrack = TrackCompiler.compile(doc)
		var visual := NativeTrackVisual.new()
		visual.hide()
		visual.persist_road_meshes = false
		visual.cache_road_meshes = false
		stage.add_child(visual)
		await visual.build(track,BridgePresentation.new(track))
		var originals: Array[ShaderMaterial] = PROBE.materials(visual)
		var variants: Dictionary = {"baseline":[],"candidate":[]}
		for mode: String in variants:
			for original: ShaderMaterial in originals:
				var material: ShaderMaterial = original.get_meta("surface_dynamic_material").duplicate()
				(baseline if mode == "baseline" else candidate).specialize(material)
				variants[mode].append(material)
		visual.free()
		# Prime textures, lighting and common engine pipelines before timed A/B.
		for mode: String in ["warmup","baseline","candidate","candidate","baseline"]:
			var material_mode: String = "baseline" if mode == "warmup" else mode
			var grid := Node3D.new()
			stage.add_child(grid)
			var nonce: String = "bmt_probe_sampler_"+str(Time.get_ticks_usec())
			var shaders: Dictionary = {}
			var start: int = Time.get_ticks_usec()
			for index: int in range(variants[material_mode].size()):
				var original: ShaderMaterial = variants[material_mode][index]
				var material: ShaderMaterial = original.duplicate()
				var source: String = original.shader.code
				# Expand the remaining small includes before renaming their sampler.
				var include_pattern := RegEx.new()
				include_pattern.compile('#include "([^"]+)"')
				for pass_index: int in range(3):
					for match_include: RegExMatch in include_pattern.search_all(source):
						source = source.replace(match_include.get_string(),FileAccess.get_file_as_string(match_include.get_string(1)))
				source = source.replace("surface_factors",nonce)
				if not shaders.has(source):
					var shader := Shader.new()
					shader.code = source
					shaders[source] = shader
				material.shader = shaders[source]
				material.set_shader_parameter(nonce,original.get_shader_parameter("surface_factors"))
				var mesh := MeshInstance3D.new()
				var plane := PlaneMesh.new()
				plane.size = Vector2(9,9)
				mesh.mesh = plane
				mesh.material_override = material
				grid.add_child(mesh)
				mesh.position = Vector3((index%4-1.5)*10,0,(index/4-1)*10)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var captured: Image = root.get_texture().get_image()
			var elapsed: float = float(Time.get_ticks_usec()-start)/1000.0
			var row: Dictionary = {"theme":theme,"mode":mode,"sources":shaders.size(),"materials":variants[material_mode].size(),"elapsed_ms":elapsed,"readback_bytes":captured.get_data().size()}
			report.rows.append(row)
			print("FIRST_DRAW ",JSON.stringify(row))
			FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
			grid.free()
			for frame: int in range(3): await process_frame
	quit()
