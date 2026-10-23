class_name GarageCleanliness
extends RefCounted
## Inspect washable exterior points, never inaccessible interior wash voxels.
## Work is lazy, bounded and reused until the actual car/parts or masks change.
# Cosmetic work needs a reasonably clean car, without hunting missed specks.
const CLEAN_RESIDUE: float = 0.20
# A light film is tolerated across panels; only stronger patches count as
# missed area. Keep the mean limit so broadly dirty cars still need a wash.
const MISSED_PATCH_RESIDUE: float = 0.30
const MAX_DIRTY_FRACTION: float = 0.25
# The finish's broad slow film has 0.42 to 0.62 opacity before its coverage mask.
const SLOW_FILM_WEIGHT: float = 0.62
const SAMPLES_PER_AXIS: int = VehicleCondition.GRID
var points := PackedVector3Array()
var _scopes := PackedVector3Array()
var _geometry: Array = []
var _state: Array = []
var _clean: bool = true
var _mean_residue: float = 0.0
var _dirty_fraction: float = 0.0

func description(view: CarShowroom) -> String:
	if is_clean(view):
		return "Shiny. For now." if _mean_residue <= 0.025 and _dirty_fraction <= 0.01 else "Clean enough for company"
	if _mean_residue >= 0.50: return "Certified mud magnet"
	if _mean_residue >= 0.25: return "Grubby but proud"
	return "Needs a rinse"

func is_clean(view: CarShowroom) -> bool:
	var effect: VehicleWeathering = view.weathering
	var primary: float = maxf(effect.dirt_amount,effect.snow_amount)
	var slow: float = maxf(effect.slow_dirt_amount * SLOW_FILM_WEIGHT,effect.slow_snow_amount * 0.38)
	if maxf(primary,slow) == 0.0:
		_state.clear()
		_clean = true
		_mean_residue = maxf(primary,slow)
		_dirty_fraction = 0.0
		return true
	var wash: PackedByteArray = effect.wash_image.get_data()
	var slow_wash: PackedByteArray = effect.slow_wash_image.get_data()
	var geometry: Array = [view.car.get_instance_id(),view.customisation.duplicate(true),effect.bounds]
	var state: Array = [geometry,effect.dirt_amount,effect.snow_amount,effect.slow_dirt_amount,effect.slow_snow_amount,wash,slow_wash]
	if state == _state: return _clean
	_state = state
	if geometry != _geometry:
		_geometry = geometry
		_sample_exterior(view)
	var total_residue: float = 0.0
	var total_weight: float = 0.0
	var missed_weight: float = 0.0
	var cutoff: float = minf(maxf(primary,slow),CLEAN_RESIDUE)
	for index: int in range(points.size()):
		var point: Vector3 = points[index]
		var scope: Vector3 = _scopes[index]
		# The finish distributes these layers across complementary coverage.
		# Adding full-strength layers everywhere overstated barely visible film.
		var primary_here: float = maxf(effect.dirt_amount * scope.x,effect.snow_amount * scope.y)
		var residue: float = clampf(maxf(primary_here * (1.0 - _washed(point,effect.bounds,wash)),slow * scope.z * (1.0 - _washed(point,effect.bounds,slow_wash))),0.0,1.0)
		# Clean roof/trim must not dilute a missed dirty door either. Weight by
		# the layer's potential footprint, fixed across strokes in this wash.
		var weight: float = maxf(scope.x if effect.dirt_amount >= cutoff else 0.0,scope.y if effect.snow_amount >= cutoff else 0.0)
		if slow >= cutoff: weight = maxf(weight,scope.z)
		total_weight += weight
		total_residue += residue * weight
		if residue > MISSED_PATCH_RESIDUE: missed_weight += weight
	_mean_residue = total_residue / maxf(total_weight,0.0001)
	_dirty_fraction = missed_weight / maxf(total_weight,0.0001)
	_clean = not points.is_empty() and _mean_residue <= CLEAN_RESIDUE and _dirty_fraction <= MAX_DIRTY_FRACTION
	return _clean

func _sample_exterior(view: CarShowroom) -> void:
	points.clear()
	_scopes.clear()
	var body: Transform3D = view.car.body.global_transform
	var inverse_body: Transform3D = body.affine_inverse()
	var entries: Array[Dictionary] = []
	var washable: Dictionary = {}
	for binding: Dictionary in view.weathering.bindings:
		var key: int = binding.node.get_instance_id()
		if not washable.has(key): washable[key] = {}
		washable[key][binding.index] = binding
	var envelope: AABB = view.weathering.bounds
	for entry: Dictionary in view.pick_meshes:
		var node: MeshInstance3D = entry.node
		var transform: Transform3D = inverse_body * node.global_transform
		envelope = envelope.merge(transform * (entry.bounds as AABB))
		var face_ends := PackedInt32Array()
		var count: int = 0
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			count += (arrays[Mesh.ARRAY_VERTEX].size() if indices.is_empty() else indices.size()) / 3
			face_ends.append(count)
		entries.append({"node":node,"transform":transform,"inverse":transform.affine_inverse(),"bounds":entry.bounds,"triangles":entry.triangles,"faces":(entry.triangles as TriangleMesh).get_faces(),"face_ends":face_ends})
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
				var target_entry: Dictionary = {}
				var face: int = -1
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
						target_entry = entry
						face = int(hit.face_index)
				if target == null or not washable.has(target.get_instance_id()): continue
				var surface: int = 0
				while face >= target_entry.face_ends[surface]: surface += 1
				var bindings: Dictionary = washable[target.get_instance_id()]
				if not bindings.has(surface): continue
				# TriangleMesh turns hit.normal toward the ray, including back
				# faces. Recover the actual clockwise surface normal instead.
				var faces: PackedVector3Array = target_entry.faces
				face *= 3
				var outward: Vector3 = (faces[face+2] - faces[face]).cross(faces[face+1] - faces[face]).normalized()
				var normal: Vector3 = ((target_entry.inverse as Transform3D).basis.transposed() * outward).normalized()
				# Side rays can reach downward-facing chassis/wing surfaces too.
				# Never require the underbody, even when a gap exposes it sideways.
				if normal.y < -0.05: continue
				var point: Vector3 = view.weathering.wash_point(target,position)
				points.append(point)
				_scopes.append(_surface_scope(bindings[surface],point,normal,view.weathering))

static func _surface_scope(binding: Dictionary, point: Vector3, normal: Vector3, effect: VehicleWeathering) -> Vector3:
	# Broad coverage from vehicle_weathering.gdshader; ignore fine noise/specks.
	# In particular, primary road dirt never coats an otherwise clean roof.
	var material: ShaderMaterial = binding.finish
	var roof: float = material.get_shader_parameter("roof_height")
	var rear_only: float = material.get_shader_parameter("rear_only")
	var wheel: bool = binding.wheel
	var rear: float = smoothstep(0.20,0.75,normal.z) * smoothstep(effect.axle_half * 0.85,effect.axle_half * 1.18,point.z)
	var film: float = 1.0 - smoothstep(effect.wheel_radius * 1.1,minf(roof * 0.58,effect.wheel_radius * 2.4),point.y)
	var near_wheels: float = smoothstep(effect.wheel_half_span * 0.24,effect.wheel_half_span * 0.80,absf(point.x))
	var spray: float = 0.0
	for axle: float in [-effect.axle_half,effect.axle_half]:
		var behind: float = point.z - axle
		var distance: float = maxf(behind,0.0)
		var width: float = effect.wheel_radius * 0.48 + distance * 0.20
		var fan: float = 1.0 - smoothstep(width * 0.25,width,absf(point.y - effect.wheel_radius * 0.75 - distance * 0.32))
		spray = maxf(spray,fan * smoothstep(-0.12,effect.wheel_radius * 0.6,behind) * (1.0 - smoothstep(effect.axle_half * 2.2,effect.axle_half * 3.0,distance)))
	var band: float = near_wheels * (0.65 + absf(normal.x) * 0.35) * film * 0.94
	var coverage: float = clampf(maxf(band,spray * near_wheels * (0.55 + absf(normal.x) * 0.45) * 0.72) * (1.0 - smoothstep(roof * 0.53,roof * 0.72,point.y)),0.0,1.0)
	var wake: float = rear * (0.26 + film * 0.69)
	coverage = lerpf(maxf(coverage,wake),wake,rear_only)
	if wheel:
		var rim: Vector3 = point
		for frame: Dictionary in effect._wheel_frames:
			if (frame.rotor as Node3D).is_ancestor_of(binding.node):
				rim = (frame.rest as Transform3D).affine_inverse() * point
				break
		coverage = 1.0 - smoothstep(effect.wheel_radius * 0.67,effect.wheel_radius * 0.81,Vector2(rim.y,rim.z).length())
	return Vector3(coverage,maxf(coverage,maxf(normal.y,0.0) * 0.38 * (1.0 - rear_only) * (0.0 if wheel else 1.0)),(1.0 - coverage) * lerpf(1.0,rear,rear_only) * (0.0 if wheel else 1.0))

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
