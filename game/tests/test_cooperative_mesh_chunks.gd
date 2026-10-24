extends SceneTree
var checks: int = 0
var failures: int = 0
var visits: int = 0
var slice_started: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func cooperate() -> bool:
	visits += 1
	if Time.get_ticks_usec()-slice_started >= 1000:
		await process_frame
		slice_started = Time.get_ticks_usec()
	return true
func tree_signature(node: Node) -> Array:
	var values: Array = [str(node.name),node.get_class()]
	if node is Node3D: values.append(node.transform)
	if node is GeometryInstance3D: values.append([node.layers,node.cast_shadow,node.material_override,node.extra_cull_margin])
	if node is MeshInstance3D: values.append(node.mesh.surface_get_arrays(0))
	for meta: StringName in node.get_meta_list(): values.append([meta,node.get_meta(meta)])
	for child: Node in node.get_children(): values.append(tree_signature(child))
	return values
func source_mesh(mesh: Mesh) -> MeshInstance3D:
	var source := MeshInstance3D.new(); source.mesh = mesh; source.name = "Chunks"
	source.transform = Transform3D(Basis(Vector3.UP,0.2),Vector3(1,2,3)); source.set_meta("original",17)
	return source
func run() -> void:
	var reference := GDScript.new()
	reference.source_code = FileAccess.get_file_as_string("res://tests/fixtures/gameplay_f04_f05_before/spatial_mesh_chunks.gd.txt").replace("class_name SpatialMeshChunks","")
	check(reference.reload()==OK,"independent original partitioner compiles")
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle: int in range(8192):
		var center := Vector3((triangle%32-16)*4.0,0,(triangle/32-128)*1.0)
		tool.set_normal(Vector3.UP)
		for corner: int in range(3):
			tool.set_color(Color((triangle%19)/19.0,(triangle%23)/23.0,0.5,1))
			tool.set_uv(Vector2(triangle/8192.0,corner/2.0)); tool.set_uv2(Vector2(corner/2.0,triangle/8192.0))
			tool.add_vertex(center+Vector3([0,0.8,0.0][corner],0,[0,0,0.6][corner]))
	tool.index(); var mesh: ArrayMesh = tool.commit()
	for adaptive: bool in [false,true]:
		var before := Node3D.new(); root.add_child(before)
		var after := Node3D.new(); root.add_child(after)
		var original: Array = reference.add(before,source_mesh(mesh),true,false,adaptive)
		var source: MeshInstance3D = source_mesh(mesh)
		if adaptive: after.add_child(source)
		var initial_frame: int = Engine.get_process_frames(); slice_started = Time.get_ticks_usec()
		var actual: Array = await SpatialMeshChunks.add_cooperative(after,source,true,false,adaptive,-1,cooperate)
		check(original.size()==actual.size() and actual.size()>1,"same ordered partition count")
		check(Engine.get_process_frames()>initial_frame,"partition loops yield internally")
		for index: int in range(actual.size()): check(var_to_bytes(tree_signature(original[index]))==var_to_bytes(tree_signature(actual[index])),"byte-exact attributes, triangle order, transforms and metadata")
		before.free(); after.free()
	var cancelled := Node3D.new(); root.add_child(cancelled)
	var pending: MeshInstance3D = source_mesh(mesh); cancelled.add_child(pending)
	var owner_ref: WeakRef = weakref(pending); var calls: Array[int] = [0]
	var parts: Array = await SpatialMeshChunks.add_cooperative(cancelled,pending,true,false,true,-1,func() -> bool: calls[0] += 1; await process_frame; return calls[0]<3)
	check(parts.is_empty() and pending.get_parent()==cancelled,"cancelled work retains an owned partial family")
	cancelled.free(); check(owner_ref.get_ref()==null,"owner teardown releases cancelled source")
	await process_frame
	print("COOPERATIVE_MESH_CHUNKS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
