extends SceneTree
## CLV03: rasterise the existing licensed flat glyphs, with no generated artwork.
const DIRECTORY: String="res://assets/vehicles/compact_plate_v1"
func _initialize() -> void: bake.call_deferred()

func bake() -> void:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1024,512)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d=Viewport.MSAA_4X
	root.add_child(viewport)
	var world:=Node3D.new()
	viewport.add_child(world)
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color.BLACK
	environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	world.add_child(environment)
	# Build only the exact existing TextMesh resources, without car construction.
	var wrapper:=CarVisual.new()
	wrapper.body=Node3D.new()
	wrapper.add_child(wrapper.body)
	var white:=StandardMaterial3D.new()
	white.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color=Color.WHITE
	CompactRearDesign._text(wrapper,"RearPlateLetters","BMT 01",0.0020,Vector3(0,CompactRearDesign.PLATE_CENTER-0.010,2.129),white)
	CompactRearDesign._text(wrapper,"RearPlateHeader","BEAT MY TRACK",0.00048,Vector3(0,CompactRearDesign.PLATE_CENTER+0.070,2.129),white)
	wrapper.remove_child(wrapper.body)
	world.add_child(wrapper.body)
	wrapper.free()
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=0.206
	camera.position=Vector3(0,CompactRearDesign.PLATE_CENTER,3)
	world.add_child(camera)
	camera.look_at(Vector3(0,CompactRearDesign.PLATE_CENTER,2))
	camera.current=true
	for frame: int in range(12): await process_frame;await RenderingServer.frame_post_draw
	var image: Image=viewport.get_texture().get_image()
	image.resize(512,256,Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_L8)
	var covered: int=0
	for value: int in image.get_data():
		if value>127: covered+=1
	if covered<100 or covered>512*256/2:
		push_error("Plate glyph coverage invalid: "+str(covered));quit(1);return
	image.generate_mipmaps()
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	for entry: Array in [["ink",image]]:
		var texture:=ImageTexture.create_from_image(entry[1])
		var error: Error=ResourceSaver.save(texture,DIRECTORY.path_join(entry[0]+".res"),ResourceSaver.FLAG_COMPRESS)
		if error!=OK: push_error("Plate bake failed "+str(error));quit(1);return
	image.save_png("res://../docs/evidence/car-detail-reduction-2026-11-14/plate-ink.png")
	viewport.queue_free();await process_frame
	print("PLATE_TEXTURE 512x256 L8 with mipmaps; source BarlowCondensed-SemiBold.ttf; exact existing TextMesh placement")
	quit()
