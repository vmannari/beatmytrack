extends RefCounted
## Presentation-only camera focus; one retained showroom and its existing tween.
var focused_category: String = ""
var _showroom: CarShowroom
var _home: Transform3D
var target: Vector3
var _local_target: Vector3
var _direction: Vector3
var _distance: float
var _focus_zoom: float
var _focus_elevation: float
var _home_orbit: Vector3

func focus(showroom: CarShowroom, category: String) -> void:
	if not is_instance_valid(showroom) or not showroom.is_inside_tree() or not showroom.garage_mode or showroom.read_only: return
	showroom.finish_car_transition()
	if focused_category.is_empty():
		if showroom.camera_motion != null and showroom.camera_motion.is_running(): showroom._orbit()
		_showroom = showroom
		_home = showroom.camera.transform
		_home_orbit = Vector3(showroom.yaw,showroom.elevation,showroom.zoom)
	focused_category = category
	var local_target := Vector3(0,0.65,0)
	var direction := Vector3(3,1.6,-4)
	var distance: float = 6.2
	match category:
		"hood":
			local_target = Vector3(0,1.0,-1.35)
			direction = Vector3(1.8,2.5,-3.5)
			distance = 3.1
		"aero":
			local_target = Vector3(0,1.25,1.7)
			direction = Vector3(3,1.5,3)
			distance = 3.7
		"rims":
			local_target = Vector3(0.83,0.4,-1.28)
			direction = Vector3(4,1.0,-0.8)
			distance = 2.7
		"roof":
			local_target = Vector3(0,1.5,0.1)
			direction = Vector3(0.5,4,-1.5)
			distance = 3.3
	# Narrow landscape panes still fit the selected region horizontally.
	var aspect: float = showroom.size.x / maxf(1.0,showroom.size.y)
	distance *= maxf(1.0,0.95/maxf(0.4,aspect))
	_local_target = local_target*HandlingConfig.BODY_SCALE
	_direction = showroom.car.global_basis*direction.normalized()
	_distance = distance
	_focus_zoom = showroom.zoom
	_focus_elevation = showroom.elevation
	showroom.customisation_orbit = _orbit.bind(showroom)
	target = showroom.car.global_transform * (local_target*HandlingConfig.BODY_SCALE)
	var position: Vector3 = target + showroom.car.global_basis*direction.normalized()*distance
	var destination := Transform3D(Basis.IDENTITY,position).looking_at(target)
	if showroom.camera_motion != null: showroom.camera_motion.kill()
	var start: Transform3D = showroom.camera.transform
	showroom.camera_motion = showroom.create_tween()
	showroom.camera_motion.tween_method(_blend.bind(showroom,start,destination),0.0,1.0,0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _blend(weight: float, showroom: CarShowroom, start: Transform3D, destination: Transform3D) -> void:
	if not is_instance_valid(showroom) or not showroom.is_inside_tree(): return
	showroom.camera.transform = start.interpolate_with(destination,weight)
	showroom._update_roof()
	showroom.invalidate_render()

func _orbit(showroom: CarShowroom) -> void:
	if not showroom.is_inside_tree(): return
	target = showroom.car.global_transform*_local_target
	var elevation: float = clampf(asin(_direction.y)+showroom.elevation-_focus_elevation,CarShowroom.MIN_ELEVATION,CarShowroom.MAX_ELEVATION)
	var horizontal := Vector3(_direction.x,0,_direction.z).normalized()*cos(elevation)
	var offset := Vector3(horizontal.x,sin(elevation),horizontal.z)*_distance*showroom.zoom/_focus_zoom
	showroom.camera.look_at_from_position(target+offset,target)
	showroom._update_roof()
	showroom.invalidate_render()

func clear() -> void:
	if focused_category.is_empty(): return
	focused_category = ""
	if not is_instance_valid(_showroom): return
	if _showroom.camera_motion != null: _showroom.camera_motion.kill()
	_showroom.customisation_orbit = Callable()
	_showroom.yaw = _home_orbit.x
	_showroom.elevation = _home_orbit.y
	_showroom.zoom = _home_orbit.z
	if _showroom.is_inside_tree() and _showroom.camera.is_inside_tree(): _showroom._orbit()
	_showroom.camera.transform = _home
	_showroom._update_roof()
	_showroom.invalidate_render()
	_showroom = null
