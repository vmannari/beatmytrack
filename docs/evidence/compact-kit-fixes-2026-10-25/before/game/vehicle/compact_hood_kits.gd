class_name CompactHoodKits
extends RefCounted
## Pressed replacement panels with genuine recesses and modest blended intakes.

static func build(root: Node3D, kind: String, paint: Material, accent: Material) -> void:
	var key: String = "hood6/"+kind+"/"
	var dark: Material = CompactFinish.rubber(Color("171e21"))
	var holes: Array[Rect2] = []
	match kind:
		"louvres": holes = [Rect2(0.15,0.29,0.18,0.44),Rect2(0.67,0.29,0.18,0.44)]
		"scoop": holes = [Rect2(0.36,0.30,0.28,0.44)]
		"extractor": holes = [Rect2(0.30,0.30,0.40,0.40)]
		"cowl": holes = [Rect2(0.34,0.855,0.32,0.043)]
		"twin_scoop": holes = [Rect2(0.17,0.33,0.21,0.39),Rect2(0.62,0.33,0.21,0.39)]
		"reverse": holes = [Rect2(0.33,0.29,0.34,0.44)]
		"vented": holes = [Rect2(0.13,0.34,0.15,0.35),Rect2(0.72,0.34,0.15,0.35)]
	CompactKits._patch(root,key+"sheet",func(u: float,v: float) -> Vector3: return CompactKits.hood_sample(kind,u,v),paint,Vector3.UP,88,32,false,holes)
	for index: int in range(holes.size()):
		var hole: Rect2 = holes[index]
		var prefix: String = key+"opening"+str(index)+"/"
		_recess(root,prefix,kind,hole,dark)
		if kind in ["louvres","extractor","vented"]:
			_louvres(root,prefix,kind,hole,paint)
		elif kind=="cowl":
			for bar: int in range(9):
				var u: float = lerpf(hole.position.x+0.012,hole.end.x-0.012,bar/8.0)
				CompactKitSurface.solid(root,prefix+"grille"+str(bar),func(t: float,v: float) -> Vector3:
					var p: Vector3 = CompactKits.hood_sample(kind,u,lerpf(hole.position.y,hole.end.y,t))
					return p+Vector3(cos(v*TAU)*0.002,0.001+sin(v*TAU)*0.002,0),paint,4,8)
		else: _scoop(root,prefix,kind,hole,paint,dark)
	if kind in ["dome","vented"]:
		# A narrow fitted crown insert, with tapered ends rather than a rectangle
		# laid over the whole hood; the owner's accent pigment remains independent.
		CompactKits._patch(root,key+"crowninsert",func(u: float,v: float) -> Vector3:
			var along: float = lerpf(0.24,0.78,v)
			var span: float = 0.16*(0.25+0.75*smoothstep(0,0.15,v)*(1-smoothstep(0.85,1,v)))
			return CompactKits.hood_sample(kind,0.5+(u-0.5)*span,along)+Vector3.UP*0.0012,accent,Vector3.UP,16,24)
	for side: float in [-1,1]:
		CompactKitSurface.solid(root,key+"panelgap"+str(side),func(u: float,v: float) -> Vector3:
			return CompactKits.hood_sample(kind,0.5+side*0.494,u)+Vector3(cos(v*TAU)*0.0015,0.0008+sin(v*TAU)*0.0015,0),dark,32,8)

static func _recess(root: Node3D, key: String, kind: String, hole: Rect2, dark: Material) -> void:
	var corners: Array[Vector2] = [hole.position,Vector2(hole.end.x,hole.position.y),hole.end,Vector2(hole.position.x,hole.end.y)]
	for edge: int in range(4):
		var a: Vector2 = corners[edge]
		var b: Vector2 = corners[(edge+1)%4]
		var hint: Vector3 = CompactKits.hood_sample(kind,hole.get_center().x,hole.get_center().y)-CompactKits.hood_sample(kind,(a.x+b.x)*0.5,(a.y+b.y)*0.5)
		CompactKits._patch(root,key+"wall"+str(edge),func(u: float,v: float) -> Vector3:
			var t: Vector2 = a.lerp(b,u)
			return CompactKits.hood_sample(kind,t.x,t.y)-Vector3.UP*v*0.031,dark,Vector3(hint.x,0,hint.z),16,2)
	CompactKits._patch(root,key+"recess",func(u: float,v: float) -> Vector3:
		var t: Vector2 = hole.position+hole.size*Vector2(u,v)
		return CompactKits.hood_sample(kind,t.x,t.y)-Vector3.UP*0.032,dark,Vector3.UP,16,8)

static func _louvres(root: Node3D, key: String, kind: String, hole: Rect2, paint: Material) -> void:
	var count: int = 6 if kind=="louvres" else 4 if kind=="extractor" else 4
	var pitch: float = hole.size.y/count
	var rise: float = 0.015 if kind!="extractor" else 0.022
	for index: int in range(count):
		var start: float = hole.position.y+0.008+index*pitch
		var section: Array[Vector2] = [Vector2(0,0.002),Vector2(pitch*0.70,rise),Vector2(pitch*0.74,rise-0.003),Vector2(0,-0.001)]
		CompactKitSurface.solid(root,key+"louvre"+str(index),func(u: float,v: float) -> Vector3:
			var q: Vector2 = CompactKitSurface.contour(section,v,0.0015)
			var x: float = lerpf(hole.position.x-0.004,hole.end.x+0.004,u)
			var p: Vector3 = CompactKits.hood_sample(kind,x,start+q.x)
			p.y += q.y*(0.18+0.82*sin(u*PI))
			return p,paint,18,16)

static func _scoop(root: Node3D, key: String, kind: String, hole: Rect2, paint: Material, dark: Material) -> void:
	var reverse: bool = kind=="reverse"
	var rise: float = 0.054 if kind=="twin_scoop" else 0.069 if kind=="scoop" else 0.060
	var mouth: float = 1.0 if reverse else 0.0
	var crown: Callable = func(u: float,v: float) -> Vector3:
		var along: float = 1-v if reverse else v
		var x: float = hole.position.x+hole.size.x*u
		var y: float = hole.position.y+hole.size.y*v
		var p: Vector3 = CompactKits.hood_sample(kind,x,y)
		p.y += rise*(0.78+0.22*sin(u*PI))*(1-smoothstep(0.04,1,along))
		return p
	CompactKits._patch(root,key+"crown",crown,paint,Vector3.UP,28,20)
	for side: float in [0.0,1.0]:
		CompactKitSurface.panel(root,key+"blendedcheek"+str(side),func(u: float,v: float) -> Vector3:
			var edge: float = hole.position.x+side*hole.size.x
			var y: float = hole.position.y+u*hole.size.y
			var top: Vector3 = crown.call(side,u)
			var height: float = top.y-CompactKits.hood_sample(kind,edge,y).y
			var x: float = edge+(v-1)*(0.013 if side==0 else -0.013)*height/rise
			return CompactKits.hood_sample(kind,x,y)+Vector3.UP*height*v,paint,Vector3(-1 if side==0 else 1,0,0),24,8)
	# Dark intake is recessed behind the rolled mouth; it reads as a cavity.
	CompactKits._patch(root,key+"intake",func(u: float,v: float) -> Vector3:
		var top: Vector3 = crown.call(u,mouth)
		var base: Vector3 = CompactKits.hood_sample(kind,hole.position.x+hole.size.x*u,hole.position.y+mouth*hole.size.y)-Vector3.UP*0.006
		return base.lerp(top,v)+Vector3(0,0,-0.018 if reverse else 0.018),dark,Vector3.BACK if reverse else Vector3.FORWARD,24,6)
	CompactKitSurface.solid(root,key+"mouthreturn",func(u: float,v: float) -> Vector3:
		return (crown.call(u,mouth) as Vector3)+Vector3(0,cos(v*TAU)*0.003,sin(v*TAU)*0.006),paint,28,12)
	# One horizontal grille rail keeps the mouth open and restrained.
	CompactKitSurface.solid(root,key+"intakerail",func(u: float,v: float) -> Vector3:
		var p: Vector3 = crown.call(u,mouth)
		p.y -= rise*0.48
		return p+Vector3(0,cos(v*TAU)*0.0018,(0.006 if reverse else -0.006)+sin(v*TAU)*0.0018),paint,24,8)
