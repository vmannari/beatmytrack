class_name CompactWheelKits
extends RefCounted
## Open, bevelled cast / forged faces within the unchanged original tyre bead.

static func build(root: Node3D, kind: String, side: float, alloy: Material, polished: Material, dark: Material, steel: Material) -> void:
	var key: String = "rim6/"+kind+"/"+str(side)+"/"
	var dish: bool = kind=="dish"
	var depth: float = 0.102 if dish else 0.130
	var barrel: Array[Vector2] = [Vector2(0.024,0.224),Vector2(0.126,0.224),Vector2(0.142,0.232),Vector2(0.146,0.237),Vector2(0.141,0.240),Vector2(0.129,0.235),Vector2(0.025,0.232)]
	CompactKitSurface.skin(root,key+"barrel",func(u: float,v: float) -> Vector3:
		var a: float = u*TAU
		var q: Vector2 = CompactKitSurface.contour(barrel,v,0.0015)
		return Vector3(side*q.x,sin(a)*q.y,cos(a)*q.y),alloy,64,14)
	# A slim machined bead, with a distinct deeper stepped shelf on Deep dish.
	CompactKits._patch(root,key+"lip",func(u: float,v: float) -> Vector3:
		var a: float = u*TAU
		var radius: float = lerpf(0.194 if dish else 0.222,0.238,v)
		var x: float = lerpf(depth+0.003,0.145,smoothstep(0,1,v))
		return Vector3(side*x,sin(a)*radius,cos(a)*radius),polished,Vector3(side,0,0),64,6)
	# Plain machined rotor, instead of dark dots pretending to be holes.
	var rotor: Array[Vector2] = [Vector2(0.037,0.068),Vector2(0.049,0.068),Vector2(0.049,0.188),Vector2(0.037,0.188)]
	CompactKitSurface.skin(root,"rim6/rotor/"+str(side),func(u: float,v: float) -> Vector3:
		var a: float = u*TAU
		var q: Vector2 = CompactKitSurface.contour(rotor,v,0.0007)
		return Vector3(side*q.x,sin(a)*q.y,cos(a)*q.y),steel,48,8)
	if kind=="rallydisc": _disc(root,key,side,alloy,dark)
	else:
		var count: int = {"five":5,"split":6,"turbine":12,"mesh":8,"dish":5,"six":6,"ten":10,"tri":3}[kind]
		for spoke: int in range(count):
			for fork: int in range(2 if kind in ["split","mesh"] else 1):
				_spoke(root,key,kind,side,spoke,fork,count,depth,alloy)
		if kind=="mesh":
			# Bolts land in the continuous rim flange, rather than in open air.
			for index: int in range(16):
				var a: float = index*TAU/16
				var bolt := CompactKits._cylinder(root,0.0038,0.0025,Vector3(side*0.146,sin(a)*0.230,cos(a)*0.230),polished,8)
				bolt.rotation.z = PI*0.5
	var hub := CompactKits._cylinder(root,0.066,0.027,Vector3(side*(depth-0.008),0,0),alloy,32)
	hub.rotation.z = PI*0.5
	var center := CompactKits._cylinder(root,0.022,0.005,Vector3(side*(depth+0.008),0,0),dark,24)
	center.rotation.z = PI*0.5
	for index: int in range(4):
		var a: float = index*TAU/4+PI/4
		var point := Vector3(side*(depth+0.006),sin(a)*0.045,cos(a)*0.045)
		var socket := CompactKits._cylinder(root,0.012,0.003,point,dark,12)
		socket.rotation.z = PI*0.5
		var lug := CompactKits._cylinder(root,0.0078,0.007,point+Vector3(side*0.003,0,0),polished,6)
		lug.rotation.z = PI*0.5
	var radial := Vector3(0,0.924,0.383)
	var valve := CompactKits._cylinder(root,0.0048,0.017,Vector3(side*0.133,0,0)+radial*0.216,dark,10)
	valve.quaternion = Quaternion(Vector3.UP,radial)

static func _spoke(root: Node3D, key: String, kind: String, side: float, spoke: int, fork: int, count: int, depth: float, alloy: Material) -> void:
	var profile: Array[Vector2] = [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]
	CompactKitSurface.solid(root,key+"spoke%d/%d"%[spoke,fork],func(u: float,v: float) -> Vector3:
		var radius: float = lerpf(0.056,0.231,u)
		var twist: float = 0.32*u if kind=="turbine" else (fork*2-1)*(0.52*u if kind=="mesh" else 0.14*smoothstep(0.05,0.70,u)) if kind in ["mesh","split"] else -0.17*u if kind=="tri" else 0.035*u
		var a: float = spoke*TAU/count+twist
		var width: float = lerpf(0.026,0.018,u) if kind=="five" else lerpf(0.036,0.046,u) if kind=="tri" else lerpf(0.023,0.030,u) if kind=="dish" else lerpf(0.019,0.015,u) if kind=="six" else 0.0075 if kind in ["ten","mesh"] else 0.010
		var q: Vector2 = CompactKitSurface.contour(profile,v,0.20)
		var x: float = lerpf(depth,0.143,smoothstep(0,1,u))+q.y*0.006
		if kind=="mesh": x += fork*sin(u*PI)*0.001
		if kind=="dish": x = lerpf(depth-0.005,depth+0.008,u)+q.y*0.007
		return Vector3(side*x,sin(a)*radius+cos(a)*q.x*width,cos(a)*radius-sin(a)*q.x*width),alloy,8,12)

static func _disc(root: Node3D, key: String, side: float, alloy: Material, dark: Material) -> void:
	# Eight actual cooling windows through a shallow pressed face; the rim and
	# hub remain joined by an uninterrupted inner and outer mounting web.
	var holes: Array[Rect2] = []
	for index: int in range(8): holes.append(Rect2(index/8.0+0.032,0.29,0.061,0.49))
	var sample: Callable = func(u: float,v: float,back: bool) -> Vector3:
		var a: float = u*TAU
		var radius: float = lerpf(0.064,0.229,v)
		var x: float = 0.137-0.016*sin(v*PI)-(0.007 if back else 0)
		return Vector3(side*x,sin(a)*radius,cos(a)*radius)
	for back: bool in [false,true]:
		CompactKits._patch(root,key+"disc"+str(back),func(u: float,v: float) -> Vector3: return sample.call(u,v,back),alloy,Vector3(side*(-1 if back else 1),0,0),32,12,false,holes)
	for index: int in range(holes.size()):
		var hole: Rect2 = holes[index]
		var corners: Array[Vector2] = [hole.position,Vector2(hole.end.x,hole.position.y),hole.end,Vector2(hole.position.x,hole.end.y)]
		for edge: int in range(4):
			var a: Vector2 = corners[edge]
			var b: Vector2 = corners[(edge+1)%4]
			var center: Vector3 = sample.call(hole.get_center().x,hole.get_center().y,false)
			var mid: Vector3 = sample.call((a.x+b.x)*0.5,(a.y+b.y)*0.5,false)
			CompactKits._patch(root,key+"window%d/%d"%[index,edge],func(u: float,v: float) -> Vector3:
				var p: Vector2 = a.lerp(b,u)
				return (sample.call(p.x,p.y,false) as Vector3).lerp(sample.call(p.x,p.y,true),v),dark,Vector3(0,center.y-mid.y,center.z-mid.z),8,2)
