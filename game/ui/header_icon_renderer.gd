extends "res://ui/rivalry_simple_car.gd"
## Header-only small-model renderer. Garage, awards and authored art keep their
## existing studios. Reuse the real fitted geometry and production livery UVs.
const LOD_BIAS: float = 0.25
const DRIVER_CLOTH: Shader = preload("res://vehicle/kart_driver_cloth.gdshader")
static var _cloth_picture: Shader
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

func _material(source: Material) -> ShaderMaterial:
	if source is ShaderMaterial and source.shader == DRIVER_CLOTH:
		# Retain the live garment's complete panels, seams, zip, vertex colours
		# and weave. Only replace lighting for the image's fixed, unlit studio.
		var finish: ShaderMaterial = source.duplicate()
		finish.shader = cloth_picture_shader()
		return finish
	return super._material(source)

static func cloth_picture_shader() -> Shader:
	if _cloth_picture == null:
		var code: String = DRIVER_CLOTH.code
		code = code.replace("render_mode diffuse_burley, specular_schlick_ggx;","render_mode unshaded;")
		code = code.replace("varying vec3 garment_position;","varying vec3 garment_position;\nvarying vec3 picture_world_normal;")
		code = code.replace("garment_position = VERTEX;","garment_position = VERTEX;\n\tpicture_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);")
		var lighting: String = "vec3 n = normalize(picture_world_normal);\n\tfloat key = max(dot(n, normalize(vec3(-0.65, 0.85, 0.55))), 0.0);\n\tfloat fill = max(dot(n, normalize(vec3(0.8, 0.3, -0.5))), 0.0);\n\tpigment *= vec3(0.43, 0.48, 0.53) + vec3(0.62, 0.59, 0.53) * key + vec3(0.16, 0.19, 0.23) * fill;\n\t"
		code = code.replace("ALBEDO = OUTPUT_IS_SRGB",lighting+"ALBEDO = OUTPUT_IS_SRGB")
		_cloth_picture = Shader.new()
		_cloth_picture.code = code
	return _cloth_picture

func _prepare_materials() -> void:
	super._prepare_materials()
	# Select existing prepared mesh distance levels. Never simplify or read
	# mesh buffers on the runtime capture path, including on Vulkan.
	viewport.mesh_lod_threshold = 1.0
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		part.lod_bias = 0.35 if vehicle_id=="super_rally" else LOD_BIAS
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
