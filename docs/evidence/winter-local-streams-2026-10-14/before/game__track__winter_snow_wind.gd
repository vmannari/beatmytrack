class_name WinterSnowWind
extends Node3D
## Bounded, world-space presentation. No simulation, input or race-clock writes.
const WIND: Vector2 = Vector2(0.91, 0.414608)
const GRID: int = 7
const SPACING: float = 6.0
const BANK_SLOTS: int = 12
const WISPS: int = 3
const BUCKET: float = 6.0
const REFRESH: float = 0.25
const VERSION: String = "winter-wind-14"
const CALM_SPEED: float = 12.0
const GUST_SPEED: float = 18.0
const AIR_GRAINS: int = 48
var ground: MultiMeshInstance3D
var powder: MultiMeshInstance3D
var airborne: MultiMeshInstance3D
var ground_material: ShaderMaterial
var powder_material: ShaderMaterial
var anchors: Dictionary = {}
var active_banks := PackedVector3Array()
var center := Vector2.INF
var elapsed: float = 0.0
var travel: float = 0.0
var intensity: float = 0.0
var motion_intensity: float = 0.0
var refresh_wait: float = 0.0
var suspended: bool = false
var enabled: bool = false
var sources_from_visual: bool = false
var sources_checked: bool = false
var bank_visual: Node3D
var source_track: NativeTrack
var surface_materials: Array[ShaderMaterial] = []
var surface_bindings: Array[Dictionary] = []
var surface_instances: Dictionary = {}
var last_focus: Vector2 = Vector2.ZERO
var surface_child_count: int = -1
var car_visual: Node3D
var _fallback_active: bool = true

func configure(track: NativeTrack, visual: Node3D = null, vehicle: Node3D = null) -> void:
	_release_surfaces()
	car_visual = vehicle
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
		ground = _batch("GroundDrifts", GRID * GRID, false)
		powder = _batch("BankPowder", BANK_SLOTS * WISPS, true)
		airborne = _air_batch()
		ground_material = ground.material_override
		powder_material = powder.material_override
	_bind_surfaces()
	_fallback_active = surface_materials.is_empty()
	if _fallback_active and not _prepare_visual_sources(track): _prepare_contact_sources(track)
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
	motion_intensity = 0.0
	refresh_wait = 0.0
	center = Vector2.INF
	active_banks.clear()
	if ground != null:
		ground_material.set_shader_parameter("strength", 0.0)
		powder_material.set_shader_parameter("strength", 0.0)
		powder.multimesh.visible_instance_count = 0
		if not surface_materials.is_empty(): ground.multimesh.visible_instance_count = 0
		(airborne.material_override as ShaderMaterial).set_shader_parameter("strength",0.0)
	_sync_surfaces()

func present(delta: float, focus: Vector2, gust: float, paused: bool, finished: bool) -> void:
	if not enabled or suspended or paused: return
	if not is_finite(delta) or delta < 0.0 or not focus.is_finite() or not is_finite(gust): return
	var step: float = minf(delta, 0.25)
	elapsed += step
	# Share the existing recorded wind's smooth gust envelope, without new audio.
	intensity = move_toward(intensity, 0.0 if finished else lerpf(0.12, 0.45, clampf(gust, 0.0, 1.0)), step * 1.5)
	# Snow amount and transport speed stay independent, with restrained
	# coverage and moderate travel rather than racing sheets of powder.
	motion_intensity = move_toward(motion_intensity,clampf(gust,0.0,1.0),step*1.5)
	travel += step * lerpf(CALM_SPEED, GUST_SPEED, motion_intensity)
	var next_center: Vector2 = (focus / SPACING).floor() * SPACING
	var center_changed: bool = center != next_center
	if center_changed:
		center = next_center
		refresh_wait = 0.0
	refresh_wait -= step
	var refresh: bool = refresh_wait <= 0.0
	if refresh:
		_bind_surfaces()
		refresh_wait = REFRESH
	var fallback: bool = surface_materials.is_empty()
	if fallback:
		if center_changed or not _fallback_active: _place_ground()
		# Native road construction may finish a few frames after race startup.
		if refresh or not _fallback_active:
			if not sources_checked and is_instance_valid(bank_visual):
				if not _prepare_visual_sources(source_track) and anchors.is_empty(): _prepare_contact_sources(source_track)
			elif anchors.is_empty(): _prepare_contact_sources(source_track)
			_place_banks(focus)
	else:
		if ground.multimesh.visible_instance_count != 0: ground.multimesh.visible_instance_count = 0
		if powder.multimesh.visible_instance_count != 0: powder.multimesh.visible_instance_count = 0
	_fallback_active = fallback
	for material: ShaderMaterial in ([ground_material, powder_material,airborne.material_override] if fallback else [airborne.material_override]):
		material.set_shader_parameter("elapsed", elapsed)
		material.set_shader_parameter("travel", travel)
		material.set_shader_parameter("strength", intensity)
		material.set_shader_parameter("focus", VisualGeometry.world(focus))
	airborne.multimesh.custom_aabb = AABB(VisualGeometry.world(focus)+Vector3(-80,-1,-80),Vector3(160,6,160))
	last_focus = focus
	_sync_surfaces()

func _bind_surfaces() -> void:
	if not enabled or not is_instance_valid(bank_visual): return
	# Let prepared-world recording finish before installing run-owned finishes.
	if bank_visual is NativeTrackVisual and not (bank_visual as NativeTrackVisual).world_built: return
	# Native roads/bridges arrive as prepared children. After the sliced build,
	# stable worlds need only this count check, not recurring scene traversal.
	var count: int = bank_visual.get_child_count()
	# A replacement can retain the child count. Validate weak owners and the
	# installed binding before treating integration as ready for this world.
	var bindings_live: bool = surface_bindings.all(func(binding: Dictionary) -> bool:
		var mesh: MeshInstance3D = binding.node.get_ref() as MeshInstance3D
		return is_instance_valid(mesh) and (mesh.material_override if binding.surface < 0 else mesh.get_surface_override_material(binding.surface)) == binding.material)
	if count == surface_child_count and bindings_live: return
	if not bindings_live: _release_surfaces()
	surface_child_count = count
	var pending: Array[Node] = [bank_visual]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child: Node in node.get_children(): pending.append(child)
		if not node is MeshInstance3D: continue
		var mesh: MeshInstance3D = node
		if mesh.mesh == null: continue
		if mesh.material_override is ShaderMaterial:
			_bind_surface(mesh,-1,mesh.material_override as ShaderMaterial)
		elif mesh.material_override == null:
			for index: int in range(mesh.mesh.get_surface_count()):
				var material: Material = mesh.get_active_material(index)
				if material is ShaderMaterial: _bind_surface(mesh,index,material as ShaderMaterial)

func _bind_surface(mesh: MeshInstance3D, index: int, original: ShaderMaterial) -> void:
	if original in surface_materials or original.shader == null: return
	var code: String = original.shader.code
	if not code.contains("wind_surface_strength"): return
	if not (code.contains("const bool winter_snow = true;") or code.contains("const bool icy_road = true;")
		or original.get_shader_parameter("winter_snow") == true or original.get_shader_parameter("icy_road") == true): return
	# Cache resources stay immutable. All uses of a material share one run-owned
	# duplicate, restored exactly when the weather node is removed/reconfigured.
	var key: int = original.get_instance_id()
	var material: ShaderMaterial
	if surface_instances.has(key): material = surface_instances[key]
	else:
		material = original.duplicate() as ShaderMaterial
		material.set_shader_parameter("wind_surface_flow",preload("res://assets/textures/winter_wind_flow_v1.png"))
		surface_instances[key] = material
		surface_materials.append(material)
	var previous: Material = mesh.material_override if index < 0 else mesh.get_surface_override_material(index)
	surface_bindings.append({"node":weakref(mesh),"surface":index,"original":previous,"material":material})
	if index < 0: mesh.material_override = material
	else: mesh.set_surface_override_material(index,material)

func _sync_surfaces() -> void:
	var car_point := Vector2(last_focus.x,-last_focus.y)
	if is_instance_valid(car_visual): car_point = Vector2(car_visual.global_position.x,car_visual.global_position.z)
	if airborne != null: (airborne.material_override as ShaderMaterial).set_shader_parameter("protected_car",car_point)
	for material: ShaderMaterial in surface_materials:
		material.set_shader_parameter("wind_surface_elapsed",elapsed)
		material.set_shader_parameter("wind_surface_travel",travel)
		material.set_shader_parameter("wind_surface_strength",intensity if enabled and is_visible_in_tree() else 0.0)
		material.set_shader_parameter("wind_surface_focus",Vector2(last_focus.x,-last_focus.y))
		material.set_shader_parameter("wind_surface_car",car_point)

func _release_surfaces() -> void:
	for material: ShaderMaterial in surface_materials: material.set_shader_parameter("wind_surface_strength",0.0)
	for binding: Dictionary in surface_bindings:
		var mesh: MeshInstance3D = binding.node.get_ref() as MeshInstance3D
		if not is_instance_valid(mesh): continue
		var index: int = binding.surface
		if index < 0 and mesh.material_override == binding.material: mesh.material_override = binding.original
		elif index >= 0 and mesh.get_surface_override_material(index) == binding.material: mesh.set_surface_override_material(index,binding.original)
	surface_materials.clear(); surface_instances.clear(); surface_bindings.clear()
	surface_child_count = -1

func _exit_tree() -> void:
	_release_surfaces()

func _air_batch() -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = "AirborneGrains"
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := QuadMesh.new()
	mesh.orientation = PlaneMesh.FACE_Y
	mesh.size = Vector2(0.10,0.025)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.mesh = mesh
	instances.instance_count = AIR_GRAINS
	for i: int in range(AIR_GRAINS):
		instances.set_instance_transform(i,Transform3D.IDENTITY)
		instances.set_instance_custom_data(i,Color(_hash(Vector2(i,13)),_hash(Vector2(i,31)),_hash(Vector2(i,47)),1.0))
	node.multimesh = instances
	var material := ShaderMaterial.new()
	material.shader = preload("res://track/winter_air_snow.gdshader")
	node.material_override = material
	add_child(node)
	return node

func _batch(label: String, count: int, bank: bool) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh: PlaneMesh = PlaneMesh.new() if bank else QuadMesh.new()
	mesh.orientation = PlaneMesh.FACE_Y
	mesh.size = Vector2(12.0, 3.0) if bank else Vector2(14.0, 2.1)
	if bank:
		# Six short spans let a connected sheet descend from crest to road.
		# One reusable mesh, no per-frame surface queries or billboard rotation.
		mesh.subdivide_width = 5
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
	for y: int in range(-3, 4):
		for x: int in range(-3, 4):
			var point: Vector2 = center + Vector2(x, y) * SPACING
			var seed: float = _hash(point)
			var at: Vector3 = VisualGeometry.world(point + Vector2(seed - 0.5, _hash(point + Vector2.ONE) - 0.5) * 3.5)
			at.y = 0.065
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
	powder.multimesh.custom_aabb = AABB(world_focus + Vector3(-46, -1, -46), Vector3(92, 6, 92))

func _hash(point: Vector2) -> float:
	return fposmod(sin(point.dot(Vector2(12.9898, 78.233))) * 43758.5453, 1.0)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]: suspended = true
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]: suspended = false
	elif what == NOTIFICATION_VISIBILITY_CHANGED: _sync_surfaces()
