extends RefCounted
## Temporary opaque paint finishes, owned only by the interactive Garage.
## +Z is the authored rear. The sweep stays attached to the car while orbiting.
const GRAPHICS: ShaderInclude = preload("res://vehicle/livery_finish.gdshaderinc")
const SECONDS: float = 0.72
static var shaders: Dictionary = {}
static var old_graphics: String = ""
static var uniform_names: Array[String] = []
var bindings: Array[Dictionary] = []
var progress: float = 0.0
var z_bounds := Vector2(INF,-INF)

func capture(car: CarVisual) -> void:
	_prepare_graphics()
	var inverse: Transform3D = car.body.global_transform.affine_inverse()
	var overridden: Dictionary = {}
	for binding: Dictionary in car.graphics.bindings:
		if binding.node.material_override != null:
			if overridden.has(binding.node): continue
			overridden[binding.node] = true
		var old_values: Dictionary = {}
		for parameter: String in uniform_names:
			old_values[parameter] = binding.finish.get_shader_parameter(parameter)
		var box: AABB = (inverse * binding.node.global_transform) * binding.node.get_aabb()
		z_bounds.x = minf(z_bounds.x,box.position.z)
		z_bounds.y = maxf(z_bounds.y,box.end.z)
		bindings.append({"node":binding.node,"index":binding.index,"old_color":binding.source.albedo_color,"old_values":old_values,"paint":binding.finish,"transform":inverse*binding.node.global_transform})

static func _prepare_graphics() -> void:
	if not old_graphics.is_empty(): return
	# Reuse the exact livery projection and stickers for both sides of the sweep.
	var declarations := RegEx.new()
	declarations.compile("uniform\\s+\\w+\\s+(\\w+)|\\bvec3\\s+(\\w+)\\s*\\(")
	var names: Array[String] = []
	for declaration: RegExMatch in declarations.search_all(GRAPHICS.code):
		var parameter: String = declaration.get_string(1)
		var identifier: String = parameter if not parameter.is_empty() else declaration.get_string(2)
		names.append(identifier)
		if not parameter.is_empty(): uniform_names.append(parameter)
	var identifiers := RegEx.new()
	identifiers.compile("\\b("+"|".join(names)+")\\b")
	old_graphics = identifiers.sub(GRAPHICS.code,"garage_old_$1",true)

func install() -> void:
	for binding: Dictionary in bindings:
		var node: MeshInstance3D = binding.node
		binding.override = node.material_override
		binding.surface = node.get_surface_override_material(binding.index)
		var active: Material = node.get_active_material(binding.index)
		var source: ShaderMaterial = active if active is ShaderMaterial else binding.paint
		var material: ShaderMaterial = source.duplicate() as ShaderMaterial
		var key: String = source.shader.code
		if active is StandardMaterial3D and active.specular_mode==BaseMaterial3D.SPECULAR_DISABLED:
			key = key.replace("specular_schlick_ggx","specular_disabled")
		if not shaders.has(key):
			var shader := Shader.new()
			var code: String = key.replace("apply_graphics(paint_color.rgb,","garage_apply_paint(paint_color.rgb,")
			var injection: String = old_graphics + """
uniform vec4 garage_old_color : source_color;
uniform float garage_paint_progress = 0.0;
uniform vec2 garage_paint_bounds;
vec3 garage_apply_paint(vec3 pigment, vec3 p, vec3 n) {
	float along = (garage_paint_bounds.y-p.z) / max(garage_paint_bounds.y-garage_paint_bounds.x,0.001);
	float front = mix(-0.08,1.08,garage_paint_progress);
	float coverage = 1.0-smoothstep(front-0.065,front+0.065,along);
	vec3 before = garage_old_apply_graphics(garage_old_color.rgb,p,n);
	vec3 after = apply_graphics(pigment,p,n);
	vec3 paint = mix(before,after,coverage);
	float edge = 1.0-smoothstep(0.0,0.025,abs(along-front));
	return mix(paint,vec3(1.0),edge*0.12);
}
"""
			shader.code = code.insert(code.find("void vertex()"),injection)
			shaders[key] = shader
		material.shader = shaders[key]
		material.next_pass = active.next_pass
		material.render_priority = active.render_priority
		material.set_shader_parameter("mesh_to_body",binding.transform)
		material.set_shader_parameter("garage_old_color",binding.old_color)
		material.set_shader_parameter("garage_paint_bounds",z_bounds)
		for parameter: String in binding.old_values:
			if binding.old_values[parameter] != null:
				material.set_shader_parameter("garage_old_"+parameter,binding.old_values[parameter])
		binding.material = material
		if binding.override != null: node.material_override = material
		else: node.set_surface_override_material(binding.index,material)
	set_progress(0.0)

func set_progress(value: float) -> void:
	progress = value
	for binding: Dictionary in bindings:
		(binding.material as ShaderMaterial).set_shader_parameter("garage_paint_progress",value)

func restore() -> void:
	for binding: Dictionary in bindings:
		if not is_instance_valid(binding.node): continue
		binding.node.material_override = binding.override
		binding.node.set_surface_override_material(binding.index,binding.surface)
	bindings.clear()
