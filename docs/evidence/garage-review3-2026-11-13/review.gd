extends "res://tests/test_garage_model_pass2.gd"
const Buffers = preload("res://tests/support/car_model_buffers.gd")
var inspected: bool = false

func _initialize() -> void:
	output = "res://../build/garage-review3-2026-11-13/native"
	super._initialize()

func inspect_room(view: CarShowroom) -> void:
	var room: Node = view.camera.get_parent().find_child("GarageArchitecture",true,false)
	var rows: Array[Dictionary] = []
	var seen: Dictionary = {}
	var instance_bytes: int = 0
	var unique_bytes: int = 0
	for part: MeshInstance3D in room.find_children("*","MeshInstance3D",true,false):
		if part.mesh == null: continue
		var triangles: int = 0
		for surface: int in range(part.mesh.get_surface_count()):
			var arrays: Array = part.mesh.surface_get_arrays(surface)
			var count: int = arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else arrays[Mesh.ARRAY_VERTEX].size()
			triangles += count/3
		var bytes: int = Buffers.payload(part.mesh) if part.mesh is ArrayMesh else 0
		instance_bytes += bytes
		if not seen.has(part.mesh):
			seen[part.mesh] = true
			unique_bytes += bytes
		var finish: Material = part.get_active_material(0)
		var role: Dictionary = {"class":finish.get_class()}
		if finish is ShaderMaterial:
			role.shader = finish.shader.resource_path
			role.finish_color = str(finish.get_shader_parameter("finish_color"))
		elif finish is BaseMaterial3D: role.color = str(finish.albedo_color)
		rows.append({"path":str(room.get_path_to(part)),"triangles":triangles,"array_mesh_bytes":bytes,"finish":role})
	rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.triangles > b.triangles)
	report.room_costs = {"mesh_instances":rows.size(),"unique_meshes":seen.size(),"array_mesh_instance_bytes":instance_bytes,"array_mesh_unique_bytes":unique_bytes,"rows":rows}
	inspected = true

func capture(view: CarShowroom, label: String) -> void:
	if not inspected: inspect_room(view)
	await super.capture(view,label)
	if DisplayServer.get_name() == "headless" or not (label.ends_with("-front") or label in ["record","trophies","tyres"]): return
	var views: Array[SubViewport] = [view.showroom_viewport]
	views.append_array(view.reflections.views)
	for target: SubViewport in views: target.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await frames(5)
	var counters: Array[Dictionary] = []
	for target: SubViewport in views:
		var rid: RID = target.get_viewport_rid()
		counters.append({"draw_calls":RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)})
		target.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if not report.has("view_costs"): report.view_costs = {}
	report.view_costs[label] = counters
	view.invalidate_render()
