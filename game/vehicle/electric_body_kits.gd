extends RefCounted
## Complete formed lower coachwork. Metres in the reference body's coordinates.
const M = preload("res://vehicle/electric_reference_mesh.gd")
const B = preload("res://vehicle/electric_reference_body.gd")
const REVISION := "volt-fitted-details-4"
# Explicit silhouettes: projection, sill breadth, front rise and rear rise.
# Road packages stay restrained; competition packages have deeper venturi decks.
const PROFILES: Array[Vector4] = [
	Vector4(0.050,0.034,0.25,0.26), Vector4(0.077,0.052,0.29,0.30),
	Vector4(0.084,0.048,0.27,0.29), Vector4(0.040,0.030,0.23,0.25),
	Vector4(0.100,0.063,0.30,0.33), Vector4(0.115,0.058,0.28,0.35),
	Vector4(0.075,0.047,0.27,0.31), Vector4(0.092,0.066,0.28,0.30),
	Vector4(0.065,0.043,0.26,0.29), Vector4(0.108,0.082,0.31,0.34),
	Vector4(0.088,0.058,0.29,0.32), Vector4(0.110,0.071,0.31,0.36),
	Vector4(0.058,0.040,0.25,0.28), Vector4(0.045,0.035,0.24,0.27),
	Vector4(0.125,0.077,0.32,0.37)]
const SILL_RISE: Array[float] = [0.284,0.290,0.288,0.281,0.294,0.292,0.289,0.291,0.287,0.295,0.290,0.296,0.283,0.282,0.298]

static func arch_joint(side: float,axle: float,direction: float,y: float) -> Vector3:
	# Sample the actual painted opening, rather than ending a rectangular strip
	# at a guessed Z. This is shared with the existing fender, not the tire.
	var angle: float=asin(clampf((maxf(y,0.243)-0.24)/0.545,0.0,1.0))
	var u: float=angle/PI if direction>0.0 else 1.0-angle/PI
	return B.fender_point(side,axle,u,1.0)

static func profile(i: int) -> Vector4:
	return PROFILES[i-1]

# A six-sided shell, including the hidden fitted backing. Every visible edge
# has a physical return; material double-sidedness never conceals an open sheet.
static func shell(parent: Node3D,label: String,columns: int,rows: int,outer: Callable,inner: Callable,material: Material,hint: Vector3,simple: bool) -> void:
	# The shared simple sampler keeps at least four columns. Keeping at least
	# eight rows makes each end return use the exact same edge samples.
	rows=maxi(8,rows)
	M.patch(parent,label+"Face",columns,rows,outer,material,hint,simple)
	M.patch(parent,label+"Back",columns,rows,inner,material,-hint,simple)
	for edge: int in range(4):
		var count: int=columns if edge<2 else rows
		var sample: Callable=func(u: float,v: float)->Vector3:
			var s: float=u if edge<2 else float(edge-2)
			var t: float=float(edge) if edge<2 else u
			return inner.call(s,t).lerp(outer.call(s,t),v)
		var outward: Callable=func(u: float,_v: float)->Vector3:
			var s: float=u if edge<2 else float(edge-2)
			var t: float=float(edge) if edge<2 else u
			var a: Vector3=outer.call(s,t)
			var b: Vector3=outer.call(s,0.001 if edge==0 else 0.999) if edge<2 else outer.call(0.001 if edge==2 else 0.999,t)
			return M.normal_at(sample,u,0.5,(a-b).normalized())
		M.patch(parent,label+"Return"+str(edge),count,2,sample,material,hint,simple,Callable(),outward)

static func cap_surface(i: int,rear: bool,u: float,v: float,outer: bool=true) -> Vector3:
	var spec: Vector4=profile(i)
	var across: float=2.0*u-1.0 if rear else B.front_across(u)
	var height: float=spec.w if rear else spec.z
	# The valance follows the entire factory fascia, all the way to its corners.
	var crown: float=(0.018 if i in [2,5,10,12,15] else 0.008)*pow(1.0-across*across,2)
	var p: Vector3=B.cap_point(rear,u,lerpf(0.0,height+crown,v))
	var direction: float=1.0 if rear else -1.0
	if not outer: return p+Vector3(0,0,direction*0.001)
	var projection: float=spec.x*(0.84 if rear else 1.0)
	var flare: float=projection*pow(1.0-v,2)*(0.72+0.28*(1.0-across*across))
	if i in [3,8]: flare*=0.78+0.22*smoothstep(0.35,0.90,absf(across))
	if i==11: flare*=1.0-0.34*exp(-pow(across/0.13,2))
	if i in [6,15]: flare*=0.88+0.12*pow(1.0-across*across,2)
	var depth: float = 0.004+flare+0.012*pow(sin(PI*v),2)
	if rear:
		# Cover the retained factory valance and five raised diffuser fences.
		# Roll the added clearance into the closed upper return.
		var factory_v: float = lerpf(0.0,height+crown,v)
		var fin_t: float = clampf((factory_v-0.025)/0.195,0.0,1.0)
		var trim_depth: float = 0.022+0.030*sin(PI*fin_t)
		var trim_span: float = smoothstep(0.005,0.025,factory_v)*(1.0-smoothstep(0.25,0.26,factory_v))
		depth = maxf(depth,trim_depth*trim_span)
	p.z+=direction*depth
	p.x+=across*(0.004+spec.y*0.48*pow(1.0-v,2))
	p.y-=0.018*pow(1.0-v,2)
	return p

static func sill_surface(side: float,i: int,u: float,v: float,outer: bool=true) -> Vector3:
	var spec: Vector4=profile(i)
	# Every package stays below the 0.31 m factory door bottoms. Its end
	# stations follow the inner arch curve at every height of the section.
	var rise: float=SILL_RISE[i-1]
	var blend: float=smoothstep(0.0,0.10,u)*(1.0-smoothstep(0.90,1.0,u))
	var low: float=lerpf(0.243,0.225,blend)
	var y: float=lerpf(low,rise,v)
	var front: Vector3=arch_joint(side,-B.AXLE,1.0,y)
	var rear: Vector3=arch_joint(side,B.AXLE,-1.0,y)
	var z: float=lerpf(front.z,rear.z,u)
	var p: Vector3=B.side_point(side,z,maxf(0.24,y))
	p.y=y
	var fitted: Vector3=front.lerp(rear,u)
	var end_weight: float=1.0-blend
	p.x=lerpf(p.x,fitted.x,end_weight)
	p.y=lerpf(p.y,fitted.y,end_weight)
	var breadth: float=-0.002
	if outer:
		# A tucked upper joint, rolled shoulder and broad lower blade.
		var longitudinal: float=blend
		var section: float=pow(sin(PI*v),1.4)
		match i:
			2,3,5,6,10,12,15: section=smoothstep(0.0,0.23,v)*(1.0-smoothstep(0.67,1.0,v))
			8: section=smoothstep(0.0,0.15,v)*(1.0-smoothstep(0.32,1.0,v))
			11: section=0.70*pow(sin(PI*v),1.4)+0.30*pow(sin(TAU*v),2)
			13: section=0.72*pow(sin(PI*v),2)-0.12*pow(sin(TAU*v),2)
		breadth=0.001+longitudinal*(spec.y*section+0.024*pow(1.0-v,2))
		if i in [8,10,12,15]: breadth+=longitudinal*0.016*pow(1.0-v,3)
		if i in [5,6,8,10,11,12,15]: breadth+=0.014*longitudinal*smoothstep(0.63,0.90,u)*pow(sin(PI*v),2)
	p.x+=side*breadth
	return p

static func fitted_decoration(parent: Node3D, label: String, backing: String, outline: Array[Vector2], material: Material, outward: Vector3, simple: bool) -> void:
	var skin: MeshInstance3D = parent.find_child(backing.replace(".","_"), false, false)
	if simple:
		skin.mesh = preload("res://vehicle/car_static_reduction.gd").resolve(skin.mesh, "electric")
		skin.mesh = preload("res://vehicle/car_coarse_reduction.gd").resolve(skin.mesh, "electric")
	M.fitted_patch(parent, label, skin, outline, material, outward, simple)

static func build(car: CarVisual,parent: Node3D,option: String,i: int) -> void:
	var paint: Material=car.paint_materials.body
	var graphite:=CompactFinish.paint(Color("252e33"))
	graphite.roughness=0.43
	graphite.clearcoat=0.12
	var black:=CompactFinish.rubber(Color("10191d"))
	var satin:=CompactFinish.alloy(Color("65757c"))
	satin.roughness=0.48
	var coloured: bool=i in [1,2,4,9,10,12,13]
	var finish: Material=paint if coloured else graphite
	var simple: bool=car.simple_model
	var label: String="VoltBodyV1_"+option
	for rear: bool in [false,true]:
		var end: String="Rear" if rear else "Front"
		var hint: Vector3=Vector3.BACK if rear else Vector3.FORWARD
		# Retain the full rear row count around the factory fin envelope.
		var rows: int = 24 if rear and simple else 12
		shell(parent,label+end,64,rows,func(u: float,v: float)->Vector3:
			return cap_surface(i,rear,u,v),func(u: float,v: float)->Vector3:
			return cap_surface(i,rear,u,v,false),finish,hint,simple)
		# A full-width lower carbon blade follows the formed shell rather than
		# stopping short of the corners. Its three millimetre edge is closed.
		shell(parent,label+end+"Blade",64,4,func(u: float,v: float)->Vector3:
			var p: Vector3=cap_surface(i,rear,u,v*0.22)
			return p+Vector3(0,-0.001,(0.003 if rear else -0.003)),func(u: float,v: float)->Vector3:
			return cap_surface(i,rear,u,v*0.22),black,hint,simple)
		# Continue around the bumper side to the wheel-opening approach. The
		# actual moving-wheel envelopes remain entirely outside these returns.
		for side: float in [-1.0,1.0]:
			shell(parent,label+end+"Corner"+str(side),10,10,func(u: float,v: float)->Vector3:
				return corner_surface(side,i,rear,u,v),func(u: float,v: float)->Vector3:
				return corner_surface(side,i,rear,u,v,false),finish,Vector3(side,0,0),simple)
			shell(parent,label+end+"CornerBlade"+str(side),10,4,func(u: float,v: float)->Vector3:
				return corner_surface(side,i,rear,u,v*0.22)+Vector3(side*0.001,0,0),func(u: float,v: float)->Vector3:
				return corner_surface(side,i,rear,u,v*0.22),black,Vector3(side,0,0),simple)
	for side: float in [-1.0,1.0]:
		shell(parent,label+"Sill"+str(side),48,12,func(u: float,v: float)->Vector3:
			return sill_surface(side,i,u,v),func(u: float,v: float)->Vector3:
			return sill_surface(side,i,u,v,false),finish,Vector3(side,0,0),simple)
		# One restrained inset per side, with different pressed outlines.
		var outline: Array[Vector2] = []
		for index: int in range(33):
			var u: float = index / 32.0
			var low: float = 0.15 + 0.12*u if i in [3,8,9,12,15] else 0.16
			outline.append(Vector2(lerpf(0.04,0.96,u),low))
		for index: int in range(32,-1,-1):
			var u: float = index / 32.0
			var low: float = 0.15 + 0.12*u if i in [3,8,9,12,15] else 0.16
			var high: float = low + (0.26 if i in [5,6,7,11,15] else 0.14)*pow(maxf(0.0,sin(PI*u)),0.65)
			outline.append(Vector2(lerpf(0.04,0.96,u),high))
		fitted_decoration(parent,label+"SillInlay"+str(side),label+"Sill"+str(side)+"Face",outline,black if coloured else satin,Vector3(side,0,0),simple)
	build_rear_tunnels(car,parent,label,i,black,graphite)
	var valance: Array[Vector2] = [Vector2(0.08,0.06),Vector2(0.92,0.06)]
	for index: int in range(32,-1,-1):
		var u: float = index / 32.0
		var rise: float = 0.20 + (0.44 if i in [5,6,12,15] else 0.32)*pow(maxf(0.0,sin(PI*u)),0.55)
		valance.append(Vector2(lerpf(0.08,0.92,u),rise))
	fitted_decoration(parent,label+"RearValance",label+"RearFace",valance,black,Vector3.BACK,simple)
	# Narrow, fitted front intake with a dark floor and upper formed brow.
	var intake: Array[Vector2] = [Vector2(0.17,0.39),Vector2(0.83,0.39)]
	for index: int in range(32,-1,-1):
		var u: float = index / 32.0
		intake.append(Vector2(lerpf(0.17,0.83,u),0.39+0.29*pow(maxf(0.0,sin(PI*u)),0.45)))
	fitted_decoration(parent,label+"FrontIntake",label+"FrontFace",intake,black,Vector3.FORWARD,simple)

static func corner_surface(side: float,i: int,rear: bool,u: float,v: float,outer: bool=true) -> Vector3:
	var edge: Vector3=cap_surface(i,rear,0.0 if side<0.0 else 1.0,v,outer)
	# The lower surface rises into the foot of the arch. The whole boundary
	# ends on the painted fender curve, so no exposed pillar remains between
	# a short bumper strip and the wheel opening.
	var ease: float=smoothstep(0.0,1.0,u)
	var y: float=lerpf(edge.y,maxf(0.243+0.018*v,edge.y),ease)
	var axle: float=B.AXLE if rear else -B.AXLE
	var arch: Vector3=arch_joint(side,axle,1.0 if rear else -1.0,y)
	var z: float=lerpf(B.REAR if rear else B.FRONT,arch.z,u)
	var p: Vector3=B.flank_point(side,z,y)
	var joint: Vector3=B.flank_point(side,B.REAR if rear else B.FRONT,edge.y)
	# Transfer the exact cap/side seam correction, easing into factory metal.
	var fade: float=1.0-ease
	p+=(edge-joint)*fade
	var arch_side: Vector3=B.flank_point(side,arch.z,y)
	p+=(arch-arch_side)*ease
	p.x+=side*(0.001 if outer else -0.002)*ease
	return p

static func build_rear_tunnels(car: CarVisual,parent: Node3D,label: String,i: int,black: Material,graphite: Material) -> void:
	var count: int=2 if i in [1,4,9,13,14] else 6 if i in [5,6,12,15] else 4
	# Curved diffuser bed is a formed volume, with proper attachment at the
	# bumper, upturned rear exit and closed inboard/front/outer boundaries.
	shell(parent,label+"Diffuser",48,8,func(u: float,v: float)->Vector3:
		return diffuser_point(i,u,v,true),func(u: float,v: float)->Vector3:
		return diffuser_point(i,u,v,false),black,Vector3.DOWN,car.simple_model)
	for fin: int in range(count):
		var x: float=lerpf(-0.62,0.62,float(fin)/float(count-1))
		# Thin swept strakes have radiused noses, finite thickness and end caps.
		shell(parent,label+"Strake"+str(fin),10,6,func(u: float,v: float)->Vector3:
			return strake_point(i,x,u,v,1.0),func(u: float,v: float)->Vector3:
			return strake_point(i,x,u,v,-1.0),graphite,Vector3.RIGHT,car.simple_model)

static func diffuser_point(i: int,u: float,v: float,outer: bool) -> Vector3:
	var x: float=lerpf(-0.70,0.70,u)
	var edge: Vector3=cap_surface(i,true,(x/0.845+1.0)*0.5,0.20)
	return Vector3(x,0.226+0.045*v*v+(0.0 if outer else 0.012),lerpf(1.98,edge.z+0.002,v))

static func strake_point(i: int,x: float,u: float,v: float,side: float) -> Vector3:
	var edge: Vector3=cap_surface(i,true,(x/0.845+1.0)*0.5,0.20)
	var z: float=lerpf(2.00,edge.z,u)
	var top: float=0.266+0.050*u*u
	var depth: float=0.003+(0.047 if i in [5,6,12,15] else 0.030)*sin(PI*0.5*u)
	return Vector3(x+side*0.005,top-depth*v,z)
