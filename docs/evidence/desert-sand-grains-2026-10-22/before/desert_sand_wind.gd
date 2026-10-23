class_name DesertSandWind
extends Node3D
## Local wind-lifted sand. Presentation only; no track or driving writes.
const GRID: int = 9
const SPACING: float = 6.0
const WIND: Vector2 = Vector2(0.91, 0.414608)
const FLOW: Texture2D = preload("res://assets/textures/winter_wind_flow_v1.png")
const SAND_SHADER: Shader = preload("res://track/desert_sand_wind.gdshader")
var ribbons: MultiMeshInstance3D
var material: ShaderMaterial
var track: NativeTrack
var relief: RefCounted
var center := Vector2.INF
var elapsed: float = 0.0
var travel: float = 0.0
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
	if enabled and ribbons == null:
		var plane := PlaneMesh.new()
		plane.size = Vector2(8.0, 3.0)
		plane.subdivide_width = 7
		plane.subdivide_depth = 1
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.use_custom_data = true
		batch.mesh = plane
		batch.instance_count = GRID * GRID
		batch.visible_instance_count = 0
		material = ShaderMaterial.new()
		material.shader = SAND_SHADER
		material.set_shader_parameter("flow_texture", FLOW)
		ribbons = MultiMeshInstance3D.new()
		ribbons.name = "WindLiftedSand"
		ribbons.multimesh = batch
		ribbons.material_override = material
		ribbons.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ribbons)
	reset()

func reset() -> void:
	elapsed = 0.0
	travel = 0.0
	intensity = 0.0
	center = Vector2.INF
	sources.clear()
	if material != null:
		material.set_shader_parameter("strength", 0.0)
		ribbons.multimesh.visible_instance_count = 0

func present(delta: float, focus: Vector2, gust: float, paused: bool, finished: bool) -> void:
	if not enabled or suspended or paused or not is_visible_in_tree(): return
	if not is_finite(delta) or delta <= 0.0 or not focus.is_finite() or not is_finite(gust): return
	var step: float = minf(delta, 0.25)
	var wind: float = clampf(gust, 0.0, 1.0)
	elapsed += step
	intensity = move_toward(intensity, 0.0 if finished else lerpf(0.22, 0.80, wind), step * 0.5)
	travel += step * lerpf(1.6, 3.6, wind)
	var next_center: Vector2 = (focus / SPACING).floor() * SPACING
	if center != next_center:
		center = next_center
		_place()
	material.set_shader_parameter("elapsed", elapsed)
	material.set_shader_parameter("travel", travel)
	material.set_shader_parameter("strength", intensity)
	material.set_shader_parameter("focus", VisualGeometry.world(focus))

func _place() -> void:
	sources.clear()
	var along: Vector3 = VisualGeometry.world(WIND)
	var basis := Basis(along, Vector3.UP, along.cross(Vector3.UP))
	var index: int = 0
	for y: int in range(-4, 5):
		for x: int in range(-4, 5):
			var point: Vector2 = center + Vector2(x, y) * SPACING
			var seed: float = _hash(point)
			point += Vector2(seed - 0.5, _hash(point + Vector2(3, 7)) - 0.5) * 2.0
			var source: Vector2 = point - WIND * 4.0
			# Lift from loose sand, never water, rock, compacted road or a deck.
			if track.cell_at(source) not in [1, 2] or track.cell_at(point) not in [1, 2]: continue
			if absf(source.x) > track.half_extent.x or absf(source.y) > track.half_extent.y: continue
			if track.has_overhead_bridge(source, false) or track.has_overhead_bridge(point, false): continue
			var at: Vector3 = VisualGeometry.world(point)
			at.y = ground_height + (float(relief.height(source)) if relief != null else 0.0) + 0.055
			ribbons.multimesh.set_instance_transform(index, Transform3D(basis, at))
			ribbons.multimesh.set_instance_custom_data(index, Color(seed, _hash(point + Vector2(11, 19)), 0, 1))
			sources.append(source)
			index += 1
	ribbons.multimesh.visible_instance_count = index
	ribbons.multimesh.custom_aabb = AABB(VisualGeometry.world(center) + Vector3(-32, -1, -32), Vector3(64, 4, 64))

static func _hash(point: Vector2) -> float:
	return fposmod(sin(point.dot(Vector2(12.9898, 78.233))) * 43758.5453, 1.0)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]: suspended = true
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]: suspended = false
