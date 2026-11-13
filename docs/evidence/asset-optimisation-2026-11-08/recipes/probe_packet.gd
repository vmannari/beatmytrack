extends SceneTree
func _initialize()->void:
	for method: Dictionary in RenderingServer.get_method_list():
		if str(method.name).begins_with("mesh_surface_get_format"):print("METHOD ",method.name)
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(6):
		tool.set_normal(Vector3(0.25,1,0.1).normalized());tool.set_color(Color(0.3,0.4,0.5,1));tool.set_uv(Vector2(i%3,0));tool.add_vertex([Vector3.ZERO,Vector3.RIGHT,Vector3.FORWARD][i%3])
	var mesh: ArrayMesh=tool.commit()
	var packet: Dictionary=mesh.get("_surfaces")[0]
	for key: String in packet:print("PACKET ",key," ",packet[key].size() if packet[key] is PackedByteArray else packet[key])
	var format: int=mesh.surface_get_format(0)
	print("STRIDES ",RenderingServer.mesh_surface_get_format_vertex_stride(format,6)," ",RenderingServer.mesh_surface_get_format_normal_tangent_stride(format,6)," ",RenderingServer.mesh_surface_get_format_attribute_stride(format,6)," ",RenderingServer.mesh_surface_get_format_skin_stride(format,6))
	quit()
