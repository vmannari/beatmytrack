class_name GarageCleanliness
extends RefCounted
## Inspect washable exterior points, never inaccessible interior wash voxels.
## Work is lazy, bounded and reused until the actual car/parts or masks change.
# Cosmetic work needs a reasonably clean car, without hunting missed specks.
const CLEAN_RESIDUE: float = 0.05
const MAX_DIRTY_FRACTION: float = 0.05
const SAMPLES_PER_AXIS: int = VehicleCondition.GRID
var points := PackedVector3Array()
var _geometry: Array = []
var _state: Array = []
var _clean: bool = true

func is_clean(view: CarShowroom) -> bool:
	var effect: VehicleWeathering = view.weathering
	var primary: float = maxf(effect.dirt_amount,effect.snow_amount)
	var slow: float = maxf(effect.slow_dirt_amount,effect.slow_snow_amount)
	if primary + slow <= CLEAN_RESIDUE: return true
	var wash: PackedByteArray = effect.wash_image.get_data()
	var slow_wash: PackedByteArray = effect.slow_wash_image.get_data()
	var geometry: Array = [view.car.get_instance_id(),view.customisation.duplicate(true),effect.bounds]
	var state: Array = [geometry,primary,slow,wash,slow_wash]
	if state == _state: return _clean
	_state = state
	# An unwashed car requires no geometry inspection at all.
	if (primary > CLEAN_RESIDUE and wash.count(0) == wash.size()) or (slow > CLEAN_RESIDUE and slow_wash.count(0) == slow_wash.size()):
		_clean = false
		return false
	if geometry != _geometry:
		_geometry = geometry
		_sample_exterior(view)
	var residue_budget: float = points.size() * CLEAN_RESIDUE
	var missed_budget: int = floori(points.size() * MAX_DIRTY_FRACTION)
	var total_residue: float = 0.0
	var missed: int = 0
	_clean = not points.is_empty()
	for point: Vector3 in points:
		var residue: float = clampf(primary * (1.0 - _washed(point,effect.bounds,wash)) + slow * (1.0 - _washed(point,effect.bounds,slow_wash)),0.0,1.0)
		total_residue += residue
		if residue > CLEAN_RESIDUE: missed += 1
		if total_residue > residue_budget or missed > missed_budget:
			_clean = false
			break
	return _clean

func _sample_exterior(view: CarShowroom) -> void:
	points.clear()
	var body: Transform3D = view.car.body.global_transform
	var inverse_body: Transform3D = body.affine_inverse()
	var entries: Array[Dictionary] = []
	var washable: Dictionary = {}
	for binding: Dictionary in view.weathering.bindings: washable[binding.node.get_instance_id()] = true
	var envelope: AABB = view.weathering.bounds
	for entry: Dictionary in view.pick_meshes:
		var node: MeshInstance3D = entry.node
		var transform: Transform3D = inverse_body * node.global_transform
		envelope = envelope.merge(transform * (entry.bounds as AABB))
		entries.append({"node":node,"transform":transform,"inverse":transform.affine_inverse(),"bounds":entry.bounds,"triangles":entry.triangles})
	envelope = envelope.grow(0.1)
	# Top and four sides are reachable with the original orbit/wash controls.
	# The hidden underside and enclosed body volume do not demand scrubbing.
	for direction: Vector3 in [Vector3.DOWN,Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
		var axis: int = direction.abs().max_axis_index()
		var u: int = (axis + 1) % 3
		var v: int = (axis + 2) % 3
		for row: int in range(SAMPLES_PER_AXIS):
			for column: int in range(SAMPLES_PER_AXIS):
				var origin: Vector3 = envelope.position
				origin[axis] += envelope.size[axis] if direction[axis] < 0.0 else 0.0
				origin[u] += envelope.size[u] * (float(column) + 0.5) / SAMPLES_PER_AXIS
				origin[v] += envelope.size[v] * (float(row) + 0.5) / SAMPLES_PER_AXIS
				var nearest: float = INF
				var target: MeshInstance3D
				var position := Vector3.ZERO
				for entry: Dictionary in entries:
					var inverse: Transform3D = entry.inverse
					var local_origin: Vector3 = inverse * origin
					var local_direction: Vector3 = (inverse.basis * direction).normalized()
					if not (entry.bounds as AABB).intersects_ray(local_origin,local_direction): continue
					var hit: Dictionary = (entry.triangles as TriangleMesh).intersect_ray(local_origin,local_direction)
					if hit.is_empty(): continue
					var distance: float = origin.distance_squared_to((entry.transform as Transform3D) * (hit.position as Vector3))
					if distance < nearest:
						nearest = distance
						target = entry.node
						position = hit.position
				if target != null and washable.has(target.get_instance_id()): points.append(view.weathering.wash_point(target,position))

static func _washed(point: Vector3, bounds: AABB, bytes: PackedByteArray) -> float:
	# Same trilinear 16-cube mapping used by the existing finish shader.
	var p: Vector3 = ((point - bounds.position) / bounds.size).clamp(Vector3.ZERO,Vector3.ONE) * (VehicleCondition.GRID - 1)
	var lower := Vector3i(p.floor())
	var upper := Vector3i(p.ceil())
	var fraction: Vector3 = p - Vector3(lower)
	var value: float = 0.0
	for z: int in range(2):
		for y: int in range(2):
			for x: int in range(2):
				var index: int = (lower.y if y == 0 else upper.y) * 256 + (lower.z if z == 0 else upper.z) * 16 + (lower.x if x == 0 else upper.x)
				value += float(bytes[index]) / 255.0 * (1.0 - fraction.x if x == 0 else fraction.x) * (1.0 - fraction.y if y == 0 else fraction.y) * (1.0 - fraction.z if z == 0 else fraction.z)
	return value
