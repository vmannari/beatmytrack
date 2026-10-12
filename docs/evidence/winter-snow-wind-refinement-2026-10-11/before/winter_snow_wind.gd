class_name WinterSnowWind
extends Node3D
## Bounded, world-space presentation. No simulation, input or race-clock writes.
const WIND: Vector2 = Vector2(0.91, 0.414608)
const GRID: int = 9
const SPACING: float = 6.0
const BANK_SLOTS: int = 12
const WISPS: int = 3
const BUCKET: float = 6.0
const REFRESH: float = 0.25
var ground: MultiMeshInstance3D
var powder: MultiMeshInstance3D
var ground_material: ShaderMaterial
var powder_material: ShaderMaterial
var anchors: Dictionary = {}
var active_banks := PackedVector3Array()
var center := Vector2.INF
var elapsed: float = 0.0
var travel: float = 0.0
var intensity: float = 0.0
var refresh_wait: float = 0.0
var suspended: bool = false
var enabled: bool = false

func configure(track: NativeTrack) -> void:
	enabled = track != null and track.metadata.get("theme", "pine") == "winter"
	visible = enabled
	anchors.clear()
	active_banks.clear()
	if not enabled: return
	if ground == null:
		ground = _batch("GroundDrifts", GRID * GRID, false)
		powder = _batch("BankPowder", BANK_SLOTS * WISPS, true)
		ground_material = ground.material_override
		powder_material = powder.material_override
	# One anchor per spatial bucket, on the crest of an exposed upwind bank.
	# Read prepared geometry once, rather than search the whole track each frame.
	for triangle: Dictionary in track.snow_banks.triangles:
		var points: PackedVector2Array = triangle.points
		var heights: PackedFloat32Array = triangle.heights
		var high: int = 0
		var low: int = 0
		for i: int in range(1, 3):
			if heights[i] > heights[high]: high = i
			if heights[i] < heights[low]: low = i
		if heights[high] < 0.20 or heights[low] > 0.01: continue
		# Outer bank slope rises back toward the road; lift powder downwind.
		if (points[high] - points[low]).normalized().dot(WIND) < 0.15: continue
		var point: Vector2 = points[high]
		if CreatorBridges.at_any(track.creator_bridges, point): continue
		var key := Vector2i((point / BUCKET).floor())
		if not anchors.has(key): anchors[key] = VisualGeometry.world(point) + Vector3.UP * (heights[high] + 0.04)
	reset()

func reset() -> void:
	elapsed = 0.0
	travel = 0.0
	intensity = 0.0
	refresh_wait = 0.0
	center = Vector2.INF
	active_banks.clear()
	if ground != null:
		ground_material.set_shader_parameter("strength", 0.0)
		powder_material.set_shader_parameter("strength", 0.0)
		powder.multimesh.visible_instance_count = 0

func present(delta: float, focus: Vector2, gust: float, paused: bool, finished: bool) -> void:
	if not enabled or suspended or paused: return
	if not is_finite(delta) or delta < 0.0 or not focus.is_finite() or not is_finite(gust): return
	var step: float = minf(delta, 0.25)
	elapsed += step
	# Share the existing recorded wind's smooth gust envelope, without new audio.
	intensity = move_toward(intensity, 0.0 if finished else lerpf(0.24, 1.0, clampf(gust, 0.0, 1.0)), step * 1.5)
	travel += step * lerpf(2.0, 5.5, intensity)
	var next_center: Vector2 = (focus / SPACING).floor() * SPACING
	if center != next_center:
		center = next_center
		_place_ground()
		refresh_wait = 0.0
	refresh_wait -= step
	if refresh_wait <= 0.0:
		_place_banks(focus)
		refresh_wait = REFRESH
	for material: ShaderMaterial in [ground_material, powder_material]:
		material.set_shader_parameter("elapsed", elapsed)
		material.set_shader_parameter("travel", travel)
		material.set_shader_parameter("strength", intensity)
		material.set_shader_parameter("focus", VisualGeometry.world(focus))

func _batch(label: String, count: int, bank: bool) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := QuadMesh.new()
	mesh.orientation = PlaneMesh.FACE_Z if bank else PlaneMesh.FACE_Y
	mesh.size = Vector2(2.8, 0.95) if bank else Vector2(6.5, 0.75)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.instance_count = count
	instances.visible_instance_count = 0
	instances.mesh = mesh
	node.multimesh = instances
	var material := ShaderMaterial.new()
	material.shader = preload("res://track/winter_snow_wind.gdshader")
	material.set_shader_parameter("bank", bank)
	material.set_shader_parameter("powder_texture", preload("res://assets/textures/dust_puff_v1.png"))
	node.material_override = material
	add_child(node)
	return node

func _basis(bank: bool = false) -> Basis:
	var along: Vector3 = VisualGeometry.world(WIND)
	var side: Vector3 = along.cross(Vector3.UP)
	var lift: Vector3 = (Vector3.UP * 0.65 + side * 0.76).normalized() if bank else Vector3.UP
	return Basis(along, lift, along.cross(lift))

func _place_ground() -> void:
	var index: int = 0
	for y: int in range(-4, 5):
		for x: int in range(-4, 5):
			var point: Vector2 = center + Vector2(x, y) * SPACING
			var seed: float = _hash(point)
			var at: Vector3 = VisualGeometry.world(point + Vector2(seed - 0.5, _hash(point + Vector2.ONE) - 0.5) * 3.5)
			at.y = 0.085
			ground.multimesh.set_instance_transform(index, Transform3D(_basis(), at))
			ground.multimesh.set_instance_custom_data(index, Color(seed, _hash(point + Vector2(3, 7)), 0, 1))
			index += 1
	ground.multimesh.visible_instance_count = index
	ground.multimesh.custom_aabb = AABB(VisualGeometry.world(center) + Vector3(-36, -1, -36), Vector3(72, 5, 72))

func _place_banks(focus: Vector2) -> void:
	var candidates: Array[Vector3] = []
	var cell := Vector2i((focus / BUCKET).floor())
	# At most 81 dictionary lookups, four times per second while stationary.
	for y: int in range(-4, 5):
		for x: int in range(-4, 5):
			var key: Vector2i = cell + Vector2i(x, y)
			if anchors.has(key): candidates.append(anchors[key])
	var world_focus: Vector3 = VisualGeometry.world(focus)
	candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(world_focus) < b.distance_squared_to(world_focus))
	active_banks.clear()
	var index: int = 0
	for i: int in range(mini(BANK_SLOTS, candidates.size())):
		var at: Vector3 = candidates[i]
		active_banks.append(at)
		for wisp: int in range(WISPS):
			powder.multimesh.set_instance_transform(index, Transform3D(_basis(true), at))
			powder.multimesh.set_instance_custom_data(index, Color(_hash(Vector2(at.x, at.z) + Vector2.ONE * wisp), float(wisp) / WISPS, 0, 1))
			index += 1
	powder.multimesh.visible_instance_count = index
	powder.multimesh.custom_aabb = AABB(world_focus + Vector3(-38, -1, -38), Vector3(76, 6, 76))

func _hash(point: Vector2) -> float:
	return fposmod(sin(point.dot(Vector2(12.9898, 78.233))) * 43758.5453, 1.0)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]: suspended = true
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]: suspended = false
