extends SceneTree
## TSO01: offline-only source-corner maps for the three accepted prop candidates.
const LODS = preload("res://track/scenery_mesh_lods.gd")
const GENERATOR = preload("res://tests/support/track_asset_lod_review.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LODS.ROOT))
	for kind: String in LODS.KINDS:
		CreatorPropVisual.trim_cache()
		var visual := NativeTrackVisual.new(); visual.scenery_lods = false; visual._capture_editor_prop_arrays = true
		var track := NativeTrack.new(); track.metadata = {"creator_document":{"objects":[{"kind":kind,"position":[0.0,0.0],"rotation":0.0}]}}
		await visual._build_placed_objects(track)
		var node: MeshInstance3D
		for child: Node in visual.get_children():
			if child is MeshInstance3D and not child.is_in_group("contact_lighting"): node = child; break
		assert(node != null)
		var source: ArrayMesh = CreatorPropVisual.meshes[CreatorPropVisual._key(kind,"pine",-1.0,"")]
		var unpruned: Array = node.get_meta("editor_prop_arrays")
		var expanded: PackedInt32Array = unpruned[Mesh.ARRAY_INDEX]
		assert(expanded.size() == source.surface_get_array_len(0))
		var first_corner: Dictionary = {}
		for corner: int in range(expanded.size()):
			if not first_corner.has(expanded[corner]): first_corner[expanded[corner]] = corner
		var policy = GENERATOR.new()
		var mesh: ArrayMesh = policy.prepare(node.mesh)
		var packet: Dictionary = mesh.get("_surfaces")[0]
		var levels: Array = packet.lods
		var stride: int = packet.index_data.size()/int(packet.index_count)
		var data: PackedByteArray = levels[1]
		var corners := PackedInt32Array()
		for index: int in range(data.size()/stride):
			var vertex: int = data.decode_u16(index*stride) if stride == 2 else data.decode_u32(index*stride)
			corners.append(first_corner[vertex])
		var asset := Resource.new()
		asset.set_meta("version",LODS.VERSION); asset.set_meta("kind",kind)
		asset.set_meta("signature",LODS.signature(source)); asset.set_meta("corner_count",expanded.size()); asset.set_meta("corners",corners)
		assert(ResourceSaver.save(asset,LODS.ROOT+kind+".res",ResourceSaver.FLAG_COMPRESS) == OK)
		print("SCENERY_LOD_BAKE ",kind," ",node.mesh.surface_get_array_index_len(0)/3," -> ",corners.size()/3)
		visual.free()
	quit()
