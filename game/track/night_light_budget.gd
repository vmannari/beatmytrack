extends Node3D
## Deterministic cosmetic selection below both supported per-mesh omni limits.
## Lamp geometry/emission and canonical track/vehicle data remain untouched.
const MAX_ACTIVE: int = 8
const INTERVAL: float = 0.1
const RETAIN_DISTANCE: float = 3.0
var sources: Array[OmniLight3D] = []
var selected: Array[OmniLight3D] = []
var _wait: float = 0.0
var _order: Array[int] = []
var _scores := PackedFloat64Array()

func _ready() -> void: refresh()

static func set_available(light: OmniLight3D, available: bool) -> void:
	light.set_meta("night_light_available",available)
	light.visible = available and bool(light.get_meta("night_budget_selected",true))

func refresh() -> void:
	sources.clear(); selected.clear()
	for node: Node in get_parent().find_children("*","OmniLight3D",true,false):
		if not node.has_meta("night_authored_visible"): node.set_meta("night_authored_visible",node.visible)
		if bool(node.get_meta("night_authored_visible")): sources.append(node)
	_order.clear(); _scores.resize(sources.size())
	# Stable scene order gives a valid bounded state before a camera exists.
	for index: int in range(sources.size()):
		_order.append(index)
		var active: bool = selected.size()<MAX_ACTIVE and bool(sources[index].get_meta("night_light_available",true))
		sources[index].set_meta("night_budget_selected",active)
		sources[index].visible = active
		if active: selected.append(sources[index])
	_wait = 0.0

func update_camera(camera: Camera3D) -> void:
	if camera == null: return
	# Freed typed objects cannot pass a typed callback argument conversion.
	if sources.any(func(node: Variant) -> bool: return not is_instance_valid(node)): refresh()
	if sources.size() <= MAX_ACTIVE: return
	var centre: Vector2 = get_viewport().get_visible_rect().size*0.5
	var origin: Vector3 = camera.project_ray_origin(centre)
	var ray: Vector3 = camera.project_ray_normal(centre)
	var focus: Vector3 = origin-ray*(origin.y/ray.y) if absf(ray.y)>0.0001 else camera.global_position
	for index: int in range(sources.size()):
		var node: OmniLight3D = sources[index]
		var distance: float = node.global_position.distance_to(focus)
		if node in selected: distance = maxf(0.0,distance-RETAIN_DISTANCE)
		_scores[index] = distance if bool(node.get_meta("night_light_available",true)) else INF
	_order.sort_custom(func(a: int,b: int) -> bool: return _scores[a]<_scores[b] if _scores[a]!=_scores[b] else a<b)
	var next: Array[OmniLight3D] = []
	for index: int in range(mini(MAX_ACTIVE,_order.size())):
		if is_finite(_scores[_order[index]]): next.append(sources[_order[index]])
	for node: OmniLight3D in selected:
		if node not in next: node.set_meta("night_budget_selected",false); node.visible = false
	for node: OmniLight3D in next:
		node.set_meta("night_budget_selected",true)
		if not node.visible: node.visible = true
	selected = next

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_wait -= delta
	if _wait > 0.0: return
	_wait = INTERVAL
	update_camera(get_viewport().get_camera_3d())
