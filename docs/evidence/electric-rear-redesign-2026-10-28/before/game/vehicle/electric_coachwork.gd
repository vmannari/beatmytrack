extends RefCounted
## Original electric sportback. One authored section model; metres, nose -Z.
const AXLE: float = 2.46 / (2.0 * HandlingConfig.BODY_SCALE)
const HALF_TRACK: float = 1.48 / (2.0 * HandlingConfig.BODY_SCALE)
const FRONT_JOIN: float = -1.98
const REAR_JOIN: float = 1.98
const ASSET_ROOT: String = "res://assets/vehicles/electric_coachwork_v15"
static var meshes: Dictionary = {}
static var reveal_queries: Dictionary = {}
static var use_baked: bool = true
const REAR_FLOW_START: float = 0.88
static var rear_profile_data: PackedFloat64Array = []
static var rear_join_data: PackedFloat64Array = []

static func cubic(a: float,b: float,c: float,d: float,t: float) -> float:
	return a*pow(1-t,3)+3*b*pow(1-t,2)*t+3*c*(1-t)*t*t+d*t*t*t

static func upper(z: float) -> float:
	if z< -0.91: return 1.014+0.028*(z+0.91)-0.070*pow(z+0.91,2)
	return 1.014+0.028*(z+0.91)*(1-smoothstep(-0.91,0.50,z))-0.060*smoothstep(0.60,1.98,z)

static func top_width(z: float) -> float:
	return 0.882+0.025*exp(-pow((z+AXLE)/0.48,2))+0.047*exp(-pow((z-AXLE)/0.55,2))

static func width(y: float,z: float) -> float:
	var top: float=upper(z)-0.04
	var radius: float=0.10
	var rise: float=clampf(y-top+radius,0,radius)
	var roll: float=sqrt(maxf(0,radius*radius-rise*rise))
	var t: float=clampf((y-0.28)/maxf(0.1,top-0.28),0,1)
	var low_tuck: float=0.045*pow(1-t,2)
	var hollow: float=0.022*exp(-pow((y-0.48)/0.16,2))*exp(-pow(z/0.90,4))*(1-smoothstep(top-0.18,top-0.10,y))
	return top_width(z)+roll-low_tuck-hollow

static func skin_width(y: float,z: float) -> float: return width(y,z)
static func deform_front_point(point: Vector3) -> Vector3: return point

static func nose_edge(a: float) -> float:
	return FRONT_JOIN-0.27*sqrt(maxf(0,1-a*a))

static func tail_edge(a: float) -> float:
	return REAR_JOIN+0.19*sqrt(maxf(0,1-a*a))

static func hood_point(u: float,v: float) -> Vector3:
	var a: float=2*u-1
	var z: float=lerpf(nose_edge(a),-0.91,v)
	return Vector3(a*top_width(z),upper(z)-0.04*(2*a*a-pow(a,4)),z)

static func quintic(a: float,da: float,dda: float,b: float,db: float,ddb: float,t: float) -> float:
	var c2: float=dda*0.5
	var e: float=b-a-da-c2
	var f: float=db-da-2*c2
	var g: float=ddb-2*c2
	return a+da*t+c2*t*t+(10*e-4*f+0.5*g)*pow(t,3)+(-15*e+7*f-g)*pow(t,4)+(6*e-3*f+0.5*g)*pow(t,5)

static func cubic_d(a: float,b: float,c: float,d: float,t: float) -> float:
	return 3*(b-a)*pow(1-t,2)+6*(c-b)*(1-t)*t+3*(d-c)*t*t

static func cubic_dd(a: float,b: float,c: float,d: float,t: float) -> float:
	return 6*(c-2*b+a)*(1-t)+6*(d-2*c+b)*t

static func rear_blend(v: float) -> float:
	var t: float=clampf((v-REAR_FLOW_START)/(1-REAR_FLOW_START),0,1)
	return t*t*t*(10-15*t+6*t*t)

static func rear_center_height(z: float) -> float:
	if rear_profile_data.is_empty():
		var v: float=REAR_FLOW_START
		var end_y: float=upper(1.65)
		var dz: float=cubic_d(-0.91,-0.37,0.62,1.65,v)
		var ddz: float=cubic_dd(-0.91,-0.37,0.62,1.65,v)
		var dy: float=cubic_d(1.014,1.64,1.70,end_y,v)
		var ddy: float=cubic_dd(1.014,1.64,1.70,end_y,v)
		rear_profile_data=PackedFloat64Array([canopy_z(v),canopy_center(v),dy/dz,(ddy*dz-dy*ddz)/pow(dz,3)])
	var length: float=2.17-rear_profile_data[0]
	var t: float=clampf((z-rear_profile_data[0])/length,0,1)
	# Endpoint derivatives retain the original small formed tail lip.
	return quintic(rear_profile_data[1],rear_profile_data[2]*length,rear_profile_data[3]*length*length,upper(2.17)+0.018,0.072/0.52*length,0.216/pow(0.52,2)*length*length,t)

static func rear_surface_height(x: float,z: float) -> float:
	var a: float=x/top_width(z)
	return upper(z)-0.04*(2*a*a-pow(a,4))+(rear_center_height(z)-upper(z))*pow(1-a*a,2)

static func deck_point(u: float,v: float) -> Vector3:
	var a: float=2*u-1
	var length: float=tail_edge(a)-1.65
	var z: float=1.65+length*v
	var lip: float=0.018*pow(v,4)*(1-a*a)
	if rear_join_data.is_empty():
		var h: float=0.0001
		var y: float=rear_center_height(1.65)-upper(1.65)
		var before: float=rear_center_height(1.65-h)-upper(1.65-h)
		var after: float=rear_center_height(1.65+h)-upper(1.65+h)
		rear_join_data=PackedFloat64Array([y,(after-before)/(2*h),(after-2*y+before)/(h*h)])
	# Continue exactly the glass/corner height, tangent and curvature. The
	# correction vanishes with both derivatives at the unchanged tail lip.
	var fairing: float=quintic(rear_join_data[0],rear_join_data[1]*length,rear_join_data[2]*length*length,0,0,0,v)*pow(1-a*a,2)
	return Vector3(a*top_width(z),upper(z)-0.04*(2*a*a-pow(a,4))+lip+fairing,z)

static func side_point(side: float,z: float,y: float) -> Vector3:
	return Vector3(side*width(y,z),y,z)

static func side_bottom(z: float) -> float:
	var bottom: float=0.28
	for axle: float in [-AXLE,AXLE]:
		var d: float=absf(z-axle)
		if d<0.418: bottom=maxf(bottom,0.37+sqrt(0.418*0.418-d*d))
	return bottom

static func side_surface(side: float,u: float,v: float) -> Vector3:
	var z: float=lerpf(FRONT_JOIN,REAR_JOIN,u)
	return side_point(side,z,lerpf(side_bottom(z),upper(z)-0.04,1-pow(1-v,2)))

static func cap_point(rear_face: bool,u: float,v: float) -> Vector3:
	var a: float=2*u-1
	var join: float=REAR_JOIN if rear_face else FRONT_JOIN
	var end: float=tail_edge(a) if rear_face else nose_edge(a)
	var top: float=upper(end)-0.04*(2*a*a-pow(a,4))+(0.018*(1-a*a) if rear_face else 0)
	var y: float=cubic(0.28,0.48,top-0.05,top,v)
	var z: float
	if rear_face: z=cubic(2.20,2.36,2.34,2.17,v)
	else: z=cubic(-2.27,-2.43,-2.47,-2.25,v)
	z=join+(z-join)*sqrt(maxf(0,1-a*a))
	var level: float=(y-0.28)/(top-0.28)
	var section_y: float=lerpf(0.28,upper(join)-0.04,level)
	var outside: float=width(section_y,join)+pow(v,4)*(top_width(end)-top_width(join))
	var middle: float=top_width(end)+0.065*sin(PI*level)-0.04*pow(1-level,2)
	var x: float=a*lerpf(middle,outside,smoothstep(0.84,1,absf(a)))
	return Vector3(x,y,z)

static func front_z(x: float,y: float) -> float:
	return FRONT_JOIN-(0.43-0.45*pow(y-0.70,2))*sqrt(maxf(0,1-pow(x/width(y,FRONT_JOIN),2)))
static func rear_z(x: float,y: float) -> float:
	return REAR_JOIN+(0.36-0.55*pow(y-0.64,2))*sqrt(maxf(0,1-pow(x/width(y,REAR_JOIN),2)))

static func normal_at(sample: Callable,u: float,v: float,hint: Vector3) -> Vector3:
	var du: Vector3=sample.call(minf(1,u+0.001),v)-sample.call(maxf(0,u-0.001),v)
	var dv: Vector3=sample.call(u,minf(1,v+0.001))-sample.call(u,maxf(0,v-0.001))
	var n: Vector3=du.cross(dv).normalized()
	return -n if n.dot(hint)<0 else n

static func patch(parent: Node3D,label: String,columns: int,rows: int,sample: Callable,material: Material,hint: Vector3,simple: bool=false,_normal_at: Callable=Callable(),_normal_uv: Callable=Callable()) -> void:
	var key: String=label+("_simple" if simple else "")
	var path: String=ASSET_ROOT.path_join(key.sha256_text().left(24)+".res")
	if use_baked and not meshes.has(key) and ResourceLoader.exists(path): meshes[key]=load(path) as ArrayMesh
	if not meshes.has(key):
		if simple:
			columns=maxi(4,columns/2)
			rows=maxi(2,rows/2)
		var tool:=SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row: int in range(rows):
			for column: int in range(columns):
				var uv: Array[Vector2]=[Vector2(float(column)/columns,float(row)/rows),Vector2(float(column+1)/columns,float(row)/rows),Vector2(float(column+1)/columns,float(row+1)/rows),Vector2(float(column)/columns,float(row+1)/rows)]
				var p: Array[Vector3]=[]
				for q: Vector2 in uv: p.append(sample.call(q.x,q.y))
				for triangle: Array in [[0,1,2],[0,2,3]]:
					var face: Vector3=(p[triangle[1]]-p[triangle[0]]).cross(p[triangle[2]]-p[triangle[0]])
					if face.length_squared()<1e-18: continue
					var order: Array=triangle.duplicate()
					var facing: Vector3=_normal_uv.call((uv[0].x+uv[2].x)*0.5,(uv[0].y+uv[2].y)*0.5) if _normal_uv.is_valid() else hint
					if face.dot(facing)>0: order.reverse()
					for index: int in order:
						var t: Vector2=uv[index]
						var n: Vector3=_normal_uv.call(t.x,t.y) if _normal_uv.is_valid() else _normal_at.call(p[index]) if _normal_at.is_valid() else normal_at(sample,t.x,t.y,hint)
						tool.set_normal(n)
						tool.set_uv(t)
						tool.add_vertex(p[index])
		tool.index()
		tool.generate_tangents()
		meshes[key]=tool.commit()
	var node:=MeshInstance3D.new()
	node.name=label
	node.mesh=meshes[key]
	node.material_override=material
	parent.add_child(node)

static func ribbon(parent: Node3D,label: String,sample: Callable,count: int,radius: float,material: Material,simple: bool=false) -> void:
	patch(parent,label,count,6,func(u: float,v: float) -> Vector3:
		var p: Vector3=sample.call(u)
		var tangent: Vector3=(sample.call(minf(1,u+0.0001))-sample.call(maxf(0,u-0.0001))).normalized()
		var n: Vector3=tangent.cross(Vector3.UP).normalized()
		if n.length_squared()<0.1: n=Vector3.RIGHT
		var b: Vector3=tangent.cross(n).normalized()
		return p+radius*(n*cos(v*TAU)+b*sin(v*TAU)),material,Vector3.UP,simple,Callable(),func(u: float,v: float)->Vector3:
		var tangent: Vector3=(sample.call(minf(1,u+0.0001))-sample.call(maxf(0,u-0.0001))).normalized()
		var n: Vector3=tangent.cross(Vector3.UP).normalized()
		if n.length_squared()<0.1: n=Vector3.RIGHT
		return n*cos(v*TAU)+tangent.cross(n).normalized()*sin(v*TAU))

static func rounded(parent: Node3D,label: String,size: Vector3,center: Vector3,radius: float,material: Material) -> void:
	var half: Vector3=size*0.5
	var r: float=minf(radius,minf(half.x,minf(half.y,half.z))*0.95)
	for n: Vector3 in [Vector3.LEFT,Vector3.RIGHT,Vector3.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.BACK]:
		patch(parent,label+str(n)+str(center),6,4,func(u: float,v: float) -> Vector3:
			var p:=Vector3(n.x,2*u-1,2*v-1) if n.x!=0 else Vector3(2*u-1,n.y,2*v-1) if n.y!=0 else Vector3(2*u-1,2*v-1,n.z)
			p*=half
			var q: Vector3=p.clamp(-half+Vector3.ONE*r,half-Vector3.ONE*r)
			return center+q+(p-q).normalized()*r,material,n)

static func panel_loop(points: Array[Vector2],edge: int,t: float,radius: float) -> Vector2:
	var p: Vector2=points[edge]
	var q: Vector2=points[(edge+1)%points.size()]
	var next: Vector2=points[(edge+2)%points.size()]
	var start: Vector2=p+(q-p).normalized()*radius
	var before: Vector2=q+(p-q).normalized()*radius
	var after: Vector2=q+(next-q).normalized()*radius
	if t<0.84: return start.lerp(before,t/0.84)
	var v: float=(t-0.84)/0.16
	return before*pow(1-v,2)+2*q*v*(1-v)+after*v*v

static func hood_edge_uv(edge: int,t: float,inset: float=0) -> Vector2:
	var points: Array[Vector2]=[Vector2(0.105+inset,0.075+inset),Vector2(0.895-inset,0.075+inset),Vector2(0.925-inset,0.96-inset),Vector2(0.075+inset,0.96-inset)]
	return panel_loop(points,edge,t,0.035)
static func hood_surround_outer_uv(edge: int,t: float) -> Vector2: return hood_edge_uv(edge,t,0.004)

static func body(car: CarVisual,paint: Material,accent: Material,trim: Material) -> void:
	patch(car.body,"ClamshellHood",64,40,hood_point,paint,Vector3.UP,car.simple_model)
	patch(car.body,"RearDeck",64,20,deck_point,paint,Vector3.UP,car.simple_model)
	for edge: int in range(4):
		ribbon(car.body,"BonnetShutline"+str(edge),func(t: float)->Vector3:
			var uv: Vector2=hood_edge_uv(edge,t)
			return hood_point(uv.x,uv.y)+Vector3.UP*0.0005,64,0.0014,trim,car.simple_model)
	var hatch: Array[Vector2]=[Vector2(0.055,0.12),Vector2(0.945,0.12),Vector2(0.945,0.88),Vector2(0.055,0.88)]
	for edge: int in range(4):
		ribbon(car.body,"TrunkShutline"+str(edge),func(t: float)->Vector3:
			var uv: Vector2=panel_loop(hatch,edge,t,0.035)
			return deck_point(uv.x,uv.y)+Vector3.UP*0.0005,32,0.0014,trim,car.simple_model)
	var charge: Array[Vector2]=[Vector2(1.70,0.77),Vector2(1.87,0.77),Vector2(1.87,0.89),Vector2(1.70,0.89)]
	for edge: int in range(4):
		ribbon(car.body,"ChargingFlap"+str(edge),func(t: float)->Vector3:
			var p: Vector2=panel_loop(charge,edge,t,0.018)
			return side_point(-1,p.x,p.y)+Vector3.LEFT*0.0007,24,0.0011,trim,car.simple_model)
	for side: float in [-1.0,1.0]:
		patch(car.body,"SculptedSide"+str(side),112,16,func(u: float,v: float)->Vector3:return side_surface(side,u,v),paint,Vector3(side,0,0),car.simple_model)
		patch(car.body,"SillBlade"+str(side),48,6,func(u: float,v: float)->Vector3:
			var z: float=lerpf(-0.94,0.94,u)
			var y: float=lerpf(0.285,0.345,v)
			return side_point(side,z,y)+Vector3(side*0.005,0,0),accent,Vector3(side,0,0),car.simple_model)
	rounded(car.body,"BatteryTray",Vector3(1.30,0.06,3.65),Vector3(0,0.285,0),0.02,trim)

	for rear_face: bool in [false,true]:
		patch(car.body,"EndUndertrayRear" if rear_face else "EndUndertrayFront",64,4,func(u: float,v: float)->Vector3:
			var p: Vector3=cap_point(rear_face,u,0)
			return Vector3(p.x,0.28,lerpf(p.z,1.85 if rear_face else -1.85,v)),trim,Vector3.DOWN,car.simple_model)

static func canopy_z(v: float) -> float: return cubic(-0.91,-0.37,0.62,1.65,v)
static func canopy_center(v: float) -> float: return cubic(1.014,1.64,1.70,upper(1.65),v)
static func raw_canopy_width(v: float) -> float: return lerpf(0.816,0.823,v)-0.215*pow(sin(PI*v),0.78)
static func canopy_width(v: float) -> float:
	if v<=REAR_FLOW_START: return raw_canopy_width(v)
	var a: float=REAR_FLOW_START
	var h: float=0.0001
	var y: float=raw_canopy_width(a)
	var dy: float=(raw_canopy_width(a+h)-raw_canopy_width(a-h))/(2*h)
	var ddy: float=(raw_canopy_width(a+h)-2*y+raw_canopy_width(a-h))/(h*h)
	var length: float=1-a
	return quintic(y,dy*length,ddy*length*length,0.823,0.25*length,0,(v-a)/length)
static func canopy_base_point(u: float,v: float) -> Vector3:
	var a: float=2*u-1
	var blend: float=sin(PI*v)
	var cross: float=a*canopy_width(v)/top_width(canopy_z(v))
	var edge: float=0.04*(2*cross*cross-pow(cross,4))
	return Vector3(a*canopy_width(v),canopy_center(v)-lerpf(edge,0.11*a*a,blend),canopy_z(v))
static func canopy_point(u: float,v: float) -> Vector3:
	var p: Vector3=canopy_base_point(u,v)
	var blend: float=rear_blend(v)
	if blend>0: p.y=lerpf(p.y,rear_surface_height(p.x,p.z),blend)
	return p
static func roof_point(u: float,v: float) -> Vector3: return canopy_point(u,lerpf(0.27,0.68,v))
static func screen_point(rear_face: bool,u: float,v: float) -> Vector3: return canopy_point(u,lerpf(0.68,1,v) if rear_face else lerpf(0,0.27,v))
static func cabin_side(side: float,u: float,v: float) -> Vector3:
	var z: float=canopy_z(u)
	var top: Vector3=canopy_base_point(0 if side<0 else 1,u)
	var bottom:=Vector3(side*top_width(z),upper(z)-0.04,z)
	var p: Vector3=bottom.lerp(top,v)+Vector3(side*0.014*sin(PI*v)*sin(PI*u),0,0)
	var blend: float=rear_blend(u)
	if blend>0: p.y=lerpf(p.y,rear_surface_height(p.x,p.z),blend)
	return p

static func cabin(car: CarVisual,paint: Material,accent: Material,trim: Material,glass: Material) -> void:
	for rear_face: bool in [false,true]:
		var lo: float=0.68 if rear_face else 0
		var hi: float=1 if rear_face else 0.27
		var lead: float=lo+0.014
		var tail: float=hi-0.014
		var sample: Callable=func(u: float,v: float)->Vector3:return canopy_point(lerpf(0.026,0.974,u),lerpf(lead,tail,v))
		patch(car.body,"RearScreen" if rear_face else "Windscreen",48,36,sample,glass,Vector3.UP,car.simple_model)
		for border: int in range(4):
			patch(car.body,"CanopyBorder"+str(rear_face)+str(border),48 if border%2==0 else 24,4,func(u: float,v: float)->Vector3:
				if border==0: return canopy_point(u,lerpf(lo,lead,v))
				if border==2: return canopy_point(u,lerpf(tail,hi,v))
				return canopy_point(lerpf(0,0.026,v) if border==3 else lerpf(0.974,1,v),lerpf(lead,tail,u)),paint,Vector3.UP,car.simple_model)
	patch(car.body,"CrownedRoof",48,40,roof_point,accent,Vector3.UP,car.simple_model)
	for side: float in [-1.0,1.0]:
		var hint:=Vector3(side,0.4,0)
		for band: int in range(4):
			patch(car.body,"CanopySideFrame"+str(side)+str(band),48,6,func(u: float,v: float)->Vector3:
				if band==0: return cabin_side(side,u,lerpf(0,0.13,v))
				if band==1: return cabin_side(side,u,lerpf(0.90,1,v))
				var h: float=lerpf(0.13,0.90,u)
				var start: float=lerpf(0.055,0.165,(h-0.13)/0.77)
				var end: float=lerpf(0.945,0.835,(h-0.13)/0.77)
				return cabin_side(side,lerpf(0,start,v) if band==2 else lerpf(end,1,v),h),paint,hint,car.simple_model)
		patch(car.body,"SideGlazing"+str(side),80,28,func(u: float,v: float)->Vector3:
			var start: float=lerpf(0.055,0.165,v)
			var end: float=lerpf(0.945,0.835,v)
			return cabin_side(side,lerpf(start,end,u),lerpf(0.13,0.90,v)),glass,hint,car.simple_model)
		for divider: float in [0.465,0.765]:
			patch(car.body,"GlassPillar"+str(side)+str(divider),4,24,func(u: float,v: float)->Vector3:
				return cabin_side(side,divider+lerpf(-0.007,0.007,u),lerpf(0.13,0.90,v))+Vector3(side*0.0015,0,0),trim,hint,car.simple_model)
		ribbon(car.body,"WindowSill"+str(side),func(t: float)->Vector3:return cabin_side(side,t,0.13)+Vector3(side*0.001,0,0),64,0.0025,trim,car.simple_model)
	for side: float in [-1.0,1.0]:
		ribbon(car.body,"Wiper"+str(side),func(t: float)->Vector3:return canopy_point(lerpf(0.18 if side<0 else 0.53,0.47 if side<0 else 0.83,t),0.035+0.011*t)+Vector3.UP*0.004,12,0.005,trim,car.simple_model)

static func arch(car: CarVisual,side: float,axle: float,paint: Material,trim: Material) -> void:
	patch(car.body,"RolledArch"+str(side)+str(axle),72,8,func(u: float,v: float)->Vector3:
		var angle: float=PI*u
		var radius: float=lerpf(0.402,0.431,v)
		var z: float=axle+cos(angle)*radius
		var y: float=0.37+sin(angle)*radius
		var p: Vector3=side_point(side,z,y)
		p.x+=side*0.003*sin(PI*v)
		return p,paint,Vector3(side,0.2,0),car.simple_model)
	patch(car.body,"WheelwellTub"+str(side)+str(axle),64,6,func(u: float,v: float)->Vector3:
		var angle: float=PI*u
		return Vector3(side*lerpf(width(0.37+sin(angle)*0.414,axle+cos(angle)*0.414),0.66,v),0.37+sin(angle)*0.414,axle+cos(angle)*0.414),trim,Vector3(side,-0.3,0),car.simple_model)

static func cap_band(car: CarVisual,label: String,rear_face: bool,u0: float,u1: float,v0: float,v1: float,material: Material,offset: float=0) -> void:
	patch(car.body,label,maxi(8,ceili((u1-u0)*64)),maxi(2,ceili((v1-v0)*24)),func(u: float,v: float)->Vector3:
		return cap_point(rear_face,lerpf(u0,u1,u),lerpf(v0,v1,v))+Vector3(0,0,offset),material,Vector3.BACK if rear_face else Vector3.FORWARD,car.simple_model,Callable(),func(u: float,v: float)->Vector3:
		return normal_at(func(a: float,b: float)->Vector3:return cap_point(rear_face,a,b),lerpf(u0,u1,u),lerpf(v0,v1,v),Vector3.BACK if rear_face else Vector3.FORWARD))

static func cap_pocket(car: CarVisual,label: String,rear_face: bool,rect: Rect2,depth: float,trim: Material) -> void:
	var sign_z: float=-1 if rear_face else 1
	cap_band(car,label+"Back",rear_face,rect.position.x,rect.end.x,rect.position.y,rect.end.y,trim,sign_z*depth)
	for edge: int in range(4):
		patch(car.body,label+"Return"+str(edge),32,4,func(u: float,v: float)->Vector3:
			var uv:=Vector2(lerpf(rect.position.x,rect.end.x,u),rect.position.y if edge==0 else rect.end.y) if edge%2==0 else Vector2(rect.end.x if edge==1 else rect.position.x,lerpf(rect.position.y,rect.end.y,u))
			return cap_point(rear_face,uv.x,uv.y)+Vector3(0,0,sign_z*depth*v),trim,Vector3.BACK if rear_face else Vector3.FORWARD,car.simple_model)

static func raw_lightbar_point(u: float,v: float) -> Vector3:
	return cap_point(false,lerpf(0.035,0.965,u),lerpf(0.824,0.845,v))+Vector3(0,0,-0.004)
static func lightbar_point(u: float,v: float) -> Vector3: return raw_lightbar_point(u,v)

static func front(car: CarVisual,paint: Material,trim: Material,metal: Material) -> void:
	# The fascia is cut around the optical band and lower inlet, not layered
	# over an intact painted face. All borders evaluate the same section.
	cap_band(car,"FrontLowerCheek",false,0,1,0,0.18,paint)
	cap_band(car,"FrontBumper",false,0,1,0.32,0.795,paint)
	cap_band(car,"FrontBrow",false,0,1,0.875,1,paint)
	for side: bool in [false,true]:
		cap_band(car,"IntakeEnd"+str(side),false,0 if not side else 0.93,0.07 if not side else 1,0.18,0.32,paint)
		cap_band(car,"OpticEnd"+str(side),false,0 if not side else 0.98,0.02 if not side else 1,0.795,0.875,paint)
	cap_pocket(car,"IntakeThroat",false,Rect2(0.07,0.18,0.86,0.14),0.020,trim)
	cap_pocket(car,"OpticalHousing",false,Rect2(0.02,0.795,0.96,0.08),0.009,trim)
	var running:=StandardMaterial3D.new()
	running.albedo_color=Color("dceef3")
	running.roughness=0.30
	running.emission_enabled=true
	running.emission=Color("cce8f0")
	running.emission_energy_multiplier=0.55
	patch(car.body,"ContinuousFrontLightbar",96,4,raw_lightbar_point,running,Vector3.FORWARD,car.simple_model)
	var optics:=CompactFinish.alloy(Color("8fa5ae"))
	for side: float in [-1.0,1.0]:
		for cell: int in range(5):
			var center: float=0.5+side*(0.235+cell*0.035)
			cap_band(car,"Projector"+str(side)+str(cell),false,center-0.013,center+0.013,0.850,0.869,optics,-0.002)
		cap_band(car,"Curtain"+str(side),false,0.065 if side<0 else 0.918,0.082 if side<0 else 0.935,0.35,0.65,trim,-0.001)
		cap_band(car,"CurtainEdge"+str(side),false,0.062 if side<0 else 0.935,0.065 if side<0 else 0.938,0.38,0.63,metal,-0.002)
	cap_band(car,"FrontSplitter",false,0.06,0.94,0.035,0.064,trim,-0.008)
	for x: float in [-0.009,0.009]: rounded(car.body,"NoseMark"+str(x),Vector3(0.008,0.028,0.005),Vector3(x,0.65,front_z(x,0.65)-0.006),0.003,metal)

static func rear(car: CarVisual,paint: Material,accent: Material,trim: Material,metal: Material) -> void:
	cap_band(car,"RearValance",true,0,1,0,0.20,accent)
	cap_band(car,"RearBumperTop",true,0,1,0.61,0.77,paint)
	cap_band(car,"RearBumperBottom",true,0,1,0.20,0.35,paint)
	cap_band(car,"RearBumperLeft",true,0,0.35,0.35,0.61,paint)
	cap_band(car,"RearBumperRight",true,0.65,1,0.35,0.61,paint)
	cap_band(car,"RearDeckReturn",true,0,1,0.86,1,paint)
	for side: bool in [false,true]: cap_band(car,"TailOpticEnd"+str(side),true,0 if not side else 0.98,0.02 if not side else 1,0.77,0.86,paint)
	cap_band(car,"RearOpticalHousing",true,0.02,0.98,0.77,0.86,trim,-0.012)
	cap_band(car,"RearLightGuide",true,0.035,0.965,0.806,0.826,car.brake_material,0.003)
	cap_band(car,"RearSecondaryGuide",true,0.055,0.945,0.782,0.789,car.brake_material,0.001)
	# Inset graphic plate and a restrained, formed lower diffuser.
	cap_pocket(car,"PlatePocket",true,Rect2(0.35,0.35,0.30,0.26),0.030,trim)
	var plate:=CompactFinish.rubber(Color("b0b5ad"))
	cap_band(car,"LicensePlate",true,0.38,0.62,0.39,0.57,plate,-0.027)
	for u: float in [0.40,0.60]:
		var p: Vector3=cap_point(true,u,0.55)+Vector3(0,0,-0.024)
		rounded(car.body,"PlateBolt"+str(u),Vector3(0.009,0.009,0.004),p,0.003,metal)
	cap_band(car,"RearDiffuser",true,0.12,0.88,0.028,0.15,trim,0.008)
	for x: float in [-0.54,-0.27,0.27,0.54]: rounded(car.body,"DiffuserVane"+str(x),Vector3(0.009,0.053,0.16),Vector3(x,0.300,2.17),0.003,trim)
	for side: float in [-1.0,1.0]:
		cap_band(car,"RearReflector"+str(side),true,0.075 if side<0 else 0.85,0.15 if side<0 else 0.925,0.16,0.174,car.brake_material,0.002)
	for index: int in range(4): rounded(car.body,"TailSignature"+str(index),Vector3(0.022,0.018,0.004),Vector3((index-1.5)*0.042,0.741,2.343),0.005,metal)

static func door_outline(front_door: bool) -> Array[Vector2]:
	var points: Array[Vector2]=[]
	points.assign([Vector2(-0.80,0.95),Vector2(0.17,0.96),Vector2(0.17,0.39),Vector2(-0.73,0.39)] if front_door else [Vector2(0.17,0.96),Vector2(0.98,0.94),Vector2(0.89,0.40),Vector2(0.17,0.39)])
	return points

static func doors(car: CarVisual,side: float,trim: Material,metal: Material) -> void:
	for front_door: bool in [true,false]:
		var points: Array[Vector2]=door_outline(front_door)
		for index: int in range(points.size()):
			ribbon(car.body,"DoorCut"+str(side)+str(front_door)+str(index),func(t: float)->Vector3:
				var p: Vector2=panel_loop(points,index,t,0.035)
				return side_point(side,p.x,p.y)+Vector3(side*0.0008,0,0),32,0.0014,trim,car.simple_model)
		var z: float=-0.04 if front_door else 0.79
		patch(car.body,"FlushHandle"+str(side)+str(front_door),16,4,func(u: float,v: float)->Vector3:
			var yy: float=0.874+0.013*(2*v-1)*sqrt(maxf(0.001,1-pow(2*u-1,8)))
			return side_point(side,z+lerpf(-0.072,0.072,u),yy)+Vector3(side*0.002,0,0),trim,Vector3(side,0,0),car.simple_model)
		patch(car.body,"HandleFace"+str(side)+str(front_door),12,2,func(u: float,v: float)->Vector3:
			return side_point(side,z+lerpf(-0.060,0.060,u),0.874+lerpf(-0.004,0.004,v))+Vector3(side*0.003,0,0),metal,Vector3(side,0,0),car.simple_model)

static func mirror(car: CarVisual,side: float,accent: Material,trim: Material,glass: Material) -> void:
	rounded(car.body,"MirrorStalk"+str(side),Vector3(0.10,0.025,0.07),Vector3(side*0.883,1.014,-0.65),0.010,trim)
	patch(car.body,"MirrorShell"+str(side),32,16,func(u: float,v: float)->Vector3:
		var theta: float=TAU*u
		var phi: float=PI*v
		return Vector3(side*1.00+0.139*sin(phi)*cos(theta),1.058+0.047*cos(phi),-0.635+0.101*sin(phi)*sin(theta)),accent,Vector3(side,0.3,-0.3),car.simple_model,Callable(),func(u: float,v: float)->Vector3:return Vector3(sin(PI*v)*cos(TAU*u)/0.139,cos(PI*v)/0.047,sin(PI*v)*sin(TAU*u)/0.101).normalized())
	patch(car.body,"MirrorGlass"+str(side),16,8,func(u: float,v: float)->Vector3:
		var a: float=2*u-1
		return Vector3(side*1.00+0.112*a,1.057+0.033*(2*v-1)*sqrt(maxf(0.001,1-a*a)),-0.550+0.004*a*a),glass,Vector3.BACK,car.simple_model)
