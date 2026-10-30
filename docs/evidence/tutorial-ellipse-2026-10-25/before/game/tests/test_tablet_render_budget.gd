extends SceneTree
## Rendering budget, native HUD/framing and exact dry/wet presentation regression.
const GAME = preload("res://core/game.gd")
const SCENE = preload("res://core/game.tscn")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	for pixels: Vector2i in [Vector2i(3000,2120),Vector2i(3840,2160),Vector2i(2560,1600),Vector2i(2400,1080)]:
		var scale: float = GAME.render_scale_for("pine",0.667,true,pixels)
		check(scale<=0.667 and scale>0.0,"mobile budget only reduces positive world scale")
		check(float(pixels.x)*pixels.y*scale*scale<=GAME.MOBILE_WORLD_PIXEL_BUDGET+0.01,"high resolution stays within the world pixel budget")
		check(is_equal_approx(scale,GAME.render_scale_for("pine",0.667,true,Vector2i(pixels.y,pixels.x))),"orientation does not change area budget")
		check(GAME.render_scale_for("pine",1.0,false,pixels)==1.0,"desktop quality remains independent of the mobile budget")
	check(GAME.render_scale_for("pine",0.667,true,Vector2i(2400,1080))==0.667,"existing phone quality is preserved below budget")
	check(GAME.render_scale_for("night_city",0.667,true,Vector2i(2400,1080))==0.55,"phone night headroom is retained")
	check(GAME.render_scale_for("pine",0.4,true,Vector2i(3000,2120))==0.4,"a lower requested quality is not raised")
	check(GAME.render_scale_for("pine",0.667,true,Vector2i.ZERO)==0.667,"unknown output size retains the existing scale")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(3000,2120)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 30.0/1.15
	viewport.add_child(camera)
	camera.position = Vector3(0,30,20)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var hud := Control.new()
	viewport.add_child(hud)
	hud.position = Vector2(40,40)
	hud.size = Vector2(240,180)
	await process_frame
	var hud_rect: Rect2 = hud.get_global_rect()
	var positions: Array[Vector2] = []
	var world_points: Array[Vector3] = [Vector3.ZERO,Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,0,2),Vector3(0,0,-2)]
	for point: Vector3 in world_points: positions.append(camera.unproject_position(point))
	viewport.scaling_3d_scale = GAME.render_scale_for("pine",0.667,true,viewport.size)
	await process_frame
	check(viewport.size==Vector2i(3000,2120),"output viewport remains native resolution")
	check(hud.get_global_rect()==hud_rect,"HUD size and position do not follow world resolution")
	for index: int in range(world_points.size()):
		check(camera.unproject_position(world_points[index]).is_equal_approx(positions[index]),"whole-scene framing remains exact at lower world resolution")
	viewport.free()
	for wet: bool in [false,true]:
		var track := NativeTrack.read("res://resources/tracks/starter_circuit.json")
		track.cells.fill(3 if wet else 0)
		if wet:
			track.cells[track.cells.size()/2] = 6
		var game: Node = SCENE.instantiate()
		var prior_scale: float = root.scaling_3d_scale
		var prior_msaa: Viewport.MSAA = root.msaa_3d
		game.set("initial_track",track)
		game.set("editor_test",true)
		root.add_child(game)
		game.set_process(false)
		game.set_physics_process(false)
		check(bool(game.get("_presentation_has_water"))==wet,"built race classifies its actual surface raster")
		var points: Array[Vector2] = [track.spawn,Vector2.ZERO,track.half_extent,-track.half_extent,track.half_extent+Vector2(2,2)]
		for point: Vector2 in track.route: points.append(point)
		for point: Vector2 in points:
			check(float(game.call("_presentation_water_depth",point))==track.water_depth(point),"cached presentation depth equals original footprint including shore and bounds")
		if not wet:
			for method: String in ["original","cached"]:
				var began: int = Time.get_ticks_usec()
				for index: int in range(500):
					var point: Vector2 = points[index%points.size()]
					if method=="original": track.water_depth(point)
					else: game.call("_presentation_water_depth",point)
				print("DRY_WATER_LOOKUP_US ",method," mean=",float(Time.get_ticks_usec()-began)/500.0)
		root.msaa_3d = Viewport.MSAA_4X if prior_msaa!=Viewport.MSAA_4X else Viewport.MSAA_DISABLED
		game.free()
		check(root.msaa_3d==prior_msaa,"leaving a race restores its entry anti-aliasing setting")
		check(root.scaling_3d_scale==prior_scale,"leaving a race restores the previous viewport quality")
		await process_frame
	print("TABLET_RENDER_BUDGET_TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
