extends SceneTree
## Native before/after pixels, bounded work, context reuse and invalidation.
const Shared = preload("res://rendering/graphics_preparation.gd")
const Queue = preload("res://race/world_render_preparation.gd")
const Before = preload("res://../docs/evidence/graphics-preparation-2026-11-04/before/game/race/world_render_preparation.gd")
var checks: int = 0
var failures: int = 0
var rows: Array = []
var view: SubViewport
var stage: Stage
var nodes: Array[MeshInstance3D] = []

class Stage extends Node3D:
	var camera: Camera3D
	var showroom_viewport: SubViewport

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("SHARED_GRAPHICS_FAIL ",label)
func draw() -> bool:
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	await process_frame
	return true
func pixels() -> PackedByteArray:
	return view.get_texture().get_image().get_data()
func run() -> void:
	create_timer(90).timeout.connect(func() -> void: printerr("SHARED_GRAPHICS_TIMEOUT"); quit(1))
	root.size = Vector2i(640,360)
	view = SubViewport.new()
	view.size = Vector2i(512,256)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	root.add_child(view)
	stage = Stage.new()
	stage.showroom_viewport = view
	view.add_child(stage)
	stage.camera = Camera3D.new()
	stage.add_child(stage.camera)
	stage.camera.position = Vector3(0,8,9)
	stage.camera.look_at(Vector3.ZERO)
	stage.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	stage.camera.size = 16
	stage.camera.current = true
	var materials: Array[ShaderMaterial] = []
	for index: int in range(7):
		var shader := Shader.new()
		shader.code = "shader_type spatial; render_mode unshaded; uniform vec4 pigment : source_color; void fragment(){ALBEDO=pigment.rgb;} //"+str(index)
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("pigment",Color.from_hsv(float(index)/7.0,0.7,0.8))
		materials.append(material)
	for index: int in range(70):
		var node := MeshInstance3D.new()
		node.mesh = BoxMesh.new()
		node.material_override = materials[index%7]
		node.position = Vector3((index%10-4.5)*1.2,0,(index/10-3)*1.2)
		node.extra_cull_margin = 0.01*index
		stage.add_child(node)
		nodes.append(node)
	var reference: PackedByteArray
	for control: bool in [true,false]:
		Before.warmed.clear()
		Shared.invalidate()
		var queue: Node = Before.new() if control else Queue.new()
		stage.add_child(queue)
		queue.hold(stage)
		var observed: Dictionary = {"draws":0,"first_objects":0}
		var submit: Callable = func() -> bool:
			observed.draws += 1
			if observed.draws == 1: observed.first_objects = nodes.filter(func(node: MeshInstance3D) -> bool: return node.visible).size()
			return await draw()
		var began: int = Time.get_ticks_usec()
		check(await queue.prepare(submit,func() -> bool: return true),"native queue completes "+str(control))
		var elapsed: float = (Time.get_ticks_usec()-began)/1000.0
		check(nodes.all(func(node: MeshInstance3D) -> bool: return node.visible),"complete visibility restored")
		for index: int in range(nodes.size()): check(is_equal_approx(nodes[index].extra_cull_margin,0.01*index),"original culling margin "+str(index))
		check(observed.draws == 7 if control else observed.draws >= ceili(7.0/Shared.PROGRAMS_PER_DRAW) and observed.draws <= 7,"seven real programs respect the adaptive bounded submission policy")
		check(observed.first_objects == Shared.OBJECTS_PER_PROGRAM,"first submission conservatively exposes one program")
		for _i: int in range(4): await draw()
		if DisplayServer.get_name() != "headless":
			var image: Image = view.get_texture().get_image()
			if control: reference = image.get_data()
			else: check(reference == image.get_data(),"final native pixels equal the task-start queue")
			check(image.save_png(OS.get_environment("BMT_GRAPHICS_EVIDENCE").path_join("queue-"+str(control)+".png")) == OK,"native evidence capture")
		rows.append({"control":control,"ms":elapsed,"draws":observed.draws,"first_objects":observed.first_objects})
		queue.free()
	# Two different owners share only successfully completed matching contexts.
	var reused := Queue.new()
	stage.add_child(reused)
	reused.hold(stage)
	check(reused.pending.is_empty(),"another owner reuses matching completed preparation")
	var key: String = Shared.geometry_key(nodes[0])
	var context: String = Shared.context(view,stage,stage.camera)
	check(Shared.ready(context,key),"completed program has a shared receipt")
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	check(Shared.context(view,stage,stage.camera) == context,"one-shot scheduling is not a different pipeline context")
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	view.msaa_3d = Viewport.MSAA_2X
	check(not Shared.ready(Shared.context(view,stage,stage.camera),key),"AA changes never reuse the other render context")
	view.msaa_3d = Viewport.MSAA_4X
	var light := DirectionalLight3D.new()
	stage.add_child(light)
	check(not Shared.ready(Shared.context(view,stage,stage.camera),key),"lighting changes never reuse the former context")
	light.free()
	var spot := SpotLight3D.new()
	stage.add_child(spot)
	var local_context: String = Shared.context(view,stage,stage.camera)
	var first_receipt: String = Shared.receipt_key(nodes[0],local_context)
	var second_receipt: String = Shared.receipt_key(nodes[7],local_context)
	check(Shared.spatial_context(local_context) and first_receipt != second_receipt,"local lights require exact mesh and pose receipts")
	Shared.complete(local_context,first_receipt,Shared.generation)
	check(Shared.ready(local_context,first_receipt) and not Shared.ready(local_context,second_receipt),"a local-light receipt cannot certify another mesh position")
	spot.spot_range += 1.0
	check(Shared.context(view,stage,stage.camera) != local_context,"local-light influence changes invalidate the context")
	spot.free()
	var overlay := ShaderMaterial.new()
	overlay.shader = materials[1].shader
	nodes[0].material_overlay = overlay
	check(Shared.geometry_key(nodes[0]) != key,"overlay programs distinguish geometry keys")
	nodes[0].material_overlay = null
	var shader: Shader = materials[0].shader
	var code: String = shader.code
	shader.code += "\n// source changed"
	check(Shared.geometry_key(nodes[0]) != key,"in-place shader edits invalidate the program")
	shader.code = code
	var epoch: int = Shared.generation
	Shared.invalidate("context loss")
	context = Shared.context(view,stage,stage.camera)
	Shared.complete(context,key,epoch)
	check(not Shared.ready(context,key),"an old in-flight draw cannot republish after invalidation")
	for index: int in range(Shared.LIMIT+8): Shared.complete(context,str(index),Shared.generation)
	check(Shared.warmed.size() == Shared.LIMIT,"shared registry is bounded")
	Shared.invalidate()
	reused.hold(stage)
	var calls: Dictionary = {"count":0}
	var cancel: Callable = func() -> bool:
		calls.count += 1
		return await draw()
	check(not await reused.prepare(cancel,func() -> bool: return calls.count == 0),"cancellation after native submission stops publication")
	check(Shared.warmed.is_empty(),"cancelled draws publish no shared receipts")
	reused.free()
	check(nodes.all(func(node: MeshInstance3D) -> bool: return node.visible),"cancelled owner releases all held geometry")
	var ticket: Dictionary = Shared.begin_capture(stage,view,stage.camera)
	await draw()
	Shared.finish_capture(ticket,stage,view,stage.camera)
	check(Shared.ready(Shared.context(view,stage,stage.camera),key),"completed capture seeds the same shared ledger")
	var changed_ticket: Dictionary = Shared.begin_capture(stage,view,stage.camera)
	Shared.invalidate()
	Shared.finish_capture(changed_ticket,stage,view,stage.camera)
	check(Shared.warmed.is_empty(),"obsolete capture cannot seed preparation")
	var output: String = OS.get_environment("BMT_LOADING_OUTPUT")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	view.queue_free()
	for _i: int in range(6): await process_frame
	print("SHARED_GRAPHICS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
