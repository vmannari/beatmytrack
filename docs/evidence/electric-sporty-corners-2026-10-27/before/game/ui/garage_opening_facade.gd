extends RefCounted
## Temporary live geometry while the original full finishes take their first draws.
var items: Array[Dictionary]=[]
var shaders: Dictionary={}
var materials: Dictionary={}

func build(pending: Array[Dictionary]) -> void:
	for job: Dictionary in pending:
		var source: Object=job.node.get_ref()
		if not source is MeshInstance3D: continue
		var copy:=MeshInstance3D.new()
		copy.name="OpeningLiveGeometry"
		copy.set_meta("garage_opening_proxy",true)
		copy.mesh=source.mesh
		copy.transform=source.transform
		copy.layers=source.layers
		copy.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if source.material_override!=null: copy.material_override=_finish(source.material_override)
		else:
			for index: int in range(source.mesh.get_surface_count()): copy.set_surface_override_material(index,_finish(source.get_active_material(index)))
		if source.material_overlay!=null: copy.material_overlay=_finish(source.material_overlay)
		var parent: Node=source.get_parent()
		if source.layers&4==0:
			while parent.get_parent() is Node3D: parent=parent.get_parent()
		parent.add_child(copy)
		if parent!=source.get_parent(): copy.global_transform=source.global_transform
		items.append({"source":weakref(source),"copy":copy,"layers":source.layers,"signature":_signature(source)})
		source.layers=8

func _signature(source: MeshInstance3D) -> Array:
	var result: Array=[source.mesh,source.material_overlay]
	for surface: int in range(source.mesh.get_surface_count()):
		var material: Material=source.get_active_material(surface)
		result.append(material)
		result.append(material.shader if material is ShaderMaterial else null)
	return result

func refresh(world: Node,stage: Node) -> void:
	var known: Dictionary={}
	for index: int in range(items.size()-1,-1,-1):
		var item: Dictionary=items[index]
		var source: Object=item.source.get_ref()
		if not is_instance_valid(source) or not source.is_inside_tree():
			if is_instance_valid(item.copy):
				if item.copy.get_parent()!=null: item.copy.get_parent().remove_child(item.copy)
				item.copy.free()
			items.remove_at(index)
			continue
		known[source]=true
		# Kit rebuilding reapplies reflection membership to the whole turntable.
		# Keep every held original outside the visible camera during preparation.
		source.layers=8
		source.hide()
		var signature: Array=_signature(source)
		if signature==item.signature: continue
		item.signature=signature
		item.copy.mesh=source.mesh
		item.copy.material_overlay=_finish(source.material_overlay)
		if source.material_override==null: item.copy.material_override=null
		for surface: int in range(source.mesh.get_surface_count()):
			var material: Material=source.get_active_material(surface)
			materials.erase(material)
			if source.material_override!=null: item.copy.material_override=_finish(material)
			else: item.copy.set_surface_override_material(surface,_finish(material))
		stage.queue_geometry(source)
	for source: Node in world.find_children("*","MeshInstance3D",true,false):
		if known.has(source) or source.has_meta("garage_opening_proxy") or source.has_meta("garage_opening_warm") or not source.is_visible_in_tree(): continue
		if not stage.queue_geometry(source): continue
		build([{"node":weakref(source)}])
	sync_parameters()

func sync_poses() -> void:
	for item: Dictionary in items:
		var source: Object=item.source.get_ref()
		if not is_instance_valid(source) or not is_instance_valid(item.copy): continue
		if item.copy.get_parent()!=source.get_parent():
			item.copy.global_transform=source.global_transform
			item.copy.visible=source.get_parent().is_visible_in_tree()
		elif item.copy.transform!=source.transform: item.copy.transform=source.transform

func sync_parameters() -> void:
	sync_poses()
	for original: Material in materials:
		var target: ShaderMaterial=materials[original]
		if original is ShaderMaterial:
			for declaration: Dictionary in target.shader.get_shader_uniform_list():
				var value: Variant=original.get_shader_parameter(declaration.name)
				if value!=null and target.get_shader_parameter(declaration.name)!=value: target.set_shader_parameter(declaration.name,value)
		else:
			if target.get_shader_parameter("paint_color")!=original.albedo_color: target.set_shader_parameter("paint_color",original.albedo_color)

func _finish(original: Material) -> Material:
	if original==null: return null
	if materials.has(original): return materials[original]
	if original is ShaderMaterial and original.shader.code.contains("unshaded"): return original
	var alpha: bool=original is StandardMaterial3D and original.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED
	var cull: int=original.cull_mode if original is StandardMaterial3D else BaseMaterial3D.CULL_BACK
	var key: String=str(alpha)+"-"+str(cull)
	if not shaders.has(key):
		var shader:=Shader.new()
		# One common light finish retains the actual livery, stickers and wash
		# volumes without creating a new lighting program for every room finish.
		var code: String=preload("res://vehicle/vehicle_weathering.gdshader").code
		code=code.replace("render_mode diffuse_burley, specular_schlick_ggx;","render_mode unshaded,"+("cull_front" if cull==BaseMaterial3D.CULL_FRONT else "cull_disabled" if cull==BaseMaterial3D.CULL_DISABLED else "cull_back")+";")
		code=code.replace("void vertex() {","uniform vec4 opening_glow:source_color=vec4(0.0);\nuniform float opening_grow=0.0;\nvarying vec3 opening_normal;\nvoid vertex() {\n VERTEX+=NORMAL*opening_grow;\n opening_normal=MODEL_NORMAL_MATRIX*NORMAL;")
		var end: int=code.rfind("}")
		code=code.insert(end,"\n ALBEDO*=0.48+0.52*max(0.0,dot(normalize(opening_normal),normalize(vec3(-0.5,0.9,-0.4))));\n EMISSION=opening_glow.rgb;\n"+("ALPHA=paint_color.a;\n" if alpha else ""))
		shader.code=code
		shaders[key]=shader
	var result:=ShaderMaterial.new()
	result.shader=shaders[key]
	if original is ShaderMaterial and (original.shader.code.contains("garage_paint_progress") or original.shader.code.contains("garage_kit_progress")):
		var motion_code: String=original.shader.code.replace("render_mode ","render_mode unshaded,")
		if not shaders.has(motion_code):
			var motion_shader:=Shader.new()
			motion_shader.code=motion_code
			shaders[motion_code]=motion_shader
		result.shader=shaders[motion_code]
	result.set_shader_parameter("mesh_to_body",Transform3D.IDENTITY)
	result.set_shader_parameter("mesh_to_wheel",Transform3D.IDENTITY)
	if original is ShaderMaterial:
		for declaration: Dictionary in result.shader.get_shader_uniform_list():
			var value: Variant=original.get_shader_parameter(declaration.name)
			if value!=null: result.set_shader_parameter(declaration.name,value)
		var pigment: Variant=null
		for parameter: String in ["paint_color","finish_color","timber_color","color"]:
			pigment=original.get_shader_parameter(parameter)
			if pigment!=null: break
		result.set_shader_parameter("paint_color",pigment if pigment!=null else Color("53616b"))
	else:
		result.set_shader_parameter("paint_color",original.albedo_color)
		result.set_shader_parameter("opening_glow",original.emission*original.emission_energy_multiplier if original.emission_enabled else Color.BLACK)
		if original.get("grow")==true: result.set_shader_parameter("opening_grow",original.get("grow_amount"))
	if original.next_pass!=null: result.next_pass=_finish(original.next_pass)
	materials[original]=result
	return result

func restore() -> void:
	for item: Dictionary in items:
		var source: Object=item.source.get_ref()
		if is_instance_valid(source):
			source.layers=item.layers
			source.show()
		if is_instance_valid(item.copy):
			if item.copy.get_parent()!=null: item.copy.get_parent().remove_child(item.copy)
			item.copy.free()
	items.clear()
	materials.clear()
	shaders.clear()
