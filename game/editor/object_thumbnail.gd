class_name ObjectThumbnail
extends Button
## Small one-shot renders use exactly the placed-object mesh builder.
static func make(kind: String, title: String, chosen: bool, action: Callable) -> Button:
	var button := ObjectThumbnail.new()
	button.name = "Asset_"+kind
	button.custom_minimum_size = Vector2(104,88)
	button.tooltip_text = title
	button.toggle_mode = true
	button.button_pressed = chosen
	button.pressed.connect(action)
	EditorStyle.apply(button,chosen)
	for state: String in ["normal","hover","disabled"]:
		var tile: StyleBoxFlat=EditorStyle.box(chosen,state=="hover")
		if not chosen: tile.bg_color=Color("293c40") if state=="hover" else Color("203034")
		tile.border_color=EditorStyle.ACCENT if chosen else Color("34464a")
		button.add_theme_stylebox_override(state,tile)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(208,128)
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.gui_disable_input = true
	button.add_child(viewport)
	var kit := NativeTrackVisual.new()
	viewport.add_child(kit)
	var track := NativeTrack.new()
	var object: Dictionary = {"kind":kind,"position":[0,0],"rotation":0}
	track.metadata = {"creator_document":{"objects":[object]}}
	track.tyre_origins = LooseTyres.positions(track.metadata.creator_document)
	kit._build_placed_objects(track)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c4cec8")
	environment.ambient_light_energy = 0.7
	world_environment.environment = environment
	viewport.add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50,-30,0)
	viewport.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(2.0,CreatorObjects.dimensions(kind).length()*0.85)
	if kind in ["tree","broadleaf","light","flag","gantry","hut","shed"]: camera.size=maxf(6.0,camera.size)
	camera.position = Vector3(7,8,10)
	viewport.add_child(camera)
	camera.look_at_from_position(camera.position,Vector3(0,1.5 if kind in ["tree","broadleaf","light","flag","gantry","hut","shed"] else 0.45,0))
	camera.current = true
	var image := TextureRect.new()
	image.texture = viewport.get_texture()
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.position = Vector2(2,2)
	image.size = Vector2(100,62)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(image)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",14)
	label.add_theme_font_override("font",EditorStyle.FONT)
	label.position = Vector2(0,65)
	label.size = Vector2(104,20)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	return button
