extends RefCounted
## Review-only counts. Stored geometry and conservative buffers are not FPS.

static func collect(node: Node, result: Array, visible_only: bool=true) -> void:
	if visible_only and node is Node3D and not node.visible:return
	if node.is_in_group("contact_lighting"):return
	var mesh: Mesh
	var count: int=1
	if node is MeshInstance3D:mesh=node.mesh
	if node is MultiMeshInstance3D and node.multimesh!=null:
		mesh=node.multimesh.mesh;count=node.multimesh.instance_count
		if node.multimesh.visible_instance_count>=0:count=mini(count,node.multimesh.visible_instance_count)
	if mesh!=null and count>0 and (not visible_only or node.layers!=0):result.append({"node":node,"mesh":mesh,"instances":count})
	for child: Node in node.get_children():collect(child,result,visible_only)

static func chain(material: Material) -> int:
	var seen: Dictionary={};var count: int=0
	while material!=null and not seen.has(material.get_instance_id()):
		seen[material.get_instance_id()]=true;count+=1;material=material.next_pass
	return count

static func mesh_info(mesh: Mesh, index_probe: bool=false) -> Dictionary:
	var result: Dictionary={"triangles":0,"vertices":0,"surfaces":mesh.get_surface_count(),"lod_surfaces":0,"first_lod_triangles":0,"min_lod_triangles":0,"raw_gpu_buffer_bytes":0,"lod_index_bytes":0,"unindexed_vertices":0,"indexed_probe_vertices":0,"surface_rows":[]}
	var packets: Array=mesh.get("_surfaces") if mesh is ArrayMesh else []
	for surface: int in range(mesh.get_surface_count()):
		var arrays: Array=mesh.surface_get_arrays(surface)
		var vertices: int=arrays[Mesh.ARRAY_VERTEX].size()
		var indices: int=arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else 0
		var triangles: int=(vertices if indices==0 else indices)/3
		var first: int=triangles;var minimum: int=triangles;var raw_bytes: int=0;var lod_bytes: int=0
		var indexed_vertices: int=vertices
		if indices==0:result.unindexed_vertices+=vertices
		if index_probe and vertices<=400000:
			var tool:=SurfaceTool.new();tool.create_from(mesh,surface);tool.index()
			indexed_vertices=tool.commit_to_arrays()[Mesh.ARRAY_VERTEX].size()
		if not packets.is_empty():
			var packet: Dictionary=packets[surface]
			for key: String in ["vertex_data","attribute_data","skin_data","index_data"]:
				raw_bytes+=packet.get(key,PackedByteArray()).size()
			var levels: Array=packet.get("lods",[])
			if not levels.is_empty():
				result.lod_surfaces+=1
				var stride: int=packet.index_data.size()/int(packet.index_count) if int(packet.get("index_count",0))>0 else (2 if vertices<=65536 else 4)
				first=levels[1].size()/stride/3
				for index: int in range(1,levels.size(),2):
					lod_bytes+=levels[index].size();minimum=mini(minimum,levels[index].size()/stride/3)
		result.triangles+=triangles;result.vertices+=vertices;result.first_lod_triangles+=first;result.min_lod_triangles+=minimum
		result.raw_gpu_buffer_bytes+=raw_bytes;result.lod_index_bytes+=lod_bytes;result.indexed_probe_vertices+=indexed_vertices
		result.surface_rows.append({"surface":surface,"triangles":triangles,"vertices":vertices,"indices":indices,"first_lod_triangles":first,"min_lod_triangles":minimum,"raw_buffer_bytes":raw_bytes,"lod_index_bytes":lod_bytes,"indexed_probe_vertices":indexed_vertices})
	return result

static func inventory(model: Node, index_probe: bool=false) -> Dictionary:
	var parts: Array=[];collect(model,parts)
	var rows: Array=[];var materials: Dictionary={};var meshes: Dictionary={};var shaders: Dictionary={}
	var result: Dictionary={"mesh_nodes":parts.size(),"instances":0,"base_triangles":0,"base_vertices":0,"first_lod_triangles":0,"min_lod_triangles":0,"lod_surfaces":0,"surfaces":0,"estimated_material_draws":0,"shadow_triangles":0,"unique_raw_buffer_bytes":0,"unique_lod_index_bytes":0,"unindexed_vertices":0,"indexed_probe_vertices":0,"unique_vertices":0,"unique_indexed_probe_vertices":0,"rows":rows}
	for part: Dictionary in parts:
		var node: GeometryInstance3D=part.node;var mesh: Mesh=part.mesh
		var info: Dictionary=mesh_info(mesh,index_probe)
		var shadow_only: bool=node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:result.shadow_triangles+=info.triangles*part.instances
		if not meshes.has(mesh.get_instance_id()):
			meshes[mesh.get_instance_id()]=true;result.unique_raw_buffer_bytes+=info.raw_gpu_buffer_bytes;result.unique_lod_index_bytes+=info.lod_index_bytes
			result.unique_vertices+=info.vertices;result.unique_indexed_probe_vertices+=info.indexed_probe_vertices
		if shadow_only:continue
		result.instances+=part.instances;result.base_triangles+=info.triangles*part.instances;result.base_vertices+=info.vertices*part.instances
		result.first_lod_triangles+=info.first_lod_triangles*part.instances;result.min_lod_triangles+=info.min_lod_triangles*part.instances
		result.surfaces+=info.surfaces;result.lod_surfaces+=info.lod_surfaces
		result.unindexed_vertices+=info.unindexed_vertices*part.instances;result.indexed_probe_vertices+=info.indexed_probe_vertices*part.instances
		var names: Array=[];var passes: int=0
		for surface: int in range(mesh.get_surface_count()):
			var material: Material=node.material_override
			if material==null:material=mesh.surface_get_material(surface)
			if node is MeshInstance3D:material=node.get_active_material(surface)
			if material==null:continue
			materials[material.get_instance_id()]=true;passes+=chain(material)
			if material is ShaderMaterial and material.shader!=null:
				var path: String=material.shader.resource_path
				if path.is_empty():path="generated:"+material.shader.code.sha256_text().left(12)
				shaders[path]=true;names.append(path)
			else:names.append("StandardMaterial3D")
		passes+=chain(node.material_overlay);result.estimated_material_draws+=passes
		rows.append({"path":str(model.get_path_to(node)),"instances":part.instances,"geometry":info,"material_passes":passes,"shaders":names,"shadow_mode":node.cast_shadow})
	rows.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.geometry.triangles*a.instances>b.geometry.triangles*b.instances)
	result.unique_materials=materials.size();result.unique_meshes=meshes.size();result.shaders=shaders.keys()
	return result
