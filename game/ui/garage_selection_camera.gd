extends RefCounted
## The selection composition uses the showroom's existing presentation callback.
var _showroom: CarShowroom
var _active: bool = false
var _ratio: float = 0.275

func sync(view: CarShowroom, enabled: bool, panel_ratio: float) -> void:
	if not enabled:
		clear()
		return
	var changed: bool = not _active or _showroom != view or not is_equal_approx(_ratio,panel_ratio)
	_showroom = view
	_ratio = panel_ratio
	_active = true
	view.customisation_orbit = _orbit
	if changed and is_instance_valid(view.camera): _orbit()

func _orbit() -> void:
	if not is_instance_valid(_showroom) or not is_instance_valid(_showroom.camera): return
	var view: CarShowroom = _showroom
	var tall: bool = view.vehicle_id == "forklift"
	var wide: bool = view.vehicle_id in ["electric","hovercraft"]
	var distance: float = view.garage_distance*view.zoom*(0.96 if tall else 0.68 if wide else 0.56)
	var angle: float = view.elevation+0.04
	var target := Vector3(0,(1.40 if tall else 0.52)+GarageEnvironment.DECK_HEIGHT,0)
	var point: Vector3 = target+Vector3(0,sin(angle)*distance,-cos(angle)*distance)
	view.camera.transform = Transform3D(Basis.IDENTITY,point).looking_at(target)
	view.camera.h_offset = -_ratio*3.8
	view._update_roof()
	view.invalidate_render()

func clear() -> void:
	if not _active: return
	_active = false
	if is_instance_valid(_showroom) and _showroom.customisation_orbit == _orbit:
		_showroom.customisation_orbit = Callable()
		if is_instance_valid(_showroom.camera):
			_showroom.camera.h_offset = 0.0
			if _showroom.camera.is_inside_tree(): _showroom._orbit()
	_showroom = null
