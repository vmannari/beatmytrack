extends SceneTree
## Every material/ordered triangle retains its raw vertex records in all ten poses.
const ROOT: String="res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/"
var checks: int=0
var failures: int=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("LOADING_SPLIT_FAIL ",message)
func triangles(mesh: ArrayMesh, pose: int, result: Dictionary) -> void:
	for packet: Dictionary in mesh.get("_surfaces"):
		var count: int=packet.vertex_count
		var format: int=packet.format
		var ps: int=RenderingServer.mesh_surface_get_format_vertex_stride(format,count)
		var ns: int=RenderingServer.mesh_surface_get_format_normal_tangent_stride(format,count)
		var ats: int=RenderingServer.mesh_surface_get_format_attribute_stride(format,count)
		var raw: PackedByteArray=packet.vertex_data
		if pose>=0 and mesh.get_blend_shape_count()>0: raw=packet.blend_shapes.slice(pose*count*(ps+ns),(pose+1)*count*(ps+ns))
		var attrs: PackedByteArray=packet.get("attribute_data",PackedByteArray())
		var indices: PackedByteArray=packet.index_data
		var stride: int=indices.size()/int(packet.index_count)
		for face: int in range(0,int(packet.index_count),3):
			var code: PackedByteArray=var_to_bytes([packet.material.resource_name,ps,ns,ats])
			for corner: int in range(3):
				var index: int=indices.decode_u16((face+corner)*stride) if stride==2 else indices.decode_u32((face+corner)*stride)
				code.append_array(raw.slice(index*ps,(index+1)*ps))
				code.append_array(raw.slice(count*ps+index*ns,count*ps+(index+1)*ns))
				if ats: code.append_array(attrs.slice(index*ats,(index+1)*ats))
			var hash: String=code.hex_encode().sha256_text()
			result[hash]=int(result.get(hash,0))+1
func run() -> void:
	var original: ArrayMesh=load(ROOT+"driver.res")
	var dynamic: ArrayMesh=load(ROOT+"driver_steering.res")
	var fixed: ArrayMesh=load(ROOT+"driver_static.res")
	check(dynamic.get_blend_shape_count()==10 and fixed.get_blend_shape_count()==0,"ten animated poses and zero static poses")
	check(dynamic.get_faces().size()+fixed.get_faces().size()==original.get_faces().size(),"all original triangle corners retained")
	for pose: int in range(-1,10):
		var source: Dictionary={}
		var split: Dictionary={}
		triangles(original,pose,source); triangles(dynamic,pose,split); triangles(fixed,pose,split)
		check(source==split,"ordered raw position/normal/tangent/UV/material triangles for pose "+str(pose))
	for mesh: ArrayMesh in [dynamic,fixed]: check(mesh.get_meta("kart_split_source_sha256")==FileAccess.get_sha256(ROOT+"driver.res"),"split source provenance")
	var bytes: int=preload("res://tests/support/car_model_buffers.gd").payload(dynamic)+preload("res://tests/support/car_model_buffers.gd").payload(fixed)
	check(bytes<preload("res://tests/support/car_model_buffers.gd").payload(original),"split actually reduces loaded raw buffers")
	print("LOADING_DRIVER_SPLIT ",checks," checks, ",failures," failures; bytes=",bytes)
	quit(1 if failures else 0)
