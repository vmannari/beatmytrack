extends SceneTree
## Shared render coverage, geometry integrity, cached transforms and canonical isolation.
var checks: int = 0
var failures: int = 0
var rows: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",message)

func run() -> void:
	var primitive := SurfaceTool.new(); primitive.begin(Mesh.PRIMITIVE_TRIANGLES)
	PropGeometry.box(primitive,Vector3.ZERO,Vector3(2,2,2),Color.WHITE,0.1)
	primitive.generate_normals()
	var arrays: Array = primitive.commit().surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var outward: bool = true
	for i: int in range(vertices.size()):
		if vertices[i].dot(normals[i]) < 0.5:
			outward = false
			if i%12 == 0: print("BOX_NORMAL: ",vertices[i]," ",normals[i])
	check(outward,"bevel box faces have outward normals, including top and bottom")
	primitive = SurfaceTool.new(); primitive.begin(Mesh.PRIMITIVE_TRIANGLES)
	PropGeometry.tube(primitive,Vector3.ZERO,Vector3.UP,0.2,0.2,Color.WHITE,12)
	primitive.generate_normals(); arrays = primitive.commit().surface_get_arrays(0)
	vertices = arrays[Mesh.ARRAY_VERTEX]; normals = arrays[Mesh.ARRAY_NORMAL]
	outward = true
	for i: int in range(vertices.size()):
		if (vertices[i]-Vector3.UP*0.5).dot(normals[i]) < 0.15:
			outward = false
			if i%12 == 0: print("TUBE_NORMAL: ",vertices[i]," ",normals[i])
	check(outward,"cylindrical posts have outward side and cap normals")
	var kinds: Array[String] = []
	for family: Array in CreatorCatalog.ASSETS:
		for kind: String in family[3]: kinds.append(kind)
	kinds.append("puddle")
	for biome: String in TrackTheme.IDS:
		for kind: String in kinds:
			var object: Dictionary = {"kind":kind,"position":[0,0],"rotation":0}
			var track := NativeTrack.new()
			track.cells = PackedInt32Array([0,2,4,3,6])
			track.metadata = {"creator_document":{"objects":[object]}}
			track.tyre_origins = LooseTyres.positions(track.metadata.creator_document)
			var original: Dictionary = track.metadata.duplicate(true)
			var cells: PackedInt32Array = track.cells.duplicate()
			var visual := NativeTrackVisual.new(); visual.theme_id = biome
			visual._build_placed_objects(track)
			var stats: Dictionary = geometry_stats(visual)
			check(stats.triangles > 0 and stats.valid,biome+"/"+kind+" has finite coloured geometry and normals")
			check(stats.triangles < 10000,biome+"/"+kind+" stays within per-object review budget")
			check(track.cells == cells and track.metadata == original,biome+"/"+kind+" rendering leaves collision and document exact")
			if biome == "pine": rows.append({"kind":kind,"triangles":stats.triangles,"vertices":stats.vertices,"meshes":stats.meshes})
			visual.free()
	var kit := NativeTrackVisual.new()
	for kind: String in ["barrier","guardrail","fence","wire_fence","parked_car","broadleaf"]:
		var source: SurfaceTool = stream(kind,kit,Vector3.ZERO,1,0,3)
		var source_mesh: ArrayMesh = source.commit()
		var pose := Transform3D(Basis(Vector3.UP,0.7).scaled(Vector3.ONE*1.5),Vector3(11,0,-7))
		var target_mesh: ArrayMesh = stream(kind,kit,pose.origin,1.5,0.7,4.5).commit()
		var a: PackedVector3Array = source_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var b: PackedVector3Array = target_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var exact: bool = a.size() == b.size()
		for i: int in range(mini(a.size(),b.size())):
			if (pose*a[i]).distance_to(b[i]) > 0.00001: exact = false
		check(exact,kind+" cached shape retains requested scale, rotation and independent run length")
	kit.free()
	check(CreatorPropVisual.meshes.size() <= CreatorPropVisual.CACHE_LIMIT,"local mesh cache is bounded across every biome")
	print("PROP_MODEL_METRICS: ",JSON.stringify(rows))
	print("PROP_REFINEMENT_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func stream(kind: String, kit: NativeTrackVisual, center: Vector3, scale: float, turn: float, length: float) -> SurfaceTool:
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	CreatorPropVisual.append(tool,kit,kind,center,scale,turn,length)
	return tool

func geometry_stats(node: Node) -> Dictionary:
	var stats: Dictionary = {"triangles":0,"vertices":0,"meshes":0,"valid":true}
	if node.is_in_group("contact_lighting"): return stats
	var mesh: Mesh
	var instances: int = 1
	if node is MeshInstance3D: mesh = node.mesh
	if node is MultiMeshInstance3D:
		mesh = node.multimesh.mesh; instances = node.multimesh.instance_count
	if mesh != null:
		stats.meshes += 1
		for surface: int in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			stats.triangles += (indices.size() if not indices.is_empty() else vertices.size())/3*instances
			stats.vertices += vertices.size()*instances
			if normals.size() != vertices.size() or (not colors.is_empty() and colors.size() != vertices.size()): stats.valid = false
			var material: Material = node.material_override if node.material_override != null else mesh.surface_get_material(surface)
			if not colors.is_empty() and material is StandardMaterial3D and not material.vertex_color_is_srgb: stats.valid = false
			for i: int in range(vertices.size()):
				if not vertices[i].is_finite() or not normals[i].is_finite(): stats.valid = false
	for child: Node in node.get_children():
		var sub: Dictionary = geometry_stats(child)
		for key: String in ["triangles","vertices","meshes"]: stats[key] += sub[key]
		stats.valid = stats.valid and sub.valid
	return stats
