class_name CompactKitVariants
extends RefCounted
## Original second collection, fitted to the same compact sheet and wheel frames.
const HOODS: Array[String] = ["extractor","cowl","twin_scoop","reverse","ribs","vented"]
const AERO: Array[String] = ["touring","pedestal","swan","biwing","rallywing","endurance"]
const RIMS: Array[String] = ["mesh","dish","rallydisc","six","ten","tri"]
const BODIES: Array[String] = ["heritage","touring","wide","endurance","gravel","urban"]

static func hood_point(kind: String, _u: float, v: float, point: Vector3) -> Vector3:
	var along: float = smoothstep(0.12,0.34,v)*(1-smoothstep(0.81,0.98,v))
	if kind=="vented": point.y += 0.090*(1-smoothstep(0.19,0.43,absf(point.x)))*along
	elif kind=="cowl":
		point.y += 0.115*(1-smoothstep(0.29,0.51,absf(point.x)))*smoothstep(0.16,0.75,v)*(1-smoothstep(0.90,0.99,v))
	elif kind=="ribs":
		for x: float in [-0.38,0.0,0.38]: point.y += 0.035*(1-smoothstep(0.03,0.10,absf(point.x-x)))*along
	return point

static func hood(car: CarVisual, kind: String, paint: Material, accent: Material) -> void:
	var root: Node3D = CompactKits._node(car.body,"KitHood_"+kind)
	var dark: Material = CompactFinish.rubber(Color("171e21"))
	var metal: Material = CompactFinish.alloy(Color("8d979b"))
	var holes: Array[Rect2] = []
	match kind:
		"extractor": holes = [Rect2(0.30,0.29,0.40,0.43)]
		"twin_scoop": holes = [Rect2(0.15,0.30,0.23,0.43),Rect2(0.62,0.30,0.23,0.43)]
		"reverse": holes = [Rect2(0.31,0.28,0.38,0.46)]
		"vented": holes = [Rect2(0.11,0.32,0.17,0.39),Rect2(0.72,0.32,0.17,0.39)]
	CompactKits._patch(root,"hood/"+kind,func(u: float,v: float) -> Vector3: return CompactKits.hood_sample(kind,u,v),paint,Vector3.UP,88,32,false,holes)
	for index: int in range(holes.size()):
		var hole: Rect2 = holes[index]
		var prefix: String = "hood/%s/opening%d/"%[kind,index]
		var center: Vector2 = hole.get_center()
		for edge: int in range(4):
			var corners: Array[Vector2] = [hole.position,Vector2(hole.end.x,hole.position.y),hole.end,Vector2(hole.position.x,hole.end.y)]
			var a: Vector2 = corners[edge]
			var b: Vector2 = corners[(edge+1)%4]
			var hint: Vector3 = CompactKits.hood_sample(kind,center.x,center.y)-CompactKits.hood_sample(kind,(a.x+b.x)*0.5,(a.y+b.y)*0.5)
			CompactKits._patch(root,prefix+"wall"+str(edge),func(u: float,v: float) -> Vector3:
				var t: Vector2 = a.lerp(b,u)
				return CompactKits.hood_sample(kind,t.x,t.y)-Vector3.UP*v*0.045,dark,Vector3(hint.x,0,hint.z),20,2)
		CompactKits._patch(root,prefix+"recess",func(u: float,v: float) -> Vector3:
			var t: Vector2 = hole.position+hole.size*Vector2(u,v)
			return CompactKits.hood_sample(kind,t.x,t.y)-Vector3.UP*0.046,dark,Vector3.UP,16,8)
		if kind in ["extractor","vented"]:
			var count: int = 5 if kind=="extractor" else 4
			for blade: int in range(count):
				var start: float = hole.position.y+0.018+blade*(hole.size.y-0.028)/count
				CompactKits._patch(root,prefix+"blade"+str(blade),func(u: float,v: float) -> Vector3:
					var p: Vector3 = CompactKits.hood_sample(kind,lerpf(hole.position.x-0.005,hole.end.x+0.005,u),start+v*hole.size.y/count*0.70)
					p.y += 0.003+sin(v*PI*0.82)*sin(u*PI)*(0.035 if kind=="extractor" else 0.019)
					return p,paint,Vector3.UP,20,6)
		else:
			_scoop(car,root,kind,prefix,hole,kind=="reverse",paint,dark)
		# Flush captive fasteners on the pressed flange.
		for x: float in [hole.position.x-0.013,hole.end.x+0.013]:
			for y: float in [hole.position.y+0.04,hole.end.y-0.04]:
				CompactKits._cylinder(root,0.0055,0.0025,CompactKits.hood_sample(kind,x,y)+Vector3.UP*0.0018,metal,8)
	if kind=="cowl":
		CompactKits._patch(root,"hood/cowl/reargrille",func(u: float,v: float) -> Vector3:
			return CompactKits.hood_sample(kind,lerpf(0.36,0.64,u),lerpf(0.84,0.88,v))+Vector3.UP*0.0015,dark,Vector3.UP,24,4)
		for bar: int in range(9):
			var x: float = lerpf(0.37,0.63,bar/8.0)
			car._seam(root,CompactKits.hood_sample(kind,x,0.84)+Vector3.UP*0.003,CompactKits.hood_sample(kind,x,0.88)+Vector3.UP*0.003,0.004,paint)
	if kind=="vented":
		CompactKits._patch(root,"hood/vented/pressedcenter",func(u: float,v: float) -> Vector3:
			return CompactKits.hood_sample(kind,lerpf(0.39,0.61,u),lerpf(0.18,0.87,v))+Vector3.UP*0.0015,accent,Vector3.UP,20,24)
	# The original panel gap is retained along both fenders.
	for side: float in [-1,1]:
		for segment: int in range(24):
			car._seam(root,CompactKits.hood_sample(kind,0.5+side*0.494,segment/24.0)+Vector3.UP*0.002,CompactKits.hood_sample(kind,0.5+side*0.494,(segment+1)/24.0)+Vector3.UP*0.002,0.004,dark)

static func _scoop(car: CarVisual, root: Node3D, kind: String, prefix: String, hole: Rect2, reverse: bool, paint: Material, dark: Material) -> void:
	var rise: float = 0.084 if kind=="twin_scoop" else 0.092
	var crown: Callable = func(u: float,v: float) -> Vector3:
		var t: Vector2 = hole.position+hole.size*Vector2(u,v)
		var p: Vector3 = CompactKits.hood_sample(kind,t.x,t.y)
		var progress: float = 1-v if reverse else v
		p.y += (rise+0.009*sin(u*PI))*(1-smoothstep(0.03,1,progress))
		return p
	CompactKits._patch(root,prefix+"crown",crown,paint,Vector3.UP,28,24)
	for side: float in [0.0,1.0]:
		CompactKits._patch(root,prefix+"cheek"+str(side),func(u: float,v: float) -> Vector3:
			var t: Vector2 = hole.position+hole.size*Vector2(side,u)
			var base: Vector3 = CompactKits.hood_sample(kind,t.x,t.y)
			return base.lerp(crown.call(side,u),v),paint,Vector3(-1 if side==0 else 1,0,0),24,6)
	var mouth: float = 1.0 if reverse else 0.0
	CompactKits._patch(root,prefix+"intake",func(u: float,v: float) -> Vector3:
		var p: Vector3 = crown.call(u,mouth)
		var base: Vector3 = CompactKits.hood_sample(kind,hole.position.x+u*hole.size.x,hole.position.y+mouth*hole.size.y)
		return base.lerp(p,v)+Vector3(0,0,-0.004 if reverse else 0.004),dark,Vector3.BACK if reverse else Vector3.FORWARD,24,6)
	CompactKits._patch(root,prefix+"rollededge",func(u: float,v: float) -> Vector3:
		return (crown.call(u,mouth) as Vector3)+Vector3(0,cos(v*TAU)*0.004,sin(v*TAU)*0.004),paint,Vector3.ZERO,28,10,true)
	for bar: int in range(7):
		var u: float = lerpf(0.08,0.92,bar/6.0)
		var top: Vector3 = crown.call(u,mouth)
		var base: Vector3 = CompactKits.hood_sample(kind,hole.position.x+u*hole.size.x,hole.position.y+mouth*hole.size.y)
		car._seam(root,base+Vector3.UP*0.008,top-Vector3.UP*0.008,0.0045,paint)

static func aero(_car: CarVisual, root: Node3D, kind: String, paint: Material, trim: Material, metal: Material) -> void:
	# Span, height, half chord, sweep. All saddles land on actual roof sheet.
	var profile: Array = {"touring":[0.74,1.65,0.13,0.025],"pedestal":[0.77,1.76,0.16,0.025],"swan":[0.88,1.85,0.18,0.035],"biwing":[0.80,1.83,0.145,0.02],"rallywing":[0.83,1.75,0.16,0.12],"endurance":[0.93,1.87,0.21,0.05]}[kind]
	var half: float = profile[0]
	var height: float = profile[1]
	var chord: float = profile[2]
	var sweep: float = profile[3]
	for side: float in [-1,1]:
		var mount: Vector3 = CompactCoachwork.roof_point(side*(0.90 if kind=="touring" else 0.77),0.94)
		var prefix: String = "aero/%s/%s/"%[kind,side]
		CompactKits._rounded_box(root,prefix+"seal",mount+Vector3.UP*0.004,Vector3(0.15,0.012,0.18),0.005,trim)
		CompactKits._rounded_box(root,prefix+"saddle",mount+Vector3.UP*0.016,Vector3(0.12,0.022,0.15),0.009,metal)
		var top: Vector3 = Vector3(mount.x,height+(0.058 if kind=="swan" else -0.01),1.36)
		CompactKits._patch(root,prefix+"support",func(u: float,v: float) -> Vector3:
			var p: Vector3 = (mount+Vector3.UP*0.019).lerp(top,u)
			if kind=="swan": p.z -= sin(u*PI)*0.13
			elif kind=="pedestal": p.z += sin(u*PI)*0.035
			return p+Vector3(cos(v*TAU)*0.013,0,sin(v*TAU)*(0.027 if kind=="touring" else 0.034)),trim,Vector3.ZERO,24,12,true)
		if kind=="swan":
			CompactKits._rounded_box(root,prefix+"upperclamp",Vector3(mount.x,height+0.034,1.36),Vector3(0.055,0.065,0.11),0.015,metal)
		for z: float in [-0.045,0.045]: CompactKits._cylinder(root,0.009,0.004,mount+Vector3(0,0.030,z),metal,10)
	_blade(root,"aero/"+kind+"/blade",half,height,chord,sweep,kind,paint)
	if kind=="biwing": _blade(root,"aero/biwing/lower",half*0.96,height-0.13,chord*0.90,sweep,kind,paint)
	for side: float in [-1,1]:
		if kind=="touring": continue
		var plate_height: float = 0.24 if kind=="biwing" else 0.15 if kind=="endurance" else 0.115
		var tip_y: float = height+(0.062 if kind=="rallywing" else 0.012)
		CompactKits._rounded_box(root,"aero/%s/end%s"%[kind,side],Vector3(side*(half+0.008),tip_y-(0.053 if kind=="biwing" else 0),1.36+sweep),Vector3(0.022,plate_height,chord*2+0.04),0.010,trim)
		for z: float in [-0.07,0.07]:
			var bolt := CompactKits._cylinder(root,0.007,0.005,Vector3(side*(half+0.021),tip_y,1.36+sweep+z),metal,10)
			bolt.rotation.z = PI*0.5

static func _blade(root: Node3D, key: String, half: float, height: float, chord: float, sweep: float, kind: String, paint: Material) -> void:
	var sample: Callable = func(u: float,v: float) -> Vector3:
		var x: float = lerpf(-half,half,u)
		var edge: float = pow(absf(x)/half,3)
		var a: float = v*TAU
		return Vector3(x,height+(0.062 if kind=="rallywing" else 0.012)*edge+0.021*sin(a)-0.014*sin(a)*sin(a)+0.017*cos(a),1.36+sweep*edge+cos(a)*chord*(1-0.16*edge))
	CompactKits._patch(root,key,sample,paint,Vector3.ZERO,48,20,true)
	# Solid end caps are part of the authored mesh cache, including touring's bare tips.
	for end: float in [0.0,1.0]:
		var cap_key: String = key+"/cap"+str(end)+("/simple" if CompactKits.simple_parts else "")
		CompactKits._load_prepared(cap_key)
		if not CompactKits.meshes.has(cap_key):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			var normal := Vector3(-1 if end==0 else 1,0,0)
			var center: Vector3 = Vector3.ZERO
			for t: float in [0.0,0.25,0.5,0.75]: center += (sample.call(end,t) as Vector3)*0.25
			for index: int in range(20):
				var a: Vector3 = sample.call(end,index/20.0)
				var b: Vector3 = sample.call(end,(index+1)/20.0)
				var points: Array = [center,a,b] if (a-center).cross(b-center).dot(normal)<0 else [center,b,a]
				for point: Vector3 in points:
					tool.set_normal(normal)
					tool.set_uv(Vector2(point.y-height,point.z-1.36))
					tool.add_vertex(point)
			tool.index()
			tool.generate_tangents()
			CompactKits.meshes[cap_key] = tool.commit()
		var cap := MeshInstance3D.new()
		cap.mesh = CompactKits.meshes[cap_key]
		cap.material_override = paint
		root.add_child(cap)

static func body(car: CarVisual, root: Node3D, kind: String, paint: Material, trim: Material, metal: Material) -> void:
	# Flare, skirt drop, bumper extension; the original bumper path stays authoritative.
	var profile: Array = {"heritage":[0.032,0.018,0.045],"touring":[0.048,0.038,0.080],"wide":[0.095,0.027,0.095],"endurance":[0.083,0.048,0.150],"gravel":[0.067,0.010,0.050],"urban":[0.045,0.045,0.065]}[kind]
	var flare: float = profile[0]
	var drop: float = profile[1]
	var depth: float = profile[2]
	for side: float in [-1,1]:
		CompactKits._patch(root,"body/%s/skirt%s"%[kind,side],func(u: float,v: float) -> Vector3:
			var z: float = lerpf(-0.85,0.85,u)
			var a: float = v*TAU
			var base_y: float = 0.375-drop
			return Vector3(side*(CompactCoachwork.body_width(0.39,z)+flare*pow(sin(u*PI),0.6)+cos(a)*0.020),base_y+sin(a)*(0.044 if kind=="heritage" else 0.056),z),trim if kind=="gravel" else paint,Vector3.ZERO,32,12,true)
		if kind in ["touring","endurance","urban"]:
			CompactKits._rounded_box(root,"body/%s/rocker%s"%[kind,side],Vector3(side*0.95,0.291-drop*0.2,0),Vector3(0.095,0.022,1.64),0.010,trim)
		if kind in ["wide","endurance","gravel","heritage"]:
			for axle: float in [-1.28,1.28]:
				var outer: float = 0.490 if kind!="heritage" else 0.458
				CompactKits._patch(root,"body/%s/arch%s/%s"%[kind,side,axle],func(u: float,v: float) -> Vector3:
					var a: float = lerpf(-0.12,PI+0.12,u)
					var radius: float = lerpf(0.423,outer,v)
					var y: float = 0.37+sin(a)*radius
					var z: float = axle+cos(a)*radius
					return Vector3(side*(CompactCoachwork.body_width(y,z)+CompactKits.arch_roll(radius,axle)+0.010+flare*sin(v*PI)+0.019*(1-v)),y,z),trim if kind=="gravel" else paint,Vector3(side,0,0),40,8)
				if kind=="gravel":
					CompactKits._rounded_box(root,"body/gravel/flap%s/%s"%[side,axle],Vector3(side*0.83,0.267,axle+0.40),Vector3(0.27,0.235,0.022),0.010,trim)
					CompactKits._rounded_box(root,"body/gravel/flaprail%s/%s"%[side,axle],Vector3(side*0.83,0.372,axle+0.413),Vector3(0.25,0.018,0.014),0.006,metal)
	for rear: bool in [false,true]:
		CompactKits._patch(root,"body/%s/valance%s"%[kind,rear],func(u: float,v: float) -> Vector3:
			var p: Vector2 = CompactCoachwork._bumper_path(rear,u)
			var tangent: Vector2 = (CompactCoachwork._bumper_path(rear,minf(1,u+0.0002))-CompactCoachwork._bumper_path(rear,maxf(0,u-0.0002))).normalized()
			var a: float = v*TAU
			p += Vector2(-tangent.y,tangent.x)*(depth*(0.5+0.5*cos(a))-0.027)
			return Vector3(p.x,(0.335 if rear else 0.36)-drop*0.6+sin(a)*0.033,p.y),trim if kind in ["gravel","endurance"] else paint,Vector3.ZERO,64,12,true)
	if kind in ["touring","endurance","urban"]:
		var count: int = 7 if kind=="endurance" else 3
		for fin: int in range(count):
			CompactKits._rounded_box(root,"body/%s/diffuser%d"%[kind,fin],Vector3((fin-(count-1)*0.5)*0.20,0.288,2.00),Vector3(0.019,0.098,0.25 if kind=="endurance" else 0.17),0.008,trim)
	if kind=="endurance":
		for side: float in [-1,1]:
			CompactKits._rounded_box(root,"body/endurance/canard"+str(side),Vector3(side*0.96,0.473,-1.85),Vector3(0.18,0.018,0.23),0.008,trim)
			CompactKits._rounded_box(root,"body/endurance/endfence"+str(side),Vector3(side*1.03,0.374,-1.90),Vector3(0.020,0.099,0.30),0.009,trim)

static func wheel_face(_car: CarVisual, root: Node3D, kind: String, side: float, alloy: Material, polished: Material, dark: Material) -> void:
	var count: int = {"mesh":8,"dish":5,"rallydisc":8,"six":6,"ten":10,"tri":3}[kind]
	var forks: int = 2 if kind=="mesh" else 1
	for spoke: int in range(count):
		for fork: int in range(forks):
			CompactKits._patch(root,"rim/%s/spoke%d/%d/%s"%[kind,spoke,fork,side],func(u: float,v: float) -> Vector3:
				var radius: float = lerpf(0.048,0.230,u)
				var twist: float = (fork*2-1)*0.28*u if kind=="mesh" else -0.10*u if kind=="tri" else 0.0
				var a: float = spoke*TAU/count+twist
				var b: float = v*TAU
				var width: float = lerpf(0.040,0.074,u) if kind=="rallydisc" else lerpf(0.046,0.049,u) if kind=="tri" else lerpf(0.027,0.039,u) if kind=="dish" else lerpf(0.025,0.020,u) if kind=="six" else 0.011 if kind=="ten" else 0.009
				var x: float = 0.102+u*(0.006 if kind=="dish" else 0.038)+sin(b)*0.009
				return Vector3(side*x,sin(a)*radius+cos(a)*cos(b)*width,cos(a)*radius-sin(a)*cos(b)*width),alloy,Vector3.ZERO,12,10,true)
	if kind=="dish":
		CompactKits._patch(root,"rim/dish/steplip"+str(side),func(u: float,v: float) -> Vector3:
			var a: float = v*TAU
			var radius: float = lerpf(0.196,0.230,u)
			return Vector3(side*(0.112+smoothstep(0.0,1,u)*0.036),sin(a)*radius,cos(a)*radius),polished,Vector3(side,0,0),8,64)
	if kind in ["mesh","rallydisc"]:
		for rivet: int in range(16):
			var a: float = rivet*TAU/16.0
			var bolt := CompactKits._cylinder(root,0.0035,0.002,Vector3(side*0.150,sin(a)*0.218,cos(a)*0.218),polished if kind=="mesh" else dark,8)
			bolt.rotation.z = PI*0.5
