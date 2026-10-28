extends RefCounted
## A local assembly sweep over changed fittings, in the existing Garage world.
const SECONDS: float = 0.58
const STANDARD: String = """shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 kit_albedo : source_color = vec4(1.0);
uniform float kit_roughness = 0.8;
uniform float kit_metallic = 0.0;
uniform float kit_specular = 0.5;
uniform float kit_clearcoat = 0.0;
uniform float kit_clearcoat_roughness = 0.0;
uniform vec3 kit_emission : source_color;
uniform bool kit_vertex_color = false;
void fragment() {
	ALBEDO = kit_albedo.rgb * (kit_vertex_color ? COLOR.rgb : vec3(1.0));
	ROUGHNESS = kit_roughness;
	METALLIC = kit_metallic;
	SPECULAR = kit_specular;
	CLEARCOAT = kit_clearcoat;
	CLEARCOAT_ROUGHNESS = kit_clearcoat_roughness;
	EMISSION = kit_emission;
}
"""
static var shaders: Dictionary = {}
var categories: Array[String] = []
var outgoing_root: Node3D
var bindings: Array[Dictionary] = []
var materials: Array[ShaderMaterial] = []
var progress: float = 0.0
var height_range := Vector2(INF,-INF)
var _copies: Dictionary = {}

func capture(car: CarVisual, value: Dictionary) -> void:
	outgoing_root = Node3D.new()
	outgoing_root.name = "OutgoingGarageFittings"
	var inverse: Transform3D = car.global_transform.affine_inverse()
	for category: String in VehicleCustomisation.CATEGORIES:
		if car.customisation[category]==value[category]: continue
		categories.append(category)
		for frame: Node3D in car.kit_frames.get(category,[]):
			var copy: Node3D = frame.duplicate(0) as Node3D
			outgoing_root.add_child(copy)
			copy.transform = inverse*frame.global_transform

func install(car: CarVisual) -> void:
	car.get_parent().add_child(outgoing_root)
	outgoing_root.transform = car.transform
	_collect(outgoing_root,true)
	for category: String in categories:
		for frame: Node3D in car.kit_frames.get(category,[]): _collect(frame,false)
	set_progress(0.0)

func _collect(node: Node3D, outgoing: bool) -> void:
	if node is MeshInstance3D and node.mesh!=null:
		var box: AABB = node.global_transform*node.get_aabb()
		height_range.x = minf(height_range.x,box.position.y)
		height_range.y = maxf(height_range.y,box.end.y)
		var original: Material = node.material_override
		for index: int in range(1 if original!=null else node.mesh.get_surface_count()):
			var source: Material = node.get_active_material(index)
			if source==null: continue
			bindings.append({"node":node,"index":index,"override":original,"surface":node.get_surface_override_material(index)})
			var material: ShaderMaterial = _copy(source,outgoing)
			if original!=null: node.material_override = material
			else: node.set_surface_override_material(index,material)
	for child: Node in node.get_children():
		if child is Node3D: _collect(child,outgoing)

func _copy(source: Material, outgoing: bool) -> ShaderMaterial:
	var identity: String = str(source.get_instance_id())+str(outgoing)
	if _copies.has(identity): return _copies[identity]
	var code: String = source.shader.code if source is ShaderMaterial else STANDARD
	if source is BaseMaterial3D:
		if source.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED:
			code = code.replace("diffuse_burley, specular_schlick_ggx","unshaded")
		else:
			if source.diffuse_mode==BaseMaterial3D.DIFFUSE_TOON: code = code.replace("diffuse_burley","diffuse_toon")
			if source.specular_mode==BaseMaterial3D.SPECULAR_DISABLED: code = code.replace("specular_schlick_ggx","specular_disabled")
		if source.cull_mode==BaseMaterial3D.CULL_DISABLED: code = code.replace("render_mode ","render_mode cull_disabled, ")
		elif source.cull_mode==BaseMaterial3D.CULL_FRONT: code = code.replace("render_mode ","render_mode cull_front, ")
	if not shaders.has(code):
		var shader := Shader.new()
		var modified: String = code
		var fragment: int = modified.find("void fragment()")
		var start: int = modified.find("{",fragment)
		var finish: int = _function_end(modified,start)
		modified = modified.insert(finish,"\nEMISSION += vec3(1.0,0.70,0.30)*kit_edge*0.65;\n")
		modified = modified.insert(start+1,"""
float kit_cut = mix(kit_height_range.x-0.035,kit_height_range.y+0.035,kit_progress);
if (kit_outgoing ? kit_height < kit_cut : kit_height > kit_cut) { discard; }
float kit_band = clamp((kit_height_range.y-kit_height_range.x)*0.055,0.0025,0.012);
float kit_edge = (1.0-smoothstep(0.0,kit_band,abs(kit_height-kit_cut)))*step(0.001,kit_progress)*step(kit_progress,0.999);
""")
		var vertex: int = modified.find("void vertex()")
		var height: String = "\nkit_height = (MODEL_MATRIX*vec4(VERTEX,1.0)).y;\n"
		if vertex<0: modified += "\nvoid vertex() {"+height+"}\n"
		else: modified = modified.insert(_function_end(modified,modified.find("{",vertex)),height)
		modified = modified.insert(modified.find(";")+1,"\nuniform float kit_progress = 0.0;\nuniform bool kit_outgoing = false;\nuniform vec2 kit_height_range;\nvarying float kit_height;\n")
		shader.code = modified
		shaders[code] = shader
	var material: ShaderMaterial = source.duplicate() as ShaderMaterial if source is ShaderMaterial else ShaderMaterial.new()
	material.shader = shaders[code]
	material.render_priority = source.render_priority
	material.set_shader_parameter("kit_outgoing",outgoing)
	if source is BaseMaterial3D:
		material.set_shader_parameter("kit_albedo",source.albedo_color)
		material.set_shader_parameter("kit_roughness",source.roughness)
		material.set_shader_parameter("kit_metallic",source.metallic)
		material.set_shader_parameter("kit_specular",0.0 if source.specular_mode==BaseMaterial3D.SPECULAR_DISABLED else source.metallic_specular)
		material.set_shader_parameter("kit_clearcoat",source.clearcoat if source.clearcoat_enabled else 0.0)
		material.set_shader_parameter("kit_clearcoat_roughness",source.clearcoat_roughness)
		material.set_shader_parameter("kit_emission",source.emission*source.emission_energy_multiplier if source.emission_enabled else Color.BLACK)
		material.set_shader_parameter("kit_vertex_color",source.vertex_color_use_as_albedo)
	_copies[identity] = material
	materials.append(material)
	if source.next_pass!=null: material.next_pass = _copy(source.next_pass,outgoing)
	return material

static func _function_end(code: String, start: int) -> int:
	assert(start>=0,"Kit finishes require a fragment function")
	var depth: int = 1
	for index: int in range(start+1,code.length()):
		if code[index]=="{": depth += 1
		elif code[index]=="}": depth -= 1
		if depth==0: return index
	assert(false,"Kit finishes require complete shader functions")
	return code.length()

func set_progress(value: float) -> void:
	progress = value
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("kit_progress",value)
		material.set_shader_parameter("kit_height_range",height_range)

func restore() -> void:
	for binding: Dictionary in bindings:
		if not is_instance_valid(binding.node): continue
		binding.node.material_override = binding.override
		binding.node.set_surface_override_material(binding.index,binding.surface)
	bindings.clear()
	materials.clear()
	_copies.clear()
	if is_instance_valid(outgoing_root): outgoing_root.free()
	outgoing_root = null
