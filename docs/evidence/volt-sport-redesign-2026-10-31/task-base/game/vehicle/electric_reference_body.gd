extends RefCounted
## Coachwork for the reference fastback. Coordinates are metres before the
## common car scale; the nose points towards negative Z.
const M = preload("res://vehicle/electric_reference_mesh.gd")
const AXLE := 2.46 / (2.0 * HandlingConfig.BODY_SCALE)
const FRONT := -2.04
const REAR := 2.01

static func blend(a: float,b: float,t: float) -> float:
	return lerpf(a,b,smoothstep(0.0,1.0,clampf(t,0.0,1.0)))

static func shoulder(z: float) -> float:
	if z < -1.02:
		# A softened square-root profile falls throughout the bonnet, with a
		# finite tangent at the nose and a shallower slope near the cowl.
		var nose: float=FRONT-0.215
		var t: float=clampf((z-nose)/(-1.02-nose),0.0,1.0)
		var soft: float=0.20
		var curve: float=(sqrt(t+soft)-sqrt(soft))/(sqrt(1.0+soft)-sqrt(soft))
		return 0.655+0.285*curve
	# The lower edge of the side glazing is a straight belt from cowl to rear.
	if z < 1.70: return 0.94
	var t: float=clampf((z-1.70)/0.50,0.0,1.0)
	return 0.94-0.05*t*t

static func top_width(z: float) -> float:
	if z < -1.02:
		# Preserve the fitted windscreen width and gently taper towards the nose.
		var cowl: float=0.87+0.040*exp(-pow((-1.02+AXLE)/0.48,2))+0.045*exp(-pow((-1.02-AXLE)/0.48,2))
		var progress: float=clampf((-1.02-z)/(-1.02-FRONT),0.0,1.0)
		return cowl-0.040*progress
	return 0.87+0.040*exp(-pow((z+AXLE)/0.48,2))+0.045*exp(-pow((z-AXLE)/0.48,2))

static func front_shoulder_round(z: float) -> float:
	return 0.145*(1.0-smoothstep(FRONT,-1.00,z))

static func rear_shoulder_round(z: float) -> float:
	return 0.075*smoothstep(1.70,2.01,z)

static func side_width(z: float,y: float) -> float:
	var h: float=shoulder(z)
	var t: float=clampf((y-0.22)/(h-0.22),0.0,1.0)
	var door: float=exp(-pow(z/0.98,6))
	# The doors carry a broad outward crown, with just a restrained lower fold.
	var swell: float=(0.032+0.014*door)*sin(PI*t)
	var hollow: float=0.006*door*exp(-pow((y-(0.52+0.065*z))/0.22,2))
	var lower_fold: float=0.012*door*exp(-pow((y-(0.34+0.075*z))/0.13,2))
	var end_tuck: float=0.075*smoothstep(1.45,2.05,absf(z))*pow(1.0-t,1.6)
	var radius: float=front_shoulder_round(z)+rear_shoulder_round(z)
	var upper: float=clampf((y-(h-radius))/maxf(radius,0.00001),0.0,1.0)
	var roundover: float=radius*(1.0-sqrt(maxf(0.0,1.0-upper*upper)))
	return top_width(z)+swell-hollow+lower_fold-0.045*pow(1.0-t,2)-end_tuck-roundover

static func side_point(side: float,z: float,y: float) -> Vector3:
	return Vector3(side*side_width(z,y),y,z)

static func wheel_bottom(z: float) -> float:
	var bottom := 0.24+(0.018+0.010*z)*smoothstep(-0.98,-0.88,z)*(1.0-smoothstep(0.88,0.98,z))
	for axle: float in [-AXLE,AXLE]:
		var d: float=absf(z-axle)
		if d < 0.43: bottom=maxf(bottom,0.24+0.545*sqrt(maxf(0.0,1.0-pow(d/0.43,2))))
	return bottom

static func nose_edge(a: float) -> float:
	var corner: float=clampf((absf(a)-0.72)/0.28,0.0,1.0)
	return FRONT-0.215*sqrt(maxf(0.0,1.0-corner*corner))

# Sample the front ellipse by angle to keep its side corners round instead of
# bunching the curve into a few long, pointed triangles.
static func front_across(u: float) -> float:
	return sin((2.0*u-1.0)*PI*0.5)

static func front_uv_from_width(u: float) -> float:
	return 0.5+asin(clampf(2.0*u-1.0,-1.0,1.0))/PI

static func tail_edge(a: float) -> float:
	return REAR+0.25*sqrt(maxf(0.0,1.0-a*a))

static func hood_point(u: float,v: float) -> Vector3:
	var a: float=lerpf(front_across(u),2.0*u-1.0,smoothstep(0.72,1.0,v))
	var z: float=lerpf(nose_edge(a),-1.02,v)
	var cowl_x: float=a*top_width(-1.02)
	z+=0.038*maxf(0.0,1.0-pow(cowl_x/0.82,2))*smoothstep(0.70,1.0,v)
	# Form the soft, swept shoulders in the metal rather than drawing dark
	# stripes on a flat surface. The bonnet closes exactly to the nose cap.
	var envelope: float=pow(sin(PI*v),2)
	var ridge: float=0.024*exp(-pow((absf(a)-lerpf(0.55,0.72,v))/0.16,2))*envelope
	var valley: float=0.006*exp(-pow((absf(a)-lerpf(0.37,0.54,v))/0.14,2))*envelope
	# A restrained crown leaves a low, gently descending bonnet.
	var crown: float=0.030-0.010*pow(1.0-v,2.0)
	var side_blend: float=lerpf(pow(absf(a),2.0),smoothstep(0.68,1.0,absf(a)),smoothstep(-1.35,-1.02,z))
	var width: float=lerpf(top_width(z),side_width(z,shoulder(z)),side_blend)
	return Vector3(a*width,shoulder(z)+crown*(1.0-a*a)+ridge-valley,z)

static func deck_point(u: float,v: float) -> Vector3:
	# The centre leading edge is the backlight foot. The outer shoulders
	# continue forward to meet the side, and the trailing edge meets the cap.
	var a: float=2.0*u-1.0
	var aa: float=absf(a)
	var inner: float=5.0/6.0
	var wing: float=smoothstep(inner,1.0,aa)
	var inner_z: float=1.88-0.16*(1.0-pow(minf(1.0,aa/inner),2))
	var start_z: float=lerpf(inner_z,1.70,wing)
	var z: float=lerpf(start_z,tail_edge(a),v)
	var start_width: float=side_width(1.70,shoulder(1.70))
	var q: float=clampf((aa-inner)/(1.0-inner),0.0,1.0)
	var h: float=(-2.0*q*q*q+3.0*q*q)+(q*q*q-2.0*q*q+q)*(0.8/inner)*(1.0-inner)/(start_width-0.8)
	var start_x: float=0.8*aa/inner if aa<=inner else 0.8+(start_width-0.8)*h
	var width: float=lerpf(top_width(z),side_width(z,shoulder(z)),smoothstep(0.68,1.0,aa))
	var x: float=lerpf(signf(a)*start_x,a*width,v)
	var crown: float=lerpf(0.025,0.045,smoothstep(0.0,1.0,v))
	return Vector3(x,shoulder(z)+crown*(1.0-a*a),z)

static func cap_point(rear: bool,u: float,v: float) -> Vector3:
	var a: float=(2.0*u-1.0) if rear else front_across(u)
	var ztop: float=tail_edge(a) if rear else nose_edge(a)
	# Keep the lower bumper close to the hood edge in profile.  The old
	# outward mid-height bulge and tucked-under lower edge made a beak.
	var front_roll: float=lerpf(0.020*(1.0-v)-0.040*sin(PI*v),0.05*pow(1.0-v,3.6),smoothstep(0.55,1.0,absf(a)))
	var rear_roll: float=-0.12*pow(1.0-v,3.6)+0.075*sin(PI*v)*pow(1.0-a*a,2)
	var z: float=ztop + (rear_roll if rear else front_roll)
	var top: float=shoulder(ztop)+0.045*(1.0-a*a) if rear else hood_point(u,0.0).y
	var floor_y: float=0.24 if rear else 0.24+0.012*maxf(0.0,1.0-a*a)
	var y: float=top-(top-floor_y)*pow(1.0-v,1.8)
	if not rear:
		# Continue the bonnet tangent through the nose roll instead of forming
		# a separate flat top on the fascia.
		var next: Vector3=hood_point(u,0.001)
		var delta_z: float=next.z-ztop
		var hood_slope: float=(next.y-top)/delta_z if absf(delta_z)>0.000001 else 0.0
		var corner_blend: float=smoothstep(0.55,1.0,absf(a))
		var roll_slope: float=lerpf(0.020-0.040*PI,0.0,corner_blend)
		y+=hood_slope*roll_slope*(1.0-v)*smoothstep(0.45,0.98,v)
	var join: float=REAR if rear else FRONT
	var side_x: float=side_width(join,y)
	var top_round: float=(rear_shoulder_round(ztop)*smoothstep(0.68,1.0,absf(a)) if rear else front_shoulder_round(ztop)*pow(absf(a),2.0))*v
	var blend_to_side: float=pow(absf(a),2.0)
	var lower_taper: float=0.045 if rear else 0.090
	var x: float=a*lerpf(top_width(ztop)-top_round+0.045*sin(PI*v)-lower_taper*pow(1-v,2),side_x,blend_to_side)
	if rear:
		var deck_side: float=side_width(REAR,top)
		var upper_x: float=deck_point(u,1.0).x+a*pow(absf(a),2.0)*(side_x-deck_side)
		x=lerpf(x,upper_x,smoothstep(0.80,1.0,v))
	else:
		var hood_side: float=side_width(FRONT,top)
		var upper_x: float=hood_point(u,0.0).x+a*pow(absf(a),2.0)*(side_x-hood_side)
		x=lerpf(x,upper_x,lerpf(smoothstep(0.35,1.0,v),smoothstep(0.80,1.0,v),smoothstep(0.78,1.0,absf(a))))
	return Vector3(x,y,z)

static func front_lightbar_point(u: float,v: float) -> Vector3:
	var p: Vector3=cap_point(false,u,front_lamp_v(u,v,true))
	return p+Vector3.FORWARD*0.006

static func front_lamp_v(u: float,v: float,lit: bool) -> float:
	# Keep the guide's height continuous across the curved nose and into the
	# side wraps, instead of creating an artificial V or dip in the light.
	var reference_top: float=minf(hood_point(1.0,0.0).y,hood_point(0.5,0.0).y)
	var low_v: float=0.68 if lit else 0.66
	var high_v: float=0.72 if lit else 0.74
	var low_y: float=reference_top-(reference_top-0.24)*pow(1.0-low_v,1.8)
	var high_y: float=reference_top-(reference_top-0.24)*pow(1.0-high_v,1.8)
	var top: float=hood_point(u,0.0).y
	var y: float=lerpf(low_y,high_y,v)+0.003*(1.0-pow(front_across(u),2))
	var a: float=front_across(u)
	var floor_y: float=0.24+0.012*maxf(0.0,1.0-a*a)
	var value: float=1.0-pow(clampf((top-y)/(top-floor_y),0.0,1.0),1.0/1.8)
	# Invert the formed fascia height so the light remains level across it.
	for i: int in range(3):
		var lo: float=maxf(0.0,value-0.001)
		var hi: float=minf(1.0,value+0.001)
		var d: float=(cap_point(false,u,hi).y-cap_point(false,u,lo).y)/maxf(hi-lo,0.000001)
		if absf(d)<0.000001: break
		value=clampf(value+(y-cap_point(false,u,value).y)/d,0.0,1.0)
	return value

static func cap_strip(parent: Node3D,name_value: String,rear: bool,u0: float,u1: float,v0: float,v1: float,material: Material,simple: bool,offset: float=0.002) -> void:
	M.patch(parent,name_value,64,4,func(u: float,v: float)->Vector3:
		return cap_point(rear,lerpf(u0,u1,u),lerpf(v0,v1,v))+Vector3(0,0,offset if rear else -offset),material,Vector3.BACK if rear else Vector3.FORWARD,simple)

# Bounds in the same UV space as the front cap, so the opening rims, inset
# backs and the surrounding paint all share exactly the same boundary.
static func intake_edge(side: float,t: float) -> float:
	var half: float=lerpf(0.365,0.325,t)+0.008*sin(PI*t)
	return front_uv_from_width(0.5+side*half)

static func curtain_edge(side: float,outer: bool,t: float) -> float:
	# The outside edge is nearly vertical. A soft inner edge tapers into the
	# ends, following the upright air-curtain shape of the reference.
	var outside: float=0.5+side*0.421
	var width: float=0.006+0.039*pow(sin(PI*t),0.40)
	return front_uv_from_width(outside if outer else outside-side*width)

static func front_normal(u: float,v: float) -> Vector3:
	var du: Vector3=cap_point(false,minf(1.0,u+0.001),v)-cap_point(false,maxf(0.0,u-0.001),v)
	var dv: Vector3=cap_point(false,u,minf(1.0,v+0.001))-cap_point(false,u,maxf(0.0,v-0.001))
	var n: Vector3=-du.cross(dv).normalized()
	var a: float=front_across(u)
	var p: Vector3=cap_point(false,u,v)
	var eps: float=0.001
	var dy: float=(side_width(FRONT,p.y+eps)-side_width(FRONT,p.y-eps))/(2.0*eps)
	var dz: float=(side_width(FRONT+eps,p.y)-side_width(FRONT,p.y))/eps
	var side_n: Vector3=Vector3(signf(a),-dy,-dz).normalized()
	var joined: Vector3=n.slerp(side_n,smoothstep(0.80,1.0,absf(a))*smoothstep(0.55,0.98,v))
	var hood_n: Vector3=M.normal_at(hood_point,clampf(u,0.001,0.999),0.0,Vector3.UP)
	return joined.slerp(hood_n,smoothstep(0.80,1.0,v))

static func front_panel(parent: Node3D,label: String,v0: float,v1: float,left: Callable,right: Callable,paint: Material,simple: bool,columns: int=32,rows: int=20) -> void:
	M.patch(parent,label,columns,rows,func(u: float,v: float)->Vector3:
		return cap_point(false,lerpf(left.call(v),right.call(v),u),lerpf(v0,v1,v)),paint,Vector3.FORWARD,simple,Callable(),func(u: float,v: float)->Vector3:
		var x: float=lerpf(left.call(v),right.call(v),u)
		var y: float=lerpf(v0,v1,v)
		return front_normal(x,y))

static func front_recess(parent: Node3D,label: String,v0: float,v1: float,left: Callable,right: Callable,paint: Material,dark: Material,simple: bool) -> void:
	var point: Callable=func(u: float,v: float)->Vector3:
		return cap_point(false,lerpf(left.call(v),right.call(v),u),lerpf(v0,v1,v))
	var depth: float=0.014
	M.patch(parent,label+"Back",32,16,func(u: float,v: float)->Vector3:
		return point.call(u,v)+Vector3.BACK*depth,dark,Vector3.FORWARD,simple)
	for edge: int in range(4):
		M.patch(parent,label+"Return"+str(edge),24,3,func(u: float,v: float)->Vector3:
			var uv:=Vector2(u,0.0) if edge==0 else Vector2(1.0,u) if edge==1 else Vector2(1.0-u,1.0) if edge==2 else Vector2(0.0,1.0-u)
			return point.call(uv.x,uv.y)+Vector3.BACK*depth*v,dark,Vector3.FORWARD,simple)

static func build(car: CarVisual,paint: Material,trim: Material,bright: Material) -> void:
	var body: Node3D=car.body
	var simple: bool=car.simple_model
	M.patch(body,"ReferenceHood",80,48,hood_point,paint,Vector3.UP,simple)
	# Matching transverse stations make the deck and curved tail share the
	# same polygon edge, including the tightly rounded corners.
	M.patch(body,"ReferenceRearDeck",120,20,deck_point,paint,Vector3.UP,simple)
	for side: float in [-1.0,1.0]:
		var hint:=Vector3(side,0,0)
		M.patch(body,"ReferenceSide"+str(side),160,32,func(u: float,v: float)->Vector3:
			# Share the hood and deck edge stations, so curved boundaries meet
			# as actual triangles rather than only as mathematical surfaces.
			var z: float
			if u <= 0.30:
				z=lerpf(FRONT,-1.02,u/0.30)
			elif u <= 0.875:
				z=lerpf(-1.02,1.70,(u-0.30)/0.575)
			else:
				z=lerpf(1.70,REAR,(u-0.875)/0.125)
			var y: float=lerpf(wheel_bottom(z),shoulder(z),1.0-pow(1.0-v,1.8))
			var t: float=clampf((y-0.24)/(shoulder(z)-0.24),0,1)
			var offset: float=0.05*pow(1-t,2)*(1-smoothstep(FRONT,FRONT+0.20,z))-0.12*pow(1-t,2)*smoothstep(REAR-0.25,REAR,z)
			return side_point(side,z,y)+Vector3(0,0,offset),paint,hint,simple)
		# The moulded lower sill rises at the back and carries the strong black blade.
		M.patch(body,"ReferenceSill"+str(side),64,4,func(u: float,v: float)->Vector3:
			var z: float=lerpf(-0.98,0.98,u)
			var rise: float=(0.018+0.010*z)*smoothstep(-0.98,-0.88,z)*(1.0-smoothstep(0.88,0.98,z))
			var y: float=lerpf(0.235+rise,0.282+0.024*u+rise,v)
			return side_point(side,z,y)+Vector3(side*0.004,0,0),trim,hint,simple)
		# Narrow shut lines follow the curved body, stopping at the wheel apertures.
		for seam: int in range(3):
			M.ribbon(body,"ReferenceDoorSeam"+str(side)+str(seam),func(t: float)->Vector3:
				var z: float=(-0.96+0.08*t) if seam==0 else (0.02+0.03*t) if seam==1 else (0.93-0.18*t)
				var seam_top: float=minf(0.96,shoulder(z)-0.002)
				var y: float=lerpf(seam_top,0.31,t)
				return side_point(side,z,y)+Vector3(side*0.0015,0,0),32,0.0014,trim,simple)
		for axle: float in [-AXLE,AXLE]:
			M.patch(body,"ReferenceArch"+str(side)+str(axle),64,6,func(u: float,v: float)->Vector3:
				var angle: float=PI*u
				var z: float=axle+cos(angle)*lerpf(0.43,0.449,v)
				var y: float=0.24+sin(angle)*lerpf(0.545,0.565,v)
				return side_point(side,z,y)+Vector3(side*0.002*sin(PI*v),0,0),paint,hint,simple)
			M.patch(body,"ReferenceWheelWell"+str(side)+str(axle),64,5,func(u: float,v: float)->Vector3:
				var a: float=PI*u
				var z: float=axle+0.43*cos(a)
				var y: float=0.24+0.545*sin(a)
				return Vector3(side*lerpf(side_width(z,y),0.69,v),y,z),trim,Vector3(side,-0.2,0),simple)
	# A continuous painted fascia is genuinely closed, with the light guide
	# following the same curved surface and a restrained lower aerodynamic lip.
	M.patch(body,"ReferenceFrontUpper",80,36,func(u: float,v: float)->Vector3:
		return cap_point(false,u,v),paint,Vector3.FORWARD,simple,Callable(),func(u: float,v: float)->Vector3:
		return front_normal(u,v))
	# Match the side panel's vertical stations at both rear corners.
	M.patch(body,"ReferenceRear",120,32,func(u: float,v: float)->Vector3:return cap_point(true,u,v),paint,Vector3.BACK,simple)
	# The slim light guide follows the closed electric nose.
	M.patch(body,"ReferenceFrontLampHousing",72,4,func(u: float,v: float)->Vector3:
		return cap_point(false,u,front_lamp_v(u,v,false))+Vector3.FORWARD*0.003,trim,Vector3.FORWARD,simple)
	var white:=StandardMaterial3D.new()
	white.albedo_color=Color("dcefff")
	white.emission_enabled=true
	white.emission=Color("cde9ff")
	white.emission_energy_multiplier=0.65
	M.patch(body,"ReferenceFrontLightbar",72,4,front_lightbar_point,white,Vector3.FORWARD,simple)
	for side: float in [-1.0,1.0]:
		var edge_u: float=0.0 if side<0 else 1.0
		var center: float=(cap_point(false,edge_u,front_lamp_v(edge_u,0.0,true)).y+cap_point(false,edge_u,front_lamp_v(edge_u,1.0,true)).y)*0.5
		var strip_half: float=(cap_point(false,edge_u,front_lamp_v(edge_u,1.0,true)).y-cap_point(false,edge_u,front_lamp_v(edge_u,0.0,true)).y)*0.5
		var housing_half: float=(cap_point(false,edge_u,front_lamp_v(edge_u,1.0,false)).y-cap_point(false,edge_u,front_lamp_v(edge_u,0.0,false)).y)*0.5
		# Bridge the rounded corner between the cap and the side rather than
		# leaving the ends of the two independent patches floating apart.
		for lit: bool in [false,true]:
			M.patch(body,("ReferenceLightCorner" if lit else "ReferenceLightCornerHousing")+str(side),6,4,func(u: float,v: float)->Vector3:
				var cap_v: float=front_lamp_v(edge_u,v,lit)
				var p: Vector3=cap_point(false,edge_u,cap_v)
				var front: Vector3=p+Vector3.FORWARD*(0.006 if lit else 0.003)
				var flank: Vector3=p+Vector3(side*(0.006 if lit else 0.004),0,0)
				return front.lerp(flank,u),white if lit else trim,Vector3(side,0,-1).normalized(),simple)
		M.patch(body,"ReferenceLightWrapHousing"+str(side),20,4,func(u: float,v: float)->Vector3:
			var z: float=lerpf(FRONT,FRONT+0.22,u)
			var y: float=center+0.016*u+lerpf(-housing_half,housing_half,v)*(1.0-0.55*u)
			var t: float=clampf((y-0.24)/(shoulder(z)-0.24),0,1)
			var offset: float=0.05*pow(1-t,2)*(1-smoothstep(FRONT,FRONT+0.20,z))
			return side_point(side,z,y)+Vector3(side*0.004,0,offset),trim,Vector3(side,0,0),simple)
		M.patch(body,"ReferenceLightWrap"+str(side),20,4,func(u: float,v: float)->Vector3:
			var z: float=lerpf(FRONT,FRONT+0.22,u)
			var y: float=center+0.016*u+lerpf(-strip_half,strip_half,v)*(1.0-0.55*u)
			var t: float=clampf((y-0.24)/(shoulder(z)-0.24),0,1)
			var offset: float=0.05*pow(1-t,2)*(1-smoothstep(FRONT,FRONT+0.20,z))
			return side_point(side,z,y)+Vector3(side*0.006,0,offset),white,Vector3(side,0,0),simple)
	# A fine lower lip sits below the closed, grille-free nose.
	cap_strip(body,"ReferenceFrontSplitter",false,0.035,0.965,0.01,0.035,trim,simple,0.008)
	cap_strip(body,"ReferenceFrontSplitterEdge",false,0.045,0.955,0.008,0.018,bright,simple,0.011)
	cap_strip(body,"ReferenceRearLampHousing",true,0.02,0.98,0.79,0.86,trim,simple,0.003)
	cap_strip(body,"ReferenceRearLightbar",true,0.025,0.975,0.805,0.835,car.brake_material,simple,0.004)
	cap_strip(body,"ReferenceRearDiffuser",true,0.08,0.92,0.025,0.085,trim,simple,0.003)
