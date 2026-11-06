extends RefCounted
## Diagnostic only, copied into an isolated frozen project.
static var case_name: String = "startup"
static var known: Dictionary = {}
static var rows: Array = []

static func material(material: Material) -> Dictionary:
	if material == null: return {}
	var result := {"class":material.get_class(),"path":material.resource_path}
	if material is ShaderMaterial and material.shader != null:
		var key: String = material.shader.code.sha256_text()
		result.hash = key
		result.shader_path = material.shader.resource_path
		if material.has_meta("surface_dynamic_material"):
			result.origin = material.get_meta("surface_dynamic_material").shader.resource_path
		if not known.has(key):
			known[key] = true
			FileAccess.open(OS.get_environment("BMT_GRAPHICS_OUTPUT").path_join(key+".gdshader"),FileAccess.WRITE).store_string(material.shader.code)
	return result

static func node(node: Node) -> Dictionary:
	var result := {"path":str(node.get_path()),"class":node.get_class(),"materials":[]}
	if node is MeshInstance3D and node.mesh != null:
		for index: int in range(node.mesh.get_surface_count()): result.materials.append(material(node.get_active_material(index)))
	elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
		for index: int in range(node.multimesh.mesh.get_surface_count()): result.materials.append(material(node.material_override if node.material_override != null else node.multimesh.mesh.surface_get_material(index)))
	elif node is GPUParticles3D:
		result.process = material(node.process_material)
		for index: int in range(node.draw_passes):
			var mesh: Mesh = node.get_draw_pass_mesh(index)
			if mesh != null:
				for surface: int in range(mesh.get_surface_count()): result.materials.append(material(mesh.surface_get_material(surface)))
	return result

static func begin(kind: String, groups: Array) -> Dictionary:
	var sources: Array = []
	for group: Variant in groups:
		if group is Dictionary:
			for source: Dictionary in group.sources:
				var value: Dictionary = node(source.node.get_ref()); value.key = group.key; sources.append(value)
		else: sources.append(node(group))
	var ticket := {"case":case_name,"kind":kind,"sources":sources,"utc_begin_us":int(Time.get_unix_time_from_system()*1000000.0),"begin_us":Time.get_ticks_usec()}
	print("GRAPHICS_BEGIN ",JSON.stringify(ticket))
	return ticket

static func end(ticket: Dictionary, ok: bool) -> void:
	ticket.us = Time.get_ticks_usec()-int(ticket.begin_us)
	ticket.utc_end_us = int(Time.get_unix_time_from_system()*1000000.0)
	ticket.ok = ok
	rows.append(ticket)
	print("GRAPHICS_END ",JSON.stringify(ticket))
