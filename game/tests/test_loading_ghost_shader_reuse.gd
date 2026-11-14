extends SceneTree
## Exact original shader/pixels, private materials and stable native identities.
const Rewind = preload("res://vehicle/rewind_ghosts.gd")
const Graphics = preload("res://rendering/graphics_preparation.gd")
var checks: int = 0
var failures: int = 0

class FixtureCar extends CarVisual:
	func _ready() -> void: pass

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("GHOST_REUSE_FAIL ",label)

func draw() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func run() -> void:
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/loading_ghost_shaders_before.json"))
	var car := FixtureCar.new()
	root.add_child(car)
	var source := MeshInstance3D.new()
	source.mesh = BoxMesh.new()
	car.add_child(source)
	var first := PersonalGhost.new()
	first.configure(car,false)
	var shader: Shader = first.material_override.shader
	check(shader.code == original.personal,"personal shader source remains byte-exact")
	var first_key: String
	first.mesh = source.mesh
	first_key = Graphics.geometry_key(first)
	var second := PersonalGhost.new()
	second.configure(car,false)
	second.mesh = source.mesh
	check(first.material_override != second.material_override,"personal materials stay independent")
	check(shader == second.material_override.shader,"personal owners share one native shader")
	first.material_override.render_priority = 3
	check(second.material_override.render_priority == 0,"material mutation cannot leak to another owner")
	first.free()
	second.free()
	var third := PersonalGhost.new()
	third.configure(car,false)
	third.mesh = source.mesh
	check(third.material_override.shader == shader,"personal shader survives releasing every previous owner")
	check(Graphics.geometry_key(third) == first_key,"same render geometry keeps its completed-draw key")
	third.free()
	var previous: Shader
	for cycle: int in range(3):
		var marker: Node3D = Rewind.new()
		root.add_child(marker)
		var track := NativeTrack.new()
		var history: Array[Dictionary] = []
		marker.configure(car,track,BridgePresentation.new(track),history,0)
		check(marker.ghosts.size() == 4,"four original rewind markers")
		var actual: Shader = marker.ghosts[0].material_override.shader
		check(actual.code == original.rewind,"rewind shader source remains byte-exact")
		if previous != null: check(actual == previous,"rewind native program survives prior owner destruction")
		previous = actual
		marker.free()
	car.free()
	if DisplayServer.get_name() != "headless":
		var view := SubViewport.new()
		view.size = Vector2i(320,240)
		view.own_world_3d = true
		view.transparent_bg = false
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var camera := Camera3D.new()
		camera.position = Vector3(2,1.5,3)
		view.add_child(camera)
		camera.look_at(Vector3.ZERO)
		camera.current = true
		var model := MeshInstance3D.new()
		model.mesh = BoxMesh.new()
		view.add_child(model)
		for kind: String in ["personal","rewind"]:
			var before_shader := Shader.new()
			before_shader.code = original[kind]
			var material := ShaderMaterial.new()
			material.shader = before_shader
			model.material_override = material
			await draw(); await draw(); await draw()
			var before: Image = view.get_texture().get_image()
			material.shader = PersonalGhost.finish_shader() if kind == "personal" else Rewind.finish_shader()
			await draw(); await draw(); await draw()
			var after: Image = view.get_texture().get_image()
			check(before.get_data() == after.get_data(),kind+" native original/candidate pixels exact")
			var output: String = OS.get_environment("BMT_GRAPHICS_OUTPUT")
			check(before.save_png(output.path_join(kind+"-before.png")) == OK,"save original")
			check(after.save_png(output.path_join(kind+"-after.png")) == OK,"save candidate")
		view.free()
	for frame: int in range(5): await process_frame
	print("GHOST_REUSE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
