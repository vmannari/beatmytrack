extends SceneTree
## Owned experiment: shipping generators remain untouched during candidate selection.
var rows: Array = []
var output: String
var failures: int = 0

func _initialize() -> void: run.call_deferred()

static func generator(flags: Array, dynamic_channel: bool = false, current: bool = false) -> GDScript:
	var path: String = "res://track/surface_shader_variants.gd" if current else "res://tests/fixtures/shader_consolidation_before.gd.txt"
	var source: String = FileAccess.get_file_as_string(path).replace("class_name SurfaceShaderVariants\n","")
	var anchor := "\tfor flag: String in MATERIAL_FLAGS:\n"
	if source.count(anchor) != 1: push_error("Variant generator anchor changed"); return null
	source = source.replace(anchor,anchor+"\t\tif flag in "+str(flags)+": continue\n")
	if dynamic_channel: source = source.replace('if source.contains("uniform int terrain_region_channel"):', 'if false:')
	var script := GDScript.new()
	script.source_code = source
	if script.reload() != OK: return null
	return script

static func materials(world: Node) -> Array[ShaderMaterial]:
	var result: Array[ShaderMaterial] = []
	var seen: Dictionary = {}
	for node: Node in world.find_children("*","MeshInstance3D",true,false):
		if node.mesh == null: continue
		for surface: int in range(node.mesh.get_surface_count()):
			var material: ShaderMaterial = node.get_active_material(surface) as ShaderMaterial
			if material == null or not material.has_meta("surface_dynamic_material") or seen.has(material.get_instance_id()): continue
			seen[material.get_instance_id()] = true
			result.append(material)
	return result

func run() -> void:
	output = OS.get_environment("BMT_VARIANT_OUTPUT")
	if output.is_empty(): push_error("Explicit output required"); quit(1); return
	var policies: Array = [{"name":"baseline","flags":[]},{"name":"edge_and_marking","flags":["raised_road_edge","road_marking"]},{"name":"surface_roles","flags":["gravel","grass_shoulder","grass","kerb","asphalt_surface","edge_fringe","road_marking","raised_road_edge"]},{"name":"terrain_roles","flags":["terrain_high_present","terrain_region_low","terrain_uniform_enabled"],"channel":true},{"name":"all_material_flags","flags":SurfaceShaderVariants.MATERIAL_FLAGS,"channel":true}]
	for flag: String in SurfaceShaderVariants.MATERIAL_FLAGS: policies.append({"name":flag,"flags":[flag]})
	policies.append({"name":"terrain_region_channel","flags":[],"channel":true})
	var scripts: Array[GDScript] = []
	for policy: Dictionary in policies:
		var script: GDScript = generator(policy.flags,policy.get("channel",false))
		if script == null: quit(1); return
		scripts.append(script)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	for theme: String in ["pine","winter","desert","storm","night_city"]:
		doc.theme = theme
		var track: NativeTrack = TrackCompiler.compile(doc)
		var visual := NativeTrackVisual.new()
		visual.persist_road_meshes = false
		visual.cache_road_meshes = false
		root.add_child(visual)
		await visual.build(track,BridgePresentation.new(track))
		var originals: Array[ShaderMaterial] = materials(visual)
		var descriptors: Array = []
		for material: ShaderMaterial in originals:
			var dynamic: ShaderMaterial = material.get_meta("surface_dynamic_material")
			var flags: Dictionary = {}
			for flag: String in SurfaceShaderVariants.MATERIAL_FLAGS:
				flags[flag] = dynamic.get_shader_parameter(flag)
			descriptors.append({"source":dynamic.shader.resource_path,"flags":flags,"hash":material.shader.code.sha256_text()})
		var counts: Dictionary = {}
		for index: int in range(policies.size()):
			var hashes: Dictionary = {}
			for material: ShaderMaterial in originals:
				var candidate: ShaderMaterial = material.get_meta("surface_dynamic_material").duplicate()
				scripts[index].specialize(candidate)
				hashes[candidate.shader.code.sha256_text()] = true
			counts[policies[index].name] = hashes.size()
		rows.append({"theme":theme,"materials":originals.size(),"unique_sources":counts,"descriptors":descriptors})
		print("VARIANT_INVENTORY ",JSON.stringify(rows[-1]))
		visual.free()
		await process_frame
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"failures":failures},"  "))
	quit()
