class_name TrackShowroom
extends SubViewportContainer
## Scenic menu/editor view of the exact native geometry and shared theme kit.

var track: NativeTrack
var camera: Camera3D

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800,450)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = TrackTheme.palette(str(track.metadata.get("theme","pine")))[1]
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("bac8ce")
	environment.environment.ambient_light_energy = 0.35
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58,-35,0)
	light.light_color = Color("fff1d8")
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 160
	world.add_child(light)
	var visual := NativeTrackVisual.new()
	world.add_child(visual)
	visual.build(track,BridgePresentation.new(track))
	camera = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = maxf(track.half_extent.y * 2.1, track.half_extent.x * 1.35)
	camera.far = 400
	camera.position = Vector3(0,150,90)
	camera.look_at(Vector3.ZERO,Vector3.UP)
	camera.current = true
	resized.connect(_fit_preview)
	_fit_preview()

func _fit_preview() -> void:
	if camera == null: return
	var aspect: float = maxf(0.25,size.x/maxf(1.0,size.y))
	# Menu-only framing: preserve full circuit width in tall selection cards too.
	camera.size = maxf(track.half_extent.y*2.1,track.half_extent.x*2.1/aspect)
