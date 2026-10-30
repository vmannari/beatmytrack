extends RefCounted
const FILES: Array[String]=["garage_floor","garage_deck","garage_surface_finish","garage_audio_wood","garage_display_stone","garage_plant_leaf","garage_vinyl","vehicle_weathering","livery_finish"]
static func apply(view: CarShowroom) -> void:
	var shader: Shader=load("res://../docs/evidence/garage-first-entry-2026-10-27/finish_program.gdshader")
	var changed: Dictionary={}
	for node: GeometryInstance3D in view.camera.get_parent().find_children("*","GeometryInstance3D",true,false):
		var mesh: Mesh=node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D else null
		if mesh==null: continue
		for surface: int in range(mesh.get_surface_count()):
			var material: Material=node.get_active_material(surface) if node is MeshInstance3D else node.material_override
			if material is StandardMaterial3D:
				var source: StandardMaterial3D=material
				if source.diffuse_mode!=BaseMaterial3D.DIFFUSE_BURLEY or source.specular_mode!=BaseMaterial3D.SPECULAR_SCHLICK_GGX or source.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED or source.shading_mode!=BaseMaterial3D.SHADING_MODE_PER_PIXEL or source.cull_mode!=BaseMaterial3D.CULL_BACK or source.vertex_color_use_as_albedo: continue
				var textured: bool=false
				for index: int in range(BaseMaterial3D.TEXTURE_MAX):
					if source.get_texture(index)!=null: textured=true
				if textured: continue
				var simple:=ShaderMaterial.new()
				simple.shader=shader
				simple.set_shader_parameter("garage_finish_family",9)
				simple.set_shader_parameter("shared_albedo",source.albedo_color)
				simple.set_shader_parameter("shared_emission",source.emission*source.emission_energy_multiplier if source.emission_enabled else Color(0,0,0))
				simple.set_shader_parameter("shared_roughness",source.roughness)
				simple.set_shader_parameter("shared_metallic",source.metallic)
				simple.set_shader_parameter("shared_specular",source.metallic_specular)
				simple.set_shader_parameter("shared_clearcoat",source.clearcoat if source.clearcoat_enabled else 0.0)
				simple.set_shader_parameter("shared_clearcoat_roughness",source.clearcoat_roughness)
				if node is MeshInstance3D:
					if node.material_override!=null: node.material_override=simple
					else: node.set_surface_override_material(surface,simple)
				else: node.material_override=simple
				continue
			if not material is ShaderMaterial or material.shader==null or changed.has(material): continue
			var family: int=FILES.find(material.shader.resource_path.get_file().get_basename())
			if family<0: continue
			var uniforms: Dictionary={}
			for uniform: Dictionary in material.shader.get_shader_uniform_list(): uniforms[uniform.name]=material.get_shader_parameter(uniform.name)
			material.shader=shader
			for uniform: String in uniforms:
				if uniforms[uniform]!=null: material.set_shader_parameter(uniform,uniforms[uniform])
			material.set_shader_parameter("garage_finish_family",family)
			changed[material]=true
	print("PROTOTYPE_FINISH ",changed.size()," materials share one original-finish program")
