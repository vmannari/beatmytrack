class_name BridgeRenderPreparation
extends RefCounted
## Submit the actual bridge meshes once under the loading cover. No camera,
## material, mesh, visibility, simulation or persistent cosmetic changes.
const NAMES: Array[String] = ["BridgeUnderShadow", "BridgeAsphalt", "BridgeSteelAndFascia", "DesertBridgeSandstone", "NativeBridgeAsphalt", "NativeBridgeRails", "NativeBridgeFascia"]
const GROUP: String = "race_bridge_rendering"

static func begin(world: Node, camera: Camera3D) -> Array[Dictionary]:
	return _begin(world, camera, NAMES, [GROUP])

static func begin_groups(world: Node, camera: Camera3D, groups: Array[String]) -> Array[Dictionary]:
	return _begin(world, camera, [], groups)

static func _begin(world: Node, camera: Camera3D, names: Array[String], groups: Array[String]) -> Array[Dictionary]:
	var restore: Array[Dictionary] = []
	if world == null or camera == null: return restore
	for node: Node in world.find_children("*", "MeshInstance3D", true, false):
		if not node.is_visible_in_tree(): continue
		if str(node.name) not in names and not groups.any(func(group: String) -> bool: return node.is_in_group(group)): continue
		var mesh: MeshInstance3D = node
		restore.append({"node": mesh, "margin": mesh.extra_cull_margin})
		# Include the current camera in the local culling box, even for bridges
		# outside the starting view. Their original vertices remain untouched.
		var local_camera: Vector3 = mesh.to_local(camera.global_position)
		var bounds: AABB = mesh.get_aabb()
		var distance: Vector3 = (local_camera - bounds.get_center()).abs()
		mesh.extra_cull_margin = maxf(mesh.extra_cull_margin, maxf(distance.x, maxf(distance.y, distance.z)) + camera.near + 1.0)
	return restore

static func end(restore: Array[Dictionary]) -> void:
	for entry: Dictionary in restore:
		if is_instance_valid(entry.node): entry.node.extra_cull_margin = entry.margin
	restore.clear()
