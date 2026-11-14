extends SceneTree
## The close master is preserved; the authored distant level reduces rendering.
func _initialize() -> void: run.call_deferred()
func settle(view: CarShowroom) -> void:
	view.invalidate_render()
	for frame: int in range(16): await process_frame; await RenderingServer.frame_post_draw
func run() -> void:
	var view := CarShowroom.new()
	view.vehicle_id="hovercraft"
	view.simple_model=true
	view.read_only=true
	view.livery=VehicleLivery.defaults("hovercraft")
	view.size=Vector2(1000,760)
	root.add_child(view)
	while not view.showroom_ready or not view.car.model_ready: await process_frame
	var nodes: Array[MeshInstance3D] = []
	for part: MeshInstance3D in view.car.find_children("*","MeshInstance3D",true,false):
		if part.mesh.has_meta("car_authored_far"): nodes.append(part)
	assert(not nodes.is_empty(),"Current prepared Hover has its authored distance level")
	for part: MeshInstance3D in nodes: part.lod_bias=1000000
	await settle(view)
	var fine: int = view.showroom_viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	for part: MeshInstance3D in nodes: part.lod_bias=0.000001
	await settle(view)
	var far: int = view.showroom_viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	assert(fine-far==1152,"Authored far level saves exactly 1152 rendered seam triangles")
	var output: String = "res://../docs/evidence/car-simplification-2026-11-13/hover-lod-"+RenderingServer.get_current_rendering_method()+".json"
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"checks":2,"failures":0,"fine_primitives":fine,"far_primitives":far,"saved":fine-far}))
	view.free()
	print("HOVER_LOD 2 checks, 0 failures; ",fine," -> ",far)
	quit()
