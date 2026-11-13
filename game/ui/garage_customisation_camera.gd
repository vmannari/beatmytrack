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
var _body_corners := PackedVector3Array()
var _viewport_size := Vector2i.ZERO

func focus(showroom: CarShowroom, category: String) -> void:
	if not is_instance_valid(showroom) or not showroom.is_inside_tree() or not showroom.garage_mode or showroom.read_only: return
	if _showroom==showroom and focused_category==category:
		if _viewport_size!=showroom.showroom_viewport.size: _resize_focus(showroom)
		return
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
			direction = Vector3(2.4,3.0,-4)
			distance = 3.6
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
	if showroom.car.vehicle_id == "super_rally":
		match category:
			"hood": local_target = Vector3(0,0.95,-1.35); direction = Vector3(2,2.5,-4); distance = 3.2
			"aero": local_target = Vector3(0,1.0,1.88); direction = Vector3(2,1.5,4); distance = 3.3
			"roof": local_target = Vector3(0,1.40,0.35); direction = Vector3(0.5,4,-1.5); distance = 2.9
	if showroom.car.vehicle_id=="kart":
		match category:
			"hood": local_target = Vector3(0,0.35,-1.05); direction = Vector3(2,2.5,-4); distance = 2.4
			"aero": local_target = Vector3(0,0.23,1.23); direction = Vector3(2,1.4,4); distance = 2.3
			"rims": local_target = Vector3(0.61,0.22,-0.88); direction = Vector3(4,1,-0.8); distance = 1.65
	if showroom.car.vehicle_id=="hovercraft":
		match category:
			"hood": local_target = Vector3(0,0.75,-1.55); direction = Vector3(2,2.5,-4); distance = 3.2
			"aero": local_target = Vector3(0,1.3,1.65); direction = Vector3(2,1.5,4); distance = 3.5
			"rims": local_target = Vector3(0.52,1.03,1.25); direction = Vector3(1.5,1,-4); distance = 2.5
	if showroom.car.vehicle_id == "forklift":
		match category:
			"hood": local_target = Vector3(0,1.48,1.05); direction = Vector3(1.5,3,4); distance = 2.8
			"aero": local_target = Vector3(0,0.75,1.65); direction = Vector3(2,1.3,4); distance = 2.8
			"rims": local_target = Vector3(0.8,0.43,-0.93); direction = Vector3(4,1,-1); distance = 2.2
			"body_kit": local_target = Vector3(0,1.94,0.02); direction = Vector3(3,2.1,-3.6); distance = 4.4
	# Narrow landscape panes still fit the selected region horizontally.
	var aspect: float = showroom.size.x / maxf(1.0,showroom.size.y)
	var whole_body: bool = category in ["body","body_kit"] and not (category=="body_kit" and showroom.car.vehicle_id=="forklift")
	if not whole_body: distance *= maxf(1.0,0.95/maxf(0.4,aspect))
	var frame: Transform3D = showroom.car.global_transform
	_local_target = local_target*HandlingConfig.BODY_SCALE
	if whole_body: _local_target = _model_bounds(showroom.car).get_center()
	_direction = frame.basis.orthonormalized()*direction.normalized()
	if category == "body":
		# Paint needs a raised view: the low Garage angle wastes vertical space.
		var home_direction: Vector3 = _home.basis.z.normalized()
		var elevation: float = maxf(asin(home_direction.y),deg_to_rad(30.0))
		var horizontal := Vector3(home_direction.x,0,home_direction.z).normalized()
		_direction = horizontal*cos(elevation)+Vector3.UP*sin(elevation)
	target = frame*_local_target
	if whole_body: distance = _fit_body(showroom,_model_bounds(showroom.car),target,_direction)
	_distance = distance
	_focus_zoom = showroom.zoom
	_focus_elevation = showroom.elevation
	_viewport_size = showroom.showroom_viewport.size
	showroom.customisation_orbit = _orbit.bind(showroom)
	var position: Vector3 = target+_direction*distance
	var destination := Transform3D(Basis.IDENTITY,position).looking_at(target)
	_animate(showroom,destination)

func _animate(showroom: CarShowroom, destination: Transform3D) -> void:
	if showroom.camera_motion != null: showroom.camera_motion.kill()
	var start: Transform3D = showroom.camera.transform
	showroom.camera_motion = showroom.create_tween()
	showroom.camera_motion.tween_method(_blend.bind(showroom,start,destination),0.0,1.0,0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _resize_focus(showroom: CarShowroom) -> void:
	# A resize can refit distance without discarding the player's angle or zoom.
	var moving: bool = showroom.camera_motion!=null and showroom.camera_motion.is_running()
	var direction: Vector3 = _direction if moving else showroom.camera.basis.z.normalized()
	var previous_aspect: float = float(_viewport_size.x)/maxf(1.0,_viewport_size.y)
	var aspect: float = showroom.size.x/maxf(1.0,showroom.size.y)
	target = showroom.car.global_transform*_local_target
	if focused_category in ["body","body_kit"] and not (focused_category=="body_kit" and showroom.car.vehicle_id=="forklift"):
		_distance = _fit_body(showroom,_model_bounds(showroom.car),target,direction)
	else:
		_distance *= maxf(1.0,0.95/maxf(0.4,aspect))/maxf(1.0,0.95/maxf(0.4,previous_aspect))
	_direction = direction
	_focus_elevation = showroom.elevation
	_viewport_size = showroom.showroom_viewport.size
	var position: Vector3 = target+direction*_distance*showroom.zoom/_focus_zoom
	var destination := Transform3D(Basis.IDENTITY,position).looking_at(target)
	if moving: _animate(showroom,destination)
	else:
		showroom.camera.transform = destination
		showroom._update_roof()
		showroom.invalidate_render()

func _model_bounds(car: CarVisual) -> AABB:
	var key: Array = [car.get_instance_id(),car.customisation]
	if key == _body_key: return _body_bounds
	_body_key = [car.get_instance_id(),car.customisation.duplicate(true)]
	_body_corners.clear()
	var first: bool = true
	var inverse: Transform3D = car.global_transform.affine_inverse()
	for node: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if node.mesh == null or not node.is_visible_in_tree(): continue
		var mesh_to_car: Transform3D = inverse*node.global_transform
		var mesh_box: AABB = node.mesh.get_aabb()
		var box: AABB = mesh_to_car*mesh_box
		_body_bounds = box if first else _body_bounds.merge(box)
		first = false
		for x: float in [mesh_box.position.x,mesh_box.end.x]:
			for y: float in [mesh_box.position.y,mesh_box.end.y]:
				for z: float in [mesh_box.position.z,mesh_box.end.z]:
					_body_corners.append(mesh_to_car*Vector3(x,y,z))
	return _body_bounds

func _fit_body(showroom: CarShowroom, bounds: AABB, center: Vector3, direction: Vector3) -> float:
	var basis: Basis = Transform3D(Basis.IDENTITY,center+direction).looking_at(center).basis
	var tangent: float = tan(deg_to_rad(showroom.camera.fov)*0.5)
	var aspect: float = showroom.size.x/maxf(1.0,showroom.size.y)
	var reserved_height: float = 128.0 if focused_category=="body" else 144.0
	var vertical: float = clampf(1.0-reserved_height/maxf(1.0,showroom.size.y),0.52,0.82)
	var distance: float = 2.0
	var corners: PackedVector3Array = _body_corners if focused_category=="body" else PackedVector3Array()
	# Whole-box corners include empty air above the nose and beyond the roof.
	# Paint fits each visible mesh; the low Body kits framing stays unchanged.
	if corners.is_empty():
		for x: float in [bounds.position.x,bounds.end.x]:
			for y: float in [bounds.position.y,bounds.end.y]:
				for z: float in [bounds.position.z,bounds.end.z]: corners.append(Vector3(x,y,z))
	for corner: Vector3 in corners:
		var point: Vector3 = basis.transposed()*(showroom.car.global_transform*corner-center)
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
