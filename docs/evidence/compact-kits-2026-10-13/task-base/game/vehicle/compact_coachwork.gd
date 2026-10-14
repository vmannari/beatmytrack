class_name CompactCoachwork
extends RefCounted
## Original fictional compact surfaces. Model metres, independent of collision.
## Editable analytical patches with authored UV atlas regions and smooth normals.
static var meshes: Dictionary = {}
static var use_baked: bool = true
const ASSET_ROOT: String = "res://assets/vehicles/compact_coachwork_v3"
const SIDE_WINDOW_BOTTOM: float = 1.08
const SIDE_WINDOW_TOP: float = 1.422
const B_PILLAR_FRONT: float = 0.59
const B_PILLAR_REAR: float = 0.66
const DOOR_REAR: float = (B_PILLAR_FRONT+B_PILLAR_REAR)*0.5
const DOOR_BOTTOM: float = 0.43

static func side_window_corners(side: float,front: bool) -> Array[Vector3]:
	var corners: Array[Vector3]=[]
	for vertex: Vector2 in [Vector2(0,SIDE_WINDOW_BOTTOM),Vector2(1,SIDE_WINDOW_BOTTOM),Vector2(1,SIDE_WINDOW_TOP),Vector2(0,SIDE_WINDOW_TOP)]:
		var height: float=(vertex.y-1.01)/0.47
		var a: Vector3=cabin_side_point(side,0,height)
		var b: Vector3=cabin_side_point(side,1,height)
		var leading: float=a.z+0.048 if front else B_PILLAR_REAR
		var trailing: float=B_PILLAR_FRONT if front else b.z-0.065
		corners.append(Vector3(a.x+side*0.005,vertex.y,lerpf(leading,trailing,vertex.x)))
	return corners

static func door_outline() -> Array[Vector2]:
	# Z/Y profile: the lower leading edge clears the front arch, while the
	# trailing edge lines up with the shared window pillar above it.
	return [Vector2(-0.91,1.01),Vector2(DOOR_REAR,1.01),Vector2(DOOR_REAR,DOOR_BOTTOM),Vector2(-0.70,DOOR_BOTTOM)]

static func build_body(car: CarVisual, paint: Material) -> void:
	for side: float in [-1.0,1.0]:
		_patch(car,"CurvedBody",96,24,func(u: float,v: float) -> Vector3:
			# The first 24 stations coincide with the hood's side boundary.
			var station: float=u*96.0
			var z: float=lerpf(-1.84,-1.015,station/24.0) if station<=24 else lerpf(-1.015,1.75,(station-24)/72.0)
			var lower: float = 0.33
			for axle: float in [-1.28,1.28]:
				var offset: float = absf(z-axle)
				if offset < 0.421: lower = maxf(lower,0.37+sqrt(0.421*0.421-offset*offset))
			var upper: float = body_upper(z)
			# Keep shoulder rows at consistent heights instead of stretching
			# their reflection samples with the wheel-opening boundary.
			var y: float = maxf(lower,body_height(v,upper))
			var width: float = body_width(y,z)
			return Vector3(side*width,y,z),paint,Vector3(side,0.1,0),Rect2(0 if side < 0 else 0.25,0,0.25,1))
	# Sealed black underside remains visible only during rollover.
	VisualGeometry.box(car.body,Vector3(1.56,0.055,3.98),Vector3(0,0.34,0),car.underside_material)
	# One profile owns every side/corner/rear/hatch boundary.
	for side: float in [-1.0,1.0]:
		_patch(car,"RearShoulder",12,24,func(u: float,v: float) -> Vector3:
			return rear_shoulder_point(side,u,v),paint,Vector3(side,0.1,0),Rect2(0,0,1,1))
		_patch(car,"RearCorner",24,24,func(u: float,v: float) -> Vector3:
			return rear_corner_point(side,u,v),paint,Vector3(side,0.1,1),Rect2(0,0,1,1))
	var rear_finish: StandardMaterial3D=CompactFinish.paint((paint as StandardMaterial3D).albedo_color)
	rear_finish.roughness=0.68
	rear_finish.clearcoat_enabled=false
	rear_finish.metallic_specular=0.20
	car.paint_variants.append({"material":rear_finish,"slot":"body","darken":0.0})
	_patch(car,"RearCoachwork",40,24,func(u: float,v: float) -> Vector3:
		return rear_face_point(u,v),rear_finish,Vector3.BACK,Rect2(0.5,0.85,0.25,0.15))

static func body_width(y: float, z: float) -> float:
	# Front taper belongs to the continuous nose curve, never a separate side.
	return width_at_height(y)-front_roll(y,body_upper(z))*(1-smoothstep(-1.015,-0.95,z))

static func body_height(v: float,upper: float) -> float:
	return lerpf(0.33,0.80,v*3.0) if v<=1.0/3.0 else lerpf(0.80,upper,(v-1.0/3.0)*1.5)

static func body_fraction(height: float,upper: float) -> float:
	return clampf((height-0.33)/0.47/3.0,0,1.0/3.0) if height<=0.80 else clampf(1.0/3.0+(height-0.80)/(upper-0.80)/1.5,1.0/3.0,1)

static func front_roll(height: float,top: float) -> float:
	var t: float=clampf((height-top+0.03)/0.03,0,1)
	return 0.03*(1-sqrt(maxf(0,1-t*t)))

static func front_rim_width() -> float:
	return width_at_height(0.976)-0.03

static func body_upper(z: float) -> float:
	if z<=-1.015:return lerpf(0.976,1.048,clampf((z+1.84)/0.825,0,1))
	return lerpf(1.048,1.01,smoothstep(-1.015,-0.95,z))

static func width_at_height(y: float) -> float:
	var swell: float=sin(clampf((y-0.33)/0.53,0,1)*PI)
	return 0.88+0.012*swell*swell-0.12*smoothstep(0.85,1.01,y)

static func _hermite_end(a: float, b: float, slope: float, t: float) -> float:
	t=clampf(t,0,1)
	return a*(2*t*t*t-3*t*t+1)+b*(-2*t*t*t+3*t*t)+slope*(t*t*t-t*t)

static func rear_depth(y: float) -> float:
	return _hermite_end(2.03,1.91,-0.73/0.47/0.97*0.21,(y-0.80)/0.21)

static func rear_radius(y: float) -> float:
	return _hermite_end(0.19,0.12,-0.06/0.47/0.97*0.21,(y-0.80)/0.21)

static func _rounded_rear_z(x: float, width: float, depth: float, radius: float) -> float:
	var corner: float = clampf(absf(x)-(width-radius),0,radius)
	return depth-radius+sqrt(maxf(0,radius*radius-corner*corner))

static func rear_handle_recess(x: float,y: float) -> float:
	return 0.014*(1-smoothstep(0.145,0.182,absf(x)))*(1-smoothstep(0.033,0.058,absf(y-0.898)))

static func rear_skin(x: float, y: float) -> float:
	if y>1.01:
		var v: float = clampf((y-1.01)/0.47,0,1)
		return _rounded_rear_z(x,cabin_width(v),lerpf(1.91,1.18,cabin_depth_progress(v)),lerpf(0.12,0.06,cabin_depth_progress(v)))
	return _rounded_rear_z(x,width_at_height(y),rear_depth(y),rear_radius(y))-rear_handle_recess(x,y)

static func rear_shoulder_point(side: float, u: float, v: float) -> Vector3:
	var y: float = body_height(v,1.01)
	return Vector3(side*width_at_height(y),y,lerpf(1.75,rear_depth(y)-rear_radius(y),u))

static func rear_corner_point(side: float, u: float, v: float) -> Vector3:
	var y: float = body_height(v,1.01)
	var r: float = rear_radius(y)
	var angle: float = u*PI*0.5
	return Vector3(side*(width_at_height(y)-r+r*cos(angle)),y,rear_depth(y)-r+r*sin(angle))

static func rear_face_point(u: float, v: float) -> Vector3:
	var y: float = body_height(v,1.01)
	var x: float=lerpf(-1,1,u)*(width_at_height(y)-rear_radius(y))
	return Vector3(x,y,rear_skin(x,y))

static func cabin_depth_progress(v: float) -> float:
	return 1.0-pow(1.0-v,2)/(2*0.06*0.97) if v>0.94 else v/0.97

static func cabin_width(v: float) -> float:
	var progress: float = (v-0.03)/0.94
	if v<0.06: progress=v*v/(2*0.06*0.94)
	elif v>0.94: progress=1.0-pow(1.0-v,2)/(2*0.06*0.94)
	return lerpf(0.76,0.63,progress)

static func cabin_rear_point(u: float,v: float) -> Vector3:
	var x: float = cabin_width(v)*u
	var p: float = cabin_depth_progress(v)
	return Vector3(x,1.01+0.47*v,_rounded_rear_z(x,cabin_width(v),lerpf(1.91,1.18,p),lerpf(0.12,0.06,p)))

static func cabin_front_point(u: float,v: float) -> Vector3:
	var x: float = cabin_width(v)*u
	return Vector3(x,1.01+0.47*v,-_rounded_rear_z(x,cabin_width(v),lerpf(1.0,0.4,cabin_depth_progress(v)),0.06))

static func cabin_side_point(side: float,u: float,v: float) -> Vector3:
	var p: float = cabin_depth_progress(v)
	return Vector3(side*cabin_width(v),1.01+0.47*v,lerpf(lerpf(-1.0,-0.4,p)+0.06,lerpf(1.91,1.18,p)-lerpf(0.12,0.06,p),u))

static func build_cabin(car: CarVisual, accent: Material, paint: Material) -> void:
	_patch(car,"CabinFront",40,28,func(u: float,v: float) -> Vector3:
		var x: float=lerpf(-1,1,u)*(cabin_width(v)-0.06)
		return cabin_front_point(x/cabin_width(v),v),accent,Vector3(0,0.8,-0.6),Rect2(0.75,0.5,0.25,0.25))
	_patch(car,"CabinRear",40,28,func(u: float,v: float) -> Vector3:
		var p: float=cabin_depth_progress(v)
		var x: float=lerpf(-1,1,u)*(cabin_width(v)-lerpf(0.12,0.06,p))
		return cabin_rear_point(x/cabin_width(v),v),accent,Vector3(0,0.8,0.6),Rect2(0.75,0.75,0.25,0.25))
	for side: float in [-1,1]:
		_patch(car,"CabinRearCorner",24,28,func(u: float,v: float) -> Vector3:
			return cabin_corner_point(side,u,v,false),accent,Vector3(side,0.8,0.6),Rect2(0,0,1,1))
		_patch(car,"CabinFrontCorner",24,28,func(u: float,v: float) -> Vector3:
			return cabin_corner_point(side,u,v,true),accent,Vector3(side,0.8,-0.6),Rect2(0,0,1,1))
		_patch(car,"CabinSide",40,28,func(u: float,v: float) -> Vector3:
			return cabin_side_point(side,u,v),paint,Vector3(side,0.3,0),Rect2(0,0,1,1))

static func cabin_corner_point(side: float,u: float,v: float,front: bool) -> Vector3:
	var p: float=cabin_depth_progress(v)
	var radius: float=0.06 if front else lerpf(0.12,0.06,p)
	var depth: float=lerpf(1.0,0.4,p) if front else lerpf(1.91,1.18,p)
	var angle: float=u*PI*0.5
	return Vector3(side*(cabin_width(v)-radius+radius*cos(angle)),1.01+0.47*v,(depth-radius+radius*sin(angle))*(-1.0 if front else 1.0))

static func build_arch(car: CarVisual, side: float, axle: float, paint: Material, rubber: Material) -> void:
	var bulge: float = 0.070 if axle > 0 else 0.055
	_patch(car,"RolledWheelArchFront" if axle < 0 else "RolledWheelArchRear",56,10,func(u: float,v: float) -> Vector3:
		var angle: float = u*PI
		var radius: float = lerpf(0.405,0.48,v)
		var y: float = 0.37+sin(angle)*radius
		var z: float = axle+cos(angle)*radius
		# Roll into the fender below the waist; the old raised outer rim cut
		# across the shoulder highlight and looked like a dented quarter panel.
		var width: float = body_width(y,z)+(bulge+0.009)*pow(1.0-v,2)+0.0005*smoothstep(0,1,v)
		return Vector3(side*width,y,z),paint,Vector3(side,0.1,0),Rect2(0 if side < 0 else 0.25,0.4,0.25,0.2))
	_patch(car,"ArchRubberSealFront" if axle < 0 else "ArchRubberSealRear",56,2,func(u: float,v: float) -> Vector3:
		var angle: float = u*PI
		var radius: float = lerpf(0.392,0.405,v)
		var y: float = 0.37+sin(angle)*radius
		var z: float = axle+cos(angle)*radius
		return Vector3(side*(body_width(y,z)+bulge+0.011),y,z),rubber,Vector3(side,0.1,0),Rect2(0,0,1,1))

static func hood_point(u: float,v: float) -> Vector3:
	var front: Vector3=front_rim_point(u,1.0)
	var across: float=front.x/front_rim_width()
	var upper: float=lerpf(0.976,1.048,v)
	var x: float=across*body_width(upper,lerpf(-1.84,-1.015,v))
	var z: float=lerpf(front.z,-1.015,v)
	var base: float=upper+0.010*(1-across*across)
	# Reference-led pressed sheet: a shallow planar centre and two straight
	# longitudinal folds. No sine dome or rounded shoulder ridges.
	var plane: float=0.986+0.072*(z+2.089)/1.074+0.014
	var folded: float=1-smoothstep(0.24,0.30,absf(x))
	var ends: float=smoothstep(0,0.18,v)*(1-smoothstep(0.65,1,v))
	return Vector3(x,lerpf(base,plane,folded*ends),z)

static func build_hood(car: CarVisual, paint: Material, accent: Material) -> void:
	# 24 + 40 + 24 stations exactly match the two corners and front face.
	_patch(car,"CrownedHood",88,24,func(u: float,v: float) -> Vector3:
		return hood_point(lerpf(-1,1,u),v),paint,Vector3.UP,Rect2(0.5,0,0.25,0.5))
	# The accent uses the same 56 interior columns as the 88-column steel.
	# Matching triangles keep sculpted paint surfaces from intersecting.
	var accent_edge: float=28.0/44.0
	_patch(car,"HoodAccent",56,24,func(u: float,v: float) -> Vector3:
		return hood_point(lerpf(-accent_edge,accent_edge,u),v)+Vector3.UP*0.0015,accent,Vector3.UP,Rect2(0.5,0,0.25,0.5))
	var trim: Material = VisualGeometry.material(Color("263039"))
	for side: float in [-1,1]:
		for segment: int in range(24):
			var a: Vector3 = hood_point(side*(accent_edge+0.01),segment/24.0)+Vector3.UP*0.003
			var b: Vector3 = hood_point(side*(accent_edge+0.01),(segment+1)/24.0)+Vector3.UP*0.003
			car._seam(car.body,a,b,0.005,trim)

static func roof_point(u: float,v: float) -> Vector3:
	var x: float = u*0.63
	var front: float = -_rounded_rear_z(x,0.63,0.4,0.06)
	var rear: float = _rounded_rear_z(x,0.63,1.18,0.06)
	var z: float = lerpf(front,rear,v)
	var roll: float = pow(maxf(0,1.0-pow(absf(u),8)),0.7)
	var end_roll: float = sqrt(maxf(0,1.0-pow(absf(2*v-1),12)))
	var y: float = 1.48 + 0.033*roll*end_roll
	return Vector3(x,y,z)

static func build_roof(car: CarVisual, accent: Material) -> void:
	# 24 angular samples per corner and 40 across the centre match cabin edges.
	_patch(car,"RolledRoof",88,32,func(u: float,v: float) -> Vector3:
		var step: float=u*88.0
		var x: float
		if step<24:x=-0.57-0.06*cos(step/24.0*PI*0.5)
		elif step>64:x=0.57+0.06*sin((step-64)/24.0*PI*0.5)
		else:x=lerpf(-0.57,0.57,(step-24)/40.0)
		return roof_point(x/0.63,v),accent,Vector3.UP,Rect2(0.75,0,0.25,0.5))

static func _rounded_box_point(point: Vector3, half_size: Vector3, radius: float) -> Vector3:
	var core: Vector3 = half_size-Vector3.ONE*radius
	var closest: Vector3 = point.clamp(-core,core)
	return closest+(point-closest).normalized()*radius

static func front_face_point(u: float,v: float) -> Vector3:
	var height: float=body_height(v,0.976)
	var roll: float=front_roll(height,0.976)
	var width: float=width_at_height(height)-roll
	var x: float=lerpf(-1,1,u)*(width-0.15)
	return Vector3(x,height+0.010*pow((height-0.33)/0.646,8)*(1-pow(x/width,2)),CompactDetail._nose_z(x)+roll)

static func front_corner_point(side: float,u: float,v: float) -> Vector3:
	var height: float=body_height(v,0.976)
	var roll: float=front_roll(height,0.976)
	var width: float=width_at_height(height)-roll
	var x: float=width-0.15
	var p0:=Vector2(x,CompactDetail._nose_z(x)+roll)
	# Tangents meet the bowed fascia and the straight fender at both ends.
	var p1:=p0+Vector2(0.10,0.10*0.40625*x)
	var p2:=Vector2(width,-1.94)
	var p3:=Vector2(width,-1.84)
	var t: float=1-u
	var point: Vector2=p0*t*t*t+3*p1*t*t*u+3*p2*t*u*u+p3*u*u*u
	return Vector3(side*point.x,height+0.010*pow((height-0.33)/0.646,8)*(1-pow(point.x/width,2)),point.y)

static func front_rim_point(u: float,v: float) -> Vector3:
	var station: float=(u+1)*44.0
	if station<24:return front_corner_point(-1,1-station/24.0,v)
	if station>64:return front_corner_point(1,(station-64)/24.0,v)
	return front_face_point((station-24)/40.0,v)

static func front_skin(x: float,y: float) -> float:
	# Same curve for fittings: inverse monotonic corner X, no box intersections.
	var v: float=body_fraction(y,0.976)
	var height: float=body_height(v,0.976)
	var roll: float=front_roll(height,0.976)
	var width: float=width_at_height(height)-roll
	if absf(x)<=width-0.15:return CompactDetail._nose_z(x)+roll
	var low: float=0.0
	var high: float=1.0
	for iteration: int in range(20):
		var middle: float=(low+high)*0.5
		if front_corner_point(1,middle,v).x<absf(x):low=middle
		else:high=middle
	return front_corner_point(1,(low+high)*0.5,v).z

static func build_nose(car: CarVisual,paint: Material) -> void:
	for side: float in [-1,1]:
		_patch(car,"FrontCorner",24,24,func(u: float,v: float) -> Vector3:
			return front_corner_point(side,u,v),paint,Vector3(side,0,-1),Rect2(0,0,1,1))
	_patch(car,"FrontCoachwork",40,24,func(u: float,v: float) -> Vector3:
		return front_face_point(u,v),paint,Vector3.FORWARD,Rect2(0.5,0.5,0.25,0.25))
	_patch(car,"FrontUnderpan",88,2,func(u: float,v: float) -> Vector3:
		var front: Vector3=front_rim_point(lerpf(-1,1,u),0)
		return Vector3(front.x,0.33,lerpf(front.z,-1.84,v)),car.underside_material,Vector3.DOWN,Rect2(0,0,1,1))

static func build_mirror(car: CarVisual, side: float, rubber: Material, metal: Material) -> void:
	var center := Vector3(side*0.932,1.065,-0.74)
	var half_size := Vector3(0.103,0.0825,0.032)
	var prefix: String = "MirrorLeft" if side<0 else "MirrorRight"
	var normals: Array[Vector3] = [Vector3.LEFT,Vector3.RIGHT,Vector3.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.BACK]
	for face: int in range(6):
		var normal: Vector3 = normals[face]
		_patch(car,prefix+str(face),12,10,func(u: float,v: float) -> Vector3:
			var a: float = lerpf(-1,1,u)
			var b: float = lerpf(-1,1,v)
			var p := Vector3(normal.x,a,b) if face<2 else Vector3(a,normal.y,b) if face<4 else Vector3(a,b,normal.z)
			return center+_rounded_box_point(p*half_size,half_size,0.022),rubber,normal,Rect2(0,0,1,1))
	# A small rounded insert on the rear-facing surface; no chrome slab.
	_patch(car,prefix+"Glass",20,12,func(u: float,v: float) -> Vector3:
		var x: float = lerpf(-0.077,0.077,u)
		var y: float = lerpf(-0.036,0.036,v)
		var corner: float = maxf(0,absf(x)-0.063)
		var height: float = 0.019+sqrt(maxf(0,0.014*0.014-corner*corner))
		y=lerpf(-height,height,v)*1.5
		return center+Vector3(x,y,0.033),metal,Vector3.BACK,Rect2(0,0,1,1))
	var mount := MeshInstance3D.new()
	mount.name = prefix+"Mount"
	var capsule := CapsuleMesh.new()
	var a := Vector3(side*0.758,1.035,-0.78)
	var b := Vector3(side*0.882,1.045,-0.755)
	capsule.radius=0.018
	capsule.height=a.distance_to(b)+0.036
	capsule.radial_segments=12
	capsule.rings=4
	mount.mesh=capsule
	mount.position=(a+b)*0.5
	mount.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	mount.material_override=rubber
	car.body.add_child(mount)

static func _bumper_path(rear: bool, u: float) -> Vector2:
	if not rear:
		var point: Vector2=_front_bumper_body(u)
		var tangent: Vector2=(_front_bumper_body(minf(1,u+0.0002))-_front_bumper_body(maxf(0,u-0.0002))).normalized()
		return point+Vector2(-tangent.y,tangent.x)*0.085
	var run: float = 0.23
	var back: float = 1.99
	var arc: float = PI*0.08
	var length: float = run*2+arc*2+1.56
	var distance: float = u*length
	var p: Vector2
	if distance<run:
		p=Vector2(-0.94,1.76+distance)
	elif distance<run+arc:
		var angle: float=(distance-run)/0.16
		p=Vector2(-0.78-0.16*cos(angle),back+0.16*sin(angle))
	elif distance<run+arc+1.56:
		p=Vector2(-0.78+distance-run-arc,back+0.16)
	elif distance<run+arc*2+1.56:
		var angle: float=(distance-run-arc-1.56)/0.16
		p=Vector2(0.78+0.16*sin(angle),back+0.16*cos(angle))
	else:
		p=Vector2(0.94,back-(distance-run-arc*2-1.56))
	return p

static func _front_bumper_body(u: float) -> Vector2:
	# Eight side stations + 24/40/24 nose stations + eight side stations.
	# The bumper is an offset of the actual shell, including its bowed face.
	var station: float=u*104.0
	var width: float=body_width(0.53,-1.84)
	if station<8:return Vector2(width,lerpf(-1.76,-1.84,station/8.0))
	if station>96:return Vector2(-width,lerpf(-1.84,-1.76,(station-96)/8.0))
	var point: Vector3=front_rim_point(1.0-(station-8.0)/44.0,body_fraction(0.53,0.976))
	return Vector2(point.x,point.z)

static func front_bumper_parameter(x: float) -> float:
	var low: float=8.0/104.0
	var high: float=96.0/104.0
	for iteration: int in range(24):
		var middle: float=(low+high)*0.5
		if _bumper_path(false,middle).x>x:low=middle
		else:high=middle
	return (low+high)*0.5

static func _bumper_point(rear: bool,u: float,v: float) -> Vector3:
	var p: Vector2=_bumper_path(rear,u)
	var tangent: Vector2=(_bumper_path(rear,minf(1,u+0.0002))-_bumper_path(rear,maxf(0,u-0.0002))).normalized()
	var outward:=Vector2(-tangent.y,tangent.x)
	var half_height: float=0.1144 if rear else 0.088
	var half_depth: float=0.06 if rear else 0.046
	var raw:=Vector2(cos(v*TAU)*half_depth,sin(v*TAU)*half_height)
	var core:=Vector2(half_depth-0.024,half_height-0.024)
	var closest: Vector2=raw.clamp(-core,core)
	var section: Vector2=closest+(raw-closest).normalized()*0.024
	p+=outward*(section.x-half_depth)
	if rear and section.x>0:
		# Deeper American-format plate pocket, with a shaped bevel and intact back.
		var horizontal: float=1.0-smoothstep(0.220,0.252,absf(p.x))
		var vertical: float=1.0-smoothstep(0.104,0.114,absf(section.y))
		p.y-=0.036*horizontal*vertical*smoothstep(0,0.036,section.x)
	return Vector3(p.x,(0.4856 if rear else 0.53)+section.y,p.y)

static func build_bumper(car: CarVisual,rear: bool,rubber: Material) -> void:
	_patch(car,"RoundedRearBumper" if rear else "RoundedFrontBumper",96 if rear else 104,24,func(u: float,v: float) -> Vector3:
		return _bumper_point(rear,u,v),rubber,Vector3.BACK,Rect2(0,0,1,1),true)
	for endpoint: float in [0.0,1.0]:
		var tool:=SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var tangent: Vector2=(_bumper_path(rear,minf(1,endpoint+0.001))-_bumper_path(rear,maxf(0,endpoint-0.001))).normalized()
		var normal:=Vector3(tangent.x,0,tangent.y)*(1.0 if endpoint>0 else -1.0)
		var center: Vector3=(_bumper_point(rear,endpoint,0)+_bumper_point(rear,endpoint,0.5))*0.5
		var cap_steps: int=48 if rear else 24
		for segment: int in range(cap_steps):
			var a: Vector3=_bumper_point(rear,endpoint,segment/float(cap_steps))
			var b: Vector3=_bumper_point(rear,endpoint,(segment+1)/float(cap_steps))
			var points: Array[Vector3]=[center,a,b]
			if (a-center).cross(b-center).dot(normal)>0:points.reverse()
			for point: Vector3 in points:
				tool.set_normal(normal)
				tool.add_vertex(point)
		var cap:=MeshInstance3D.new()
		cap.name=("Rear" if rear else "Front")+"BumperCap"+("Left" if center.x<0 else "Right")
		cap.mesh=tool.commit()
		cap.material_override=rubber
		car.body.add_child(cap)

static func _patch(car: CarVisual, label: String, columns: int, rows: int, sample: Callable, surface: Material, normal_hint: Vector3, uv_region: Rect2, closed_profile: bool = false) -> void:
	var key: String = label.to_snake_case()+ ("_left" if normal_hint.x < 0 else "_right" if normal_hint.x > 0 else "")
	var path: String = ASSET_ROOT.path_join(key+".res")
	var original_path: String = path
	if car.simple_model:
		key += "_simple"
		path = RacingCarModels.COACH_ROOT.path_join(key+".res")
		columns = maxi(2,columns/2)
		rows = maxi(1,rows/2)
	if not meshes.has(key) and use_baked and ResourceLoader.exists(path):
		meshes[key] = load(path) as ArrayMesh
	if meshes.has(key):
		_attach(car,label,meshes[key],surface)
		return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in range(rows):
		for column: int in range(columns):
			var uv: Array[Vector2] = [Vector2(float(column)/columns,float(row)/rows),Vector2(float(column+1)/columns,float(row)/rows),Vector2(float(column+1)/columns,float(row+1)/rows),Vector2(float(column)/columns,float(row+1)/rows)]
			var points: Array[Vector3] = []
			for t: Vector2 in uv: points.append(sample.call(t.x,t.y))
			var order: Array[int] = [0,1,2,0,2,3]
			if closed_profile or (points[1]-points[0]).cross(points[2]-points[0]).dot(normal_hint)>0: order=[0,2,1,0,3,2]
			for vertex_index: int in range(order.size()):
				var index: int=order[vertex_index]
				var triangle_start: int=(vertex_index/3)*3
				# Clipped wheel-opening rows can collapse to the same boundary.
				# Emit only triangles with an actual surface area.
				if label=="CurvedBody" and (points[order[triangle_start+1]]-points[order[triangle_start]]).cross(points[order[triangle_start+2]]-points[order[triangle_start]]).length_squared()<1e-20:continue
				var t: Vector2 = uv[index]
				var du: Vector3 = sample.call(minf(1,t.x+0.001),t.y)-sample.call(maxf(0,t.x-0.001),t.y)
				var dv: Vector3 = sample.call(t.x,minf(1,t.y+0.001))-sample.call(t.x,maxf(0,t.y-0.001))
				var normal: Vector3 = du.cross(dv).normalized()
				if not closed_profile and normal.dot(normal_hint)<0: normal=-normal
				if label=="CurvedBody" and points[index].y<body_upper(points[index].z)-0.035:
					# Wheel cut-outs change the patch's vertical sampling. Deriving
					# steel normals in Y/Z avoids reflecting that grid warp as dents.
					var p: Vector3=points[index]
					var dy: float=(body_width(p.y+0.00001,p.z)-body_width(p.y-0.00001,p.z))/0.00002
					var dz: float=(body_width(p.y,p.z+0.00001)-body_width(p.y,p.z-0.00001))/0.00002
					normal=Vector3(normal_hint.x,-dy,-dz).normalized()
				tool.set_normal(normal)
				var mapped: Vector2 = uv_region.position+t*uv_region.size
				if normal_hint.x != 0.0:
					# The body and arch overlays share the same world-projected atlas.
					mapped = Vector2((0.0 if normal_hint.x < 0 else 0.25)+(points[index].z+2.08)/4.11*0.25,(points[index].y-0.33)/0.75)
				elif label in ["CrownedHood","HoodAccent"]:
					mapped.x = 0.5+(points[index].x/body_width(lerpf(0.976,1.048,t.y),lerpf(-1.84,-1.015,t.y))+1.0)*0.125
				elif label=="RolledRoof":mapped.x=0.75+(points[index].x/0.63+1.0)*0.125
				tool.set_uv(mapped)
				tool.add_vertex(points[index])
	tool.index()
	tool.generate_tangents()
	var resource: ArrayMesh = tool.commit()
	if car.simple_model and ResourceLoader.exists(original_path): resource.custom_aabb = (load(original_path) as ArrayMesh).get_aabb()
	meshes[key] = resource
	_attach(car,label,resource,surface)

static func _attach(car: CarVisual, label: String, resource: ArrayMesh, surface: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = resource
	mesh.material_override = surface
	car.body.add_child(mesh)
