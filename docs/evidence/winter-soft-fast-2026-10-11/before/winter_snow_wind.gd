class_name WinterSnowWind
extends Node3D
## Bounded, world-space presentation. No simulation, input or race-clock writes.
const WIND: Vector2 = Vector2(0.91, 0.414608)
const GRID: int = 9
const GRAINS_PER_CELL: int = 6
const SPACING: float = 6.0
const BANK_SLOTS: int = 12
const WISPS: int = 18
const BUCKET: float = 6.0
const REFRESH: float = 0.25
const VERSION: String = "winter-wind-4"
const CALM_SPEED: float = 6.0
const GUST_SPEED: float = 24.0
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
var sources_from_visual: bool = false
var sources_checked: bool = false
var bank_visual: Node3D
var source_track: NativeTrack

func configure(track: NativeTrack, visual: Node3D = null) -> void:
	enabled = track != null and track.metadata.get("theme", "pine") == "winter"
	visible = enabled
	anchors.clear()
	active_banks.clear()
	sources_from_visual = false
	sources_checked = false
	bank_visual = visual
	source_track = track
	if not enabled:
		bank_visual = null
		source_track = null
		return
	if ground == null:
		ground = _batch("GroundGrains", GRID * GRID * GRAINS_PER_CELL, false)
		powder = _batch("BankPowder", BANK_SLOTS * WISPS, true)
		ground_material = ground.material_override
		powder_material = powder.material_override
	if _prepare_visual_sources(track):
		reset()
		return
	_prepare_contact_sources(track)
	reset()

func _prepare_visual_sources(track: NativeTrack) -> bool:
	if not is_instance_valid(bank_visual): return false
	var meshes: Array[MeshInstance3D] = []
	# Prepared-world batching does not preserve original mesh node names.
	# The bank material is the stable visual role across fresh/cached worlds.
	for child: Node in bank_visual.get_children():
		if child is MeshInstance3D: meshes.append(child)
	var prepared: Dictionary = {}
	var role_found: bool = false
	for bank_mesh: MeshInstance3D in meshes:
		# The visual analytic crest differs from the raster contact bank. Source
		# powder on the visible snow, once at build, without changing contacts.
		for surface: int in range(bank_mesh.mesh.get_surface_count()):
			var material: Material = bank_mesh.material_override if bank_mesh.material_override != null else bank_mesh.mesh.surface_get_material(surface)
			if not material is ShaderMaterial or not (material as ShaderMaterial).shader.code.contains("smooth_road_bank"): continue
			role_found = true
			var arrays: Array = bank_mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for index: int in range(vertices.size()):
				var at: Vector3 = bank_mesh.transform * vertices[index]
				if at.y < 0.24: continue
				if normals[index].dot(VisualGeometry.world(WIND)) > -0.08: continue
				var point := Vector2(at.x, -at.z)
				if track.cell_at(point + WIND * 2.0) != 0: continue
				if CreatorBridges.at_any(track.creator_bridges, point): continue
				var key := Vector2i((point / BUCKET).floor())
				if not prepared.has(key) or Vector3(prepared[key]).y < at.y:
					prepared[key] = at + Vector3.UP * 0.06
	sources_checked = role_found
	if not prepared.is_empty():
		anchors = prepared
		sources_from_visual = true
		return true
	return false

func _prepare_contact_sources(track: NativeTrack) -> void:
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
	travel += step * lerpf(CALM_SPEED, GUST_SPEED, intensity)
	var next_center: Vector2 = (focus / SPACING).floor() * SPACING
	if center != next_center:
		center = next_center
		_place_ground()
		refresh_wait = 0.0
	refresh_wait -= step
	if refresh_wait <= 0.0:
		# Native road construction may finish a few frames after race startup.
		if not sources_checked and is_instance_valid(bank_visual):
			_prepare_visual_sources(source_track)
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
	mesh.orientation = PlaneMesh.FACE_Y
	# Small rounded motes and short wind trails, never broad transparent sheets.
	mesh.size = Vector2(0.18, 0.13) if bank else Vector2(0.34, 0.10)
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
	material.set_shader_parameter("flow_texture", load("res://assets/textures/winter_wind_flow_v1.png"))
	material.set_shader_parameter("snow_albedo", NativeTrackVisual.WINTER_SNOW)
	node.material_override = material
	add_child(node)
	return node

func _basis(_bank: bool = false) -> Basis:
	var along: Vector3 = VisualGeometry.world(WIND)
	return Basis(along, Vector3.UP, along.cross(Vector3.UP))

func _place_ground() -> void:
	var index: int = 0
	for y: int in range(-4, 5):
		for x: int in range(-4, 5):
			var point: Vector2 = center + Vector2(x, y) * SPACING
			for grain: int in range(GRAINS_PER_CELL):
				var key: Vector2 = point + Vector2(grain * 19.31, grain * 7.77)
				var seed: float = _hash(key)
				var spread: float = _hash(key + Vector2(3, 7))
				var at: Vector3 = VisualGeometry.world(point + Vector2(seed - 0.5, spread - 0.5) * SPACING)
				at.y = 0.065
				ground.multimesh.set_instance_transform(index, Transform3D(_basis(), at))
				ground.multimesh.set_instance_custom_data(index, Color(seed, spread, _hash(key + Vector2(13, 9)), 1))
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
	var next := PackedVector3Array()
	for i: int in range(mini(BANK_SLOTS, candidates.size())): next.append(candidates[i])
	var same_membership: bool = next.size() == active_banks.size()
	if same_membership:
		for at: Vector3 in next:
			if not active_banks.has(at):
				same_membership = false
				break
	if same_membership: return # Reordering nearest sources cannot upload every mote.
	active_banks = next
	var index: int = 0
	for at: Vector3 in active_banks:
		for wisp: int in range(WISPS):
			powder.multimesh.set_instance_transform(index, Transform3D(_basis(true), at))
			var key: Vector2 = Vector2(at.x, at.z) + Vector2(wisp * 11.7, wisp * 23.1)
			powder.multimesh.set_instance_custom_data(index, Color(_hash(key), _hash(key + Vector2(3, 7)), _hash(key + Vector2(13, 9)), 1))
			index += 1
	powder.multimesh.visible_instance_count = index
	powder.multimesh.custom_aabb = AABB(world_focus + Vector3(-38, -1, -38), Vector3(76, 6, 76))

func _hash(point: Vector2) -> float:
	return fposmod(sin(point.dot(Vector2(12.9898, 78.233))) * 43758.5453, 1.0)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]: suspended = true
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]: suspended = false
