extends SceneTree
## Smoke/ground/winter preparation retains independent per-emitter materials.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	SandDust.prepared_emitters.clear()
	var begin: int = Time.get_ticks_usec()
	var dust := SandDust.new()
	root.add_child(dust)
	var track := NativeTrack.new()
	track.metadata = {"theme":"winter"}
	dust.prepare_track(track)
	var elapsed: int = Time.get_ticks_usec()-begin
	var code_groups: Dictionary = {}
	var material_ids: Dictionary = {}
	var emitters: Array[GPUParticles3D] = []
	var material: ShaderMaterial
	for child: Node in dust.get_children():
		if not child is GPUParticles3D: continue
		emitters.append(child)
		material = child.draw_pass_1.surface_get_material(0)
		var hash: String = material.shader.code.sha256_text()
		if not code_groups.has(hash): code_groups[hash] = {}
		code_groups[hash][material.shader.get_instance_id()] = true
		material_ids[material.get_instance_id()] = true
	var groups: Array = []
	for key: String in code_groups: groups.append(code_groups[key].size())
	groups.sort()
	material = null
	print("DUST_SHADER_PROBE emitters=",emitters.size()," materials=",material_ids.size()," shader_ids_per_code=",groups," build_us=",elapsed)
	if material_ids.size() != emitters.size() or groups != [1,1,1,1,1]: printerr("material ownership or shader grouping mismatch"); quit(1); return
	# Changes to one emitter's uniforms must not affect another's material.
	var a: ShaderMaterial = dust.dust_emitters[0].draw_pass_1.surface_get_material(0)
	var b: ShaderMaterial = dust.dust_emitters[1].draw_pass_1.surface_get_material(0)
	var snow: ShaderMaterial = dust.snow_impacts[0].draw_pass_1.surface_get_material(0)
	var snow_peer: ShaderMaterial = dust.snow_push[0].draw_pass_1.surface_get_material(0)
	if a.shader != b.shader or snow.shader != snow_peer.shader or a.shader == snow.shader: printerr("shader identity mismatch"); quit(1); return
	var ordinary_code: String = a.shader.code
	var snow_code: String = snow.shader.code
	if ordinary_code == snow_code: printerr("snow shader must differ"); quit(1); return
	a.set_shader_parameter("intersection_fade",0.123)
	if b.get_shader_parameter("intersection_fade") == 0.123: printerr("uniforms not independent"); quit(1); return
	dust.free()
	# A subsequent race can use the retained programs after the first world dies.
	var next := SandDust.new()
	root.add_child(next)
	next.prepare_track(track)
	var next_dust: ShaderMaterial = next.dust_emitters[0].draw_pass_1.surface_get_material(0)
	var next_snow: ShaderMaterial = next.snow_impacts[0].draw_pass_1.surface_get_material(0)
	if next_dust.shader.code != ordinary_code or next_snow.shader.code != snow_code or next_dust.get_shader_parameter("intersection_fade") == 0.123: printerr("subsequent race differs"); quit(1); return
	var dust_ref: WeakRef = weakref(next_dust.shader)
	var snow_ref: WeakRef = weakref(next_snow.shader)
	SandDust.prepared_emitters.clear()
	if next_dust.shader.code != ordinary_code or next_snow.shader.code != snow_code: printerr("live shader lost after template clearing"); quit(1); return
	next.free()
	a = null; b = null; snow = null; snow_peer = null; next_dust = null; next_snow = null
	if dust_ref.get_ref() != null or snow_ref.get_ref() != null: printerr("shader remains retained after live/template release: dust=%s snow=%s" % [dust_ref.get_ref(),snow_ref.get_ref()]); quit(1); return
	print("DUST_SHADER_REUSE_PASS")
	quit()
