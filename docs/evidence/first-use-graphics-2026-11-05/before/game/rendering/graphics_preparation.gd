extends RefCounted
## Process-local receipts for real completed draws. No nodes, meshes, materials,
## or GPU handles survive here; a receipt is valid only in its render context.
const LIMIT: int = 512
const PROGRAMS_PER_DRAW: int = 4
const OBJECTS_PER_PROGRAM: int = 8
const FAST_DRAW_US: int = 50000 # Includes cooperative frame yields.
static var warmed: Dictionary = {}
static var generation: int = 0
static var hits: int = 0
static var submissions: int = 0
static var _watcher: WeakRef
static var _feature_properties: Dictionary = {}
static var _contexts: Dictionary = {}

class Lifetime extends Node:
	signal reset(reason: String)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_APPLICATION_RESUMED: reset.emit("resume")
		if what == NOTIFICATION_OS_MEMORY_WARNING: reset.emit("memory")
	func _exit_tree() -> void: reset.emit("tree_exit")

static func watch(tree: SceneTree) -> void:
	if _watcher != null and is_instance_valid(_watcher.get_ref()): return
	var lifetime := Lifetime.new()
	lifetime.name = "GraphicsPreparationLifetime"
	lifetime.reset.connect(invalidate)
	_watcher = weakref(lifetime)
	tree.root.add_child.call_deferred(lifetime)

static func invalidate(_reason: String = "explicit") -> void:
	generation += 1
	warmed.clear()
	_contexts.clear()

static func ready(context: String, program: String) -> bool:
	var key: String = context+":"+program
	if not warmed.has(key): return false
	# An LRU contains strings only and stays bounded even through repeated views.
	warmed.erase(key)
	warmed[key] = true
	hits += 1
	return true

static func cacheable(node: GeometryInstance3D) -> bool:
	# Actual particle process/draw coverage belongs to the dedicated effect
	# preparer. An empty emitter draw cannot certify its shader program here.
	if node is MeshInstance3D:
		return node.skin == null and not node.get_node_or_null(node.skeleton) is Skeleton3D and (not node.mesh is ArrayMesh or node.mesh.get_blend_shape_count() == 0)
	return node is MultiMeshInstance3D

static func receipt_key(node: GeometryInstance3D, context_id: String, materials: Dictionary = {}) -> String:
	var program: String = geometry_key(node,materials)
	if not _contexts.get(context_id,{}).get("spatial",false): return program
	# A spot/omni context can choose lights by bounds. Cross-view reuse then
	# requires the same immutable mesh, pose and bounds, not merely its format.
	var mesh: Mesh = node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh != null else null
	return var_to_bytes([program,mesh.get_instance_id() if mesh != null else 0,node.global_transform,node.get_aabb()]).hex_encode().sha256_text()

static func spatial_context(context_id: String) -> bool:
	return _contexts.get(context_id,{}).get("spatial",false)

static func complete(context: String, program: String, epoch: int) -> void:
	if epoch != generation or context.is_empty() or not _contexts.get(context,{}).get("reusable",false): return
	var key: String = context+":"+program
	if warmed.has(key): warmed.erase(key)
	while warmed.size() >= LIMIT: warmed.erase(warmed.keys()[0])
	warmed[key] = true
	submissions += 1

static func context(view: Viewport, world: Node, camera: Camera3D) -> String:
	if view == null or world == null or camera == null: return ""
	if world.is_inside_tree(): watch(world.get_tree())
	var flags: Array = ["graphics-context-1",RenderingServer.get_current_rendering_method(),
		view.msaa_3d,view.screen_space_aa,view.use_taa,view.transparent_bg,
		view.use_occlusion_culling,camera.projection if camera != null else -1,
		camera.cull_mask if camera != null else 0,_viewport_features(view)]
	var environment: Environment = world.get_world_3d().environment if world is Node3D and world.is_inside_tree() else null
	if camera.environment != null: environment = camera.environment
	flags.append(_features(environment))
	flags.append(_features(environment.sky) if environment != null and environment.sky != null else [])
	flags.append(_features(camera.attributes))
	var lighting_layers: int = camera.cull_mask
	for geometry: GeometryInstance3D in world.find_children("*","GeometryInstance3D",true,false):
		# A mesh seen on layer 1 may also receive a light restricted to layer 4.
		# Preserve its complete membership, even while preparation hides it.
		if geometry.layers & camera.cull_mask: lighting_layers |= geometry.layers
	var lights: Array[String] = []
	var spatial: bool = false
	for light: Light3D in world.find_children("*","Light3D",true,false):
		if not light.is_visible_in_tree(): continue
		if not (light.light_cull_mask & lighting_layers): continue
		spatial = spatial or not light is DirectionalLight3D
		lights.append(var_to_bytes([_features(light),light.global_transform,light.light_cull_mask & lighting_layers]).hex_encode())
	lights.sort()
	flags.append(lights)
	if spatial: flags.append([camera.global_transform,camera.fov,camera.size,camera.near,camera.far,camera.keep_aspect,view.get_visible_rect().size])
	# These features affect pipeline compilation even if their nodes are hidden.
	var reusable: bool = true
	for kind: String in ["ReflectionProbe","LightmapGI","VoxelGI"]:
		var count: int = world.find_children("*",kind,true,false).size()
		flags.append([kind,count])
		reusable = reusable and count == 0
	var result: String = var_to_bytes(flags).hex_encode().sha256_text()
	if not _contexts.has(result) and _contexts.size() >= LIMIT: invalidate("context bound")
	_contexts[result] = {"spatial":spatial,"reusable":reusable}
	return result

static func _viewport_features(view: Viewport) -> Array:
	var result: Array = [view.get_class()]
	# Scheduling/clear modes change as a one-shot target is submitted. They
	# are not pipeline state and must not invalidate that very capture.
	for name: String in ["scaling_3d_mode","debug_draw","disable_3d","use_xr","use_debanding","use_hdr_2d","positional_shadow_atlas_size","positional_shadow_atlas_16_bits"]:
		if name in view: result.append([name,view.get(name)])
	return result

static func _features(resource: Object) -> Array:
	if resource == null: return []
	# ShaderMaterial's dynamic property list asks the backend for its uniforms.
	# That can create a lazy shader before the scheduled native draw. Its
	# program is fully described by the shader source/identity and next pass.
	if resource is ShaderMaterial: return [resource.get_class(),resource.render_priority]
	var result: Array = [resource.get_class()]
	var kind: String = resource.get_class()
	if not _feature_properties.has(kind):
		var properties: Array = []
		for property: Dictionary in resource.get_property_list():
			if not int(property.usage)&PROPERTY_USAGE_STORAGE: continue
			var name: String = property.name
			if name.begins_with("resource_") or name.begins_with("shader_parameter/") or name in ["next_pass","owner","script"]: continue
			if resource is Light3D and name in ["layers","light_cull_mask"]: continue
			properties.append([name,property.hint == PROPERTY_HINT_RESOURCE_TYPE and "Texture" in str(property.hint_string)])
		_feature_properties[kind] = properties
	for property: Array in _feature_properties[kind]:
		var name: String = property[0]
		var value: Variant = resource.get(name)
		if value is bool or value is int: result.append([name,value])
		elif resource is Light3D and (value is float or value is Color or value is Vector3 or value is Transform3D): result.append([name,value])
		elif property[1]: result.append([name,value != null])
	return result

static func geometry_key(node: GeometryInstance3D, materials: Dictionary = {}) -> String:
	var mesh: Mesh = node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh != null else null
	var parts: Array = ["graphics-program-1",node.get_class(),node.cast_shadow,node.layers,node.gi_mode,
		node.visibility_range_fade_mode,_material_key(node.material_overlay,materials)]
	if node is MeshInstance3D: parts.append([node.skin != null,node.get_node_or_null(node.skeleton) is Skeleton3D,node.mesh.get_blend_shape_count() if node.mesh is ArrayMesh else 0])
	if node is MultiMeshInstance3D and node.multimesh != null:
		parts.append([node.multimesh.transform_format,node.multimesh.use_colors,node.multimesh.use_custom_data])
	if mesh != null:
		for surface: int in range(mesh.get_surface_count()):
			var material: Material = node.get_active_material(surface) if node is MeshInstance3D else node.material_override if node.material_override != null else mesh.surface_get_material(surface)
			parts.append(_material_key(material,materials))
			parts.append([mesh.surface_get_format(surface),mesh.surface_get_primitive_type(surface)] if mesh is ArrayMesh else _features(mesh))
	return str(parts).sha256_text()

static func _material_key(material: Material, cache: Dictionary = {}) -> String:
	if material == null: return "none"
	var id: int = material.get_instance_id()
	if cache.has(id): return cache[id]
	# Break malformed next-pass cycles without a recursive shader/RID query.
	cache[id] = "cycle-"+str(id)
	var features: Array = _features(material)
	if material is ShaderMaterial:
		if material.shader != null:
			var shader_key: String = "shader-"+str(material.shader.get_instance_id())
			if not cache.has(shader_key): cache[shader_key] = material.shader.code.sha256_text()
			features.append([material.shader.get_instance_id(),cache[shader_key]])
		else: features.append([])
	elif not material is BaseMaterial3D: features.append(id)
	features.append(_material_key(material.next_pass,cache))
	var result: String = str(features).sha256_text()
	cache[id] = result
	return result

static func begin_capture(world: Node3D, view: Viewport, camera: Camera3D) -> Dictionary:
	var samples: Array[Dictionary] = []
	var materials: Dictionary = {}
	var context_id: String = context(view,world,camera)
	# Header/thumbnail callers retain their complete native settle sequence.
	# Publish only mesh sources whose bounds reach the actual capture camera.
	for node: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
		if node.mesh == null or not cacheable(node) or not node.is_visible_in_tree() or not (node.layers & camera.cull_mask): continue
		if view.use_occlusion_culling or not camera.is_position_in_frustum(node.to_global(node.get_aabb().get_center())): continue
		samples.append({"node":weakref(node),"key":receipt_key(node,context_id,materials)})
	return {"context":context_id,"epoch":generation,"samples":samples}

static func finish_capture(ticket: Dictionary, world: Node3D, view: Viewport, camera: Camera3D) -> void:
	if ticket.is_empty() or ticket.epoch != generation or ticket.context != context(view,world,camera): return
	for sample: Dictionary in ticket.samples:
		var node: Object = sample.node.get_ref()
		if is_instance_valid(node) and node.is_visible_in_tree() and receipt_key(node,ticket.context) == sample.key:
			complete(ticket.context,sample.key,ticket.epoch)
