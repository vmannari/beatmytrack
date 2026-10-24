extends RefCounted
## Night's local-light presence selects GLES shader variants at draw time.
## Prepare all four presence combinations under the existing loading cover.
const MAX_ITEMS: int = 1024
const MAX_LIGHTS: int = 64
const CONTEXTS: int = 4

static func begin(world: Node3D, camera: Camera3D) -> Dictionary:
	var result: Dictionary = {"geometry":[],"lights":[],"nodes":[],"items":0,"truncated":0,"light_limit":false}
	if world == null or camera == null or DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "gl_compatibility": return result
	for node: Node in world.find_children("*", "Light3D", true, false):
		if not node is OmniLight3D and not node is SpotLight3D: continue
		if result.lights.size() == MAX_LIGHTS:
			# Do not partially change the lighting context of an unusually large scene.
			result.light_limit = true
			result.lights.clear()
			return result
		result.lights.append({"node":node,"visible":node.visible})
	for node: Node in world.find_children("*", "GeometryInstance3D", true, false):
		if not node.is_visible_in_tree(): continue
		if result.geometry.size() == MAX_ITEMS:
			result.truncated += 1
			continue
		var geometry: GeometryInstance3D = node
		var local_camera: Vector3 = geometry.to_local(camera.global_position)
		var distance: Vector3 = (local_camera-geometry.get_aabb().get_center()).abs()
		result.geometry.append({"node":geometry,"margin":geometry.extra_cull_margin})
		geometry.extra_cull_margin = maxf(geometry.extra_cull_margin,maxf(distance.x,maxf(distance.y,distance.z))+camera.near+2.0)
	result.items = result.geometry.size()
	if result.items == 0: return result
	var omni := OmniLight3D.new()
	omni.name = "CoveredNightOmni"
	omni.omni_range = 0.5
	var spot := SpotLight3D.new()
	spot.name = "CoveredNightSpot"
	spot.spot_range = 0.5
	spot.spot_angle = 60.0
	for light: Light3D in [omni,spot]:
		light.light_energy = 0.01
		light.light_cull_mask = 0xFFFFF
		light.shadow_enabled = false
		light.visible = false
		world.add_child(light)
		light.global_transform = camera.global_transform
		result.nodes.append(light)
	for entry: Dictionary in result.lights: entry.node.visible = false
	return result

static func set_context(prepared: Dictionary, index: int) -> void:
	if prepared.nodes.size() != 2: return
	# Bounded artificial lights meet the expanded culling boxes at the camera;
	# actual vertices, lamp properties and the gameplay camera are untouched.
	prepared.nodes[0].visible = (index & 1) != 0
	prepared.nodes[1].visible = (index & 2) != 0

static func end(prepared: Dictionary) -> void:
	for entry: Dictionary in prepared.geometry:
		if is_instance_valid(entry.node): entry.node.extra_cull_margin = entry.margin
	for entry: Dictionary in prepared.lights:
		if is_instance_valid(entry.node): entry.node.visible = entry.visible
	for node in prepared.nodes:
		if is_instance_valid(node): node.free()
	prepared.geometry.clear()
	prepared.lights.clear()
	prepared.nodes.clear()
