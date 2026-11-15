extends Node3D
## Installed prepared world; no procedural geometry construction.
const VERSION: String = preload("res://track/track_visual_identity.gd").VERSION
const PREPARED_WORLDS = preload("res://track/prepared_world_cache.gd")
var scenery_lods: bool = true # False is an offline full-detail comparison control.
var piece_road_materials: bool = false
var desert_relief: RefCounted
var ground_support: RefCounted
var _suppress_night_fx: bool=false
var partition_night_ground: bool = true
var partition_static_meshes: bool = true
var uniform_terrain_regions: bool = true
var _menu_slices: bool = false
var profile_build: bool = false
var build_costs: Dictionary = {}
var build_stage: String = "initial"
var preserve_relief_surfaces: bool = false
var build_current: Callable
var _slice_started: int = 0
var theme_id: String = "pine"
var editor_preview: bool = false
var colors: Array[Color] = []
var tyre_instances: MultiMeshInstance3D
var _tyre_positions := PackedVector2Array()
var _tyre_spins: Array[float] = []
var light_instances: Array[Node3D] = []
var _prop_draw_states: Array[Dictionary] = []
var scenic_count: int = 0
var race_road_packet: Dictionary = {}
var persist_road_meshes: bool = true
var cache_race_world: bool = false
var persist_race_world: bool = true
var _world_disk_id: String = ""
var world_built: bool = false

func _build_is_current() -> bool:
	return is_inside_tree() and (not build_current.is_valid() or build_current.call())

func _menu_yield_due() -> bool:
	return _menu_slices and Time.get_ticks_usec()-_slice_started >= 6000

func _yield_build() -> bool:
	if not _build_is_current(): return false
	if _menu_yield_due():
		await get_tree().process_frame
		_slice_started = Time.get_ticks_usec()
	return _build_is_current()

func update_tyres(state: VehicleState, origins: PackedVector2Array) -> void:
	if tyre_instances == null: return
	if _tyre_positions.size() != origins.size():
		_tyre_positions.resize(origins.size())
		_tyre_spins.resize(origins.size())
		_tyre_spins.fill(NAN)
	for i: int in range(origins.size()):
		var p: Vector2 = origins[i]
		var spin: float = 0.0
		if i < state.loose_tyres.size():
			var tyre: Array = state.loose_tyres[i]
			p = Vector2(tyre[0],tyre[1])
			spin = tyre[4]
		# Only presentation data is cached. Reset and moving tyres still upload
		# their exact transforms; resting stacks do not dirty the GPU buffer.
		if _tyre_positions[i] == p and _tyre_spins[i] == spin: continue
		_tyre_positions[i] = p
		_tyre_spins[i] = spin
		var pose: Transform3D = Transform3D(Basis(Vector3.UP,spin),VisualGeometry.world(p)+Vector3.UP*(0.014+(ground_support.ground(p) if ground_support != null else 0.0)+(desert_relief.height(p) if desert_relief != null else 0.0)))
		if tyre_instances.has_method("set_pose"): tyre_instances.set_pose(i,pose)
		else: tyre_instances.multimesh.set_instance_transform(i,pose)
	if tyre_instances.has_method("flush"): tyre_instances.flush()

func update_light_props(state: VehicleState) -> void:
	_prop_draw_states.resize(light_instances.size())
	for index: int in range(light_instances.size()):
		var node: Node3D = light_instances[index]
		var origin: Vector3 = node.get_meta("prop_origin",node.position)
		var row: Array = state.light_props[index] if index < state.light_props.size() else [origin.x,-origin.z,0.0,0.0,0.0]
		var integrity: float = float(state.prop_destruction[index][0]) if index < state.prop_destruction.size() else 1.0
		var previous: Dictionary = _prop_draw_states[index]
		if previous != null and previous.get("node") == node.get_instance_id() and previous.row == row and previous.integrity == integrity: continue
		# Own a copy: canonical/rewind rows can be edited in place at the same tick.
		_prop_draw_states[index] = {"node":node.get_instance_id(),"row":row.duplicate(),"integrity":integrity}
		var base_height: float=origin.y if node.has_meta("burning_barrel_scale") else node.position.y
		var at := Vector3(row[0],0.014+(ground_support.ground(Vector2(row[0],row[1])) if ground_support != null else base_height-0.014),-float(row[1]))
		if desert_relief != null: at.y += desert_relief.height(Vector2(row[0],row[1]))
		if node.position != at: node.position = at
		if node.has_meta("burning_barrel_scale"): BurningBarrelVisual.present(node,row,at.y-0.014)
		elif node.has_meta("breakable_kind"): BreakablePropVisual.present(node,row,integrity)
		else: node.rotation.z = float(row[4])*0.9
	var fire: NightPropEffects=get_node_or_null("NightPropEffects")
	if fire!=null: fire.sync_barrels(light_instances,state)
	BreakablePropVisual.update_debris(self,state)

func restore(track: NativeTrack, bridge: BridgePresentation, menu_slices: bool = false) -> bool:
	ground_support = bridge.road_surface
	world_built = false
	_menu_slices = menu_slices
	_slice_started = Time.get_ticks_usec() if menu_slices else 0
	theme_id = TrackTheme.normalized(str(track.metadata.get("theme", "pine")))
	desert_relief = bridge.visual_relief
	colors = TrackTheme.palette(theme_id)
	set_meta("spatial_mask_budget_bytes",track.cells.size()*(20 if desert_relief != null else 16))
	var visual_version: String = VERSION if partition_static_meshes and uniform_terrain_regions else VERSION+"/"+str(partition_static_meshes)+"/"+str(uniform_terrain_regions)
	var world_key: Array = [track.content_hash,visual_version,ContactShading.VERSION,CreatorPropVisual.VERSION,theme_id,colors,partition_night_ground]
	var world_options: Array = [scenery_lods,piece_road_materials,preserve_relief_surfaces,_suppress_night_fx,VisualGeometry.optimize_model_geometry]
	world_key.append(world_options)
	var reuse_world: bool = cache_race_world and not editor_preview
	if reuse_world:
		var identity_started: int = Time.get_ticks_usec() if profile_build else 0
		_world_disk_id = ""
		if persist_race_world and persist_road_meshes:
			var disk = load("res://track/prepared_world_disk_cache.gd")
			_world_disk_id = await disk.identity_cooperative(world_key,world_options,self) if _menu_slices else disk.identity(world_key,world_options)
		if _menu_slices and not _build_is_current(): return false
		if profile_build: build_costs.world_disk_identity_us = Time.get_ticks_usec()-identity_started
		var restored: bool = await PREPARED_WORLDS.restore_cooperative(world_key,self) if _menu_slices else PREPARED_WORLDS.restore(world_key,self)
		if _menu_slices and not _build_is_current(): return false
		if restored:
			race_road_packet = {}
			world_built = true
			return true
	return false
