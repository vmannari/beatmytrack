extends RefCounted
## Original full-face competition helmet. Model coordinates, no branded asset.
const G = preload("res://vehicle/kart_geometry.gd")
const BASE: float = 0.730
const CROWN: float = 1.112
const OPENING: float = 1.25

static func profile(y: float) -> Vector3:
	# Half-width and front/rear coordinates: tucked neck, forward chin, defined
	# cheek and temple, then a lower, round crown. These are not sphere offsets.
	if y >= 0.985: return crown_profile(y)
	var crown_base: Vector3 = crown_profile(0.985)
	var levels: Array[Vector4] = [
		Vector4(0.730,0.103,0.103,0.349),Vector4(0.752,0.131,0.038,0.388),
		Vector4(0.792,0.154,0.006,0.420),Vector4(0.828,0.169,0.018,0.438),
		Vector4(0.860,0.177,0.038,0.445),Vector4(0.910,0.182,0.055,0.451),
		Vector4(0.950,0.180,0.062,0.446),Vector4(0.985,crown_base.x,crown_base.y,crown_base.z)]
	for i: int in range(levels.size()-1):
		if y > levels[i+1].x: continue
		var a: Vector4 = levels[i]
		var b: Vector4 = levels[i+1]
		var p: Vector4 = levels[maxi(0,i-1)]
		var q: Vector4 = levels[mini(levels.size()-1,i+2)]
		var t: float = clampf((y-a.x)/(b.x-a.x),0,1)
		# Nonuniform Hermite slopes agree at every height station. The final
		# tangent exactly matches the analytic crown, avoiding horizontal bands.
		var av := Vector3(a.y,a.z,a.w)
		var bv := Vector3(b.y,b.z,b.w)
		var ma: Vector3 = (bv-Vector3(p.y,p.z,p.w))/(b.x-p.x)
		var mb: Vector3 = (Vector3(q.y,q.z,q.w)-av)/(q.x-a.x)
		if i == levels.size()-2:
			var r: float = sqrt(1-pow((b.x-0.948)/0.164,2))
			var dr: float = -(b.x-0.948)/(0.164*0.164*r)
			mb = Vector3(0.1796,-0.1858,0.1827)*dr
		return av*(2*t*t*t-3*t*t+1)+ma*(b.x-a.x)*(t*t*t-2*t*t+t)+bv*(-2*t*t*t+3*t*t)+mb*(b.x-a.x)*(t*t*t-t*t)
	return Vector3.ZERO

static func crown_profile(y: float) -> Vector3:
	var r: float = sqrt(maxf(0,1-pow((y-0.948)/0.164,2)))
	return Vector3(0.1796*r,0.257-0.1858*r,0.257+0.1827*r)

static func point(angle: float, y: float) -> Vector3:
	var shape: Vector3 = profile(y)
	var exponent: float = lerpf(0.87,1,smoothstep(0.92,1.04,y))
	var x: float = shape.x*signf(sin(angle))*pow(absf(sin(angle)),exponent)
	var z: float = (shape.y+shape.z)*0.5-(shape.z-shape.y)*0.5*signf(cos(angle))*pow(absf(cos(angle)),exponent)
	# A shallow swept cheek crease connects the eye opening to the jaw corners.
	var cheek: float = 0.004*exp(-pow((y-0.842)/0.024,2))*exp(-pow((absf(wrapf(angle,-PI,PI))-0.85)/0.25,2))
	return Vector3(x-signf(x)*cheek,y,z)

static func outward(angle: float, y: float) -> Vector3:
	if y > CROWN-0.001: return Vector3.UP
	return Vector3(sin(angle),(y-0.91)*4,-cos(angle)).normalized()

static func bounds(angle: float) -> Vector2:
	var t: float = clampf(absf(wrapf(angle,-PI,PI))/OPENING,0,1)
	return Vector2(0.867+0.018*pow(t,1.4),0.991-0.032*pow(t,1.8))

static func shell_angle(u: float) -> float:
	# Opening corners coincide with the whole-shell sampling, including the LOD.
	if u < 0.3125: return lerpf(-PI,-OPENING,u/0.3125)
	if u < 0.6875: return lerpf(-OPENING,OPENING,(u-0.3125)/0.375)
	return lerpf(OPENING,PI,(u-0.6875)/0.3125)

static func build(parent: Node3D, simple: bool) -> void:
	var shell := CompactFinish.paint(Color("d7d2bf"))
	shell.roughness = 0.46
	shell.clearcoat = 0.12
	var rubber := CompactFinish.rubber(Color("111a1e"))
	var charcoal := CompactFinish.rubber(Color("263944"))
	var lens := CompactFinish.paint(Color("304650"))
	lens.metallic = 0.22
	lens.roughness = 0.25
	lens.clearcoat = 0.20
	var fastener := CompactFinish.alloy(Color("8b9595"))
	# One shell mesh wraps below the eye port, around the temples/back and over
	# the crown. The eye port is an actual aperture, with its own returned rim.
	G.attach(parent,"HelmetV2Shell"+("|simple" if simple else "|full"),shell,func() -> ArrayMesh:
		var tool := SurfaceTool.new()
		var around: int = 32 if simple else 64
		var low: ArrayMesh = G.surface(around,8 if simple else 16,func(u: float,v: float) -> Vector3:
			var a: float = shell_angle(u)
			return point(a,lerpf(BASE,bounds(a).x,v)),func(u: float,v: float) -> Vector3:
			var a: float = shell_angle(u)
			return outward(a,lerpf(BASE,bounds(a).x,v)))
		tool.append_from(low,0,Transform3D.IDENTITY)
		var upper: ArrayMesh = G.surface(around,12 if simple else 24,func(u: float,v: float) -> Vector3:
			var a: float = shell_angle(u)
			return point(a,lerpf(bounds(a).y,CROWN,v)),func(u: float,v: float) -> Vector3:
			var a: float = shell_angle(u)
			return outward(a,lerpf(bounds(a).y,CROWN,v)))
		tool.append_from(upper,0,Transform3D.IDENTITY)
		for side: float in [-1.0,1.0]:
			var back: ArrayMesh = G.surface(10 if simple else 20,4 if simple else 8,func(u: float,v: float) -> Vector3:
				var a: float = side*lerpf(OPENING,PI,u)
				return point(a,lerpf(bounds(a).x,bounds(a).y,v)),func(u: float,v: float) -> Vector3:
				var a: float = side*lerpf(OPENING,PI,u)
				return outward(a,lerpf(bounds(a).x,bounds(a).y,v)))
			tool.append_from(back,0,Transform3D.IDENTITY)
		return tool.commit())
	# Return the edge of the eye port inward; no white backing behind the lens.
	for top: bool in [false,true]:
		G.patch(parent,"HelmetV2EyePortReturn"+str(top),24,4,func(u: float,v: float) -> Vector3:
			var a: float = lerpf(-OPENING,OPENING,u)
			var y: float = bounds(a).y if top else bounds(a).x
			return point(a,y)-outward(a,y)*v*0.009,func(_u: float,_v: float) -> Vector3: return Vector3.DOWN if top else Vector3.UP,rubber,simple)
	G.patch(parent,"HelmetV2VisorSeal",28,10,func(u: float,v: float) -> Vector3:
		var a: float = lerpf(-OPENING,OPENING,u)
		var y: float = lerpf(bounds(a).x,bounds(a).y,v)
		return point(a,y)-outward(a,y)*0.006,func(u: float,v: float) -> Vector3:
		var a: float = lerpf(-OPENING,OPENING,u)
		return outward(a,lerpf(bounds(a).x,bounds(a).y,v)),rubber,simple)
	G.patch(parent,"HelmetV2Visor",28,10,func(u: float,v: float) -> Vector3:
		var a: float = lerpf(-OPENING+0.036,OPENING-0.036,u)
		var y: float = lerpf(bounds(a).x+0.006,bounds(a).y-0.006,v)
		return point(a,y)-outward(a,y)*0.002,func(u: float,v: float) -> Vector3:
		var a: float = lerpf(-OPENING+0.036,OPENING-0.036,u)
		return outward(a,lerpf(bounds(a).x,bounds(a).y,v)),lens,simple)
	G.patch(parent,"HelmetV2BrowLip",28,4,func(u: float,v: float) -> Vector3:
		var a: float = lerpf(-OPENING,OPENING,u)
		var y: float = bounds(a).y+v*0.010
		return point(a,y)+outward(a,y)*sin(v*PI)*0.003,func(u: float,v: float) -> Vector3:
		var a: float = lerpf(-OPENING,OPENING,u)
		return outward(a,bounds(a).y+v*0.010),shell,simple)
	for side: float in [-1.0,1.0]:
		# The intake follows the shaped chin surface rather than protruding dots.
		G.patch(parent,"HelmetV2ChinIntake"+str(side),12,4,func(u: float,v: float) -> Vector3:
			var a: float = side*lerpf(0.13,0.49,u)
			var y: float = lerpf(0.793,0.805,v)+u*0.004
			return point(a,y)+outward(a,y)*0.001,func(u: float,v: float) -> Vector3:
			return outward(side*lerpf(0.13,0.49,u),lerpf(0.793,0.805,v)),rubber,simple)
		G.patch(parent,"HelmetV2CrownVent"+str(side),8,4,func(u: float,v: float) -> Vector3:
			var a: float = side*lerpf(0.26,0.32,u)
			var y: float = lerpf(1.028,1.058,v)
			return point(a,y)+outward(a,y)*0.001,func(u: float,v: float) -> Vector3:
			return outward(side*lerpf(0.26,0.32,u),lerpf(1.028,1.058,v)),charcoal,simple)
		var a: float = side*(OPENING+0.035)
		var y: float = 0.922
		var pin: Vector3 = point(a,y)+outward(a,y)*0.003
		var hinge := VisualGeometry.cylinder(parent,0.014,0.006,pin,rubber,true)
		hinge.quaternion = Quaternion(Vector3.UP,outward(a,y))
		var bolt := VisualGeometry.cylinder(parent,0.006,0.008,pin+outward(a,y)*0.002,fastener,true)
		bolt.quaternion = hinge.quaternion
	var roll: Array[Vector3] = []
	for i: int in range(49): roll.append(point(i*TAU/48,BASE)+Vector3.DOWN*0.002)
	G.tube(parent,"HelmetV2NeckRoll",roll,0.008,rubber,simple,48)
