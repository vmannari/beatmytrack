extends "res://tests/test_shared_graphics_first_laps.gd"
const Profiles = preload("res://rendering/biome_shader_profile.gd")
var shader_reports: Array = []
var omitted: Dictionary = {}
func run() -> void:
	if "--observe-only" in OS.get_cmdline_user_args():
		Profiles._manifest = {}; Profiles._loaded = true
	if "--omit-profile-entry" in OS.get_cmdline_user_args():
		Profiles._manifest = JSON.parse_string(FileAccess.get_file_as_string(Profiles.MANIFEST))
		Profiles._loaded = true
		for profile: Dictionary in Profiles._manifest.profiles.values():
			if profile.context.biome != "pine" or profile.context.car != "compact": continue
			var counts: Dictionary = {}
			for entry: Dictionary in profile.entries: counts[entry.shader] = int(counts.get(entry.shader,0))+1
			for index: int in range(profile.entries.size()):
				var entry: Dictionary = profile.entries[index]
				if counts[entry.shader] > 1:
					omitted = entry.duplicate(); profile.entries.remove_at(index); break
		check(not omitted.is_empty(),"positive control omits one measured variant of a still-known shader")
	await super.run()

func race(vehicle: String, theme: String, interruption: String = "complete") -> void:
	if "--biomes-only" in OS.get_cmdline_user_args() and (vehicle != "compact" or interruption != "complete"): return
	await super.race(vehicle,theme,interruption)

func first_emission(game: Node) -> void:
	check(game.shader_profile.token > 0,"engine shader observer owns actual race scope")
	if "--require-profiles" in OS.get_cmdline_user_args():
		check(game.shader_profile.status == "matched" and game.shader_profile.snapshot().selective,"reviewed biome profile actually enables selective preparation")
	var output: String = OS.get_environment("BMT_GRAPHICS_OUTPUT")
	var theme: String = str(game.native_track.metadata.theme)
	if not output.is_empty():
		game.process_mode = Node.PROCESS_MODE_DISABLED
		Engine.time_scale = 0.0
		for _frame: int in range(6): await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(theme+"-ready.png"))
		Engine.time_scale = 1.0
	var ready: Dictionary = game.shader_profile.snapshot()
	if not omitted.is_empty():
		var found: bool = false
		for event: Dictionary in ready.observations:
			found = found or (event.shader == omitted.shader and event.variant == omitted.variant and event.specialization == omitted.specialization and event.missing)
		check(found,"omitted required variant renders through fallback and is reported")
	await super.first_emission(game)
	if "--inject-shader-miss" in OS.get_cmdline_user_args():
		var shader := Shader.new()
		shader.code = "shader_type canvas_item; // BMT deliberate late miss\nvoid fragment(){COLOR=vec4(0.5,0.1,0.2,1.0);}"
		var material := ShaderMaterial.new(); material.shader = shader
		var control := ColorRect.new(); control.size = Vector2(32,32); control.material = material
		root.add_child(control)
		await process_frame
		await RenderingServer.frame_post_draw
		var injected: Dictionary = game.shader_profile.snapshot()
		var found: bool = false
		for event: Dictionary in injected.observations:
			found = found or (event.missing and event.compile_phase == "driving" and event.compile_us > 0)
		check(found,"deliberate driving-time compilation is reported as a costly miss")
		control.queue_free()
		await process_frame
	var final: Dictionary = game.shader_profile.snapshot()
	if "--pause-profile-control" in OS.get_cmdline_user_args():
		var previous: int = game.shader_profile.token
		var original_context: String = game.shader_profile.context_key
		game.paused = true
		game.shader_profile._process(0.0)
		check(game.shader_profile.token == 0,"pause closes the driving observation before menu rendering")
		var old: Variant = game.preference_records.settings.get("shadow_quality")
		game.preference_records.settings.shadow_quality = "off"
		game.paused = false
		game.shader_profile._process(0.0)
		check(game.shader_profile.token > previous and game.shader_profile.context_key == original_context,"resume starts a fresh scope using applied graphics rather than staged settings")
		if old == null: game.preference_records.settings.erase("shadow_quality")
		else: game.preference_records.settings.shadow_quality = old
	shader_reports.append({"ready":ready,"final":final,"summary":Profiles.summary(final)})
	if not output.is_empty():
		FileAccess.open(output.path_join("profiles.json"),FileAccess.WRITE).store_string(JSON.stringify(shader_reports,"\t"))
	print("BIOME_SHADER_PROFILE ",JSON.stringify(Profiles.summary(final)))
