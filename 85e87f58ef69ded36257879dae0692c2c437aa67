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
	print("PACKING_TEST ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
