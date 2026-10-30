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
var _home_yaw: float
var _home_elevation: float
var _home_zoom: float
var _body_key: Array = []
var _body_bounds: AABB

func focus(showroom: CarShowroom, category: String) -> void:
	if not is_instance_valid(showroom) or not showroom.is_inside_tree() or not showroom.garage_mode or showroom.read_only: return
	showroom.finish_car_transition()
	if focused_category.is_empty():
		if showroom.camera_motion != null and showroom.camera_motion.is_running(): showroom._orbit()
		_showroom = showroom
		_home = showroom.camera.transform
		_home_yaw = showroom.yaw
		_home_elevation = showroom.elevation
		_home_zoom = showroom.zoom
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
		"body_kit":
			# Low front three-quarter view exposes the bumper, arches and sills.
			direction = Vector3(3,0.95,-4)
	if showroom.car.vehicle_id == "forklift" and category == "hood":
		local_target = Vector3(0,1.02,1.56)
		direction = Vector3(0.5,0.8,4)
		distance = 2.6
	# Narrow landscape panes still fit the selected region horizontally.
	var aspect: float = showroom.size.x / maxf(1.0,showroom.size.y)
	var whole_body: bool = category in ["body","body_kit"]
	if not whole_body: distance *= maxf(1.0,0.95/maxf(0.4,aspect))
	var frame: Transform3D = showroom.car.global_transform
	_local_target = local_target*HandlingConfig.BODY_SCALE
	if whole_body: _local_target = _model_bounds(showroom.car).get_center()
	_direction = frame.basis.orthonormalized()*direction.normalized()
	if category == "body": _direction = _home.basis.z.normalized()
	target = frame*_local_target
	if whole_body: distance = _fit_body(showroom,_model_bounds(showroom.car),target,_direction)
	_distance = distance
	_focus_zoom = showroom.zoom
	_focus_elevation = showroom.elevation
	showroom.customisation_orbit = _orbit.bind(showroom)
	var position: Vector3 = target+_direction*distance
	var destination := Transform3D(Basis.IDENTITY,position).looking_at(target)
	if showroom.camera_motion != null: showroom.camera_motion.kill()
	var start: Transform3D = showroom.camera.transform
	showroom.camera_motion = showroom.create_tween()
	showroom.camera_motion.tween_method(_blend.bind(showroom,start,destination),0.0,1.0,0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _model_bounds(car: CarVisual) -> AABB:
	var key: Array = [car.get_instance_id(),car.customisation]
	if key == _body_key: return _body_bounds
	_body_key = [car.get_instance_id(),car.customisation.duplicate(true)]
	var first: bool = true
	var inverse: Transform3D = car.global_transform.affine_inverse()
	for node: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if node.mesh == null or not node.is_visible_in_tree(): continue
		var box: AABB = inverse*node.global_transform*node.mesh.get_aabb()
		_body_bounds = box if first else _body_bounds.merge(box)
		first = false
	return _body_bounds

func _fit_body(showroom: CarShowroom, bounds: AABB, center: Vector3, direction: Vector3) -> float:
	var basis: Basis = Transform3D(Basis.IDENTITY,center+direction).looking_at(center).basis
	var tangent: float = tan(deg_to_rad(showroom.camera.fov)*0.5)
	var aspect: float = showroom.size.x/maxf(1.0,showroom.size.y)
	var vertical: float = clampf(1.0-144.0/maxf(1.0,showroom.size.y),0.52,0.82)
	var distance: float = 2.0
	for x: float in [bounds.position.x,bounds.end.x]:
		for y: float in [bounds.position.y,bounds.end.y]:
			for z: float in [bounds.position.z,bounds.end.z]:
				var point: Vector3 = basis.transposed()*(showroom.car.global_transform*Vector3(x,y,z)-center)
				distance = maxf(distance,point.z+maxf(absf(point.x)/(tangent*aspect*0.88),absf(point.y)/(tangent*vertical))+0.1)
	return distance

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
	_showroom.yaw = _home_yaw
	_showroom.elevation = _home_elevation
	_showroom.zoom = _home_zoom
	if _showroom.is_inside_tree() and _showroom.camera.is_inside_tree(): _showroom._orbit()
	_showroom.camera.transform = _home
	_showroom._update_roof()
	_showroom.invalidate_render()
	_showroom = null
