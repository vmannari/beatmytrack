extends MeshInstance3D
## Original full draw or conservative spatial draws; every triangle remains stored.
@export_storage var draw_layers: int = 1
@export_storage var draw_shadow: int = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
var _parts: Array[MeshInstance3D] = []
var _bounds: Array[AABB] = []
var _triangles: Array[int] = []
var _total: int = 0
var _wait: float = 0.0
var _position := Vector3.INF
var _basis := Basis.IDENTITY
var _projection := Projection()
var _chunked: bool = false

func _ready() -> void:
	for child: Node in get_children():
		if not child is MeshInstance3D or not child.has_meta("spatial_mesh_tile"): continue
		_parts.append(child)
		_bounds.append(child.mesh.get_aabb())
		var count: int = child.mesh.surface_get_array_index_len(0)/3
		_triangles.append(count)
		_total += count
	_direct()

func _direct() -> void:
	layers = draw_layers
	cast_shadow = draw_shadow as GeometryInstance3D.ShadowCastingSetting
	for part: MeshInstance3D in _parts: part.hide()
	_chunked = false
	_position = Vector3.INF

func set_spatial_draws_enabled(enabled: bool) -> void:
	set_process(enabled)
	_wait = 0.0
	_position = Vector3.INF
	if not enabled: _direct()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		if _chunked: _direct()
		return
	_wait -= delta
	if _wait > 0.0: return
	_wait = 0.15
	var pose: Transform3D = camera.global_transform
	var projection: Projection = camera.get_camera_projection()
	if _position.distance_squared_to(pose.origin) < 0.25 and _basis.is_equal_approx(pose.basis) and _projection == projection: return
	_position = pose.origin
	_basis = pose.basis
	_projection = projection
	var planes: Array[Plane] = camera.get_frustum()
	var count: int = 0
	var triangles: int = 0
	for index: int in range(_bounds.size()):
		var box: AABB = (global_transform*_bounds[index]).grow(0.1)
		var center: Vector3 = box.get_center()
		var half: Vector3 = box.size*0.5
		var visible: bool = true
		for plane: Plane in planes:
			if plane.distance_to(center) > plane.normal.abs().dot(half): visible = false; break
		if visible:
			count += 1
			triangles += _triangles[index]
	# Avoid extra submission work without a substantial vertex-work saving.
	# Retain the original complete shadow caster as one draw. Spatial chunks
	# reduce only colour/depth drawing, avoiding many small shadow submissions.
	var use_chunks: bool = draw_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED and triangles < _total*0.65 and (_total-triangles) >= maxi(1,count-1)*4096
	if use_chunks == _chunked: return
	_chunked = use_chunks
	layers = 0 if use_chunks and draw_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else draw_layers
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if use_chunks and draw_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else draw_shadow as GeometryInstance3D.ShadowCastingSetting
	for part: MeshInstance3D in _parts: part.visible = use_chunks
