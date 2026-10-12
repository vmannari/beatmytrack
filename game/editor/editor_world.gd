class_name EditorWorld
extends SubViewportContainer
## Shared race geometry under the editor's touch canvas. The orthographic
## planning camera preserves the canvas's exact metre-to-pixel mapping.

var track: NativeTrack
var camera: Camera3D
var canvas: EditorCanvas
var viewport: SubViewport
var world: Node3D
var visual: NativeTrackVisual
var sunlight: DirectionalLight3D
var environment: Environment
var ground: MeshInstance3D
var ground_material: StandardMaterial3D
var _last_size := Vector2.ZERO
var _last_pan := Vector2.INF
var _last_scale: float = -1.0
var _building: bool = false
var _visual_track: NativeTrack
var _visual_cache: Array[Dictionary] = []

func _exit_tree() -> void:
	for entry: Dictionary in _visual_cache: entry.visual.free()
	_visual_cache.clear()


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	var ambient := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("bac8ce")
	environment.ambient_light_energy = 0.35
	ambient.environment = environment
	world.add_child(ambient)
	sunlight = DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-58, -35, 0)
	sunlight.light_color = Color("fff1d8")
	sunlight.light_energy = 1.0
	sunlight.shadow_enabled = true
	sunlight.shadow_bias=0.15
	sunlight.shadow_normal_bias=2.0
	sunlight.directional_shadow_max_distance = 400.0
	world.add_child(sunlight)
	# Continue natural ground beyond the native map, including while panning.
	# This presentation-only sheet never contributes to collision or surfaces.
	ground = MeshInstance3D.new()
	var ground_plane := PlaneMesh.new()
	ground_plane.size = Vector2(4096, 4096)
	ground.mesh = ground_plane
	ground_material = VisualGeometry.material(TrackTheme.PINE[1])
	ground.material_override = ground_material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.position.y = -0.21
	world.add_child(ground)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.1
	camera.far = 500.0
	camera.position = Vector3(0, 200, 0)
	camera.rotation = Vector3(-deg_to_rad(EditorCanvas.PLANNING_PITCH), 0, 0)
	world.add_child(camera)
	camera.current = true
	resized.connect(_sync_camera)
	if track != null:
		_build_track()
	_sync_camera()


func follow_canvas(target: EditorCanvas) -> void:
	canvas = target
	_last_scale = -1.0
	_sync_camera()


func show_track(data: NativeTrack) -> void:
	var reuse: bool = not _building and visual != null and _visual_track != null and _same_ground(_visual_track,data)
	track = data
	if is_node_ready() and not _building:
		if reuse:
			if _visual_track.metadata.get("creator_document",{}).get("objects",[]) != track.metadata.get("creator_document",{}).get("objects",[]) or _visual_track.metadata.get("scenery_objects",[]) != track.metadata.get("scenery_objects",[]):
				var target: NativeTrack = track
				_building = true
				await visual.refresh_editor_objects(target,true,true)
				if not is_inside_tree(): return
				_building = false
				_visual_track = target
				if track != target:
					show_track(track)
					return
			else: _visual_track = track
			_mark_presented()
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		else:
			_build_track()


func preview_objects(document: Dictionary) -> void:
	if visual == null or track == null: return
	# Render the new props immediately; collision/scenery compilation follows.
	var props := NativeTrack.new()
	props.metadata = {"creator_document":document,"scenery_objects":track.metadata.get("scenery_objects",[])}
	props.tyre_origins = LooseTyres.positions(document)
	visual.refresh_editor_objects(props,false)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _same_ground(before: NativeTrack, after: NativeTrack) -> bool:
	if before.half_extent != after.half_extent or before.cell_size != after.cell_size: return false
	if before.deck_cells != after.deck_cells: return false
	var old_document: Dictionary = before.metadata.get("creator_document",{}).duplicate(true)
	var new_document: Dictionary = after.metadata.get("creator_document",{}).duplicate(true)
	if old_document.is_empty() or new_document.is_empty(): return false
	# Loose tyres do not stamp surfaces. Their only grid effect is suppressing
	# generated trees on clear grass; those footprints already render as grass.
	# Keep all terrain/solid props in the comparison so they rebuild correctly.
	for document: Dictionary in [old_document,new_document]:
		for key: String in ["id","name","creator"]: document.erase(key)
		var fixed_objects: Array = []
		for object: Dictionary in document.objects:
			if object.kind not in ["tyre_stack","tyre_wall"]: fixed_objects.append(object)
		document.objects = fixed_objects
	return old_document == new_document


func _build_track() -> void:
	if track == null or _building: return
	var target: NativeTrack = track
	var candidate: NativeTrackVisual
	for index: int in range(_visual_cache.size()-1,-1,-1):
		var entry: Dictionary = _visual_cache[index]
		if entry.track.content_hash == target.content_hash:
			candidate = entry.visual
			_visual_cache.remove_at(index)
			break
	if candidate == null:
		candidate = NativeTrackVisual.new()
		candidate.editor_preview = true
		candidate.visible = false
		world.add_child(candidate)
		_building = true
		# Keep the existing scene while the replacement is built in short slices.
		await candidate.build(target,BridgePresentation.new(target),true)
		if not is_inside_tree(): return
		while is_instance_valid(canvas) and canvas.active_pointer != -99:
			await get_tree().process_frame
			if not is_inside_tree(): return
		_building = false
		if track != target:
			world.remove_child(candidate)
			candidate.queue_free()
			_build_track()
			return
	else:
		world.add_child(candidate)
		candidate.refresh_editor_objects(target)
	if visual != null:
		world.remove_child(visual)
		_visual_cache.append({"track":_visual_track,"visual":visual})
		if _visual_cache.size() > 2:
			var expired: Dictionary = _visual_cache.pop_front()
			expired.visual.queue_free()
	visual = candidate
	visual.visible = true
	_visual_track = target
	var palette: Array[Color] = TrackTheme.palette(str(target.metadata.get("theme", "pine")))
	TrackTheme.apply_lighting(str(target.metadata.get("theme", "pine")),environment,sunlight)
	environment.background_color = palette[1]
	ground_material.albedo_color = palette[1]
	_mark_presented()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _mark_presented() -> void:
	if is_instance_valid(canvas):
		canvas.visual_preview = _visual_track
		canvas.queue_redraw()


func _process(_delta: float) -> void:
	if is_instance_valid(canvas):
		if canvas.size != _last_size or canvas.pan != _last_pan or canvas.scale_factor() != _last_scale:
			_sync_camera()


func _sync_camera() -> void:
	if camera == null or not is_instance_valid(canvas) or canvas.size.y < 1.0:
		return
	_last_size = canvas.size
	_last_pan = canvas.pan
	_last_scale = canvas.scale_factor()
	# Native ground projection matches the canvas; a restrained planning tilt
	# exposes object volume while retaining accurate ground placement.
	var center: Vector2 = canvas.to_world(canvas.size * 0.5)
	camera.position = Vector3(center.x, 200.0, -center.y+200.0/tan(deg_to_rad(EditorCanvas.PLANNING_PITCH)))
	camera.size = canvas.size.y / _last_scale
	ground.position = Vector3(center.x, -0.21, -center.y)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
