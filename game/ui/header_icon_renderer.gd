extends "res://ui/rivalry_simple_car.gd"
## Header-only small-model renderer. Garage, awards and authored art keep their
## existing studios. Reuse the real fitted geometry and production livery UVs.
const LOD_BIAS: float = 0.35
var deferred_render: bool = false

class IconCar extends CarVisual:
	func _ready() -> void:
		_model_slice_started = Time.get_ticks_usec() if cooperative_build else 0
		scale = Vector3.ONE*HandlingConfig.BODY_SCALE
		if not VehicleCustomisation.valid(customisation,vehicle_id): customisation = VehicleCustomisation.defaults()
		if preload("res://ui/header_simple_cache.gd").restore(self):
			if livery.is_empty(): livery = VehicleLivery.defaults(vehicle_id)
			apply_livery(livery)
			_update_rear_lights()
			graphics.configure(self)
			force_update_transform()
			for node: Node3D in find_children("*","Node3D",true,false): node.force_update_transform()
			model_ready = true
			return
		await super._ready()

func _init() -> void:
	render_scale = 1.0
	cache_rest_pose = false

func _create_car() -> CarVisual:
	return IconCar.new()

func _prepare_materials() -> void:
	super._prepare_materials()
	# Select existing prepared mesh distance levels. Never simplify or read
	# mesh buffers on the runtime capture path, including on Vulkan.
	viewport.mesh_lod_threshold = 1.0
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		part.lod_bias = LOD_BIAS
		part.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

func _refresh() -> void:
	if not is_inside_tree() or camera == null: return
	# Centre small icons once against all of their immutable fitted bounds.
	# Local transforms also work while a caller reparents the preview.
	var origin := Vector3(-5,2.5,6)
	camera.transform = Transform3D(Basis.looking_at(Vector3(0,0.65,0)-origin),origin)
	var points := PackedVector3Array()
	var view: Transform3D = camera.transform.affine_inverse()*car.transform
	var depths := Vector2(INF,-INF)
	for corner: Vector3 in _bounds:
		var point: Vector3 = view*corner
		points.append(point)
		depths.x = minf(depths.x,-point.z)
		depths.y = maxf(depths.y,-point.z)
	var shift := Vector2.ZERO
	for _pass: int in range(4):
		var low := Vector2(INF,INF)
		var high := Vector2(-INF,-INF)
		for point: Vector3 in points:
			var projected: Vector2 = (Vector2(point.x,point.y)-shift)/maxf(0.01,-point.z)
			low = low.min(projected)
			high = high.max(projected)
		if not points.is_empty(): shift += (low+high)*0.5*(depths.x+depths.y)*0.5
	camera.position += camera.basis*Vector3(shift.x,shift.y,0)
	super._refresh()
	if deferred_render: viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

static func make_preview(vehicle: String,paint: Dictionary,parts: Dictionary) -> Control:
	var view: Control = load("res://ui/header_icon_renderer.gd").new()
	view.name = "HeaderIconRender"
	view.vehicle_id = vehicle
	view.livery = paint.duplicate(true)
	view.customisation = parts.duplicate(true)
	return view
