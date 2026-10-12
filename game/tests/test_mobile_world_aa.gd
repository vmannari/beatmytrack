extends SceneTree
var failures: int = 0
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)
func capture() -> Image:
	for frame: int in range(4): await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	root.size = Vector2i(800,600)
	root.content_scale_size = Vector2i(800,600)
	root.scaling_3d_scale = 1.0
	var world := CanvasLayer.new()
	world.layer = -20
	root.add_child(world)
	var background := ColorRect.new()
	background.color = Color(0.05,0.05,0.05)
	background.size = Vector2(800,600)
	world.add_child(background)
	var triangle := Polygon2D.new()
	triangle.polygon = PackedVector2Array([Vector2(80,80),Vector2(710,150),Vector2(200,470)])
	triangle.color = Color.WHITE
	world.add_child(triangle)
	var hud := CanvasLayer.new()
	hud.layer = 1
	root.add_child(hud)
	var hud_panel := ColorRect.new()
	hud_panel.position = Vector2(620,40)
	hud_panel.size = Vector2(140,45)
	hud_panel.color = Color(0.1,0.2,0.35)
	hud.add_child(hud_panel)
	var label := Label.new()
	label.text = "HUD 12345"
	label.position = Vector2(627,45)
	hud.add_child(label)
	var before: Image = await capture()
	var aa: CanvasLayer = preload("res://track/mobile_world_aa.gd").new()
	root.add_child(aa)
	var after: Image = await capture()
	var changed: int = 0
	var blended_before: int = 0
	var blended_after: int = 0
	for y: int in range(90,480):
		for x: int in range(90,710):
			var a: Color = before.get_pixel(x,y)
			var b: Color = after.get_pixel(x,y)
			if absf(a.r-b.r)>1.0/255.0: changed += 1
			if a.r>0.15 and a.r<0.9: blended_before += 1
			if b.r>0.15 and b.r<0.9: blended_after += 1
	check(changed>500,"diagonal geometry edges receive antialiasing")
	check(blended_after>blended_before+300,"new edge coverage is blended instead of jagged")
	for point: Vector2i in [Vector2i(20,20),Vector2i(100,560),Vector2i(250,200),Vector2i(350,250)]:
		check(before.get_pixelv(point)==after.get_pixelv(point),"flat world colour remains exact at "+str(point))
	var hud_changed: int = 0
	for y: int in range(40,85):
		for x: int in range(620,760):
			if before.get_pixel(x,y)!=after.get_pixel(x,y): hud_changed += 1
	check(hud_changed==0,"native HUD panel and text are unchanged")
	var policy: GDScript = preload("res://track/mobile_world_aa.gd")
	check(policy.required(true,"gl_compatibility","Adreno (TM) 750"),"affected tablet uses safe depth with world AA")
	check(not policy.required(false,"gl_compatibility","NVIDIA RTX"),"desktop antialiasing stays unchanged")
	check(not policy.required(true,"mobile","Adreno (TM) 750"),"other renderer is unchanged")
	print("WORLD_AA_EDGE changed=",changed," blended_before=",blended_before," blended_after=",blended_after," hud_changed=",hud_changed)
	var output: String = ProjectSettings.globalize_path("res://../docs/evidence/dust-parity-2026-10-10/aa")
	DirAccess.make_dir_recursive_absolute(output)
	before.save_png(output.path_join("before.png"))
	after.save_png(output.path_join("after.png"))
	print("MOBILE_WORLD_AA_TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
