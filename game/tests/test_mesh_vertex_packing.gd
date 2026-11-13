extends SceneTree
const Packing=preload("res://rendering/mesh_vertex_packing.gd")
var checks: int=0
var failures: int=0
func _initialize()->void:run.call_deferred()
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures+=1;printerr("PACKING_FAIL ",label)
func expanded(mesh: ArrayMesh)->Array:
	var result: Array=[]
	for surface: int in range(mesh.get_surface_count()):
		var packet: Dictionary=mesh.get("_surfaces")[surface]
		var count: int=int(packet.vertex_count);var format: int=mesh.surface_get_format(surface)
		var ps: int=RenderingServer.mesh_surface_get_format_vertex_stride(format,count)
		var ns: int=RenderingServer.mesh_surface_get_format_normal_tangent_stride(format,count)
		var ats: int=RenderingServer.mesh_surface_get_format_attribute_stride(format,count)
		var vertices: PackedByteArray=packet.vertex_data;var attrs: PackedByteArray=packet.get("attribute_data",PackedByteArray())
		var indices: PackedByteArray=packet.get("index_data",PackedByteArray())
		var corners: int=int(packet.get("index_count",count));var stride: int=indices.size()/corners if not indices.is_empty() else 0
		var streams: Array=[indices]
		var lods: Array=packet.get("lods",[])
		for i: int in range(1,lods.size(),2):streams.append(lods[i])
		for stream: PackedByteArray in streams:
			var bytes:=PackedByteArray()
			for corner: int in range(stream.size()/stride if stride else count):
				var index: int=corner if stream.is_empty() else stream.decode_u16(corner*stride) if stride==2 else stream.decode_u32(corner*stride)
				bytes.append_array(vertices.slice(index*ps,(index+1)*ps))
				bytes.append_array(vertices.slice(count*ps+index*ns,count*ps+(index+1)*ns))
				bytes.append_array(attrs.slice(index*ats,(index+1)*ats))
			result.append(bytes)
	return result
func run()->void:
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for copy: int in range(64):
		for i: int in range(6):
			tool.set_normal(Vector3(0.25,1,0.1).normalized());tool.set_color(Color(0.3,0.4,0.5,1));tool.set_uv(Vector2(i%3,0));tool.set_uv2(Vector2(i%3,0.5));tool.add_vertex([Vector3.ZERO,Vector3.RIGHT,Vector3.FORWARD][i%3])
	var source: ArrayMesh=tool.commit();source.set_meta("owner_data",{"exact":true})
	var original: Array=source.get("_surfaces").duplicate(true)
	var packed: ArrayMesh=Packing.pack(source)
	check(packed.surface_get_array_len(0)==3,"duplicate vertices merged")
	check(expanded(source)==expanded(packed),"all encoded ordered corner attributes exact")
	check(source.get("_surfaces")==original,"source packet remains immutable")
	check(packed.get_meta("owner_data")==source.get_meta("owner_data"),"metadata preserved")
	check(Packing.pack(packed)==packed,"packing idempotent")
	var material:=StandardMaterial3D.new();source.surface_set_material(0,material)
	source.custom_aabb=AABB(Vector3(-2,-2,-2),Vector3(4,4,4))
	packed=Packing.pack(source)
	check(packed.surface_get_material(0)==material and packed.custom_aabb==source.custom_aabb,"material and custom culling bounds retained")
	check(await Packing.pack_cooperative(source,func()->bool:return false)==source,"cancelled packing returns the immutable original")
	# Exercise a real 32-to-16-bit transition, not just a small duplicate mesh.
	var many:=SurfaceTool.new();many.begin(Mesh.PRIMITIVE_TRIANGLES)
	for copy: int in range(24000):
		for point: Vector3 in [Vector3.ZERO,Vector3.RIGHT,Vector3.FORWARD]:
			many.set_normal(Vector3.UP);many.set_color(Color.WHITE);many.add_vertex(point)
	var large: ArrayMesh=many.commit()
	var keep:=PackedInt32Array([0,1,2,71997,71998,71999])
	large=SceneryMeshLods.attach(large,{0.1:keep})
	packed=Packing.pack(large)
	check(packed.surface_get_array_len(0)==3 and packed.get("_surfaces")[0].index_data.size()==72000*2,"large indexed source reduces to 16-bit indices")
	check(expanded(large)==expanded(packed),"32-bit master and LOD corner attributes remain exact after remapping")
	packed=Packing.pack(source)
	var joined: ArrayMesh=Packing.with_detail(source,packed,0.028)
	check(expanded(joined)[0]==expanded(source)[0],"authored distance level retains every master encoded corner")
	check(expanded(joined)[1]==expanded(packed)[0],"authored distance level retains every distant encoded corner")
	check(source.get("_surfaces")[0].get("lods",[]).is_empty(),"adding a distance level never mutates the master source")
	print("PACKING_TEST ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
