extends RefCounted
## Reference-based electric fastback; model coordinates use -Z for the nose.
const BODY = preload("res://vehicle/electric_reference_body.gd")
const CABIN = preload("res://vehicle/electric_reference_cabin.gd")
const DETAILS = preload("res://vehicle/electric_reference_details.gd")
const M = preload("res://vehicle/electric_reference_mesh.gd")
static var glass_shader: ShaderMaterial

static func build(car: CarVisual) -> void:
	car.body.name = "ElectricFastback"
	var paint := CompactFinish.paint(Color("b8bbb9"))
	paint.roughness = 0.30
	paint.metallic = 0.26
	paint.clearcoat = 0.30
	var accent := CompactFinish.paint(Color("272f33"))
	var alloy := CompactFinish.alloy(Color("9ba8ab"))
	var bright := CompactFinish.alloy(Color("bac6c6"))
	var trim := CompactFinish.rubber(Color("152025"))
	car.paint_materials = {"body":paint,"accent":accent,"detail":alloy}
	if glass_shader == null:
		glass_shader = ShaderMaterial.new()
		glass_shader.shader = preload("res://vehicle/electric_glass.gdshader")
		glass_shader.set_shader_parameter("glass_tint_srgb", Vector3(0.10, 0.15, 0.19))
	BODY.build(car,paint,trim,bright)
	CABIN.build(car,paint,trim,glass_shader)
	DETAILS.build(car,paint,trim,bright,glass_shader)

static func night_lens(parent: Node3D, material: Material) -> void:
	M.patch(parent,"ReferenceNightLightbar",72,4,func(u: float,v: float)->Vector3:
		return BODY.front_lightbar_point(u,v)+Vector3.FORWARD*0.001,material,Vector3.FORWARD)
