extends SceneTree
## Isolate native LOD selection using stored geometry, independently of the
## source-checkout cache guards. This is not current-model freshness approval.
const Renderer = preload("res://ui/header_icon_renderer.gd")
const SIZE := Vector2i(176,112)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	root.add_child(viewport)
	var packed: PackedScene = load("res://assets/vehicles/modular_car_bases_v1/compact_simple_editable.scn")
	var body: Node3D = packed.instantiate()
	body.scale = Vector3.ONE*HandlingConfig.BODY_SCALE
	body.rotation.y = PI
	viewport.add_child(body)
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = Color("72a7b5")
	for mesh: MeshInstance3D in body.find_children("*","MeshInstance3D",true,false):
		mesh.material_override = paint
		mesh.lod_bias = Renderer.LOD_BIAS
		if mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: mesh.hide()
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var camera := Camera3D.new()
	camera.position = Vector3(-5,2.5,6)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.0
	viewport.add_child(camera)
	camera.look_at(Vector3(0,0.65,0))
	camera.current = true
	var rows: Array = []
	for threshold: float in [0.0,1.0]:
		viewport.mesh_lod_threshold = threshold
		for _frame: int in range(3):
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await process_frame
			await RenderingServer.frame_post_draw
		rows.append({"threshold":threshold,"primitives":viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)})
	var ok: bool = rows[1].primitives>0 and rows[1].primitives<rows[0].primitives*0.85
	var result: Dictionary = {"stored_compact":rows,"passed":ok,"scope":"Stored prepared geometry only; live cache freshness remains separately guarded"}
	var output: String = OS.get_environment("BMT_RIVALRY_CARS_EVIDENCE_DIR")
	FileAccess.open(output.path_join("lod-policy.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("HEADER_STORED_LOD_POLICY ",JSON.stringify(result))
	viewport.free()
	await process_frame
	print("HEADER_LOD_POLICY: 1 checks, %d failures" % [0 if ok else 1])
	quit(0 if ok else 1)
