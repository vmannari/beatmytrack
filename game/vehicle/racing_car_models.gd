class_name RacingCarModels
extends RefCounted
## Optional racing presentation. Garage geometry and canonical state are independent.
const ASSET_ROOT: String = "res://assets/vehicles/racing_simple_v1"
const COACH_ROOT: String = ASSET_ROOT+"/compact"
static var shadow_meshes: Dictionary = {}
static var shadow_material: ShaderMaterial

static func prepare(car: CarVisual) -> void:
	_reduce_primitives(car,true)
	# Editable assemblies retain their own casters through later part replacements.
	if car.editable_kits: return
	# Baked stock shadows cannot describe fitted aero/hood/rim silhouettes.
	if VehicleCustomisation.supported(car.model_id) and car.customisation != VehicleCustomisation.defaults(): return
	var frames: Array[Node3D] = [car.body]
	frames.append_array(car.rolling_wheels)
	var meshes: Array[ArrayMesh] = []
	for index: int in range(frames.size()):
		var path: String = ASSET_ROOT.path_join(car.model_id+"_shadow_"+str(index)+".res")
		if not shadow_meshes.has(path) and ResourceLoader.exists(path): shadow_meshes[path] = load(path)
		if not shadow_meshes.has(path): return # Offline bake still owns the ordinary casters.
		meshes.append(shadow_meshes[path])
	if shadow_material == null:
		shadow_material = ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = "shader_type spatial; render_mode unshaded; void fragment(){ALBEDO=vec3(1.0);}"
		shadow_material.shader = shader
	for index: int in range(frames.size()):
		# Fitted parts can change the actual silhouette. Their already reduced
		# geometry keeps its own casters instead of using a stock-only proxy.
		if VehicleCustomisation.supported(car.model_id):
			var fitted: bool = false
			for category: String in (["hood","aero","body"] if index == 0 else ["rims"]):
				if str(car.customisation.get(category,"stock")) != "stock": fitted = true
			if fitted: continue
		_disable_casters(frames[index])
		var caster := MeshInstance3D.new()
		caster.name = "RaceShadowProxy"
		caster.mesh = meshes[index]
		caster.material_override = shadow_material
		caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		frames[index].add_child(caster)

static func _disable_casters(parent: Node3D) -> void:
	for child: Node in parent.get_children():
		if str(child.name) == "SteeringAssembly" or (child is MeshInstance3D and child.mesh is ArrayMesh and child.mesh.get_blend_shape_count() > 0): continue
		if child is MeshInstance3D: child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if child is Node3D: _disable_casters(child)

static func _reduce_primitives(parent: Node3D, axial: bool = false) -> void:
	for child: Node in parent.get_children():
		if child is MeshInstance3D:
			var source: Mesh = child.mesh
			var simple: PrimitiveMesh
			if source is CylinderMesh:
				simple = source.duplicate()
				(simple as CylinderMesh).radial_segments = mini(source.radial_segments,8 if maxf(source.top_radius,source.bottom_radius)<=0.06 else 12)
				# Straight sides need no intermediate height rows. Radial outline,
				# end caps and UV endpoints remain owned by the source cylinder.
				if axial: (simple as CylinderMesh).rings = 0
			elif source is SphereMesh:
				simple = source.duplicate()
				(simple as SphereMesh).radial_segments = mini(source.radial_segments,12)
				(simple as SphereMesh).rings = mini(source.rings,6)
			elif source is CapsuleMesh:
				simple = source.duplicate()
				(simple as CapsuleMesh).radial_segments = mini(source.radial_segments,12)
				(simple as CapsuleMesh).rings = mini(source.rings,6)
			if simple != null:
				simple.custom_aabb = source.get_aabb()
				child.mesh = simple
			elif source is ImmediateMesh:
				child.mesh = _reduce_ring(source)
		if child is Node3D: _reduce_primitives(child,axial)

static func _reduce_ring(source: ImmediateMesh) -> Mesh:
	# VisualGeometry.ring's exact planar 96-segment stream. Keep original samples
	# and material; other immediate geometry is outside this reduction policy.
	if source.get_surface_count()!=1: return source
	var arrays: Array=source.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	if vertices.size()!=576 or not source.surface_get_material(0) is StandardMaterial3D: return source
	for attribute: int in [Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_COLOR,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS]:
		if arrays[attribute]!=null and not arrays[attribute].is_empty(): return source
	var center: Vector3=source.get_aabb().get_center()
	center.y=vertices[0].y
	var inner_radius: float=(vertices[0]-center).length()
	var outer_radius: float=(vertices[2]-center).length()
	if inner_radius<=0.0 or outer_radius<=inner_radius: return source
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	if normals.size()!=vertices.size(): return source
	for segment: int in range(96):
		var a: float=TAU*segment/96.0
		var b: float=TAU*(segment+1)/96.0
		var inner_a: Vector3=center+Vector3(sin(a),0,cos(a))*inner_radius
		var outer_a: Vector3=center+Vector3(sin(a),0,cos(a))*outer_radius
		var inner_b: Vector3=center+Vector3(sin(b),0,cos(b))*inner_radius
		var outer_b: Vector3=center+Vector3(sin(b),0,cos(b))*outer_radius
		var expected: Array[Vector3]=[inner_a,outer_b,outer_a,inner_a,inner_b,outer_b]
		for corner: int in range(6):
			if vertices[segment*6+corner].distance_to(expected[corner])>0.00001 or normals[segment*6+corner].distance_to(Vector3.UP)>0.0001: return source
	var radius: float=maxf(source.get_aabb().size.x,source.get_aabb().size.z)*0.5
	var step: int=4 if radius<=0.12 else 2
	var selected:=PackedInt32Array()
	for index: int in range(0,96,step):
		var begin: int=index*6
		var end: int=(index+step-1)*6
		for at: int in [begin,end+1,begin+2,begin,end+4,end+1]:
			selected.append(at)
	# Preserve encoded normals/tangents instead of round-tripping their decoder.
	var packet: Dictionary=RenderingServer.mesh_get_surface(source.get_rid(),0)
	if int(packet.format)&Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES: return source
	var count: int=packet.vertex_count
	var ps: int=RenderingServer.mesh_surface_get_format_vertex_stride(packet.format,count)
	var ns: int=RenderingServer.mesh_surface_get_format_normal_tangent_stride(packet.format,count)
	var ats: int=RenderingServer.mesh_surface_get_format_attribute_stride(packet.format,count)
	var raw: PackedByteArray=packet.vertex_data
	var attrs: PackedByteArray=packet.get("attribute_data",PackedByteArray())
	var remap: Dictionary={}
	var used:=PackedInt32Array()
	var indices:=PackedByteArray()
	indices.resize(selected.size()*2)
	for at: int in range(selected.size()):
		var old: int=selected[at]
		if not remap.has(old): remap[old]=used.size();used.append(old)
		indices.encode_u16(at*2,remap[old])
	var positions:=PackedByteArray();var encoded_normals:=PackedByteArray();var attributes:=PackedByteArray()
	for old: int in used:
		positions.append_array(raw.slice(old*ps,(old+1)*ps))
		encoded_normals.append_array(raw.slice(count*ps+old*ns,count*ps+(old+1)*ns))
		if ats: attributes.append_array(attrs.slice(old*ats,(old+1)*ats))
	positions.append_array(encoded_normals)
	packet.vertex_data=positions;packet.vertex_count=used.size()
	packet.attribute_data=attributes;packet.index_data=indices;packet.index_count=selected.size()
	packet.format=int(packet.format)|Mesh.ARRAY_FORMAT_INDEX
	packet.material=source.surface_get_material(0);packet.aabb=source.get_aabb()
	var result:=ArrayMesh.new()
	result.set("_surfaces",[packet])
	result.custom_aabb=source.get_aabb()
	result.set_meta("car_surface_guide_locked",true)
	return result

static func shadow_source(frame: Node3D) -> ArrayMesh:
	# Offline only: one positions-only stream for each articulated frame.
	var tool := SurfaceTool.new()
	var inverse: Transform3D = frame.global_transform.affine_inverse()
	for node: Node in frame.find_children("*","MeshInstance3D",true,false):
		if not node.is_visible_in_tree() or node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		# Articulated cockpit parts cast their live silhouettes separately.
		if node.mesh is ArrayMesh and node.mesh.get_blend_shape_count() > 0: continue
		var ancestor: Node = node.get_parent()
		var articulated: bool = false
		while ancestor != frame:
			if str(ancestor.name) == "SteeringAssembly" or (ancestor is MeshInstance3D and ancestor.mesh is ArrayMesh and ancestor.mesh.get_blend_shape_count()>0): articulated = true
			ancestor = ancestor.get_parent()
		if articulated: continue
		for surface: int in range(node.mesh.get_surface_count()):
			var source: Array = node.mesh.surface_get_arrays(surface)
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = source[Mesh.ARRAY_VERTEX]
			arrays[Mesh.ARRAY_INDEX] = source[Mesh.ARRAY_INDEX]
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			tool.append_from(VisualGeometry.indexed_surface(mesh),0,inverse*node.global_transform)
	tool.index()
	return tool.commit()
