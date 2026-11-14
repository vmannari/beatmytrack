extends SceneTree
## Native mesh resources from the offline simplified owner-supplied model.
const SOURCE: String = "res://../build/challenger-panels-2026-11-12/converted-final/"
const DEST: String = "res://../build/challenger-corner-roll-2026-11-13/native/"

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var source: String = SOURCE
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source="): source = argument.trim_prefix("--source=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	var profile: String = FileAccess.get_file_as_string(source+"hood_profile.json")
	assert((JSON.parse_string(profile) as Dictionary).schema == "challenger-hood-profile-1")
	var profile_file := FileAccess.open(DEST+"hood_profile.json",FileAccess.WRITE)
	profile_file.store_string(profile); profile_file.close()
	var result: Dictionary = {"schema":"challenger-hellcat-1","tiers":{}}
	for tier: String in ["full","simple"]:
		var document := GLTFDocument.new(); var state := GLTFState.new()
		assert(document.append_from_file(ProjectSettings.globalize_path(source+tier+".glb"),state) == OK)
		var scene: Node3D = document.generate_scene(state)
		var entries: Array = []
		for part: MeshInstance3D in scene.find_children("*","MeshInstance3D",true,false):
			var label: String = str(part.name)
			var split: PackedStringArray = label.split("__")
			assert(split.size() == 2,label)
			var group: String = split[0]; var role: String = split[1].get_slice(".",0)
			var pose: Transform3D = part.transform
			var parent: Node3D = part.get_parent()
			while parent != scene: pose = parent.transform*pose; parent = parent.get_parent()
			var pivot := Vector3.ZERO
			if group.begins_with("wheel_"):
				pivot = Vector3(-0.83 if group.ends_with("_L") else 0.83,0.37,-1.28 if "_Ft_" in group else 1.28)
			var native := ArrayMesh.new(); var triangles: int = 0
			for index: int in range(part.mesh.get_surface_count()):
				var arrays: Array = part.mesh.surface_get_arrays(index)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for vertex: int in range(vertices.size()):
					vertices[vertex] = pose*vertices[vertex]-pivot
					normals[vertex] = (pose.basis.inverse().transposed()*normals[vertex]).normalized()
				arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals
				# Native fitted parts have UVs/colours. Explicit neutral attributes
				# keep direct and separately batched assemblies byte-equivalent.
				if arrays[Mesh.ARRAY_TEX_UV] == null:
					var uv := PackedVector2Array(); uv.resize(vertices.size()); arrays[Mesh.ARRAY_TEX_UV] = uv
				if arrays[Mesh.ARRAY_COLOR] == null:
					var colors := PackedColorArray(); colors.resize(vertices.size()); colors.fill(Color.WHITE); arrays[Mesh.ARRAY_COLOR] = colors
				triangles += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()/3
				native.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var file: String = tier+"_"+group+"_"+role+".res"
			assert(ResourceSaver.save(native,DEST+file) == OK)
			entries.append({"group":group,"role":role,"mesh":file,"triangles":triangles,"bounds":str(native.get_aabb())})
		result.tiers[tier] = entries
		scene.free()
	var output := FileAccess.open(DEST+"manifest.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(result,"\t")); output.close()
	var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source+"manifest.json"))
	for tier: String in ["full","simple"]:
		var actual: int = 0
		for entry: Dictionary in result.tiers[tier]: actual += int(entry.triangles)
		assert(actual == int(provenance.tiers[tier].triangles),"Native geometry must match its complete conversion receipt: "+tier)
	provenance.erase("source")
	output = FileAccess.open(DEST+"source.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(provenance,"\t")); output.close()
	print("CHALLENGER_NATIVE_BAKE ",JSON.stringify(result.tiers.keys()))
	quit()
