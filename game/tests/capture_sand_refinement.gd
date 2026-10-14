extends SceneTree
## Local review fixture; never writes player documents or changes driving rules.
func _initialize() -> void:
	capture.call_deferred()

func capture() -> void:
	root.size = Vector2i(1600,900)
	var doc: Dictionary = TrackDocument.create_default()
	doc.paint = [{"surface":2,"width":35.0,"shape":"round","points":[[-38.0,-12.0]],"protect_road":true}]
	assert(TrackDocument.validate(doc).is_empty())
	var track: NativeTrack = TrackCompiler.compile(doc)
	var game: Node = load("res://core/game.tscn").instantiate()
	game.set("initial_track",track)
	game.set("production_mode",true)
	root.add_child(game)
	game.set_physics_process(false)
	game.set("paused",true)
	(game.get("race_cues") as Control).hide()
	for frame: int in range(16):
		game.call("_process",0.0)
		await RenderingServer.frame_post_draw
	var folder: String = "res://../docs/evidence/sand-refinement-2026-10-13/"
	var suffix: String = "mobile" if RenderingServer.get_current_rendering_method() == "mobile" else "compatibility"
	var materials: Array[ShaderMaterial] = []
	game.set_process(false)
	var cloud: Node = game.get("cloud_shadow")
	if cloud != null: cloud.set("visible",false)
	for mesh: MeshInstance3D in game.find_children("*","MeshInstance3D",true,false):
		if mesh.material_override is ShaderMaterial:
			var material: ShaderMaterial = mesh.material_override
			if material.shader.code.contains("surface_detail") or material.shader.code.contains("terrain.gdshaderinc") or material.shader.code.contains("creator_road.gdshaderinc"):
				materials.append(material)
	for material: ShaderMaterial in materials: material.set_shader_parameter("sand_relief_enabled",false)
	for frame: int in range(4): await RenderingServer.frame_post_draw
	var baseline: Image = root.get_texture().get_image()
	baseline.save_png(folder+suffix+"-original.png")
	for material: ShaderMaterial in materials: material.set_shader_parameter("sand_relief_enabled",true)
	for frame: int in range(4): await RenderingServer.frame_post_draw
	var improved: Image = root.get_texture().get_image()
	var changed: int = 0
	var delta: float = 0.0
	for y: int in range(220,570):
		for x: int in range(320,500):
			var a: Color = baseline.get_pixel(x,y)
			var b: Color = improved.get_pixel(x,y)
			var difference: float = absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
			delta += difference
			if difference > 0.0: changed += 1
	print("SAND_RELIEF pixels=",changed," mean_channel_delta_255=",delta*255.0/(180.0*350.0*3.0))
	var result: Error = improved.save_png(folder+suffix+".png")
	print("SAND_REVIEW capture=",result," renderer=",suffix)
	game.queue_free()
	await process_frame
	quit(0 if result == OK else 1)
