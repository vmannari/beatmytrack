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
		var t: float=clampf((z-FRONT+0.215)/(-1.02-FRONT+0.215),0.0,1.0)
		# The low cowl establishes the bonnet, while the fender alone rises
		# around the tire. The centre of the hood stays below that shoulder.
		return 0.670+0.145*(2.0*t-t*t)+front_haunch(z)
	# A straight, gently rising waist makes the rear haunch the visual anchor.
	if z < 1.70: return lerpf(0.815,0.865,(z+1.02)/2.72)
	var t: float=clampf((z-1.70)/0.50,0.0,1.0)
	return 0.865-0.045*t*t

static func front_haunch(z: float) -> float:
	var t: float=clampf((z-FRONT+0.215)/(-1.02-FRONT+0.215),0.0,1.0)
	return 0.027*exp(-pow((z+AXLE)/0.30,2))*pow(sin(PI*t),2)

static func top_width(z: float) -> float:
	if z < -1.02:
		# Preserve the fitted windscreen width and gently taper towards the nose.
		var cowl: float=0.845+0.065*exp(-pow((-1.02+AXLE)/0.44,2))+0.075*exp(-pow((-1.02-AXLE)/0.44,2))
		var progress: float=clampf((-1.02-z)/(-1.02-FRONT),0.0,1.0)
		return cowl-0.040*progress
	return 0.845+0.065*exp(-pow((z+AXLE)/0.44,2))+0.075*exp(-pow((z-AXLE)/0.44,2))

static func front_shoulder_round(z: float) -> float:
	return 0.145*(1.0-smoothstep(FRONT,-1.00,z))

static func rear_shoulder_round(z: float) -> float:
	return 0.075*smoothstep(1.70,2.01,z)

static func side_width(z: float,y: float) -> float:
	var h: float=shoulder(z)
	var t: float=clampf((y-0.22)/(h-0.22),0.0,1.0)
	var door: float=exp(-pow(z/0.98,6))
	# A shoulder highlight, broad door crown and tucked lower flank replace
	# the single inflated slab; every shut line samples this same metal.
	var swell: float=0.025*sin(PI*t)+0.012*door*exp(-pow((t-0.72)/0.12,2))
	var hollow: float=0.028*door*exp(-pow((t-0.40)/0.22,2))
	var lower_fold: float=0.014*door*exp(-pow((t-0.18)/0.10,2))
	var end_tuck: float=0.075*smoothstep(1.45,2.05,absf(z))*pow(1.0-t,1.6)
	var radius: float=front_shoulder_round(z)+rear_shoulder_round(z)+0.030*door
	var upper: float=clampf((y-(h-radius))/maxf(radius,0.00001),0.0,1.0)
	var roundover: float=radius*(1.0-sqrt(maxf(0.0,1.0-upper*upper)))
	return top_width(z)+swell-hollow+lower_fold-0.075*pow(1.0-t,2)-end_tuck-roundover

static func side_point(side: float,z: float,y: float) -> Vector3:
	return Vector3(side*side_width(z,y),y,z)

static func flank_point(side: float,z: float,y: float) -> Vector3:
	var t: float=clampf((y-0.24)/(shoulder(z)-0.24),0.0,1.0)
	var offset: float=0.05*pow(1.0-t,2)*(1.0-smoothstep(FRONT,FRONT+0.20,z))-0.12*pow(1.0-t,2)*smoothstep(REAR-0.25,REAR,z)
	return side_point(side,z,y)+Vector3(0,0,offset)

static func fender_point(side: float,axle: float,u: float,v: float) -> Vector3:
	var angle: float=PI*u
	var outer_z: float=axle+0.490*cos(angle)
	var outer_y: float=minf(maxf(0.24+0.610*sin(angle),wheel_bottom(outer_z)),shoulder(outer_z)-0.002)
	var inner_z: float=axle+0.43*cos(angle)
	var inner_y: float=maxf(0.24+0.545*sin(angle),wheel_bottom(inner_z))
	var z: float=lerpf(outer_z,inner_z,v)
	var y: float=lerpf(outer_y,inner_y,v)
	var p: Vector3=flank_point(side,z,y)
	# A low, broad shoulder blends into the electric body skin. Only a thin
	# opening edge remains; the former pronounced rolled flare is removed.
	var flare: float=0.012*pow(maxf(0.0,sin(angle)),0.75)
	var fold: float=smoothstep(0.0,1.0,v)
	p.x+=side*(flare*fold-0.0008*(1.0-fold))
	return p

static func wheelhouse_edge(side: float,axle: float,u: float) -> Vector3:
	var p: Vector3=fender_point(side,axle,u,1.0)
	return p-Vector3(side*0.0035,0.004*sin(PI*u),0.004*cos(PI*u))

static func wheelhouse_inner(axle: float) -> float:
	return 0.48 if axle<0.0 else 0.57

static func undertray_width(z: float) -> float:
	return lerpf(0.48,0.57,smoothstep(-0.90,0.90,z))

static func build_wheelhouse(car: CarVisual,side: float,axle: float,paint: Material,trim: Material) -> void:
	var label: String=str(side)+str(axle)
	var simple: bool=car.simple_model
	M.patch(car.body,"ReferenceArch"+label,64,4,func(u: float,v: float)->Vector3:
		return fender_point(side,axle,u,v),paint,Vector3(side,0,0),simple)
	M.patch(car.body,"VoltFenderReturn"+label,64,2,func(u: float,v: float)->Vector3:
		return fender_point(side,axle,u,1.0).lerp(wheelhouse_edge(side,axle,u),v),trim,Vector3(side,-0.2,0),simple)
	# A complete cavity: curved roof, opaque inboard bulkhead and two end
	# walls. These surfaces face the tire; the aperture itself stays open.
	M.patch(car.body,"ReferenceWheelWell"+label,64,2,func(u: float,v: float)->Vector3:
		var p: Vector3=wheelhouse_edge(side,axle,u)
		p.x=lerpf(p.x,side*wheelhouse_inner(axle),v)
		return p,trim,Vector3.DOWN,simple,Callable(),func(u: float,_v: float)->Vector3:
		return Vector3(0,-sin(PI*u)/0.541,-cos(PI*u)/0.426).normalized())
	M.patch(car.body,"VoltWheelhouseBack"+label,64,2,func(u: float,v: float)->Vector3:
		var p: Vector3=wheelhouse_edge(side,axle,u)
		return Vector3(side*wheelhouse_inner(axle),lerpf(0.235,p.y,v),p.z),trim,Vector3(side,0,0),simple)
	for end: int in range(2):
		M.patch(car.body,"VoltWheelhouseEnd"+label+str(end),4,2,func(u: float,v: float)->Vector3:
			var p: Vector3=wheelhouse_edge(side,axle,float(end))
			return Vector3(lerpf(side*wheelhouse_inner(axle),p.x,u),lerpf(0.235,p.y,v),p.z),trim,Vector3(0,0,-1 if end==0 else 1),simple)

static func build_undertray(car: CarVisual,trim: Material) -> void:
	for top: bool in [false,true]:
		M.patch(car.body,"VoltUndertray"+str(top),4,16,func(u: float,v: float)->Vector3:
			var z: float=lerpf(-2.08,2.06,v)
			return Vector3((2.0*u-1.0)*undertray_width(z),0.270 if top else 0.255,z),trim,Vector3.UP if top else Vector3.DOWN,car.simple_model)
	for side: float in [-1.0,1.0]:
		M.patch(car.body,"VoltUndertraySide"+str(side),16,2,func(u: float,v: float)->Vector3:
			var z: float=lerpf(-2.08,2.06,u)
			return Vector3(side*undertray_width(z),lerpf(0.255,0.270,v),z),trim,Vector3(side,0,0),car.simple_model)
	for end: int in range(2):
		M.patch(car.body,"VoltUndertrayEnd"+str(end),4,2,func(u: float,v: float)->Vector3:
			var z: float=-2.08 if end==0 else 2.06
			return Vector3((2.0*u-1.0)*undertray_width(z),lerpf(0.255,0.270,v),z),trim,Vector3.FORWARD if end==0 else Vector3.BACK,car.simple_model)

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
	var ridge: float=0.014*exp(-pow((absf(a)-lerpf(0.55,0.72,v))/0.14,2))*envelope
	var valley: float=0.006*exp(-pow((absf(a)-lerpf(0.37,0.54,v))/0.14,2))*envelope
	# A restrained crown leaves a low, gently descending bonnet.
	var crown: float=0.025-0.009*pow(1.0-v,2.0)
	var side_blend: float=lerpf(pow(absf(a),2.0),smoothstep(0.68,1.0,absf(a)),smoothstep(-1.35,-1.02,z))
	var width: float=lerpf(top_width(z),side_width(z,shoulder(z)),side_blend)
	return Vector3(a*width,shoulder(z)+(crown-front_haunch(z))*(1.0-a*a)+ridge-valley,z)

static func rear_glass_foot(across: float) -> Vector3:
	# Shared backlight/deck boundary: the centre sweeps rearward, following
	# the owner's marked arc, with a small transverse crown in the glass.
	var bow: float=1.0-across*across
	var corner_y: float=shoulder(1.88)+0.025*(1.0-pow(5.0/6.0,2))
	return Vector3(0.80*across,corner_y+0.020*bow,1.88+0.20*bow)

static func deck_point(u: float,v: float) -> Vector3:
	# The centre leading edge is the backlight foot. The outer shoulders
	# continue forward to meet the side, and the trailing edge meets the cap.
	var a: float=2.0*u-1.0
	var aa: float=absf(a)
	var inner: float=5.0/6.0
	var wing: float=smoothstep(inner,1.0,aa)
	var foot: Vector3=rear_glass_foot(minf(1.0,aa/inner))
	var inner_z: float=foot.z
	var start_z: float=lerpf(inner_z,1.70,wing)
	var z: float=lerpf(start_z,tail_edge(a),v)
	var start_width: float=side_width(1.70,shoulder(1.70))
	var q: float=clampf((aa-inner)/(1.0-inner),0.0,1.0)
	var h: float=(-2.0*q*q*q+3.0*q*q)+(q*q*q-2.0*q*q+q)*(0.8/inner)*(1.0-inner)/(start_width-0.8)
	var start_x: float=0.8*aa/inner if aa<=inner else 0.8+(start_width-0.8)*h
	var width: float=lerpf(top_width(z),side_width(z,shoulder(z)),smoothstep(0.68,1.0,aa))
	var x: float=lerpf(signf(a)*start_x,a*width,v)
	var crown: float=lerpf(0.025,0.045,smoothstep(0.0,1.0,v))
	var start_y: float=lerpf(foot.y,shoulder(1.70),wing)
	var start_correction: float=start_y-(shoulder(start_z)+0.025*(1.0-a*a))
	var y: float=shoulder(z)+crown*(1.0-a*a)+start_correction*(1.0-smoothstep(0.0,0.90,v))
	return Vector3(x,y,z)

static func cap_point(rear: bool,u: float,v: float) -> Vector3:
	var a: float=(2.0*u-1.0) if rear else front_across(u)
	var ztop: float=tail_edge(a) if rear else nose_edge(a)
	# Keep the lower bumper close to the hood edge in profile.  The old
	# outward mid-height bulge and tucked-under lower edge made a beak.
	var front_roll: float=lerpf(0.020*(1.0-v)-0.040*sin(PI*v),0.05*pow(1.0-v,3.6),smoothstep(0.55,1.0,absf(a)))
	var rear_roll: float=-0.12*pow(1.0-v,3.6)+0.075*sin(PI*v)*pow(1.0-a*a,2)
	var z: float=ztop + (rear_roll if rear else front_roll)
	if not rear:
		z+=0.035*smoothstep(0.23,0.42,v)*(1.0-smoothstep(0.48,0.70,v))*(1.0-a*a)
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
	if not lit: low_y-=0.050*exp(-pow((absf(front_across(u))-0.86)/0.125,4))
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

static func front_recess(parent: Node3D,label: String,v0: float,v1: float,left: Callable,right: Callable,paint: Material,dark: Material,simple: bool,columns: int=32,rows: int=16) -> void:
	var point: Callable=func(u: float,v: float)->Vector3:
		return cap_point(false,lerpf(left.call(v),right.call(v),u),lerpf(v0,v1,v))
	var depth: float=0.038
	M.patch(parent,label+"Back",columns,rows,func(u: float,v: float)->Vector3:
		return point.call(u,v)+Vector3.BACK*depth,dark,Vector3.FORWARD,simple)
	for edge: int in range(4):
		M.patch(parent,label+"Return"+str(edge),12,3,func(u: float,v: float)->Vector3:
			var uv:=Vector2(u,0.0) if edge==0 else Vector2(1.0,u) if edge==1 else Vector2(1.0-u,1.0) if edge==2 else Vector2(0.0,1.0-u)
			return point.call(uv.x,uv.y)+Vector3.BACK*depth*v,dark,Vector3.FORWARD,simple)

static func build(car: CarVisual,paint: Material,trim: Material,bright: Material) -> void:
	var body: Node3D=car.body
	var simple: bool=car.simple_model
	M.patch(body,"ReferenceHood",80,48,hood_point,paint,Vector3.UP,simple)
	# A fitted shut line defines the bonnet instead of leaving one featureless
	# upper casting. It closes around the cowl without crossing the glazing.
	M.ribbon(body,"SportBonnetShutLine",func(t: float)->Vector3:
		var u: float
		var v: float
		if t<0.25:
			u=lerpf(0.09,0.91,t*4.0);v=0.045
		elif t<0.50:
			u=0.91;v=lerpf(0.045,0.97,(t-0.25)*4.0)
		elif t<0.75:
			u=lerpf(0.91,0.09,(t-0.50)*4.0);v=0.97
		else:
			u=0.09;v=lerpf(0.97,0.045,(t-0.75)*4.0)
		return hood_point(u,v)+Vector3.UP*0.0012,144,0.0009,trim,simple)
	# Matching transverse stations make the deck and curved tail share the
	# same polygon edge, including the tightly rounded corners.
	M.patch(body,"ReferenceRearDeck",120,20,deck_point,paint,Vector3.UP,simple)
	for side: float in [-1.0,1.0]:
		var hint:=Vector3(side,0,0)
		M.patch(body,"ReferenceSide"+str(side),160,26,func(u: float,v: float)->Vector3:
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
			return flank_point(side,z,y),paint,hint,simple)
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
			build_wheelhouse(car,side,axle,paint,trim)
	build_undertray(car,trim)
	# A closed electric upper nose sits over real lower cooling and corner
	# apertures. The painted regions share their perimeter with inset returns.
	var opening_left: Callable=func(t: float)->float:return front_uv_from_width(0.5-lerpf(0.35,0.31,t)+0.025*pow(absf(2.0*t-1.0),8))
	var opening_right: Callable=func(t: float)->float:return front_uv_from_width(0.5+lerpf(0.35,0.31,t)-0.025*pow(absf(2.0*t-1.0),8))
	front_panel(body,"ReferenceFrontUpper",0.48,1.0,func(_t: float)->float:return 0.0,func(_t: float)->float:return 1.0,paint,simple,80,18)
	front_panel(body,"SportLowerBumper",0.0,0.08,func(_t: float)->float:return 0.0,func(_t: float)->float:return 1.0,paint,simple,64,4)
	for side: float in [-1.0,1.0]:
		var outside: Callable=func(t: float)->float:return curtain_edge(side,true,t)
		var inside: Callable=func(t: float)->float:return curtain_edge(side,false,t)
		front_recess(body,"SportCurtain"+str(side),0.08,0.48,outside if side<0 else inside,inside if side<0 else outside,paint,trim,simple,16,12)
		for band: int in range(2):
			var lo: float=0.08 if band==0 else 0.27
			var hi: float=0.27 if band==0 else 0.48
			var outer: Callable=func(t: float)->float:return outside.call((lerpf(lo,hi,t)-0.08)/0.40)
			var inner: Callable=func(t: float)->float:return inside.call((lerpf(lo,hi,t)-0.08)/0.40)
			front_panel(body,"SportBumperOuter"+str(side)+str(band),lo,hi,func(_t: float)->float:return 0.0 if side<0 else outer.call(_t),func(_t: float)->float:return outer.call(_t) if side<0 else 1.0,paint,simple,12,10)
			if band==0:
				front_panel(body,"SportBumperInner"+str(side),lo,hi,inner if side<0 else opening_right,opening_left if side<0 else inner,paint,simple,12,10)
	front_panel(body,"SportBumperCentre",0.27,0.48,func(t: float)->float:return curtain_edge(-1.0,false,(lerpf(0.27,0.48,t)-0.08)/0.40),func(t: float)->float:return curtain_edge(1.0,false,(lerpf(0.27,0.48,t)-0.08)/0.40),paint,simple,64,10)
	front_recess(body,"SportCooling",0.08,0.27,opening_left,opening_right,paint,trim,simple)
	for slat: int in range(3):
		var vv: float=lerpf(0.11,0.23,float(slat)/2.0)
		M.patch(body,"SportCoolingSlat"+str(slat),40,2,func(u: float,v: float)->Vector3:
			var span: float=(vv-0.08)/0.19
			return cap_point(false,lerpf(opening_left.call(span),opening_right.call(span),u),vv+v*0.010)+Vector3.BACK*0.021,trim,Vector3.FORWARD,simple)
	# Match the side panel's vertical stations at both rear corners.
	M.patch(body,"ReferenceRear",120,28,func(u: float,v: float)->Vector3:return cap_point(true,u,v),paint,Vector3.BACK,simple)
	# The slim light guide follows the closed electric nose.
	M.patch(body,"ReferenceFrontLampHousing",72,4,func(u: float,v: float)->Vector3:
		return cap_point(false,u,front_lamp_v(u,v,false))+Vector3.FORWARD*0.003,trim,Vector3.FORWARD,simple)
	var white:=StandardMaterial3D.new()
	white.albedo_color=Color("dcefff")
	white.emission_enabled=true
	white.emission=Color("cde9ff")
	white.emission_energy_multiplier=0.65
	M.patch(body,"ReferenceFrontLightbar",72,4,front_lightbar_point,white,Vector3.FORWARD,simple)
	# Smoked lamp pockets and distinct projector optics give the thin guide
	# an actual headlamp assembly, fitted to the same fascia at either end.
	for side: float in [-1.0,1.0]:
		var begin: float=0.065 if side<0 else 0.770
		for optic: int in range(3):
			M.patch(body,"SportProjector"+str(side)+str(optic),8,4,func(u: float,v: float)->Vector3:
				var uu: float=begin+0.022+0.047*optic+0.027*u
				var vv: float=front_lamp_v(uu,lerpf(0.24,0.44,v),false)
				return cap_point(false,uu,vv)+Vector3.FORWARD*0.007,white,Vector3.FORWARD,simple)
	for side: float in [-1.0,1.0]:
		var edge_u: float=0.0 if side<0 else 1.0
		var center: float=(cap_point(false,edge_u,front_lamp_v(edge_u,0.0,true)).y+cap_point(false,edge_u,front_lamp_v(edge_u,1.0,true)).y)*0.5
		var strip_half: float=(cap_point(false,edge_u,front_lamp_v(edge_u,1.0,true)).y-cap_point(false,edge_u,front_lamp_v(edge_u,0.0,true)).y)*0.5
		var housing_half: float=(cap_point(false,edge_u,front_lamp_v(edge_u,1.0,false)).y-cap_point(false,edge_u,front_lamp_v(edge_u,0.0,false)).y)*0.5
		var housing_center: float=(cap_point(false,edge_u,front_lamp_v(edge_u,1.0,false)).y+cap_point(false,edge_u,front_lamp_v(edge_u,0.0,false)).y)*0.5
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
			var y: float=housing_center+0.016*u+lerpf(-housing_half,housing_half,v)*(1.0-0.55*u)
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
	cap_strip(body,"SportRearValance",true,0.06,0.94,0.085,0.25,trim,simple,0.006)
	# Five short diffuser fences follow the curved rear instead of exposed
	# rectangular blocks; a painted trailing lip finishes the deck edge.
	for fin: int in range(5):
		var uu: float=0.27+0.115*fin
		M.patch(body,"SportDiffuserFin"+str(fin),8,4,func(u: float,v: float)->Vector3:
			var p: Vector3=cap_point(true,uu,lerpf(0.025,0.22,u))
			p.z+=0.008+0.030*sin(PI*u)*sin(PI*v)
			p.x+=0.003*cos(PI*v)
			return p,trim,Vector3.BACK,simple)
	M.patch(body,"SportDeckLip",64,4,func(u: float,v: float)->Vector3:
		var p: Vector3=deck_point(lerpf(0.06,0.94,u),lerpf(0.965,1.0,v))
		p.y+=0.013*sin(PI*v*0.5)*sin(PI*u)
		return p,paint,Vector3.UP,simple)
