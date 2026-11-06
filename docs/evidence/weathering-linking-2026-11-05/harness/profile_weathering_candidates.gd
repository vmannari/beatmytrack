extends SceneTree
const CANDIDATE = preload("res://tests/weathering_candidate.gd")
var rows: Array = []
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image()
func run() -> void:
	if OS.get_environment("BMT_NATIVE_TRACE") == "1":
		if GDExtensionManager.load_extension(OS.get_environment("BMT_NATIVE_EXTENSION")) != GDExtensionManager.LOAD_STATUS_OK: quit(1); return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.size = Vector2i(800,600)
	var world := Node3D.new(); root.add_child(world)
	var camera := Camera3D.new(); world.add_child(camera)
	camera.position = Vector3(5,4,6); camera.look_at(Vector3(0,0.5,0))
	var sun := DirectionalLight3D.new(); world.add_child(sun)
	sun.rotation_degrees = Vector3(-50,-30,0); sun.shadow_enabled = true
	var selected: PackedStringArray = OS.get_environment("BMT_WEATHERING_CARS").split(",",false)
	if selected.is_empty(): selected = ["compact"]
	for id: String in selected:
		var car := CarVisual.new(); car.vehicle_id = id; world.add_child(car)
		while not car.model_ready: await process_frame
		var effect := VehicleWeathering.new(); effect.configure(car,"pine",VehicleCatalog.config(id))
		effect.dirt_amount = 0.6; effect.wetness = 0.3; effect.melt(0.0)
		await settle()
		var originals: Dictionary = {}; var roles: Dictionary = {}
		for binding: Dictionary in effect.bindings:
			var material: ShaderMaterial = binding.finish
			originals[material] = material.shader
			roles[material] = "wheel" if binding.wheel else ("paint" if binding.graphics else ("rear" if material.get_shader_parameter("rear_only") == 1.0 else "front"))
		var policies: PackedStringArray = OS.get_environment("BMT_WEATHERING_POLICIES").split(",",false)
		if policies.is_empty(): policies = ["baseline","wheel","graphics","roles","toon_rear","toon_rear","roles","graphics","wheel","baseline"]
		for policy: String in policies:
			print("WEATHERING_BEGIN ",policy," ",int(Time.get_unix_time_from_system()*1000000.0))
			var shaders: Dictionary = {}
			var nonce: String = "bmt_finish_"+str(Time.get_ticks_usec())
			var began: int = Time.get_ticks_usec()
			for material: ShaderMaterial in originals:
				var candidate: Shader = CANDIDATE.shader(originals[material],roles[material],"baseline" if policy == "warmup" else policy)
				var source: String = candidate.code.replace('#include "res://vehicle/livery_finish.gdshaderinc"',FileAccess.get_file_as_string("res://vehicle/livery_finish.gdshaderinc"))
				source = source.replace("wash_volume",nonce)
				if not shaders.has(source):
					var fresh := Shader.new(); fresh.code = source; shaders[source] = fresh
				material.shader = shaders[source]
				material.set_shader_parameter(nonce,effect.wash_texture)
				material.set_shader_parameter("slow_"+nonce,effect.slow_wash_texture)
			await settle()
			var row := {"car":id,"policy":policy,"sources":shaders.size(),"materials":originals.size(),"ms":(Time.get_ticks_usec()-began)/1000.0}
			rows.append(row); print("WEATHERING_CANDIDATE ",JSON.stringify(row))
			print("WEATHERING_END ",policy," ",int(Time.get_unix_time_from_system()*1000000.0))
			FileAccess.open(OS.get_environment("BMT_GRAPHICS_OUTPUT").path_join("timings.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
		for material: ShaderMaterial in originals: material.shader = originals[material]
		effect.reset(); car.free(); await process_frame
	quit()
