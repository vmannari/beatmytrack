class_name DesertSandWind
extends Node3D
## Local wind-lifted sand. Presentation only; no track or driving writes.
const MAX_PATCHES: int = 12
const PUFFS_PER_PATCH: int = 8
const SOURCE_SAMPLES: int = 8192
const SPACING: float = 7.0
const MIN_SEPARATION: float = 5.0
const WIND: Vector2 = Vector2(0.91, 0.414608)
const SAND_SHADER: Shader = preload("res://track/desert_sand_wind.gdshader")
const DENSITY: Texture2D = preload("res://assets/textures/desert_wind_density_v1.png")
const SAND_COLOR: Color = TrackTheme.DESERT[2]
const ORDINARY_STRENGTH: float = 0.65
const ROOT_FADE_START: float = 14.0
const ROOT_FADE_END: float = 20.0
const LIFT_SAMPLES: int = 48
const LIFT_RATE: float = 12.0
const DUNE_EDGES = preload("res://track/desert_dune_edges.gd")
const SOURCE_SURFACE = preload("res://track/desert_dune_source_surface.gd")
var plumes: MultiMeshInstance3D
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
var anchor_heights: Dictionary = {}
var anchor_roots: Dictionary = {}
var source_surface: RefCounted
var source_samples: int = 0
var source_queries: int = 0
var crest_tiles: Dictionary = {}
var lift_history := PackedFloat32Array()
var lift_elapsed: float = 0.0
var previous_lift: float = 0.0

func configure(data: NativeTrack, visual: Node3D = null) -> void:
	track = data
	enabled = data != null and data.metadata.get("theme", "pine") == "desert"
	visible = enabled
	relief = visual.desert_relief if is_instance_valid(visual) and enabled else null
	ground_height = -0.06 if enabled and not data.metadata.get("creator_document", {}).get("pieces", []).is_empty() else 0.0
	anchor_heights.clear()
	anchor_roots.clear()
	source_samples = 0
	source_queries = 0
	crest_tiles.clear()
	source_surface = SOURCE_SURFACE.new()
	if enabled:
		if is_instance_valid(visual): source_surface.prepare(visual)
		_prepare_crests(track.route[0] if not track.route.is_empty() else Vector2.ZERO)
	if enabled and plumes == null:
		var plane := QuadMesh.new()
		plane.size = Vector2.ONE
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.use_custom_data = true
		batch.mesh = plane
		batch.instance_count = MAX_PATCHES * PUFFS_PER_PATCH
		batch.visible_instance_count = 0
		material = ShaderMaterial.new()
		material.shader = SAND_SHADER
		material.set_shader_parameter("density_texture", DENSITY)
		material.set_shader_parameter("sand_color", SAND_COLOR)
		material.set_shader_parameter("source_fade_start", ROOT_FADE_START)
		material.set_shader_parameter("source_fade_end", ROOT_FADE_END)
		plumes = MultiMeshInstance3D.new()
		plumes.name = "WindLiftedSandPlumes"
		plumes.multimesh = batch
		plumes.material_override = material
		plumes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(plumes)
	reset()

func _prepare_crests(focus: Vector2) -> void:
	# Guide UVs address the visible artwork, not the unrelated 32m normal map.
	# Keep live sites, then rebuild a bounded local window as the car moves.
	var retained: Dictionary = {}
	for source: Vector2 in sources:
		if anchor_roots.has(source): retained[source] = anchor_roots[source]
	anchor_roots = retained
	anchor_heights.clear()
	for source: Vector2 in retained: anchor_heights[source] = retained[source][0].y
	source_samples = 0
	source_queries = 0
	var tile := Vector2i((Vector2(focus.x, -focus.y) / DUNE_EDGES.TILE).floor())
	# Road/bridge support and artwork roots are immutable until configure().
	# Retain only the same nine local tiles that discovery already visits.
	for key: Vector2i in crest_tiles.keys():
		if absi(key.x - tile.x) > 1 or absi(key.y - tile.y) > 1: crest_tiles.erase(key)
	for y: int in range(tile.y - 1, tile.y + 2):
		for x: int in range(tile.x - 1, tile.x + 2):
			var key := Vector2i(x, y)
			if not crest_tiles.has(key):
				crest_tiles[key] = _crest_tile(key)
				source_queries += int(crest_tiles[key].samples)
			source_samples += int(crest_tiles[key].samples)
			for roots: PackedVector3Array in crest_tiles[key].roots:
				var at: Vector3 = roots[PUFFS_PER_PATCH / 2]
				var source := Vector2(at.x, -at.z)
				anchor_roots[source] = roots
				anchor_heights[source] = at.y

func _crest_tile(tile: Vector2i) -> Dictionary:
	var samples: int = 0
	var accepted: Array[PackedVector3Array] = []
	for guide: Array in DUNE_EDGES.ROOTS:
		var roots := PackedVector3Array()
		for uv: Vector2 in guide:
			samples += 1
			var world_xz: Vector2 = (Vector2(tile) + uv) * DUNE_EDGES.TILE
			var point := Vector2(world_xz.x, -world_xz.y)
			if absf(point.x) >= track.half_extent.x or absf(point.y) >= track.half_extent.y or track.cell_at(point) not in [1, 2]: break
			if track.has_overhead_bridge(point, false) or not source_surface.clear(point): break
			var loose: bool = true
			for offset: Vector2 in [Vector2(2.5, 0), Vector2(-2.5, 0), Vector2(0, 2.5), Vector2(0, -2.5)]:
				if track.cell_at(point + offset) not in [1, 2]: loose = false; break
			if not loose: break
			var at: Vector3 = VisualGeometry.world(point)
			at.y = ground_height + (float(relief.height(point)) if relief != null else 0.0) + 0.025
			roots.append(at)
		if roots.size() == PUFFS_PER_PATCH: accepted.append(roots)
	return {"samples":samples,"roots":accepted}

func reset() -> void:
	elapsed = 0.0
	intensity = 0.0
	center = Vector2.INF
	sources.clear()
	lift_history.resize(LIFT_SAMPLES)
	lift_history.fill(0.0)
	lift_elapsed = 0.0
	previous_lift = 0.0
	if material != null:
		material.set_shader_parameter("strength", 0.0)
		material.set_shader_parameter("lift_history", lift_history)
		material.set_shader_parameter("lift_elapsed", 0.0)
		plumes.multimesh.visible_instance_count = 0

func present(delta: float, focus: Vector2, gust: float, paused: bool, finished: bool, audio_lift: float = 0.0) -> void:
	if not enabled or suspended or paused or not is_visible_in_tree(): return
	if not is_finite(delta) or delta <= 0.0 or not focus.is_finite() or not is_finite(gust) or not is_finite(audio_lift): return
	var step: float = minf(delta, 0.25)
	var wind: float = clampf(gust, 0.0, 1.0)
	elapsed += step
	intensity = move_toward(intensity, 0.0 if finished else lerpf(ORDINARY_STRENGTH, 0.95, wind), step * (0.95 / DesertAmbience.FINISH_FADE if finished else 0.5))
	# Store the wind at birth time. A gust lifts new grains at the texture lip;
	# it cannot suddenly materialise a cloud halfway through a particle's flight.
	var lift: float = 0.0 if finished else clampf(audio_lift, 0.0, 1.0)
	lift_elapsed += step
	var changed: bool = false
	while lift_elapsed >= 1.0 / LIFT_RATE:
		lift_elapsed -= 1.0 / LIFT_RATE
		for index: int in range(LIFT_SAMPLES - 1, 0, -1): lift_history[index] = lift_history[index - 1]
		lift_history[0] = lerpf(previous_lift, lift, clampf(1.0 - lift_elapsed / step, 0.0, 1.0))
		changed = true
	previous_lift = lift
	if changed: material.set_shader_parameter("lift_history", lift_history)
	material.set_shader_parameter("lift_elapsed", lift_elapsed)
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
	# The shader fades the entire site by root distance, so a finished site
	# can release its slot even when a large proxy overlaps the view bounds.
	for source: Vector2 in previous:
		if not anchor_roots.has(source): continue
		for at: Vector3 in anchor_roots[source]:
			if Vector2(at.x, -at.z).distance_squared_to(focus) < ROOT_FADE_END * ROOT_FADE_END:
				sources.append(source)
				break
	_prepare_crests(focus)
	var candidates: Array[Vector2] = []
	for source: Vector2 in anchor_heights:
		candidates.append(source)
	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(focus) < b.distance_squared_to(focus))
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
		for puff: int in range(PUFFS_PER_PATCH):
			var at: Vector3 = anchor_roots[source][puff]
			plumes.multimesh.set_instance_transform(index, Transform3D(basis, at))
			plumes.multimesh.set_instance_custom_data(index, Color(seed, (puff + 0.5) / PUFFS_PER_PATCH, _hash(source + Vector2(puff, 73)), 1.0))
			index += 1
	plumes.multimesh.visible_instance_count = index
	plumes.multimesh.custom_aabb = AABB(VisualGeometry.world(center) + Vector3(-68, -1, -68), Vector3(136, 6, 136))

static func _hash(point: Vector2) -> float:
	return fposmod(sin(point.dot(Vector2(12.9898, 78.233))) * 43758.5453, 1.0)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]: suspended = true
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]: suspended = false
