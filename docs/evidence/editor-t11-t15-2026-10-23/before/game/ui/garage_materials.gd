class_name GarageMaterials
extends RefCounted
## Original opaque surface finishes, cached only in menu presentation.
static var finishes: Dictionary = {}
static func finish(id: String, color: String, metallic: float, roughness: float, kind: int = 0) -> ShaderMaterial:
	if finishes.has(id): return finishes[id]
	var material := ShaderMaterial.new()
	material.shader = preload("res://ui/garage_surface_finish.gdshader")
	material.set_shader_parameter("finish_color",Color(color))
	material.set_shader_parameter("finish_metallic",metallic)
	material.set_shader_parameter("finish_roughness",roughness)
	material.set_shader_parameter("finish_kind",kind)
	finishes[id] = material
	return material
