class_name RacingCarModels
extends RefCounted
## Optional racing presentation. Garage geometry and canonical state are independent.
const ASSET_ROOT: String = "res://assets/vehicles/racing_simple_v1"
const COACH_ROOT: String = ASSET_ROOT+"/compact"
static var shadow_meshes: Dictionary = {}
static var shadow_material: ShaderMaterial

static func prepare(car: CarVisual) -> void:
	_reduce_primitives(car)
	# Baked stock shadows cannot describe fitted aero/hood/rim silhouettes.
	if car.vehicle_id == "compact" and car.customisation != VehicleCustomisation.defaults(): return
	var frames: Array[Node3D] = [car.body]
	frames.append_array(car.rolling_wheels)
	var meshes: Array[ArrayMesh] = []
	for index: int in range(frames.size()):
		var path: String = ASSET_ROOT.path_join(car.vehicle_id+"_shadow_"+str(index)+".res")
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
		if car.vehicle_id == "compact":
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
		if child is MeshInstance3D: child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if child is Node3D: _disable_casters(child)

static func _reduce_primitives(parent: Node3D) -> void:
	for child: Node in parent.get_children():
		if child is MeshInstance3D:
			var source: Mesh = child.mesh
			var simple: PrimitiveMesh
			if source is CylinderMesh:
				simple = source.duplicate()
				(simple as CylinderMesh).radial_segments = mini(source.radial_segments,12)
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
		if child is Node3D: _reduce_primitives(child)

static func shadow_source(frame: Node3D) -> ArrayMesh:
	# Offline only: one positions-only stream for each articulated frame.
	var tool := SurfaceTool.new()
	var inverse: Transform3D = frame.global_transform.affine_inverse()
	for node: Node in frame.find_children("*","MeshInstance3D",true,false):
		if not node.is_visible_in_tree() or node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
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
