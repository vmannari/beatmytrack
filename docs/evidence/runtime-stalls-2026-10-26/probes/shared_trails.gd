extends "res://vehicle/skid_trails.gd"
## Diagnostic only: mutable uniforms remain on independent materials.
static var shared_shader: Shader
static var exact_code_checks: int = 0
func _trail_material() -> ShaderMaterial:
	var material: ShaderMaterial = super._trail_material()
	if shared_shader == null: shared_shader = material.shader
	else:
		assert(material.shader.code==shared_shader.code,"trail shader source must remain exact")
		exact_code_checks += 1
		material.shader = shared_shader
	return material
