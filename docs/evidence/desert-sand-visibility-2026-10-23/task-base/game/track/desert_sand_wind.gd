class_name DesertSandWind
extends Node3D
## Local wind-lifted sand. Presentation only; no track or driving writes.
const MAX_PATCHES: int = 6
const GRAINS_PER_PATCH: int = 192
const SPACING: float = 14.0
const MIN_SEPARATION: float = 8.0
const WIND: Vector2 = Vector2(0.91, 0.414608)
const SAND_SHADER: Shader = preload("res://track/desert_sand_wind.gdshader")
var grains: MultiMeshInstance3D
var material: ShaderMaterial
var track: NativeTrack
var relief: RefCounted
var center := Vector2.INF
var elapsed: float = 0.0
var intensity: float = 0.0
var enabled: bool = false
var suspended: bool = false
var ground_height: float = 0.0
var sources := PackedVector2Array()

func configure(data: NativeTrack, visual: NativeTrackVisual = null) -> void:
	track = data
	enabled = data != null and data.metadata.get("theme", "pine") == "desert"
	visible = enabled
	relief = visual.desert_relief if is_instance_valid(visual) and enabled else null
	ground_height = -0.06 if enabled and not data.metadata.get("creator_document", {}).get("pieces", []).is_empty() else 0.0
	if enabled and grains == null:
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.use_custom_data = true
		batch.mesh = plane
		batch.instance_count = MAX_PATCHES * GRAINS_PER_PATCH
		batch.visible_instance_count = 0
		material = ShaderMaterial.new()
		material.shader = SAND_SHADER
		grains = MultiMeshInstance3D.new()
		grains.name = "WindLiftedSandGrains"
		grains.multimesh = batch
		grains.material_override = material
		grains.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(grains)
	reset()

func reset() -> void:
	elapsed = 0.0
	intensity = 0.0
	center = Vector2.INF
	sources.clear()
	if material != null:
		material.set_shader_parameter("strength", 0.0)
		grains.multimesh.visible_instance_count = 0

func present(delta: float, focus: Vector2, gust: float, paused: bool, finished: bool) -> void:
	if not enabled or suspended or paused or not is_visible_in_tree(): return
	if not is_finite(delta) or delta <= 0.0 or not focus.is_finite() or not is_finite(gust): return
	var step: float = minf(delta, 0.25)
	var wind: float = clampf(gust, 0.0, 1.0)
	elapsed += step
	intensity = move_toward(intensity, 0.0 if finished else lerpf(0.07, 0.88, wind), step * 0.5)
	var next_center: Vector2 = (focus / SPACING).floor() * SPACING
	if center != next_center:
		center = next_center
		_place(focus)
	material.set_shader_parameter("elapsed", elapsed)
	material.set_shader_parameter("strength", intensity)
	material.set_shader_parameter("focus", VisualGeometry.world(focus))

func _place(focus: Vector2) -> void:
	var previous: PackedVector2Array = sources.duplicate()
	sources.clear()
	# Keep sites until their entire hop envelope is beyond the visible fade.
	# Crossing a collection-cell boundary must not relocate a visible burst.
	for source: Vector2 in previous:
		if source.distance_squared_to(focus) < 28.0 * 28.0: sources.append(source)
	var candidates: Array[Vector2] = []
	# Empty cells, full-cell jitter and minimum separation avoid the original
	# carpet of identical evenly spaced ribbons. World sites survive recentering.
	for y: int in range(-3, 4):
		for x: int in range(-3, 4):
			var cell: Vector2 = center / SPACING + Vector2(x, y)
			if _hash(cell + Vector2(81, 43)) > 0.48: continue
			var source: Vector2 = (cell + Vector2(_hash(cell + Vector2(17, 31)), _hash(cell + Vector2(67, 11)))) * SPACING
			if track.cell_at(source) not in [1, 2]: continue
			if absf(source.x) > track.half_extent.x or absf(source.y) > track.half_extent.y: continue
			if track.has_overhead_bridge(source, false) or track.has_overhead_bridge(source + WIND * 4.0, false): continue
			candidates.append(source)
	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(center) < b.distance_squared_to(center))
	for source: Vector2 in candidates:
		if sources.size() >= MAX_PATCHES: break
		var separated: bool = true
		for other: Vector2 in sources:
			if source.distance_squared_to(other) < MIN_SEPARATION * MIN_SEPARATION:
				separated = false
				break
		if separated: sources.append(source)
	var index: int = 0
	for source: Vector2 in sources:
		var seed: float = _hash(source)
		var along: Vector3 = VisualGeometry.world(WIND.rotated((seed - 0.5) * 0.30))
		var basis := Basis(along, Vector3.UP, along.cross(Vector3.UP))
		var at: Vector3 = VisualGeometry.world(source)
		at.y = ground_height + (float(relief.height(source)) if relief != null else 0.0) + 0.025
		for grain: int in range(GRAINS_PER_PATCH):
			grains.multimesh.set_instance_transform(index, Transform3D(basis, at))
			grains.multimesh.set_instance_custom_data(index, Color(seed, (grain + 0.5) / GRAINS_PER_PATCH, _hash(source + Vector2(grain, 73)), 1.0))
			index += 1
	grains.multimesh.visible_instance_count = index
	grains.multimesh.custom_aabb = AABB(VisualGeometry.world(center) + Vector3(-56, -1, -56), Vector3(112, 3, 112))

static func _hash(point: Vector2) -> float:
	return fposmod(sin(point.dot(Vector2(12.9898, 78.233))) * 43758.5453, 1.0)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]: suspended = true
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]: suspended = false
