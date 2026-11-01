extends RefCounted
## Fictional single-seat sport hovercraft, bow -Z and aft +Z.
const Hull = preload("res://vehicle/hovercraft_sport_hull.gd")
const Drive = preload("res://vehicle/hovercraft_sport_drive.gd")

static func build(car: CarVisual) -> void:
	var paint: StandardMaterial3D = CompactFinish.paint(Color("b54b3d"))
	paint.roughness = 0.48
	paint.clearcoat = 0.12
	var accent: StandardMaterial3D = CompactFinish.paint(Color("253239"))
	accent.roughness = 0.50
	var detail: StandardMaterial3D = CompactFinish.alloy(Color("a6b3b4"))
	var rubber: StandardMaterial3D = CompactFinish.rubber(Color("242b2e"))
	rubber.roughness = 0.93
	var seam: StandardMaterial3D = CompactFinish.rubber(Color("10181d"))
	var metal: StandardMaterial3D = CompactFinish.alloy(Color("68777b"))
	var dark_metal: StandardMaterial3D = CompactFinish.alloy(Color("252f35"))
	dark_metal.roughness = 0.56
	var glass := ShaderMaterial.new()
	glass.shader = preload("res://vehicle/electric_glass.gdshader")
	glass.set_shader_parameter("studio_mode",false)
	glass.set_shader_parameter("mirror_surface",false)
	glass.set_shader_parameter("glass_tint_srgb",Vector3(0.11,0.16,0.19))
	car.paint_materials = {"body":paint,"accent":accent,"detail":detail}
	car.body.set_meta("hovercraft_revision",4)
	Hull.build(car.body,paint,accent,detail,rubber,seam,glass,car.brake_material,car.simple_model)
	var housings: Node3D = car.new_kit_frame("rims",car.body) if car.editable_kits else car.body
	Drive.build(car.body,paint,accent,seam,metal,dark_metal,car.simple_model,str(car.customisation.rims),housings)
	for category: String in VehicleCustomisation.CATEGORIES:
		preload("res://vehicle/hovercraft_kits.gd").build(car,category)

static func night_lens(parent: Node3D,material: Material) -> void:
	Hull.night_lens(parent,material)
