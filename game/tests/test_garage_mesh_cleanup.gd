extends SceneTree
const Cleanup = preload("res://ui/garage_mesh_cleanup.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func corners(mesh: ArrayMesh) -> Array[PackedByteArray]:
	var packet: Dictionary = mesh.get("_surfaces")[0]
	var count: int = packet.vertex_count
	var format: int = packet.format
	var ps: int = RenderingServer.mesh_surface_get_format_vertex_stride(format,count)
	var ns: int = RenderingServer.mesh_surface_get_format_normal_tangent_stride(format,count)
	var ats: int = RenderingServer.mesh_surface_get_format_attribute_stride(format,count)
	var raw: PackedByteArray = packet.vertex_data
	var attrs: PackedByteArray = packet.get("attribute_data",PackedByteArray())
	var indices: PackedByteArray = packet.get("index_data",PackedByteArray())
	var n: int = packet.get("index_count",count)
	var stride: int = indices.size()/n if not indices.is_empty() else 0
	var result: Array[PackedByteArray] = []
	for i: int in range(n):
		var index: int = i if stride == 0 else indices.decode_u16(i*stride) if stride == 2 else indices.decode_u32(i*stride)
		var vertex: PackedByteArray = raw.slice(index*ps,(index+1)*ps)
		vertex.append_array(raw.slice(count*ps+index*ns,count*ps+(index+1)*ns))
		vertex.append_array(attrs.slice(index*ats,(index+1)*ats))
		result.append(vertex)
	return result

func soup(points: Array[Vector3]) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(points.size()):
		tool.set_normal(Vector3(0.3,0.8,0.4).normalized())
		tool.set_uv(Vector2(i*0.17,i*0.23))
		tool.set_uv2(Vector2(i*0.1,i*0.2))
		tool.set_color(Color(0.27,0.39,0.52,1))
		tool.add_vertex(points[i])
	return tool.commit()

func run() -> void:
	var root_node := Node3D.new()
	root.add_child(root_node)
	var finish := StandardMaterial3D.new()
	var box: MeshInstance3D = GarageEnvironment.box(root_node,Vector3.ZERO,Vector3.ONE*2.0,finish)
	var target := MeshInstance3D.new()
	target.material_override = finish
	var points: Array[Vector3] = [Vector3(-0.2,0,0),Vector3(0.2,0,0),Vector3(0,0.2,0),Vector3(2,0,0),Vector3(3,0,0),Vector3(2,1,0),Vector3(0,0,0),Vector3(2,0,0),Vector3(0,2,0),Vector3(4,0,0),Vector3(4,0,0),Vector3(4,1,0)]
	var original: ArrayMesh = soup(points)
	original.set_meta("authored",true)
	target.mesh = original
	root_node.add_child(target)
	var packet: Array = original.get("_surfaces").duplicate(true)
	var before: Array[PackedByteArray] = corners(original)
	var cleanup = Cleanup.new()
	cleanup.gather(root_node,GarageEnvironment.cabinet_meshes)
	var result: ArrayMesh = cleanup.clean(target,Transform3D.IDENTITY)
	check(cleanup.hidden_triangles == 1 and cleanup.degenerate_triangles == 1,"remove enclosed and duplicate-position triangles only")
	check(corners(result) == before.slice(3,9),"retained ordered GPU positions/normals/UVs/UV2/colors remain byte exact")
	check(result.surface_get_array_len(0) == 6,"unused hidden/degenerate vertices are removed")
	check(result.get_meta("authored") and original.get("_surfaces") == packet,"metadata retained and source untouched")
	# All three corners must fit the same strictly interior volume.
	var core: float = 0.975-Cleanup.MARGIN
	var touching: ArrayMesh = soup([Vector3(core,0,0),Vector3(core,0.2,0),Vector3(core,0,0.2)])
	target.mesh = touching
	check(cleanup.clean(target,Transform3D.IDENTITY) == touching,"coplanar and margin-border triangles retained")
	for excluded: String in ["GarageRoof","GarageVinyl","GarageRecordSleeves"]:
		var group := Node3D.new()
		group.name = excluded
		root_node.add_child(group)
		box.reparent(group)
		var isolated = Cleanup.new()
		isolated.gather(root_node,GarageEnvironment.cabinet_meshes)
		check(isolated.solids.is_empty(),"moving/cutaway group cannot erase another batch: "+excluded)
		box.reparent(root_node)
		group.free()
	box.hide()
	var invisible = Cleanup.new()
	invisible.gather(root_node,GarageEnvironment.cabinet_meshes)
	check(invisible.solids.is_empty(),"invisible boxes cannot occlude")
	box.show()
	finish.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var translucent = Cleanup.new()
	translucent.gather(root_node,GarageEnvironment.cabinet_meshes)
	check(translucent.solids.is_empty(),"transparent boxes cannot occlude")
	finish.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	var glass := ShaderMaterial.new()
	glass.shader = preload("res://ui/garage_audio_lid.gdshader")
	check(not Cleanup.opaque(glass),"smoked record-player lid is not an opaque solid")
	finish.grow = true
	check(not Cleanup.opaque(finish),"normal-displaced material cannot occlude")
	finish.grow = false
	finish.proximity_fade_enabled = true
	check(not Cleanup.opaque(finish),"proximity-fading material cannot occlude")
	finish.proximity_fade_enabled = false
	finish.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	check(not Cleanup.opaque(finish),"camera-facing material cannot occlude")
	finish.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	# Rotation and nonuniform scale are evaluated in each solid's local frame.
	var rotated := Transform3D(Basis(Vector3.UP,0.7).scaled(Vector3(0.8,1.3,0.9)),Vector3(2,1,-3))
	box.transform = rotated
	target.mesh = soup(points.slice(0,3))
	target.transform = rotated
	var transformed = Cleanup.new()
	transformed.gather(root_node,GarageEnvironment.cabinet_meshes)
	check(transformed.clean(target,rotated) == null,"fully enclosed transformed part removed")
	# A sparse 32-bit source must retain the exact surviving encoded records.
	var large_points: Array[Vector3] = []
	for i: int in range(24000): large_points.append_array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP])
	large_points.append_array([Vector3(3,0,0),Vector3(4,0,0),Vector3(3,1,0)])
	var large: ArrayMesh = soup(large_points)
	var large_packet: Dictionary = large.get("_surfaces")[0].duplicate()
	var reduced := ArrayMesh.new()
	reduced.set("_surfaces",[Cleanup.compact(large_packet,PackedInt32Array([72000,72001,72002]))])
	check(reduced.surface_get_array_len(0) == 3 and reduced.get("_surfaces")[0].index_data.size() == 6,"32-bit to 16-bit compaction")
	check(corners(large).slice(72000) == corners(reduced),"large-source encoded attributes remain exact")
	var multi: ArrayMesh = soup(points)
	var extra: Array = soup(points.slice(0,3)).surface_get_arrays(0)
	multi.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,extra)
	target.mesh = multi
	check(cleanup.clean(target,Transform3D.IDENTITY) == multi,"multi-surface meshes retain all surfaces")
	var lod_source: ArrayMesh = SceneryMeshLods.attach(original,{0.1:PackedInt32Array([3,4,5])})
	target.mesh = lod_source
	check(cleanup.clean(target,Transform3D.IDENTITY) == lod_source,"existing LOD streams require a separate proof")
	Cleanup.enabled = false
	target.mesh = original
	check(cleanup.clean(target,Transform3D.IDENTITY) == original,"disabled cleanup is an exact control")
	Cleanup.enabled = true
	root_node.free()
	print("GARAGE_MESH_CLEANUP ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
