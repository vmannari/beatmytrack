extends SceneTree

var checks: int = 0
var failures: int = 0
var graphical: bool = false
const FOLDER: String = "res://../docs/evidence/contact-lighting-3/"

func _initialize() -> void:
	graphical = DisplayServer.get_name() != "headless"
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func run() -> void:
	root.size = Vector2i(1440,900)
	var doc: Dictionary = TrackDocument.create_blank()
	var points: Array[Vector2] = [Vector2(-48,0),Vector2(-30,0),Vector2(30,0),Vector2(50,26),Vector2(0,42),Vector2(0,-42),Vector2(-50,-26)]
	for i: int in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i+1)%points.size()]
		var piece: Dictionary = RoadPieces.create("bridge" if i == 1 else "straight",a,fposmod(rad_to_deg((b-a).angle()),360),14)
		piece.length = a.distance_to(b)
		doc.pieces.append(piece)
	for item: Array in [["tree",12,-14],["rock",-12,-14],["boulder",-17,-6],["broadleaf",16,-18]]:
		doc.objects.append({"kind":item[0],"position":[item[1],item[2]],"scale":1.0,"rotation":30.0})
	var route: Dictionary = RoadPieces.route_from_pieces(doc)
	check(route.ok,"fixture connected route")
	if not route.ok:
		quit(1)
		return
	var track: NativeTrack = TrackCompiler.compile(route.document)
	var cells: PackedInt32Array = track.cells.duplicate()
	var game: Node = load("res://core/game.tscn").instantiate()
	game.set("initial_track",track)
	game.set("production_mode",true)
	root.add_child(game)
	game.set_physics_process(false)
	game.set("paused",true)
	game.set("countdown_ticks",0)
	game.get("race_cues").hide()
	var sim: VehicleSimulation = game.get("sim")
	sim.reset(Vector2(0,-9),0)
	game.set("previous_position",sim.state.position)
	var state_before: Array = sim.state.snapshot()
	game.call("_process",0.016)
	game.set_process(false)
	var contact: MeshInstance3D = game.get("contact_shadow")
	var cloud: MeshInstance3D = game.get("cloud_shadow")
	check(cloud != null,"Grass has clouds")
	check(contact.position.y < 0.1,"ground contact stays on lower layer")
	check(contact.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"contact volume never casts a box shadow")
	var bridge_nodes: Array[Node] = game.find_children("BridgeUnderShadow","MeshInstance3D",true,false)
	check(bridge_nodes.size() == track.creator_bridges.size(),"one bounded shade per bridge")
	check(game.find_children("PropContactShadows","MultiMeshInstance3D",true,false).size() > 0,"static contacts batched")
	for id: String in VehicleCatalog.IDS:
		var car: CarVisual = game.get("car")
		car.vehicle_id = id
		ContactShading.present_car(contact,car,sim.state,Vector2.ZERO,0,track,game.get("bridge_presentation"))
		check(contact.scale.x > 1 and contact.scale.z > contact.scale.x,id+" bounded vehicle footprint")
	car_reset(game)
	var test_state := VehicleState.new()
	test_state.track_elevated = true
	ContactShading.present_car(contact,game.get("car"),test_state,Vector2.ZERO,PI*0.5,track,game.get("bridge_presentation"))
	check(is_equal_approx(contact.position.y,CreatorBridges.HEIGHT+0.03),"elevated contact stays on deck")
	ContactShading.present_car(contact,game.get("car"),test_state,Vector2(-26,0),PI*0.5,track,game.get("bridge_presentation"))
	check(contact.rotation.x > 0.1,"contact follows ramp pitch")
	test_state.track_elevated = false
	test_state.jump_height = 2.0
	ContactShading.present_car(contact,game.get("car"),test_state,Vector2.ZERO,0,track,game.get("bridge_presentation"))
	check(contact.position.y < 0.1,"jump contact remains on support")
	check(float((contact.material_override as ShaderMaterial).get_shader_parameter("strength")) < 0.1,"jump contact fades with height")
	game.call("_process",0.016)
	check(state_before == sim.state.snapshot() and cells == track.cells,"presentation preserves canonical state and cells")
	var old_elapsed: float = game.get("cloud_elapsed")
	game.call("_process",1.0)
	check(is_equal_approx(old_elapsed,game.get("cloud_elapsed")),"cloud animation pauses")
	if graphical:
		await capture_views(game,bridge_nodes)
	for theme: String in ["desert","winter","night_city","storm"]:
		track.metadata.theme = theme
		game.call("_update_cloud_shadows")
		check(game.get("cloud_shadow") == null,theme+" allocates no cloud pass")
	track.metadata.theme = "pine"
	game.call("_update_cloud_shadows")
	check(game.get("cloud_shadow") != null,"switching back to Grass restores clouds")
	check(state_before == sim.state.snapshot(),"captures and biome switches preserve canonical state")
	game.queue_free()
	await process_frame
	print("CONTACT_SHADING: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)

func car_reset(game: Node) -> void:
	(game.get("car") as CarVisual).vehicle_id = "compact"

func capture_views(game: Node, bridges: Array[Node]) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	var camera: FollowCamera = game.get("camera")
	# Production camera first. Subsequent inspection view is diagnostic only.
	await shot("gameplay")
	camera.size = 48.0
	camera.position = Vector3(7,37,34)
	camera.look_at(Vector3(0,0,0))
	var cloud: MeshInstance3D = game.get("cloud_shadow")
	cloud.hide()
	for shade: Node3D in bridges: shade.hide()
	var baseline: Image = await shot("bridge-off")
	for shade: Node3D in bridges: shade.show()
	var shaded: Image = await shot("bridge-on")
	check(changed_pixels(baseline,shaded) > 100,"bridge shader visibly shades opaque lower surfaces")
	var deck_pixel: Vector2i = screen_pixel(camera,Vector3(8,CreatorBridges.HEIGHT+0.025,0))
	check(pixel_difference(baseline,shaded,deck_pixel) < 0.02,"bridge shader leaves upper deck unchanged")
	cloud.show()
	var cloudy: Image = await shot("clouds-0s")
	check(changed_pixels(shaded,cloudy) > 1000,"clouds shade world geometry")
	check(visible_shade_pixels(shaded,cloudy) > 1000,"cloud patches darken a visible area by at least ten percent")
	(cloud.material_override as ShaderMaterial).set_shader_parameter("elapsed",8.0)
	var moved: Image = await shot("clouds-8s")
	check(changed_pixels(cloudy,moved) > 1000,"cloud field visibly moves")
	# Test a genuinely opaque CanvasLayer swatch; an empty corner is world,
	# and translucent HUD backgrounds legitimately reveal the moving shade.
	var ui := CanvasLayer.new()
	ui.layer = 100
	root.add_child(ui)
	var swatch := ColorRect.new()
	swatch.position = Vector2(10,10)
	swatch.size = Vector2(24,24)
	swatch.color = Color("f3d85e")
	ui.add_child(swatch)
	for frame: int in range(2): await RenderingServer.frame_post_draw
	var ui_on: Image = root.get_texture().get_image()
	cloud.hide()
	for frame: int in range(2): await RenderingServer.frame_post_draw
	check(pixel_difference(ui_on,root.get_texture().get_image(),Vector2i(20,20)) < 0.001,"opaque HUD untouched by world shadows")
	ui.free()
	cloud.hide()
	for shade: Node3D in bridges: shade.hide()
	var contacts: Array[Node] = game.find_children("*ContactShadow*","",true,false)
	for shade: Node3D in contacts: shade.hide()
	var no_contact: Image = await shot("contacts-off")
	for shade: Node3D in contacts: shade.show()
	var contact: Image = await shot("contacts-on")
	check(changed_pixels(no_contact,contact) > 80,"contact shadows visibly anchor car and scenery")
	check(pixel_difference(no_contact,contact,screen_pixel(camera,Vector3(-12,-0.06,15.05))) > 0.01,"instanced rock contact shades surrounding ground")
	for shade: Node3D in bridges: shade.show()
	cloud.show()
	await shot("overview")
	# Remove only visual deck occlusion to verify that the actual car roof,
	# not just a ground polygon, receives the underpass shade.
	cloud.hide()
	var deck_mesh: Node3D = game.find_child("BridgeAsphalt",true,false)
	var fascia: Node3D = game.find_child("BridgeSteelAndFascia",true,false)
	deck_mesh.hide()
	fascia.hide()
	var car: CarVisual = game.get("car")
	var original_pose: Transform3D = car.transform
	car.position = Vector3.ZERO
	var roof_pixel: Vector2i = screen_pixel(camera,Vector3(0,1.25,0.3))
	for shade: Node3D in bridges: shade.hide()
	var roof_off: Image = await shot("underpass-diagnostic-off")
	for shade: Node3D in bridges: shade.show()
	var roof_on: Image = await shot("underpass-diagnostic-on")
	check(pixel_difference(roof_off,roof_on,roof_pixel) > 0.08,"underpass darkens actual car roof")
	car.position.y = CreatorBridges.HEIGHT
	roof_pixel = screen_pixel(camera,Vector3(0,CreatorBridges.HEIGHT+1.25,0.3))
	var upper_on: Image = await shot("upper-car-diagnostic-on")
	for shade: Node3D in bridges: shade.hide()
	var upper_off: Image = await shot("upper-car-diagnostic-off")
	check(pixel_difference(upper_off,upper_on,roof_pixel) < 0.01,"upper-layer car escapes underpass shade")
	car.transform = original_pose
	deck_mesh.show()
	fascia.show()
	for shade: Node3D in bridges: shade.show()
	cloud.show()

func shot(name: String) -> Image:
	for frame: int in range(3): await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image.save_png(FOLDER+name+".png") == OK,"saved "+name)
	return image

func pixel_difference(a: Image, b: Image, p: Vector2i) -> float:
	var ca: Color = a.get_pixelv(p)
	var cb: Color = b.get_pixelv(p)
	return absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b)

func screen_pixel(camera: Camera3D, point: Vector3) -> Vector2i:
	return Vector2i(camera.unproject_position(point)*Vector2(root.size)/root.get_visible_rect().size)

func changed_pixels(a: Image, b: Image) -> int:
	var count: int = 0
	for y: int in range(0,a.get_height(),3):
		for x: int in range(0,a.get_width(),3):
			if pixel_difference(a,b,Vector2i(x,y)) > 0.015: count += 1
	return count

func visible_shade_pixels(clear: Image, shaded: Image) -> int:
	var count: int = 0
	for y: int in range(180,650,3):
		for x: int in range(180,1200,3):
			var before: float = clear.get_pixel(x,y).get_luminance()
			var after: float = shaded.get_pixel(x,y).get_luminance()
			if before > 0.10 and (before-after)/before > 0.10: count += 1
	return count
