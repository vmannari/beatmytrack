class_name SurfaceShaderVariants
extends RefCounted
## Fixed visual-material flags become constants; samples and lighting stay intact.
const FLAGS: Array[String] = ["hybrid_grass","desert_dunes","winter_snow","packed_sand","icy_road","wet_road"]
const INCLUDES: Dictionary = {
	"res://track/terrain.gdshaderinc":preload("res://track/terrain.gdshaderinc"),
	"res://track/surface_detail.gdshaderinc":preload("res://track/surface_detail.gdshaderinc"),
	"res://track/winter_ice.gdshaderinc":preload("res://track/winter_ice.gdshaderinc")
}
static var cache: Dictionary = {}

static func specialize(material: ShaderMaterial) -> void:
	var dynamic: ShaderMaterial = material.duplicate()
	var source: String = material.shader.code
	# Shallow snow/sand banks need continuous light, with matching terrain/skirt lighting.
	if bool(material.get_shader_parameter("winter_snow")) or bool(material.get_shader_parameter("desert_dunes")):
		source = source.replace("diffuse_toon","diffuse_burley")
	for pass_index: int in range(3):
		for path: String in INCLUDES:
			source = source.replace('#include "'+path+'"',(INCLUDES[path] as ShaderInclude).code)
	for flag: String in FLAGS:
		var pattern := RegEx.new()
		pattern.compile("uniform bool "+flag+"\\s*=\\s*(true|false)\\s*;")
		var found: RegExMatch = pattern.search(source)
		if found == null: continue
		var value: Variant = material.get_shader_parameter(flag)
		var enabled: bool = found.get_string(1)=="true" if value==null else bool(value)
		source = pattern.sub(source,"const bool "+flag+" = "+("true" if enabled else "false")+";",true)
	var key: String = source.sha256_text()
	if not cache.has(key):
		var shader := Shader.new()
		shader.code = source
		if cache.size()>=64: cache.erase(cache.keys()[0])
		cache[key] = shader
	material.set_meta("surface_dynamic_material",dynamic)
	material.shader = cache[key] as Shader
