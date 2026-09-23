extends RefCounted
## Debug probe only. Preserve mesh, masks, lighting and original material objects.
const PREVIOUS: ShaderInclude = preload("res://diagnostics/previous_surface.gdshaderinc")
var entries: Array[Dictionary] = []
var changed_count: int = 0

func collect(root: Node) -> void:
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var material: Material = mesh.material_override
		if material is not ShaderMaterial: continue
		var path: String = material.shader.resource_path
		if path not in ["res://track/creator_road.gdshader", "res://track/terrain.gdshader", "res://track/ground.gdshader"]: continue
		entries.append({"mesh":mesh,"original":material,"path":path,"variants":{}})

func apply(mode: String) -> void:
	changed_count = 0
	for entry: Dictionary in entries:
		var material: ShaderMaterial = entry.original
		var creator: bool = entry.path.ends_with("creator_road.gdshader")
		var road: bool = creator and (material.get_shader_parameter("asphalt_surface") == true or material.get_shader_parameter("road_marking") == true or material.get_shader_parameter("edge_fringe") == true)
		var selected: bool = mode in ["asphalt_previous","directional_off"] or (mode == "road_flat" and road) or (mode == "terrain_flat" and not road)
		if not selected:
			entry.mesh.material_override = material
			continue
		if not entry.variants.has(mode):
			var shader := Shader.new()
			var source: String = material.shader.code
			if mode == "asphalt_previous":
				# Historical shared detail predates packed sand and grass relief.
				# Adapt its interface explicitly; this mode restores historical grass too.
				var compatibility: String = "\nuniform bool packed_sand = false;\nvec3 grass_relief(vec2 p, vec3 original, mat4 view, float weight) { return original; }\nvec3 directional_asphalt(vec3 base, vec2 p, vec2 axis) { return base; }\n"
				source = source.replace('#include "res://track/surface_detail.gdshaderinc"',PREVIOUS.code + compatibility)
			elif mode == "directional_off":
				source = source.replace("ALBEDO = directional_asphalt(ALBEDO,world_position.xz,UV2);", "ALBEDO = ALBEDO;")
			elif creator:
				var first: int = source.find("\tALBEDO = surface_detail(")
				var last: int = source.find("\tROUGHNESS = 1.0;",first)
				assert(first >= 0 and last > first)
				# Kerbs retain their tapered discard and stripe pattern.
				if material.get_shader_parameter("kerb") == true:
					entry.mesh.material_override = material
					continue
				source = source.substr(0,first) + "\tALBEDO = road_color.rgb;\n" + source.substr(last)
			elif entry.path.ends_with("ground.gdshader"):
				source = source.replace("painted_grass(ground_color.rgb, world_position.xz)", "ground_color.rgb")
			else:
				var first: int = source.find("\t\tif (i == 1) layer")
				var last: int = source.find("\t\tblended += layer",first)
				assert(first >= 0 and last > first)
				source = source.substr(0,first) + source.substr(last)
			shader.code = source
			var replacement: ShaderMaterial = material.duplicate()
			replacement.shader = shader
			if mode in ["road_flat","terrain_flat"]: replacement.set_shader_parameter("hybrid_grass",false)
			entry.variants[mode] = replacement
		entry.mesh.material_override = entry.variants[mode]
		changed_count += 1

func restore() -> void:
	for entry: Dictionary in entries:
		entry.mesh.material_override = entry.original
