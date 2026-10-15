class_name LiveryGraphics
extends RefCounted
## Opaque replacement of existing paint surfaces. No extra meshes or draw passes.
const FINISH: Shader = preload("res://vehicle/livery_finish.gdshader")
static var toon_finish: Shader
var car: CarVisual
var bindings: Array[Dictionary] = []

func configure(value: CarVisual) -> void:
	car = value
	var paints: Array = car.paint_materials.values()
	if car.accent_roof != null: paints.append(car.accent_roof)
	for variant: Dictionary in car.paint_variants: paints.append(variant.material)
	var inverse: Transform3D = car.body.global_transform.affine_inverse()
	for node: Node in car.body.find_children("*","MeshInstance3D",true,false):
		for index: int in range(node.mesh.get_surface_count()):
			var source: StandardMaterial3D = node.get_active_material(index) as StandardMaterial3D
			if source not in paints: continue
			var finish := ShaderMaterial.new()
			if source.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON:
				if toon_finish == null:
					toon_finish = Shader.new()
					toon_finish.code = FINISH.code.replace("diffuse_burley, specular_schlick_ggx","diffuse_toon, specular_schlick_ggx")
				finish.shader = toon_finish
			else: finish.shader = FINISH
			finish.set_meta("livery_source",source)
			finish.set_shader_parameter("mesh_to_body",inverse*node.global_transform)
			paint_finish(finish,source)
			bindings.append({"node":node,"index":index,"source":source,"finish":finish,"override":node.material_override != null,"original":node.material_override if node.material_override != null else node.get_surface_override_material(index)})
	apply()

static func paint_finish(finish: ShaderMaterial, source: StandardMaterial3D) -> void:
	finish.set_shader_parameter("paint_color",source.albedo_color)
	finish.set_shader_parameter("paint_roughness",source.roughness)
	finish.set_shader_parameter("paint_metallic",source.metallic)
	finish.set_shader_parameter("paint_specular",0.0 if source.specular_mode == BaseMaterial3D.SPECULAR_DISABLED else source.metallic_specular)
	finish.set_shader_parameter("paint_clearcoat",source.clearcoat if source.clearcoat_enabled else 0.0)
	finish.set_shader_parameter("paint_clearcoat_roughness",source.clearcoat_roughness)

static func uniforms(finish: ShaderMaterial, value: Dictionary, id: String, enabled: bool = true) -> void:
	var decorated: bool = enabled and VehicleLivery.decorated(value,id)
	finish.set_shader_parameter("graphics_enabled",decorated)
	if not decorated: return
	finish.set_shader_parameter("pattern_enabled",value.pattern != "plain")
	if value.pattern != "plain": finish.set_shader_parameter("livery_mask",LiveryCatalog.texture(value.pattern))
	finish.set_shader_parameter("sticker_atlas",LiveryCatalog.texture("stickers"))
	for slot: String in VehicleLivery.SLOTS: finish.set_shader_parameter("livery_"+slot,Color(str(value.colors[slot])))
	var projection: Dictionary = LiveryCatalog.projection(id)
	finish.set_shader_parameter("graphic_bounds",projection.bounds)
	finish.set_shader_parameter("panel_levels",projection.levels)
	for panel: String in VehicleLivery.SURFACES:
		var rectangle: Vector4 = projection[panel]
		var sticker: Dictionary = value.stickers[panel]
		finish.set_shader_parameter(panel+"_panel",rectangle)
		finish.set_shader_parameter(panel+"_emblem",LiveryCatalog.sticker_index(sticker.id) if panel == "hood" or LiveryCatalog.has_roof(id) else -1)
		finish.set_shader_parameter(panel+"_sticker",Vector4(sticker.x,sticker.y,minf(rectangle.z,rectangle.w)*float(sticker.size),deg_to_rad(sticker.rotation)))

func apply() -> void:
	if not is_instance_valid(car) or car.livery.is_empty(): return
	for binding: Dictionary in bindings:
		paint_finish(binding.finish,binding.source)
		uniforms(binding.finish,car.livery,car.vehicle_id)
		var active: Material = binding.node.get_active_material(binding.index)
		if active is ShaderMaterial and active.has_meta("weathering_finish"): continue
		_restore(binding)

func restore_originals() -> void:
	for binding: Dictionary in bindings:
		if not is_instance_valid(binding.node): continue
		if binding.override: binding.node.material_override = binding.original
		else: binding.node.set_surface_override_material(binding.index,binding.original)

func _restore(binding: Dictionary) -> void:
	var material: Material = binding.finish if VehicleLivery.decorated(car.livery,car.vehicle_id) else binding.original
	if binding.override: binding.node.material_override = material
	else: binding.node.set_surface_override_material(binding.index,material)

func restore_surface(node: MeshInstance3D, index: int) -> bool:
	for binding: Dictionary in bindings:
		if binding.node == node and binding.index == index:
			_restore(binding)
			return true
	return false
