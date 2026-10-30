extends RefCounted
## Model metres. Nose -Z, open wheel wells and continuous shared panel boundaries.
const AXLE: float = 2.46 / (2.0 * HandlingConfig.BODY_SCALE)
const HALF_TRACK: float = 1.48 / (2.0 * HandlingConfig.BODY_SCALE)
const FRONT_JOIN: float = -1.94
const FRONT_SHOULDER_Y: float = 0.8732982719759579
static var meshes: Dictionary = {}
static var use_baked: bool = true
const ASSET_ROOT: String = "res://assets/vehicles/electric_coachwork_v7"

static func upper(z: float) -> float:
	if z < -0.94:
		return 1.0-(1.0-FRONT_SHOULDER_Y)*pow((z+0.94)/(-0.94-FRONT_JOIN),2)
	return 0.845 + 0.155*smoothstep(-2.30,-0.98,z) - 0.095*smoothstep(1.25,2.09,z)

static func skin_width(y: float, z: float) -> float:
	var waist: float = 0.915 + 0.050*sin(clampf((y-0.29)/0.73,0,1)*PI)-0.065*smoothstep(0.82,1.02,y)
	var fender: float = exp(-pow((z+AXLE)/0.45,2)) + exp(-pow((z-AXLE)/0.48,2))
	var door_hollow: float = 0.043*exp(-pow((y-0.53)/0.14,2))*(1.0-clampf(fender,0,1))
	# A shared quarter-circle shoulder turns the side into the hood/deck.
	var radius: float = 0.055+0.070*(1-smoothstep(-1.70,-0.98,z))
	var roll: float = clampf(y-upper(z)+radius,0,radius)
	return waist + 0.042*fender*smoothstep(0.34,0.77,y)-door_hollow-radius+sqrt(maxf(0,radius*radius-roll*roll))

static func door_outline(front: bool) -> Array[Vector2]:
	var points: Array[Vector2] = [Vector2(-0.86,0.98),Vector2(0.26,0.98),Vector2(0.26,0.43),Vector2(-0.74,0.43)]
	if not front: points = [Vector2(0.26,0.98),Vector2(0.95,0.98),Vector2(0.95,0.43),Vector2(0.26,0.43)]
	return points

static func door_depth(y: float, z: float) -> float:
	if z < -0.88 or z > 0.97 or y < 0.415 or y > 0.995: return 0
	var point := Vector2(z,y)
	var distance: float = 1.0
	for front: bool in [true,false]:
		var outline: Array[Vector2] = door_outline(front)
		for index: int in range(4):
			var a: Vector2 = outline[index]
			var edge: Vector2 = outline[(index+1)%4]-a
			distance = minf(distance,point.distance_to(a+edge*clampf((point-a).dot(edge)/edge.length_squared(),0,1)))
	return 0.0045*(1-smoothstep(0.0015,0.006,distance))

static func width(y: float, z: float) -> float:
	return skin_width(y,z)-door_depth(y,z)

static func edge_roll(y: float, top: float, radius: float) -> float:
	var rise: float = clampf(y-top+radius,0,radius)
	return radius-sqrt(maxf(0,radius*radius-rise*rise))

static func nose_top(across: float) -> float:
	return lerpf(0.840,upper(FRONT_JOIN),across*across)

static func tail_top(across: float) -> float:
	return upper(2.09)+0.015*(1-across*across)

static func front_z(x: float, y: float) -> float:
	# The entire nose is an elliptical plan section with a convex bumper
	# profile. Its corners turn into the wings well behind the old slab face.
	var half_width: float = width(y,FRONT_JOIN)
	# A single convex profile places the foremost point at the light brow.
	# Removing the separate upper roll and low bumper bulge removes the S bend.
	var depth: float = -2.44+0.75*pow(y-0.80,2)
	var ellipse: float = sqrt(maxf(0,1-pow(x/half_width,2)))
	return FRONT_JOIN-(FRONT_JOIN-depth)*ellipse

static func rear_z(x: float, y: float) -> float:
	var half_width: float = width(y,2.09)
	var across: float = clampf(absf(x)/width(upper(2.09),2.09),0,1)
	var depth: float = 2.30-0.11*(1-smoothstep(0.3,0.53,y))-edge_roll(y,tail_top(across),0.045)
	var radius: float = depth-2.09
	var corner: float = clampf(absf(x)-half_width+radius,0,radius)
	return 2.09+sqrt(maxf(0,radius*radius-corner*corner))

static func face_normal(point: Vector3, rear_face: bool) -> Vector3:
	var join: float = 2.09 if rear_face else FRONT_JOIN
	if absf(point.x) > width(point.y,join)-0.0001:
		var dy: float = (width(point.y+0.0001,join)-width(point.y-0.0001,join))/0.0002
		var dz: float = (width(point.y,join+0.0001)-width(point.y,join-0.0001))/0.0002
		return Vector3(signf(point.x),-dy,-dz).normalized()
	var surface: Callable = rear_z if rear_face else front_z
	var dx: float = (surface.call(point.x+0.0001,point.y)-surface.call(point.x-0.0001,point.y))/0.0002
	var dy: float = (surface.call(point.x,point.y+0.0001)-surface.call(point.x,point.y-0.0001))/0.0002
	return Vector3(-dx,-dy,1).normalized() if rear_face else Vector3(dx,dy,-1).normalized()

static func side_point(side: float, z: float, y: float, offset: float = 0.0) -> Vector3:
	return Vector3(side*(width(y,z)+offset),y,z)

static func hood_point(u: float, v: float) -> Vector3:
	var across: float = lerpf(-1,1,u)
	var front_y: float = nose_top(across)
	var front_x: float = across*width(front_y,FRONT_JOIN)
	var front: Vector3 = Vector3(front_x,front_y,front_z(front_x,front_y))
	var rear_y: float = 1.0+0.018*(1-across*across)
	var edge: float = pow(across,32)
	# Match a longitudinal (fixed-X) section of the actual nose, including
	# its changing width; a constant-across tangent leaves an off-centre kink.
	var slope: float = (front_z(front.x,front.y+0.0001)-front_z(front.x,front.y-0.0001))/0.0002
	slope = clampf(slope,0.0,3.5)
	var a := Vector2(front.z,front.y)
	var b: Vector2 = a+Vector2(slope*0.10,0.10)
	var c := Vector2(-1.52,rear_y)
	var d := Vector2(-0.94,rear_y)
	var p: Vector2 = pow(1-v,3)*a+3*pow(1-v,2)*v*b+3*(1-v)*v*v*c+pow(v,3)*d
	# The side boundary follows the same convex shoulder section as the wing.
	# Both sections share their endpoints; there is no local dip correction.
	var z: float = lerpf(p.x,lerpf(front.z,-0.94,v),edge)
	var y: float = lerpf(p.y,rear_y-(rear_y-front.y)*pow(1-v,2),edge)
	var side_z: float = maxf(z,FRONT_JOIN)
	var front_side_z: float = maxf(front.z,FRONT_JOIN)
	var at_front: float = 1-smoothstep(0,0.22,v)
	var x: float = across*width(upper(side_z),side_z)+(front.x-across*width(upper(front_side_z),front_side_z))*at_front
	return Vector3(x,y,z)

static func hood_panel_uv(u: float, v: float, padding: float = 0.0) -> Vector2:
	# Rounded clamshell perimeter, expressed in approximate surface metres.
	var half := Vector2(0.841,0.635)+Vector2.ONE*padding
	var point := Vector2(lerpf(-half.x,half.x,u),lerpf(-half.y,half.y,v))
	var radius: float = 0.045+padding
	var inner: Vector2 = half-Vector2.ONE*radius
	var closest: Vector2 = point.clamp(-inner,inner)
	var delta: Vector2 = point-closest
	if delta.length_squared() > radius*radius: point = closest+delta.normalized()*radius
	return Vector2(0.5+point.x/1.76,(point.y+0.717)/1.4)

static func hood_edge_uv(edge: int, t: float, padding: float = 0.0) -> Vector2:
	var uv: Vector2 = hood_rectangle_uv(edge,t)
	return hood_panel_uv(uv.x,uv.y,padding)

static func hood_rectangle_uv(edge: int, t: float) -> Vector2:
	if edge == 0: return Vector2(0.5+0.5*front_across(t),0)
	if edge == 1: return Vector2(1,t)
	if edge == 2: return Vector2(0.5+0.5*front_across(1-t),1)
	return Vector2(0,1-t)

static func front_across(t: float) -> float:
	var stations: Array[float] = [-1,-0.98,-0.92,-0.86,-0.70,0,0.70,0.86,0.92,0.98,1]
	var index: int = mini(floori(t*10),9)
	return lerpf(stations[index],stations[index+1],t*10-index)

static func hood(car: CarVisual, paint: Material, trim: Material) -> void:
	patch(car.body,"ClamshellHood",80,28,func(u: float,v: float) -> Vector3:
		var uv: Vector2 = hood_panel_uv(0.5+0.5*front_across(u),v)
		return hood_point(uv.x,uv.y),paint,Vector3.UP,car.simple_model)
	for edge: int in range(4):
		var segments: int = 80 if edge%2 == 0 else 28
		patch(car.body,"HoodSurround"+str(edge),segments,2,func(u: float,v: float) -> Vector3:
			var outer: Vector2 = Vector2(0.5+0.5*front_across(u),0) if edge == 0 else hood_rectangle_uv(edge,u)
			var uv: Vector2 = hood_edge_uv(edge,u,0.006).lerp(outer,v)
			return hood_point(uv.x,uv.y),paint,Vector3.UP,car.simple_model)
		# Actual painted edge returns and a recessed dark reveal replace the
		# previous two black strips sitting on the top of an unbroken hood.
		for outer: bool in [false,true]:
			var facing: Vector3 = [Vector3.FORWARD,Vector3.RIGHT,Vector3.BACK,Vector3.LEFT][edge]
			patch(car.body,"HoodReturn"+str(edge)+str(outer),segments,2,func(u: float,v: float) -> Vector3:
				var uv: Vector2 = hood_edge_uv(edge,u,0.006 if outer else 0.0)
				return hood_point(uv.x,uv.y)-Vector3.UP*v*0.005,paint,-facing if outer else facing,car.simple_model)
		patch(car.body,"HoodReveal"+str(edge),segments,2,func(u: float,v: float) -> Vector3:
			var uv: Vector2 = hood_edge_uv(edge,u).lerp(hood_edge_uv(edge,u,0.006),v)
			return hood_point(uv.x,uv.y)-Vector3.UP*0.005,trim,Vector3.UP,car.simple_model)

static func deck_point(u: float, v: float) -> Vector3:
	var across: float = lerpf(-1,1,u)
	var y: float = tail_top(across)
	var x: float = across*width(y,2.09)
	var z: float = lerpf(1.70,rear_z(x,y),v)
	var end_weight: float = smoothstep(0.78,1,v)
	return Vector3(lerpf(across*width(upper(z),z),x,end_weight),upper(z)+0.015*(1-across*across),z)

static func side_station(u: float, y: float) -> float:
	var lead: float = lerpf(-0.74,-0.86,clampf((y-0.43)/0.55,0,1))
	var stations: Array[float] = [FRONT_JOIN,-1.90,-1.80,-1.65,-1.4,-1.2,-1.0,lead-0.018,lead-0.006,lead-0.003,lead,lead+0.003,lead+0.006,lead+0.018,0.242,0.254,0.257,0.26,0.263,0.266,0.278,0.932,0.944,0.947,0.95,0.953,0.956,0.968,1.10,1.3,1.5,1.7,1.9,2.09]
	var t: float = u*(stations.size()-1)
	var index: int = mini(floori(t),stations.size()-2)
	return lerpf(stations[index],stations[index+1],t-index)

static func skin_levels(top: float) -> Array[float]:
	# Every side/end boundary uses these same stations, in both detail levels.
	# Shared positions and normals prevent the end skins leaving thin cracks.
	var heights: Array[float] = [0.31,0.35,0.39,0.415,0.424,0.4285,0.43,0.4315,0.436,0.445,0.45,0.46,0.505,0.52,0.57,0.65,0.685,0.754,0.78,0.785,0.804,0.88,0.895,0.925,0.945,0.955,0.965,0.974,0.9785,0.98,0.9815,0.986,0.992,1.0,top-0.055,top-0.035,top-0.018,top-0.006,top-0.001,top]
	heights.sort()
	return heights

static func skin_level(v: float, top: float, low: float = 0.31, high: float = 2) -> float:
	var heights: Array[float] = skin_levels(top)
	var t: float = v*(heights.size()-1)
	var index: int = mini(floori(t),heights.size()-2)
	return clampf(lerpf(heights[index],heights[index+1],t-index),low,minf(top,high))

static func side_level(v: float, z: float) -> float:
	return skin_level(v,upper(z))

static func side_surface(side: float, u: float, v: float) -> Vector3:
	var y: float = side_level(v,lerpf(FRONT_JOIN,2.09,u))
	var z: float = side_station(u,y)
	y = side_level(v,z)
	z = side_station(u,y)
	for axle: float in [-AXLE,AXLE]:
		var d: float = absf(z-axle)
		if d < 0.424: y = maxf(y,0.37+sqrt(0.424*0.424-d*d))
	return side_point(side,z,y)

static func body(car: CarVisual, paint: Material, accent: Material, trim: Material) -> void:
	for side: float in [-1.0,1.0]:
		patch(car.body,"SculptedSide"+str(side),132,39,func(u: float,v: float) -> Vector3:
			return side_surface(side,u,v),paint,Vector3(side,0.1,0),car.simple_model,
			func(point: Vector3) -> Vector3:
				var dy: float = (width(point.y+0.0001,point.z)-width(point.y-0.0001,point.z))/0.0002
				var dz: float = (width(point.y,point.z+0.0001)-width(point.y,point.z-0.0001))/0.0002
				return Vector3(side,-dy,-dz).normalized())
		rounded(car.body,"Rocker"+str(side),Vector3(0.085,0.105,2.02),Vector3(side*0.91,0.34,0),0.035,accent)
	hood(car,paint,trim)
	patch(car.body,"RearDeck",48,14,func(u: float,v: float) -> Vector3:
		return deck_point(u,v),paint,Vector3.UP,car.simple_model)

static func cabin_point(side: float, u: float, v: float) -> Vector3:
	var p: float = v
	var z: float = lerpf(lerpf(-0.94,-0.36,p)-0.045*sin(p*PI),lerpf(1.70,0.83,p)+0.025*sin(p*PI),u)
	return Vector3(side*(lerpf(0.842,0.665,p)+0.018*sin(p*PI)),lerpf(upper(z),1.43+0.045*sin(u*PI),v),z)

static func screen_point(rear: bool, u: float, v: float) -> Vector3:
	var p: float = v
	var across: float = lerpf(-1,1,u)
	var x: float = across*(lerpf(0.842,0.665,p)+0.018*sin(p*PI))
	var z: float = lerpf(1.70,0.83,p)+0.025*sin(p*PI) if rear else lerpf(-0.94,-0.36,p)-0.045*sin(p*PI)
	z += (0.035 if rear else -0.030)*(1-across*across)*sin(v*PI)
	return Vector3(x,lerpf(upper(z)+(0.015 if rear else 0.018)*(1-across*across),1.43+0.035*(1-across*across),v),z)

static func roof_point(u: float, v: float) -> Vector3:
	var x: float = lerpf(-0.665,0.665,u)
	return Vector3(x,1.43+0.045*sin(v*PI)+0.035*(1-pow(x/0.665,2)),lerpf(-0.36,0.83,v))

static func cabin(car: CarVisual, paint: Material, accent: Material, trim: Material, glass: Material) -> void:
	for rear: bool in [false,true]:
		var normal := Vector3(0,0.7,1 if rear else -1)
		patch(car.body,"CabinScreenBase"+str(rear),48,24,func(u: float,v: float) -> Vector3:
			return screen_point(rear,u,v),paint,normal,car.simple_model)
		for gasket: bool in [true,false]:
			patch(car.body,"Screen"+str(rear)+str(gasket),44,20,func(u: float,v: float) -> Vector3:
				var across: float = lerpf(0.038 if gasket else 0.052,0.962 if gasket else 0.948,u)
				var level: float = lerpf(0.095 if gasket else 0.116,0.918 if gasket else 0.898,v)
				return screen_point(rear,across,level)+normal.normalized()*(0.004 if gasket else 0.007),trim if gasket else glass,normal,car.simple_model)
	patch(car.body,"CrownedRoof",48,24,func(u: float,v: float) -> Vector3:
		return roof_point(u,v),accent,Vector3.UP,car.simple_model)
	for side: float in [-1.0,1.0]:
		patch(car.body,"CabinShoulder"+str(side),48,6,func(u: float,v: float) -> Vector3:
			var z: float = lerpf(-0.94,1.70,u)
			return Vector3(side*lerpf(0.842,width(upper(z),z),v),upper(z),z),paint,Vector3.UP,car.simple_model)
		patch(car.body,"CabinSide"+str(side),48,24,func(u: float,v: float) -> Vector3:
			return cabin_point(side,u,v),paint,Vector3(side,0.3,0),car.simple_model)
		for pane: int in range(3):
			for gasket: bool in [true,false]:
				patch(car.body,"SideGlass"+str(side)+str(pane)+str(gasket),28,18,func(u: float,v: float) -> Vector3:
					var level: float = lerpf(0.11 if gasket else 0.13,0.91 if gasket else 0.89,v)
					var lead: Vector3 = cabin_point(side,0,level)
					var tail: Vector3 = cabin_point(side,1,level)
					var split: float = lerpf(0.30,tail.z-0.070,0.65)
					var a: float = lead.z+0.055 if pane == 0 else 0.30 if pane == 1 else split+0.016
					var b: float = 0.235 if pane == 0 else split-0.016 if pane == 1 else tail.z-0.070
					var inset: float = 0.0 if gasket else 0.012
					var z: float = lerpf(a+inset,b-inset,u)
					var point: Vector3 = cabin_point(side,(z-lead.z)/(tail.z-lead.z),level)
					return point+Vector3(side*(0.004 if gasket else 0.007),0,0),trim if gasket else glass,Vector3(side,0.3,0),car.simple_model)
		patch(car.body,"GlossBPillar"+str(side),8,20,func(u: float,v: float) -> Vector3:
			var level: float = lerpf(0.10,0.93,v)
			var lead: Vector3 = cabin_point(side,0,level)
			var tail: Vector3 = cabin_point(side,1,level)
			return cabin_point(side,(lerpf(0.232,0.303,u)-lead.z)/(tail.z-lead.z),level)+Vector3(side*0.004,0,0),trim,Vector3(side,0.3,0),car.simple_model)
		var sill: Array[Vector3] = []
		for index: int in range(41): sill.append(cabin_point(side,index/40.0,0.10)+Vector3(side*0.008,0,0))
		line(car.body,sill,0.009,trim)
	for side: float in [-1.0,1.0]:
		var a: Vector3 = screen_point(false,0.5+side*0.36,0.105)+Vector3(0,0.010,-0.008)
		var b: Vector3 = screen_point(false,0.5+side*0.04,0.16)+Vector3(0,0.010,-0.008)
		line(car.body,[a,b],0.016,trim)

static func arch(car: CarVisual, side: float, axle: float, paint: Material, trim: Material) -> void:
	var label: String = str(side)+str(axle)
	patch(car.body,"RolledArch"+label,64,8,func(u: float,v: float) -> Vector3:
		var angle: float = u*PI
		var radius: float = lerpf(0.403,0.480,v)
		var y: float = 0.37+sin(angle)*radius
		var z: float = axle+cos(angle)*radius
		return side_point(side,z,y,0.020*pow(1-v,2)+0.001),paint,Vector3(side,0.1,0),car.simple_model)
	patch(car.body,"ArchReturn"+label,64,4,func(u: float,v: float) -> Vector3:
		var angle: float = u*PI
		var y: float = 0.37+sin(angle)*0.403
		var z: float = axle+cos(angle)*0.403
		return Vector3(side*lerpf(width(y,z)+0.021,HALF_TRACK-0.14,v),y,z),trim,Vector3(side,0.2,0),car.simple_model)

static func front(car: CarVisual, paint: Material, trim: Material, metal: Material) -> void:
	# Separate formed skin cells leave real openings for the optics and intake.
	var columns: Array[float] = [-1,-0.98,-0.92,-0.86,-0.70,0,0.70,0.86,0.92,0.98,1]
	var rows: Array[float] = [0.31,0.335,0.49,0.685,0.754,0.804,0.90]
	for row: int in range(rows.size()-1):
		# The upper nose and hood use identical transverse vertices, including
		# the rounded tips. Different polygon chords used to leave fine cracks.
		if row == rows.size()-2:
			patch(car.body,"FormedFrontHoodJoin",80,39,func(u: float,v: float) -> Vector3:
				var across: float = front_across(u)
				var point: Vector3 = hood_point(0.5+0.5*across,0)
				var y: float = skin_level(v,point.y,rows[row],rows[row+1])
				return point if y == point.y else front_point(across,y,0),paint,Vector3.FORWARD,car.simple_model,
				func(point: Vector3) -> Vector3: return face_normal(point,false))
			continue
		for column: int in range(columns.size()-1):
			var a: float = columns[column]
			var b: float = columns[column+1]
			var middle: float = absf((a+b)*0.5)
			if row == 4 and middle < 0.92: continue
			if row == 1 and middle < 0.86: continue
			if row in [1,2] and middle > 0.92 and middle < 0.98: continue
			patch(car.body,"FormedFront"+str(row)+str(column),8,39,func(u: float,v: float) -> Vector3:
				var across: float = lerpf(a,b,u)
				var top: float = hood_point((across+1)*0.5,0).y
				var low: float = intake_bottom(across) if row == 1 else intake_top(across) if row == 2 else rows[row]
				var high: float = intake_bottom(across) if row == 0 else intake_top(across) if row == 1 else rows[row+1]
				return front_point(across,skin_level(v,top,low,high),0),paint,Vector3.FORWARD,car.simple_model,
				func(point: Vector3) -> Vector3: return face_normal(point,false))
	var running_light := StandardMaterial3D.new()
	running_light.albedo_color = Color("e8f7ff")
	running_light.roughness = 0.22
	running_light.emission_enabled = true
	running_light.emission = Color("c5eaff")
	running_light.emission_energy_multiplier = 0.65
	front_recess(car,"ContinuousLightbarPocket",-0.92,0.92,0.754,0.804,0.030,trim)
	patch(car.body,"ContinuousFrontLightbar",96,6,func(u: float,v: float) -> Vector3:
		return lightbar_point(u,v),running_light,Vector3.FORWARD,car.simple_model)
	for side: float in [-1.0,1.0]:
		front_recess(car,"AirCurtain"+str(side),minf(side*0.92,side*0.98),maxf(side*0.92,side*0.98),intake_bottom(0.95),0.685,0.06,trim)
		fascia(car,"CurtainBrightEdge"+str(side),side*0.885-0.003,side*0.885+0.003,0.40,0.66,0.001,metal,false)
	intake(car,trim)
	fascia(car,"FrontSplitter",-0.86,0.86,0.292,0.305,0.008,trim,false)
	fascia(car,"FrontLowerLip",-0.84,0.84,0.305,0.318,0.008,metal,false)
	for x: float in [-0.018,0.018]: fascia(car,"NoseEmblem"+str(x),x-0.008,x+0.008,0.685,0.725,0.006,metal,false)

static func lightbar_point(u: float, v: float) -> Vector3:
	var across: float = lerpf(-0.90,0.90,u)
	var cap: float = sqrt(clampf(1.0-pow(absf(across)/0.90,16),0.01,1.0))
	var y: float = 0.779+lerpf(-0.009,0.009,v)*cap
	# One continuous diffuser follows the nose's curve with lightly rounded tips.
	return front_point(across,y,0.006-0.002*sin(v*PI))

static func front_point(across: float, y: float, depth: float) -> Vector3:
	var x: float = across*width(y,FRONT_JOIN)
	return Vector3(x,y,front_z(x,y)+depth)

static func intake_bottom(across: float) -> float:
	return 0.335+0.015*smoothstep(0.50,0.86,absf(across))

static func intake_top(across: float) -> float:
	return 0.490-0.100*smoothstep(0.55,0.86,absf(across))

static func intake_across(t: float) -> float:
	var stations: Array[float] = [-0.86,-0.70,0,0.70,0.86]
	var index: int = mini(floori(t*4),3)
	return lerpf(stations[index],stations[index+1],t*4-index)

static func intake(car: CarVisual, trim: Material) -> void:
	patch(car.body,"SweptCoolingIntakeBack",32,8,func(u: float,v: float) -> Vector3:
		var across: float = intake_across(u)
		return front_point(across,lerpf(intake_bottom(across),intake_top(across),v),0.085),trim,Vector3.FORWARD,car.simple_model)
	for edge: int in range(4):
		patch(car.body,"SweptCoolingIntakeReturn"+str(edge),32,4,func(u: float,v: float) -> Vector3:
			var across: float = intake_across(u) if edge < 2 else -0.86 if edge == 2 else 0.86
			var y: float = (intake_bottom(across) if edge == 0 else intake_top(across)) if edge < 2 else lerpf(intake_bottom(across),intake_top(across),u)
			return front_point(across,y,0.085*v),trim,Vector3.DOWN if edge == 0 else Vector3.UP if edge == 1 else Vector3.RIGHT if edge == 2 else Vector3.LEFT,car.simple_model)
	for slat: int in range(2):
		patch(car.body,"SweptCoolingSlat"+str(slat),32,2,func(u: float,v: float) -> Vector3:
			var across: float = lerpf(-0.80,0.80,u)
			var y: float = lerpf(intake_bottom(across),intake_top(across),0.30+slat*0.34)+v*0.007
			return front_point(across,y,0.045),trim,Vector3.FORWARD,car.simple_model)

static func front_recess(car: CarVisual, label: String, left: float, right: float, bottom: float, top: float, depth: float, material: Material) -> void:
	patch(car.body,label+"Back",28,10,func(u: float,v: float) -> Vector3:
		return front_point(lerpf(left,right,u),lerpf(bottom,top,v),depth),material,Vector3.FORWARD,car.simple_model)
	for edge: int in range(4):
		patch(car.body,label+"Return"+str(edge),28,4,func(u: float,v: float) -> Vector3:
			var across: float = lerpf(left,right,u) if edge < 2 else left if edge == 2 else right
			var y: float = (bottom if edge == 0 else top) if edge < 2 else lerpf(bottom,top,u)
			return front_point(across,y,depth*v),material,Vector3.DOWN if edge == 0 else Vector3.UP if edge == 1 else Vector3.RIGHT if edge == 2 else Vector3.LEFT,car.simple_model)

static func rear(car: CarVisual, paint: Material, accent: Material, trim: Material, metal: Material) -> void:
	# Skin cells leave real openings; rolled returns connect the face to the
	# inset backs. No intact tail surface hides behind either recess.
	var columns: Array[float] = [-1,-0.82,-0.27,0,0.27,0.82,1]
	var rows: Array[float] = [0.31,0.45,0.505,0.685,0.785,0.895,0.93]
	for row: int in range(rows.size()-1):
		for column: int in range(columns.size()-1):
			if row == 2 and column in [2,3]: continue
			if row == 4 and column in [1,2,3,4]: continue
			patch(car.body,"TailSkin"+str(row)+str(column),8,39,func(u: float,v: float) -> Vector3:
				var y: float = skin_level(v,tail_top(lerpf(-1,1,(column+u)/(columns.size()-1))),rows[row],rows[row+1])
				var a: float = -width(y,2.09) if column == 0 else columns[column]
				var b: float = width(y,2.09) if column == columns.size()-2 else columns[column+1]
				var x: float = lerpf(a,b,u)
				if row == rows.size()-2:
					# Match the deck's exact top boundary, including its crown.
					var across: float = x/width(y,2.09)
					y = skin_level(v,tail_top(across),rows[row],rows[row+1])
					a = -width(y,2.09) if column == 0 else columns[column]
					b = width(y,2.09) if column == columns.size()-2 else columns[column+1]
					x = lerpf(a,b,u)
				return Vector3(x,y,rear_z(x,y)),paint,Vector3.BACK,car.simple_model,
				func(point: Vector3) -> Vector3: return face_normal(point,true))
	rear_pocket(car,"RearOpticalPocket",Rect2(-0.82,0.785,1.64,0.110),0.022,0.044,paint,trim)
	rear_pocket(car,"PlatePocket",Rect2(-0.27,0.505,0.54,0.18),0.025,0.060,paint,trim)
	fascia(car,"RearLightBar",-0.77,0.77,0.834,0.864,-0.026,car.brake_material,true)
	for side: float in [-1.0,1.0]:
		fascia(car,"RearLightReturn"+str(side),side*0.73,side*0.775,0.807,0.868,-0.025,car.brake_material,true)
		fascia(car,"RearReflector"+str(side),side*0.64,side*0.78,0.41,0.44,0.008,car.brake_material,true)
	fascia(car,"PlateInsert",-0.205,0.205,0.544,0.635,-0.052,metal,true)
	fascia(car,"DiffuserValance",-0.78,0.78,0.31,0.425,0.012,trim,true)
	for x: float in [-0.55,-0.28,0.28,0.55]: rounded(car.body,"DiffuserFin"+str(x),Vector3(0.022,0.095,0.28),Vector3(x,0.325,2.12),0.008,trim)
	patch(car.body,"IntegratedTailLip",48,6,func(u: float,v: float) -> Vector3:
		var x: float = lerpf(-0.83,0.83,u)
		return Vector3(x,0.916+0.014*sin(v*PI),rear_z(x,0.905)-0.10+v*0.105),accent,Vector3.UP,car.simple_model)

static func pocket_perimeter(rect: Rect2, radius: float, t: float) -> Vector2:
	# Four straight edges and four circular corners have identical endpoints.
	var p: float = clampf(t,0,1)*8
	var section: int = mini(floori(p),7)
	var u: float = p-section
	var low: Vector2 = rect.position
	var high: Vector2 = rect.end
	match section:
		0: return Vector2(lerpf(low.x+radius,high.x-radius,u),low.y)
		1: return Vector2(high.x-radius,low.y+radius)+Vector2(sin(u*PI*0.5),-cos(u*PI*0.5))*radius
		2: return Vector2(high.x,lerpf(low.y+radius,high.y-radius,u))
		3: return Vector2(high.x-radius,high.y-radius)+Vector2(cos(u*PI*0.5),sin(u*PI*0.5))*radius
		4: return Vector2(lerpf(high.x-radius,low.x+radius,u),high.y)
		5: return Vector2(low.x+radius,high.y-radius)+Vector2(-sin(u*PI*0.5),cos(u*PI*0.5))*radius
		6: return Vector2(low.x,lerpf(high.y-radius,low.y+radius,u))
		_: return Vector2(low.x+radius,low.y+radius)+Vector2(-cos(u*PI*0.5),-sin(u*PI*0.5))*radius

static func pocket_profile(v: float, depth: float) -> Vector2:
	if v <= 0.2:
		var angle: float = v/0.2*PI*0.5
		return Vector2(0.008*sin(angle),0.008*(1-cos(angle)))
	if v < 0.8: return Vector2(0.008,lerpf(0.008,depth-0.004,(v-0.2)/0.6))
	var angle: float = (v-0.8)/0.2*PI*0.5
	return Vector2(0.008+0.004*(1-cos(angle)),depth-0.004+0.004*sin(angle))

static func pocket_point(rect: Rect2, radius: float, depth: float, u: float, v: float) -> Vector3:
	var profile: Vector2 = pocket_profile(v,depth)
	var point: Vector2 = pocket_perimeter(rect.grow(-profile.x),maxf(0.004,radius-profile.x),u)
	return Vector3(point.x,point.y,rear_z(point.x,point.y)-profile.y)

static func rear_pocket(car: CarVisual, label: String, rect: Rect2, radius: float, depth: float, paint: Material, trim: Material) -> void:
	# Small painted corner fans seal the rectangular skin cells to the rounded mouth.
	for sx: float in [-1.0,1.0]:
		for sy: float in [-1.0,1.0]:
			patch(car.body,label+"SkinCorner"+str(sx)+str(sy),12,3,func(u: float,v: float) -> Vector3:
				var center: Vector2 = rect.get_center()+Vector2(sx*(rect.size.x*0.5-radius),sy*(rect.size.y*0.5-radius))
				var edge: Vector2 = center+Vector2(sx*cos(u*PI*0.5),sy*sin(u*PI*0.5))*radius
				var point: Vector2 = edge.lerp(center+Vector2(sx,sy)*radius,v)
				return Vector3(point.x,point.y,rear_z(point.x,point.y)),paint,Vector3.BACK,car.simple_model,
				func(point: Vector3) -> Vector3: return face_normal(point,true))
	for rim: bool in [true,false]:
		patch(car.body,label+("RolledRim" if rim else "Return"),96,4 if rim else 8,func(u: float,v: float) -> Vector3:
			return pocket_point(rect,radius,depth,u,lerpf(0,0.2,v) if rim else lerpf(0.2,1,v)),paint if rim else trim,Vector3.BACK,car.simple_model)
	var inside: Rect2 = rect.grow(-0.012)
	patch(car.body,label+"Back",24,8,func(u: float,v: float) -> Vector3:
		var point: Vector2 = inside.position+inside.size*Vector2(u,v)
		return Vector3(point.x,point.y,rear_z(point.x,point.y)-depth),trim,Vector3.BACK,car.simple_model,
		func(point: Vector3) -> Vector3: return face_normal(point,true))

static func fascia(car: CarVisual, label: String, a: float, b: float, bottom: float, top: float, relief: float, material: Material, rear_face: bool) -> void:
	patch(car.body,label,20,6,func(u: float,v: float) -> Vector3:
		var y: float = lerpf(bottom,top,v)
		var margin: float = minf(0.006,absf(b-a)*0.08)*(1-sin(v*PI))
		var x: float = lerpf(minf(a,b)+margin,maxf(a,b)-margin,u)
		return Vector3(x,y,rear_z(x,y)+relief if rear_face else front_z(x,y)-relief),material,Vector3.BACK if rear_face else Vector3.FORWARD,car.simple_model)

static func doors(car: CarVisual, side: float, trim: Material, metal: Material) -> void:
	for front: bool in [true,false]:
		var outline: Array[Vector2] = door_outline(front)
		var gap := Node3D.new()
		gap.name = ("Front" if front else "Rear")+"RecessedDoorGap"+str(side)
		car.body.add_child(gap)
		# The front door owns the shared vertical gap. The rear lower edge now
		# joins it exactly, without a duplicate overlapping leading seam.
		for edge: int in range(4 if front else 3):
			var points: Array[Vector3] = []
			for index: int in range(25):
				var point: Vector2 = outline[edge].lerp(outline[(edge+1)%4],index/24.0)
				points.append(side_point(side,point.x,point.y,0.00025))
			line(gap,points,0.002,trim)
		var z: float = 0.05 if front else 0.86
		rounded(car.body,"FlushHandlePocket"+str(side)+str(front),Vector3(0.022,0.050,0.182),side_point(side,z,0.895,0.006),0.013,trim)
		rounded(car.body,"FlushHandle"+str(side)+str(front),Vector3(0.024,0.026,0.147),side_point(side,z,0.90,0.017),0.010,metal)
	if side < 0:
		var points: Array[Vector3] = []
		for point: Vector2 in [Vector2(1.67,0.72),Vector2(1.87,0.72),Vector2(1.87,0.87),Vector2(1.67,0.87),Vector2(1.67,0.72)]: points.append(side_point(side,point.x,point.y,0.005))
		line(car.body,points,0.004,trim)

static func mirror(car: CarVisual, side: float, accent: Material, trim: Material, glass: Material) -> void:
	var center := Vector3(side*0.975,1.075,-0.69)
	rounded(car.body,"MirrorMount"+str(side),Vector3(0.16,0.042,0.055),Vector3(side*0.88,1.035,-0.69),0.018,trim)
	rounded(car.body,"MirrorShell"+str(side),Vector3(0.23,0.13,0.13),center,0.038,accent)
	rounded(car.body,"MirrorLower"+str(side),Vector3(0.22,0.035,0.12),center+Vector3(0,-0.043,0),0.014,trim)
	patch(car.body,"MirrorGlass"+str(side),16,10,func(u: float,v: float) -> Vector3:
		return center+Vector3(lerpf(-0.088,0.088,u),lerpf(-0.025,0.040,v),0.067),glass,Vector3.BACK,car.simple_model)

static func line(parent: Node3D, points: Array[Vector3], thickness: float, material: Material) -> void:
	for index: int in range(points.size()-1):
		var a: Vector3 = points[index]
		var b: Vector3 = points[index+1]
		if a.distance_squared_to(b)<0.0000001: continue
		var bar := VisualGeometry.box(parent,Vector3(thickness,thickness,a.distance_to(b)),(a+b)*0.5,material)
		bar.quaternion = Quaternion(Vector3.BACK,(b-a).normalized())

static func rounded(parent: Node3D, label: String, dimensions: Vector3, center: Vector3, radius: float, material: Material) -> void:
	var half: Vector3 = dimensions*0.5
	var r: float = minf(radius,minf(half.x,minf(half.y,half.z))*0.95)
	for normal: Vector3 in [Vector3.LEFT,Vector3.RIGHT,Vector3.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.BACK]:
		patch(parent,label+str(normal)+str(center)+str(dimensions),8,6,func(u: float,v: float) -> Vector3:
			var a: float = lerpf(-1,1,u)
			var b: float = lerpf(-1,1,v)
			var point := Vector3(normal.x,a,b) if normal.x != 0 else Vector3(a,normal.y,b) if normal.y != 0 else Vector3(a,b,normal.z)
			point *= half
			var inner: Vector3 = half-Vector3.ONE*r
			var q: Vector3 = point.clamp(-inner,inner)
			return center+q+(point-q).normalized()*r,material,normal,false)

static func patch(parent: Node3D, label: String, columns: int, rows: int, sample: Callable, material: Material, hint: Vector3, simple: bool = false, normal_at: Callable = Callable()) -> void:
	var key: String = label+("_simple" if simple else "")
	var path: String = ASSET_ROOT.path_join(key.sha256_text().left(24)+".res")
	if use_baked and not meshes.has(key) and ResourceLoader.exists(path): meshes[key] = load(path) as ArrayMesh
	if not meshes.has(key):
		if simple:
			# Retain transverse samples through the continuous nose silhouette.
			# Halving these spans introduces a visible reverse facet at the brow.
			var front_span: bool = label.begins_with("FormedFront") or label == "ClamshellHood" or (label.begins_with("Hood") and (label.contains("0") or label.contains("2")))
			if not front_span: columns = maxi(4,columns/2)
			# Preserve the authored panel-gap cross-section in the simpler body.
			if not (label.begins_with("SculptedSide") or label.begins_with("FormedFront") or label.begins_with("TailSkin")): rows = maxi(2,rows/2)
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row: int in range(rows):
			for column: int in range(columns):
				var uv: Array[Vector2] = [Vector2(float(column)/columns,float(row)/rows),Vector2(float(column+1)/columns,float(row)/rows),Vector2(float(column+1)/columns,float(row+1)/rows),Vector2(float(column)/columns,float(row+1)/rows)]
				var corners: Array[Vector3] = []
				for t: Vector2 in uv: corners.append(sample.call(t.x,t.y))
				# Mirror the hood diagonals so its baked left/right profiles agree,
				# including between authored stations at the simpler detail level.
				var triangles: Array = [[0,1,2],[0,2,3]]
				if label == "ClamshellHood" and column >= columns/2: triangles = [[0,1,3],[1,2,3]]
				for triangle: Array in triangles:
					var face: Vector3 = (corners[triangle[1]]-corners[triangle[0]]).cross(corners[triangle[2]]-corners[triangle[0]])
					if face.length_squared() < 1e-18: continue
					var order: Array = triangle.duplicate()
					if face.dot(hint)>0: order.reverse()
					for index: int in order:
						var t: Vector2 = uv[index]
						var n: Vector3
						if normal_at.is_valid(): n = normal_at.call(corners[index])
						else:
							var du: Vector3 = sample.call(minf(1,t.x+0.0001),t.y)-sample.call(maxf(0,t.x-0.0001),t.y)
							var dv: Vector3 = sample.call(t.x,minf(1,t.y+0.0001))-sample.call(t.x,maxf(0,t.y-0.0001))
							n = du.cross(dv).normalized()
							if n.dot(hint)<0: n = -n
						tool.set_normal(n)
						tool.set_uv(t)
						tool.add_vertex(corners[index])
		tool.index()
		tool.generate_tangents()
		meshes[key] = tool.commit()
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = meshes[key]
	mesh.material_override = material
	parent.add_child(mesh)
