extends RefCounted
static var cache: Dictionary = {}
static func apply(effect: VehicleWeathering) -> void:
	if RenderingServer.get_current_rendering_method() != "gl_compatibility": return
	var targets: Array[ShaderMaterial] = []
	for binding: Dictionary in effect.bindings:
		var material: ShaderMaterial = binding.finish
		if not material.shader.code.contains("diffuse_toon"): continue
		if binding.wheel or binding.graphics or material.get_shader_parameter("rear_only") != 1.0: return
		if material not in targets: targets.append(material)
	for material: ShaderMaterial in targets: material.shader = shader(material.shader,"rear","toon_rear")
static func shader(original: Shader, role: String, policy: String) -> Shader:
	if policy == "baseline" or (policy == "wheel" and role != "wheel") or role == "paint": return original
	if policy in ["toon_rear","toon_graphics"] and (role != "rear" or not original.code.contains("diffuse_toon")): return original
	var source: String = original.code
	var include: String = FileAccess.get_file_as_string("res://vehicle/livery_finish.gdshaderinc")
	include = include.substr(0,include.find("vec3 graphic_pigment"))+"\nvec3 apply_graphics(vec3 pigment, vec3 p, vec3 n) { return pigment; }\n"
	source = source.replace('#include "res://vehicle/livery_finish.gdshaderinc"',include)
	if policy not in ["graphics","toon_graphics"]:
		for flag: String in ["wheel_surface","rear_only"]:
			var value: String = "1.0" if (flag == "wheel_surface" and role == "wheel") or (flag == "rear_only" and role == "rear") else "0.0"
			var declaration: String = "uniform float "+flag+" = 0.0;"
			source = source.replace(declaration,declaration+"\n#define "+flag+" "+value)
	var key: String = source.sha256_text()
	if not cache.has(key):
		var result := Shader.new(); result.code = source; cache[key] = result
	return cache[key]
