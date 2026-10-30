extends SceneTree
const PREPARATION = preload("res://race/world_render_preparation.gd")
var checks: int = 0
var failures: int = 0
class Stage extends Node3D:
	var camera: Camera3D
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func run() -> void:
	root.size = Vector2i(640,360)
	var stage := Stage.new(); root.add_child(stage)
	stage.camera = Camera3D.new(); stage.add_child(stage.camera)
	stage.camera.position = Vector3(0,20,0); stage.camera.rotation.x = -PI/2; stage.camera.projection = Camera3D.PROJECTION_ORTHOGONAL; stage.camera.size = 24
	var sun := DirectionalLight3D.new(); stage.add_child(sun); sun.rotation_degrees = Vector3(-60,-30,0)
	var meshes: Array[MeshInstance3D] = []
	for index: int in range(80):
		var node := MeshInstance3D.new(); node.mesh = BoxMesh.new(); node.position = Vector3(index%10-4.5,0,index/10-3.5)
		var material := StandardMaterial3D.new(); material.albedo_color = Color.from_hsv(float(index)/80,0.7,0.8)
		node.material_override = material; stage.add_child(node); meshes.append(node)
	var key: String = PREPARATION._key(meshes[0])
	for node: MeshInstance3D in meshes: check(PREPARATION._key(node) == key,"color-only material variants share a program")
	meshes[1].layers = 2; check(PREPARATION._key(meshes[1]) != key,"lighting layers remain distinct"); meshes[1].layers = 1
	(meshes[1].material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	check(PREPARATION._key(meshes[1]) != key,"shader flags remain distinct")
	(meshes[1].material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	(meshes[1].material_override as StandardMaterial3D).next_pass = StandardMaterial3D.new()
	check(PREPARATION._key(meshes[1]) != key,"next-pass programs remain distinct")
	(meshes[1].material_override as StandardMaterial3D).next_pass = null
	var before: PackedByteArray
	if DisplayServer.get_name() != "headless":
		for frame: int in range(4): await RenderingServer.frame_post_draw
		before = root.get_texture().get_image().get_data()
	var preparation = PREPARATION.new(); stage.add_child(preparation); PREPARATION.warmed.clear()
	preparation.hold(stage)
	check(meshes.all(func(node: MeshInstance3D) -> bool: return not node.visible),"all pending geometry is held")
	var observed: Dictionary = {"draws":0,"maximum":0}
	var draw: Callable = func() -> bool:
		observed.draws += 1
		var shown: int = 0
		for node: MeshInstance3D in meshes:
			if node.visible: shown += 1
		observed.maximum = maxi(observed.maximum,shown)
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
		else: await process_frame
		return true
	check(await preparation.prepare(draw,func() -> bool: return true),"current preparation completes")
	check(observed.draws == 1 and observed.maximum == 8,"one bounded submission prepares eighty equivalent programs")
	check(meshes.all(func(node: MeshInstance3D) -> bool: return node.visible and is_zero_approx(node.extra_cull_margin)),"all original geometry and cull margins restore")
	if DisplayServer.get_name() != "headless":
		for frame: int in range(4): await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().get_data() == before,"final native pixels remain exact")
	preparation.hold(stage); check(preparation.pending.is_empty(),"already prepared programs remain visible")
	PREPARATION.warmed.clear(); preparation.hold(stage)
	check(not await preparation.prepare(draw,func() -> bool: return false),"obsolete preparation stops")
	preparation.queue_free(); await process_frame
	check(meshes.all(func(node: MeshInstance3D) -> bool: return node.visible),"cancellation teardown releases every held node")
	stage.queue_free(); await process_frame
	print("EDITOR_GRAPHICS_PREPARATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
