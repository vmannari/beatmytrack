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
	var style := StyleBoxFlat.new()
	style.bg_color = Color("253438")
	style.set_corner_radius_all(7)
	style.set_border_width_all(1)
	style.border_color = Color("536466")
	button.add_theme_stylebox_override("normal",style)
	var selected: StyleBoxFlat = style.duplicate()
	selected.border_color = EditorButton.CYAN
	selected.set_border_width_all(2)
	button.add_theme_stylebox_override("pressed",selected)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(104,64)
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
	if kind in ["tree","broadleaf","light","flag","gantry"]: camera.size=maxf(5.0,camera.size)
	camera.position = Vector3(7,8,10)
	viewport.add_child(camera)
	camera.look_at_from_position(camera.position,Vector3(0,1.5 if kind in ["tree","broadleaf","light","flag","gantry"] else 0.45,0))
	camera.current = true
	var image := TextureRect.new()
	image.texture = viewport.get_texture()
	image.position = Vector2(2,2)
	image.size = Vector2(100,62)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(image)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",14)
	label.position = Vector2(0,65)
	label.size = Vector2(104,20)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	return button
