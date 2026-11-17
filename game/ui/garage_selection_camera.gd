extends RefCounted
## The selection composition uses the showroom's existing presentation callback.
var _showroom: CarShowroom
var _active: bool = false
var _ratio: float = 0.275
# Shared clearance for all six stock cars, including rotation and the mast.
const CAR_RADIUS: float = 2.55
const CAR_TOP: float = 2.85

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
	# One room composition for every car, with clearance for the Forklift mast.
	# Browsing only replaces the car; tilt and zoom remain player-controlled.
	var angle: float = view.elevation+0.04
	var target := Vector3(0,1.0+GarageEnvironment.DECK_HEIGHT,0)
	var direction := Vector3(0,sin(angle),-cos(angle))
	var basis: Basis = Transform3D(Basis.IDENTITY,target+direction).looking_at(target).basis
	var aspect: float = view.size.x/maxf(1.0,view.size.y)
	var tangent: float = tan(deg_to_rad(view.camera.fov)*0.5)
	var minimum: float = _minimum_distance(view,basis,target,tangent,aspect)
	# Leave usable zoom-in travel, then stop before any car can cross an edge.
	var home: float = maxf(view.garage_distance*0.96,minimum*1.18)
	view.zoom = maxf(view.zoom,minimum/home)
	var distance: float = home*view.zoom
	var point: Vector3 = target+direction*distance
	view.camera.transform = Transform3D(Basis.IDENTITY,point).looking_at(target)
	# Offset in proportion to distance so zoom stays centred beside the stats.
	view.camera.h_offset = -_ratio*distance*tangent*aspect
	view._update_roof()
	view.invalidate_render()

func _minimum_distance(view: CarShowroom, basis: Basis, target: Vector3, tangent: float, aspect: float) -> float:
	var horizontal: float = tangent*aspect
	var shift: float = _ratio*horizontal
	var left: float = (2.0*(_ratio+16.0/maxf(1.0,view.size.x))-1.0)*horizontal
	var right: float = (1.0-32.0/maxf(1.0,view.size.x))*horizontal
	var top: float = tangent*(1.0-32.0/maxf(1.0,view.size.y))
	var bottom: float = tangent*(1.0-96.0/maxf(1.0,view.size.y))
	var distance: float = 0.0
	# A circumscribed cylinder covers every turntable yaw without refitting to
	# the selected model. No car geometry scan or car-dependent camera change.
	var radius: float = CAR_RADIUS/cos(PI/16.0)
	for step: int in range(16):
		var azimuth: float = TAU*step/16.0
		for height: float in [GarageEnvironment.DECK_HEIGHT,CAR_TOP]:
			var point: Vector3 = basis.transposed()*(Vector3(sin(azimuth)*radius,height,cos(azimuth)*radius)-target)
			distance = maxf(distance,(point.x+right*point.z)/maxf(0.01,right-shift))
			distance = maxf(distance,(-point.x-left*point.z)/maxf(0.01,shift-left))
			distance = maxf(distance,point.z+maxf(point.y/maxf(0.01,top),-point.y/maxf(0.01,bottom)))
	return distance+0.08

func clear() -> void:
	if not _active: return
	_active = false
	if is_instance_valid(_showroom) and _showroom.customisation_orbit == _orbit:
		_showroom.customisation_orbit = Callable()
		if is_instance_valid(_showroom.camera):
			_showroom.camera.h_offset = 0.0
			if _showroom.camera.is_inside_tree(): _showroom._orbit()
	_showroom = null
