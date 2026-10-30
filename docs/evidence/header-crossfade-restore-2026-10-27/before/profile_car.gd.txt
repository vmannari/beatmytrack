extends Control
## A lightweight selected-car picture; the studio factory is for Garage/baking.
var records: LocalRecords
var preview: TextureRect
var vehicle_id: String = ""
const CHANGE_SECONDS: float = 0.24
var _outgoing: TextureRect
var _change: Tween

class ProfilePreview extends "res://ui/rivalry_victory_car.gd":
	func _fit_camera() -> void:
		var camera: Camera3D = viewport.get_camera_3d()
		if camera == null: return
		# Center the visible model rather than the podium's fixed world target.
		# Translate in the camera plane to retain the Rivalry viewing angle.
		var points := PackedVector3Array()
		var view: Transform3D = camera.global_transform.affine_inverse()
		var depth_range := Vector2(INF,-INF)
		for mesh: Node in car.find_children("*","MeshInstance3D",true,false):
			if not mesh.is_visible_in_tree() or mesh.mesh == null: continue
			var bounds: AABB = mesh.get_aabb()
			for x: float in [bounds.position.x,bounds.end.x]:
				for y: float in [bounds.position.y,bounds.end.y]:
					for z: float in [bounds.position.z,bounds.end.z]:
						var point: Vector3 = view*mesh.to_global(Vector3(x,y,z))
						points.append(point)
						depth_range.x = minf(depth_range.x,-point.z)
						depth_range.y = maxf(depth_range.y,-point.z)
		if points.is_empty(): return
		var shift := Vector2.ZERO
		for _pass: int in range(4):
			var low := Vector2(INF,INF)
			var high := Vector2(-INF,-INF)
			for point: Vector3 in points:
				var projected: Vector2 = (Vector2(point.x,point.y)-shift)/maxf(0.01,-point.z)
				low = low.min(projected)
				high = high.max(projected)
			shift += (low+high)*0.5*(depth_range.x+depth_range.y)*0.5
		camera.position += camera.basis*Vector3(shift.x,shift.y,0)
		super._fit_camera()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	visibility_changed.connect(_visibility_changed)
	resized.connect(_settle)
	refresh()

func refresh() -> void:
	if not is_inside_tree(): return
	var vehicle: String = VehicleCatalog.selected
	if preview == null:
		preview = _picture()
		preview.name = "ProfileCarPicture"
		add_child(preview)
		MenuStyle.fill(preview)
	if vehicle_id == vehicle and preview.texture == preload("res://ui/header_car_icons.gd").texture(vehicle,records): return
	vehicle_id = vehicle
	if preview.texture == null or not is_visible_in_tree():
		_settle()
	elif _change == null:
		_change_picture()
	# Coalesce rapid selections until the current blend completes. Only the
	# latest requested car follows it, keeping two pictures in the same fixed slot.

func _picture() -> TextureRect:
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture

func _change_picture() -> void:
	var target: Texture2D = preload("res://ui/header_car_icons.gd").texture(vehicle_id,records)
	if preview.texture == target: return
	_outgoing = _picture()
	_outgoing.name = "PreviousProfileCarPicture"
	_outgoing.texture = preview.texture
	add_child(_outgoing)
	move_child(_outgoing,0)
	MenuStyle.fill(_outgoing)
	preview.texture = target
	preview.modulate.a = 0.0
	MenuStyle.fill(preview)
	_change = create_tween().set_parallel(true)
	_change.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_change.tween_property(_outgoing,"modulate:a",0.0,CHANGE_SECONDS)
	_change.tween_property(preview,"modulate:a",1.0,CHANGE_SECONDS)
	_change.finished.connect(_change_finished)

func _clear_outgoing() -> void:
	if is_instance_valid(_outgoing):
		remove_child(_outgoing)
		_outgoing.queue_free()
	_outgoing = null

func _change_finished() -> void:
	_change = null
	_clear_outgoing()
	preview.modulate = Color.WHITE
	MenuStyle.fill(preview)
	if is_visible_in_tree(): _change_picture()
	else: _settle()

func _settle() -> void:
	if _change != null: _change.kill()
	_change = null
	_clear_outgoing()
	if not is_instance_valid(preview): return
	preview.modulate = Color.WHITE
	# Reset every offset. Moving an anchored picture back to zero can preserve
	# a size from its previous parent while this retained widget is reattached.
	MenuStyle.fill(preview)
	if not vehicle_id.is_empty(): preview.texture = preload("res://ui/header_car_icons.gd").texture(vehicle_id,records)

func _visibility_changed() -> void:
	if not is_visible_in_tree(): _settle()

func _exit_tree() -> void:
	_settle()

static func make_preview(vehicle: String, paint: Dictionary, parts: Dictionary) -> Control:
	var result := ProfilePreview.new()
	result.name = "ProfileCarRender"
	result.vehicle_id = vehicle
	result.livery = paint.duplicate(true)
	result.customisation = parts.duplicate(true)
	result.simple_model = true
	result.podium_presentation = true
	result.fit_to_frame = true
	return result

static func apply_presentation(view: Control) -> void:
	var environment: WorldEnvironment = view.viewport.find_child("PodiumReflectionEnvironment",true,false)
	environment.environment.ambient_light_energy = 0.7
	var fill := DirectionalLight3D.new()
	fill.name = "ProfileReadabilityFill"
	fill.light_energy = 0.65
	fill.rotation = view.viewport.get_camera_3d().rotation
	view.car.get_parent().add_child(fill)
	view._refresh()

static func repaint_preview(view: Control, paint: Dictionary) -> void:
	# Icon batches retain geometry, camera, lights and radiance. Only paint changes.
	view.livery = paint.duplicate(true)
	view.car.apply_livery(paint)
	if view.car.vehicle_id!="compact":
		preload("res://ui/rivalry_podium_studio.gd")._garage_paint(view.car)
