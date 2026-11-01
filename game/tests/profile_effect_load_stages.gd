extends "res://tests/profile_track_load_stages.gd"
## Offline diagnostic: instruments only in-memory copies of App and effect preparation.

func instrumented_app() -> GDScript:
	var script := super.instrumented_app()
	if script == null: return null
	var needle := 'var effect_preparation = preload("res://vehicle/effect_render_preparation.gd")'
	var source := script.source_code
	if source.count(needle) != 1:
		push_error("Effect preparation anchor changed")
		return null
	source = source.replace(needle,'var effect_preparation = load("res://tests/profile_effect_load_stages.gd").make_effect_probe()')
	script.source_code = source
	if script.reload() != OK:
		push_error("Effect-instrumented App failed to compile")
		return null
	return script

static func make_effect_probe() -> GDScript:
	var source := FileAccess.get_file_as_string("res://vehicle/effect_render_preparation.gd")
	var needle := '\t\tif not draw.is_valid() or not bool(await draw.call()): return prepared'
	if source.count(needle) != 1:
		push_error("Particle draw anchor changed")
		return null
	var replacement := '\t\tvar _probe_started := Time.get_ticks_usec()\n'+needle+'\n\t\tprint("EFFECT_DRAW ", JSON.stringify({"name":source.name,"elapsed_ms":(Time.get_ticks_usec()-_probe_started)/1000.0,"reused":bool(particles.get_meta("preparation_reused",false)),"process_class":source.process_material.get_class() if source.process_material != null else "none","draw_mesh":source.get_draw_pass_mesh(0).get_instance_id() if source.draw_passes > 0 and source.get_draw_pass_mesh(0) != null else 0}))'
	source = source.replace(needle,replacement)
	var script := GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		push_error("Instrumented effect preparation failed to compile")
		return null
	return script
