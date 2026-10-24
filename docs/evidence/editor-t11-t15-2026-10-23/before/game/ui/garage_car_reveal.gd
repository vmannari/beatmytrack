class_name GarageCarReveal
extends RefCounted
## Menu-only vertical light sweep. Original materials remain untouched.
static var shaders: Dictionary = {}
const STANDARD: String = """shader_type spatial;
uniform vec4 garage_albedo : source_color = vec4(1.0);
uniform float garage_roughness = 0.8;
uniform float garage_metallic = 0.0;
uniform float garage_specular = 0.5;
uniform vec3 garage_emission : source_color;
uniform bool garage_vertex_color = false;
void fragment() {
	ALBEDO = garage_albedo.rgb * (garage_vertex_color ? COLOR.rgb : vec3(1.0));
	ROUGHNESS = garage_roughness;
	METALLIC = garage_metallic;
	SPECULAR = garage_specular;
	EMISSION = garage_emission;
}
"""
var bindings: Array[Dictionary] = []
var materials: Array[ShaderMaterial] = []
var visibility: float = 1.0
var height_min: float = INF
var height_max: float = -INF

func prepare(root: Node3D) -> void:
	var copies: Dictionary = {}
	_collect(root, copies)
	set_visibility(visibility)

func _collect(node: Node3D, copies: Dictionary) -> void:
	if node is MeshInstance3D:
		var bounds: AABB = node.get_aabb()
		for corner: int in range(8):
			var height: float = (node.global_transform * bounds.get_endpoint(corner)).y
			height_min = minf(height_min,height)
			height_max = maxf(height_max,height)
		var original_override: Material = node.material_override
		for index: int in range(1 if original_override != null else node.mesh.get_surface_count()):
			var source: Material = node.get_active_material(index)
			if source == null: continue
			if not copies.has(source):
				copies[source] = _copy(source)
				materials.append(copies[source])
			bindings.append({"node":node,"index":index,"override":original_override,"surface":node.get_surface_override_material(index)})
			if original_override != null: node.material_override = copies[source]
			else: node.set_surface_override_material(index, copies[source])
	for child: Node in node.get_children():
		if child is Node3D: _collect(child, copies)

func _copy(source: Material) -> ShaderMaterial:
	var code: String = source.shader.code if source is ShaderMaterial else STANDARD
	if source is BaseMaterial3D:
		var modes: String = "unshaded" if source.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED else "diffuse_toon" if source.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON else "diffuse_burley"
		if source.cull_mode == BaseMaterial3D.CULL_DISABLED: modes += ", cull_disabled"
		code = code.replace("shader_type spatial;","shader_type spatial;\nrender_mode " + modes + ";")
	var key: String = code
	if not shaders.has(code):
		var expression := RegEx.new()
		expression.compile("void\\s+fragment\\s*\\(\\s*\\)\\s*\\{")
		var match: RegExMatch = expression.search(code)
		assert(match != null, "Garage reveal requires a spatial fragment shader")
		var injection: String = """
float garage_height = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
float garage_cutoff = mix(garage_height_range.x - 0.12, garage_height_range.y + 0.12, garage_visibility);
float garage_edge = 0.0;
if (!garage_shadow) {
	float garage_coverage = 1.0 - smoothstep(garage_cutoff - 0.025, garage_cutoff + 0.025, garage_height);
	vec2 garage_pixel = mod(floor(FRAGCOORD.xy), 4.0);
	vec2 garage_low = mod(garage_pixel, 2.0);
	vec2 garage_high = floor(garage_pixel / 2.0);
	float garage_rank = 4.0 * (2.0 * garage_low.x + 3.0 * garage_low.y - 4.0 * garage_low.x * garage_low.y) + (2.0 * garage_high.x + 3.0 * garage_high.y - 4.0 * garage_high.x * garage_high.y);
	if (garage_coverage < (garage_rank + 0.5) / 16.0) { discard; }
	garage_edge = (1.0 - smoothstep(0.008, 0.075, abs(garage_height - garage_cutoff))) * step(0.001, garage_visibility) * step(garage_visibility, 0.999);
}
"""
		var end: int = _fragment_end(code,match.get_end())
		var finish: String = "\nEMISSION += vec3(1.0, 0.67, 0.20) * garage_edge * 1.25;\nALBEDO = mix(ALBEDO, vec3(0.95, 0.77, 0.40), garage_edge * 0.4);\n"
		if source is ShaderMaterial and source.shader == preload("res://ui/studio_contact.gdshader"):
			finish += "ALPHA *= garage_visibility;\n"
		code = code.insert(end,finish)
		code = code.insert(match.get_end(), injection)
		code = code.insert(code.find(";")+1, "\nuniform float garage_visibility = 1.0;\nuniform vec2 garage_height_range = vec2(0.0, 2.0);\nuniform bool garage_shadow = false;\n")
		var shader := Shader.new()
		shader.code = code
		shaders[key] = shader
	var result: ShaderMaterial = source.duplicate() as ShaderMaterial if source is ShaderMaterial else ShaderMaterial.new()
	result.shader = shaders[key]
	result.set_shader_parameter("garage_shadow",source is ShaderMaterial and source.shader == preload("res://ui/studio_contact.gdshader"))
	if source is BaseMaterial3D:
		result.set_shader_parameter("garage_albedo",source.albedo_color)
		result.set_shader_parameter("garage_roughness",source.roughness)
		result.set_shader_parameter("garage_metallic",source.metallic)
		result.set_shader_parameter("garage_specular",source.metallic_specular)
		result.set_shader_parameter("garage_emission",source.emission * source.emission_energy_multiplier if source.emission_enabled else Color.BLACK)
		result.set_shader_parameter("garage_vertex_color",source.vertex_color_use_as_albedo)
	result.render_priority = source.render_priority
	return result

func _fragment_end(code: String, start: int) -> int:
	var depth: int = 1
	for index: int in range(start,code.length()):
		if code[index] == "{": depth += 1
		elif code[index] == "}": depth -= 1
		if depth == 0: return index
	assert(false,"Garage reveal requires a complete fragment function")
	return code.length()

func set_visibility(value: float) -> void:
	visibility = value
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("garage_visibility",value)
		material.set_shader_parameter("garage_height_range",Vector2(height_min,height_max))

func restore() -> void:
	for binding: Dictionary in bindings:
		if not is_instance_valid(binding.node): continue
		binding.node.material_override = binding.override
		binding.node.set_surface_override_material(binding.index,binding.surface)
	bindings.clear()
	materials.clear()
