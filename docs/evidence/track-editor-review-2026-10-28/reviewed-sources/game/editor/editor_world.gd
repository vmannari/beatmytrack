class_name EditorWorld
extends SubViewportContainer
## Shared race geometry under the editor's touch canvas. The orthographic
## planning camera preserves the canvas's exact metre-to-pixel mapping.

var track: NativeTrack
var theme_id: String = "pine"
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
const VISUAL_CACHE_BUDGET: int = 32 * 1024 * 1024
var visual_cache_bytes: int = 0
var preparing_materials: bool = false
var materials_warmed: int = 0
var preparation_metrics: Dictionary = {}
var _initial_preparation_done: bool = false
var _applied_theme: String = ""
var _prop_job: RefCounted
var _prop_request: Dictionary = {}
var _prop_generation: int = 0
var _object_generation: int = 0
var _detail = preload("res://editor/editor_detail.gd").new()

func trim_cache() -> void:
	for entry: Dictionary in _visual_cache: entry.visual.queue_free()
	_visual_cache.clear(); visual_cache_bytes = 0

func trim_prop_cache() -> void:
	if visual == null: return
	for node: Node in visual.find_children("*","Node3D",true,false)+[visual]:
		if node is NativeTrackVisual and node._editor_authored_batches != null:
			var batches: RefCounted = node._editor_authored_batches
			batches.models.clear(); batches.model_bytes = 0
			batches.shared_vertices.clear(); batches.shared_vertex_bytes = 0

func prop_cache_bytes() -> int:
	if visual == null: return 0
	var bytes: int = 0
	for node: Node in visual.find_children("*","Node3D",true,false)+[visual]:
		if node is NativeTrackVisual and node._editor_authored_batches != null:
			bytes += node._editor_authored_batches.model_bytes+node._editor_authored_batches.shared_vertex_bytes
	return bytes

func memory_snapshot() -> Dictionary:
	var estimate = preload("res://editor/cache_bytes.gd")
	var seen: Dictionary = {}
	var excluded: Dictionary = {}
	var stages: Array[Node] = []
	if visual != null:
		for child: Node in visual.find_children("*","Node3D",true,false):
			if child.get_meta("editor_transient",false): stages.append(child); excluded[child.get_instance_id()] = true
	var active: int = estimate.scene(visual,seen,excluded) if visual != null else 0
	var transient: int = 0
	for child: Node in world.get_children():
		if child is NativeTrackVisual and child != visual: stages.append(child)
	for stage: Node in stages: transient += estimate.scene(stage,seen)
	var idle: int = 0
	for entry: Dictionary in _visual_cache: idle += estimate.scene(entry.visual,seen)
	return {"active_unique_scene_bytes":active,"transient_unique_scene_bytes":transient,"idle_unique_scene_bytes":idle,"unique_scene_bytes":active+transient+idle,"resources":seen.size()}

func _exit_tree() -> void:
	_prop_generation += 1
	_prop_request.clear()
	if _prop_job != null: _prop_job.cancel()
	_prop_job = null
	for entry: Dictionary in _visual_cache: entry.visual.free()
	_visual_cache.clear(); visual_cache_bytes = 0


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
	ground_material = VisualGeometry.material(TrackTheme.palette(theme_id)[1])
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
	_apply_theme(str(track.metadata.get("theme", theme_id)) if track != null else theme_id)
	resized.connect(_sync_camera)
	if track != null:
		_build_track()
	_sync_camera()


func follow_canvas(target: EditorCanvas) -> void:
	NativeTrackVisual.reserve_editor_sections()
	canvas = target
	_last_scale = -1.0
	_sync_camera()
	_prepare_editing()

func _prepare_editing() -> void:
	# Prepare the actual track once. A synthetic road/bridge fixture previously
	# duplicated compilation, terrain, uploads and cold shader draws at entry.
	if is_instance_valid(canvas): canvas.preparing = true
	warm_prop(canvas.stamp_kind,canvas.stamp_scale,canvas.stamp_container_color)
	if track != null: _build_track()


func warm_prop(kind: String, scale_value: float = 1.0, color: String = "", length: float = -1.0) -> void:
	_prop_generation += 1
	_prop_request = {"kind":kind,"scale":scale_value,"color":color,"length":length,"generation":_prop_generation,"theme":theme_id}
	if _prop_job == null: _warm_selected_prop.call_deferred()

func _warm_selected_prop() -> void:
	if not is_inside_tree() or _prop_request.is_empty() or _prop_job != null: return
	var request: Dictionary = _prop_request; _prop_request = {}
	var length: float = float(request.length)/float(request.scale) if float(request.length) >= 0.0 else -1.0
	if CreatorPropVisual.warmed(str(request.kind),str(request.theme),length,str(request.color)): return
	_prop_job = preload("res://editor/work_job.gd").start(CreatorPropVisual.warm.bind(str(request.kind),str(request.theme),length,str(request.color)),get_tree())
	var job: RefCounted = _prop_job
	while not job.done:
		await get_tree().process_frame
		if not is_inside_tree() or _prop_job != job: job.cancel(); return
	if not is_inside_tree() or _prop_job != job: return
	# Publish only the selected request, on the owning scene thread and away
	# from active manipulation. Superseded CPU results need no GPU cleanup.
	while is_instance_valid(canvas) and canvas.active_pointer != -99 and int(request.generation) == _prop_generation:
		await get_tree().process_frame
		if not is_inside_tree() or _prop_job != job: return
	if int(request.generation) == _prop_generation and str(request.theme) == theme_id and job.result is Dictionary:
		CreatorPropVisual.publish_warm(job.result)
	_prop_job = null
	if not _prop_request.is_empty(): _warm_selected_prop.call_deferred()


func show_track(data: NativeTrack) -> void:
	_object_generation += 1
	var reuse: bool = not _building and visual != null and _visual_track != null and _same_ground(_visual_track,data)
	track = data
	if is_node_ready() and not _building:
		if reuse:
			track.editor_roads = {}
			visual.refresh_editor_road_masks(track)
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
	var fixed: Array = document.get("objects",[]).filter(func(object: Dictionary) -> bool: return object.kind not in ["tyre_stack","tyre_wall"])
	var previous: Array = track.metadata.get("creator_document",{}).get("objects",[]).filter(func(object: Dictionary) -> bool: return object.kind not in ["tyre_stack","tyre_wall"])
	var immediate: bool = fixed == previous
	_object_generation += 1
	var generation: int = _object_generation
	# Input records the edit immediately. Even an immediate tap after choosing
	# a cold prop cannot synchronously build its first mesh in that handler.
	if not immediate:
		await get_tree().process_frame
		if not is_inside_tree() or generation != _object_generation: return
		while _prop_job != null:
			await get_tree().process_frame
			if not is_inside_tree() or generation != _object_generation: return
	# Render the new props immediately; collision/scenery compilation follows.
	var props := NativeTrack.new()
	props.metadata = {"creator_document":document,"scenery_objects":track.metadata.get("scenery_objects",[])}
	props.tyre_origins = LooseTyres.positions(document)
	await visual.refresh_editor_objects(props,false,not immediate)
	if not is_inside_tree(): return
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _same_ground(before: NativeTrack, after: NativeTrack) -> bool:
	if not before.editor_ground_key.is_empty() and not after.editor_ground_key.is_empty():
		return before.editor_ground_key == after.editor_ground_key
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
	if visual != null and target == _visual_track:
		target.editor_roads = {}
		if is_instance_valid(canvas): canvas.preparing = false
		_mark_presented()
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		return
	if visual != null and visual.can_refresh_editor_geometry(_visual_track,target):
		_building = true
		var owner: WeakRef = weakref(self)
		visual.build_current = func() -> bool: return owner.get_ref() != null and owner.get_ref().track == target
		var updated: bool = await visual.refresh_editor_geometry(target,_visual_track,func() -> bool: return is_instance_valid(canvas) and canvas.active_pointer != -99)
		if not is_inside_tree(): return
		_building = false
		visual.build_current = Callable()
		if track != target: _build_track(); return
		if updated:
			_visual_track = target
			_mark_presented()
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			return
	var candidate: NativeTrackVisual
	for index: int in range(_visual_cache.size()-1,-1,-1):
		var entry: Dictionary = _visual_cache[index]
		if entry.track.content_hash == target.content_hash:
			candidate = entry.visual
			visual_cache_bytes -= int(entry.bytes)
			_visual_cache.remove_at(index)
			break
	if candidate == null:
		trim_cache()
		candidate = NativeTrackVisual.new()
		candidate.editor_preview = true
		# Active road nodes already own their meshes. Do not duplicate that
		# ownership in the race GPU LRU and evict reusable CPU piece work.
		candidate.cache_road_meshes = false
		candidate.profile_build = true
		candidate.visible = false
		var owner: WeakRef = weakref(self)
		candidate.build_current = func() -> bool: return owner.get_ref() != null and owner.get_ref().track == target
		world.add_child(candidate)
		_building = true
		# Keep the existing scene while the replacement is built in short slices.
		var job = preload("res://editor/work_job.gd").start(preload("res://editor/preview_ground.gd").bridge.bind(target),get_tree())
		while not job.done:
			await get_tree().process_frame
			if not is_inside_tree(): job.cancel(); return
			if track != target: job.cancel()
		if track == target:
			var bridge: BridgePresentation = job.result
			if bridge == null: bridge = BridgePresentation.new(target)
			if visual != null and bridge.visual_relief != null:
				bridge.visual_relief.reuse_from(visual,visual.desert_relief)
			if visual != null:
				for child: Node in visual.find_children("*","MeshInstance3D",true,false):
					if child.mesh != null and child.mesh.has_meta("editor_section_key"): candidate.reusable_road_meshes[child.mesh.get_meta("editor_section_key")] = child.mesh
			await candidate.build(target,bridge,true)
			candidate.reusable_road_meshes.clear()
			if not _initial_preparation_done and track == target:
				preparing_materials = true
				var draw_started: int = Time.get_ticks_usec()
				materials_warmed += await preload("res://editor/material_preparation.gd").draw(self,viewport,candidate) if DisplayServer.get_name() != "headless" else 0
				if not is_inside_tree(): return
				preparation_metrics["pipeline_draw_ms"] = (Time.get_ticks_usec()-draw_started)/1000.0
				preparing_materials = false
				if DisplayServer.get_name() != "headless" and track == target:
					# Submit the actual editor view too: fog, sky, shadows, vertex
					# formats and MSAA must match before the first input is accepted.
					candidate.show(); viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
					for frame: int in range(2):
						await RenderingServer.frame_post_draw
						if not is_inside_tree(): return
					candidate.hide(); viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
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
		target.editor_roads = {}
		world.add_child(candidate)
		candidate.refresh_editor_objects(target)
	if visual != null:
		world.remove_child(visual)
		var bytes: int = preload("res://editor/cache_bytes.gd").scene(visual)+var_to_bytes(preload("res://editor/prepared_track_cache.gd").fields(_visual_track)).size()
		_visual_cache.append({"track":_visual_track,"visual":visual,"bytes":bytes}); visual_cache_bytes += bytes
		while not _visual_cache.is_empty() and (_visual_cache.size() > 2 or visual_cache_bytes > VISUAL_CACHE_BUDGET):
			var expired: Dictionary = _visual_cache.pop_front()
			visual_cache_bytes -= int(expired.bytes)
			expired.visual.queue_free()
	candidate.build_current = Callable()
	preparation_metrics["build"] = candidate.build_costs.duplicate(true)
	visual = candidate
	visual.visible = true
	_visual_track = target
	_initial_preparation_done = true
	if is_instance_valid(canvas): canvas.preparing = false
	_apply_theme(str(target.metadata.get("theme", "pine")))
	_mark_presented()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _apply_theme(theme: String) -> void:
	var normalized: String = TrackTheme.normalized(theme)
	if _applied_theme == normalized: return
	theme_id = normalized; _applied_theme = normalized
	var palette: Array[Color] = TrackTheme.palette(theme_id)
	TrackTheme.apply_lighting(theme_id,environment,sunlight)
	environment.background_color = palette[1]
	ground_material.albedo_color = palette[1]

func _mark_presented() -> void:
	if is_instance_valid(canvas):
		canvas.visual_preview = _visual_track
		canvas.queue_redraw()


func _process(_delta: float) -> void:
	if is_instance_valid(canvas):
		var moving: bool = canvas.size != _last_size or canvas.pan != _last_pan or canvas.scale_factor() != _last_scale
		if moving:
			_sync_camera()
		if not _building and _detail.update(visual,_visual_track,canvas,sunlight,moving): viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


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
