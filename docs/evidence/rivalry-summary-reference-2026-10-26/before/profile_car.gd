extends Control
## The selected car in the Rivalry podium's static studio presentation.
var records: LocalRecords
var preview: Control
var _appearance: Dictionary = {}

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
	if records != null: records.appearance_committed.connect(refresh)
	refresh()

func refresh() -> void:
	if not is_inside_tree(): return
	var vehicle: String = VehicleCatalog.selected
	var settings: Dictionary = records.settings if records != null else {}
	var appearance: Dictionary = {
		"vehicle_id":vehicle,
		"livery":VehicleLivery.for_car(settings,vehicle),
		"customisation":VehicleCustomisation.for_car(settings,vehicle),
	}
	if appearance == _appearance: return
	_appearance = appearance.duplicate(true)
	if is_instance_valid(preview):
		remove_child(preview)
		preview.queue_free()
	preview = make_preview(vehicle,appearance.livery,appearance.customisation)
	add_child(preview)
	MenuStyle.fill(preview)
	apply_presentation(preview)

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
