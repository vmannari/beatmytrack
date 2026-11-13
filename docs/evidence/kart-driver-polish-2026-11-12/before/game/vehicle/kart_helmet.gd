extends RefCounted
## Original full-face shell, shaped from the owner's helmet silhouette reference.
const G = preload("res://vehicle/kart_geometry.gd")
const BASE: float = 0.765
const CROWN: float = 1.135
const OPENING: float = 1.19

static func crown_profile(y: float) -> Vector3:
	var r: float = sqrt(maxf(0,1-pow((y-0.958)/0.177,2)))
	return Vector3(0.180*r,0.225-0.194*r,0.225+0.188*r)

static func profile(y: float) -> Vector3:
	# Half-width, front and rear. The jaw flows into the round cranium. Shared
	# Hermite tangents keep the cheek and crown free of horizontal shading bands.
	if y >= 0.995: return crown_profile(y)
	var crown_base: Vector3 = crown_profile(0.995)
	var levels: Array[Vector4] = [
		Vector4(BASE,0.116,0.034,0.316),Vector4(0.789,0.138,0.016,0.362),
		Vector4(0.820,0.157,0.014,0.389),Vector4(0.850,0.173,0.020,0.404),
		Vector4(0.890,0.180,0.026,0.413),Vector4(0.925,0.182,0.030,0.417),
		Vector4(0.965,0.180,0.032,0.411),Vector4(0.995,crown_base.x,crown_base.y,crown_base.z)]
	for i: int in range(levels.size()-1):
		if y > levels[i+1].x: continue
		var a: Vector4 = levels[i]
		var b: Vector4 = levels[i+1]
		var p: Vector4 = levels[maxi(0,i-1)]
		var q: Vector4 = levels[mini(levels.size()-1,i+2)]
		var t: float = clampf((y-a.x)/(b.x-a.x),0,1)
		var av := Vector3(a.y,a.z,a.w)
		var bv := Vector3(b.y,b.z,b.w)
		var ma: Vector3 = (bv-Vector3(p.y,p.z,p.w))/(b.x-p.x)
		var mb: Vector3 = (Vector3(q.y,q.z,q.w)-av)/(q.x-a.x)
		if i == levels.size()-2:
			var r: float = sqrt(1-pow((b.x-0.958)/0.177,2))
			var dr: float = -(b.x-0.958)/(0.177*0.177*r)
			mb = Vector3(0.180,-0.194,0.188)*dr
		return av*(2*t*t*t-3*t*t+1)+ma*(b.x-a.x)*(t*t*t-2*t*t+t)+bv*(-2*t*t*t+3*t*t)+mb*(b.x-a.x)*(t*t*t-t*t)
	return Vector3.ZERO

static func base_height(angle: float) -> float:
	return BASE+0.082*smoothstep(0.25,2.65,absf(wrapf(angle,-PI,PI)))

static func point(angle: float, y: float) -> Vector3:
	var shape: Vector3 = profile(y)
	var exponent: float = lerpf(0.88,1,smoothstep(0.93,1.045,y))
	var x: float = shape.x*signf(sin(angle))*pow(absf(sin(angle)),exponent)
	var z: float = (shape.y+shape.z)*0.5-(shape.z-shape.y)*0.5*signf(cos(angle))*pow(absf(cos(angle)),exponent)
	var a: float = absf(wrapf(angle,-PI,PI))
	var cheek: float = 0.007*exp(-pow((y-(0.848+0.023*sin(a)))/0.022,2))*exp(-pow((a-0.90)/0.34,2))
	return Vector3(x-signf(x)*cheek,y,z+cos(angle)*cheek)

static func outward(angle: float, y: float) -> Vector3:
	if y > CROWN-0.001: return Vector3.UP
	return Vector3(sin(angle),(y-0.925)*4,-cos(angle)).normalized()

static func bounds(angle: float) -> Vector2:
	var t: float = clampf(absf(wrapf(angle,-PI,PI))/OPENING,0,1)
	return Vector2(0.867+0.070*pow(t,1.9),1.004-0.014*pow(t,2))

static func shell_angle(u: float) -> float:
	if u < 0.3125: return lerpf(-PI,-OPENING,u/0.3125)
	if u < 0.6875: return lerpf(-OPENING,OPENING,(u-0.3125)/0.375)
	return lerpf(OPENING,PI,(u-0.6875)/0.3125)

static func build(parent: Node3D, simple: bool) -> void:
	var shell := CompactFinish.paint(Color("dedfd8"))
	shell.roughness = 0.43
	shell.clearcoat = 0.10
	var rubber := CompactFinish.rubber(Color("11181c"))
	var lining := CompactFinish.rubber(Color("26343c"))
	var lens := CompactFinish.paint(Color("3d505a"))
	lens.metallic = 0.14
	lens.roughness = 0.20
	lens.clearcoat = 0.18
	var fastener := CompactFinish.alloy(Color("a2aaa8"))
	# One external shell has a real eye aperture and an upswept lower cut.
	G.attach(parent,"HelmetReferenceShell"+("|simple" if simple else "|full"),shell,func() -> ArrayMesh:
		var tool := SurfaceTool.new()
		var around: int = 32 if simple else 64
		tool.append_from(G.surface(around,8 if simple else 16,func(u: float,v: float) -> Vector3:
			var a: float = shell_angle(u)
			return point(a,lerpf(base_height(a),bounds(a).x,v)),func(u: float,v: float) -> Vector3:
			var a: float = shell_angle(u)
			return outward(a,lerpf(base_height(a),bounds(a).x,v))),0,Transform3D.IDENTITY)
		tool.append_from(G.surface(around,12 if simple else 24,func(u: float,v: float) -> Vector3:
			var a: float = shell_angle(u)
			return point(a,lerpf(bounds(a).y,CROWN,v)),func(u: float,v: float) -> Vector3:
			var a: float = shell_angle(u)
			return outward(a,lerpf(bounds(a).y,CROWN,v))),0,Transform3D.IDENTITY)
		for side: float in [-1.0,1.0]:
			tool.append_from(G.surface(10 if simple else 20,4 if simple else 8,func(u: float,v: float) -> Vector3:
				var a: float = side*lerpf(OPENING,PI,u)
				return point(a,lerpf(bounds(a).x,bounds(a).y,v)),func(u: float,v: float) -> Vector3:
				var a: float = side*lerpf(OPENING,PI,u)
				return outward(a,lerpf(bounds(a).x,bounds(a).y,v))),0,Transform3D.IDENTITY)
		return tool.commit())
	for top: bool in [false,true]:
		G.patch(parent,"HelmetReferenceEyeReturn"+str(top),48,4,func(u: float,v: float) -> Vector3:
			var a: float = lerpf(-OPENING,OPENING,u)
			var y: float = bounds(a).y if top else bounds(a).x
			return point(a,y)-outward(a,y)*v*0.012,func(_u: float,_v: float) -> Vector3: return Vector3.DOWN if top else Vector3.UP,rubber,simple)
	G.patch(parent,"HelmetReferenceVisorGasket",48,12,func(u: float,v: float) -> Vector3:
		var a: float = lerpf(-OPENING,OPENING,u)
		var y: float = lerpf(bounds(a).x,bounds(a).y,v)
		return point(a,y)-outward(a,y)*0.004,func(u: float,v: float) -> Vector3:
		var a: float = lerpf(-OPENING,OPENING,u)
		return outward(a,lerpf(bounds(a).x,bounds(a).y,v)),rubber,simple)
	G.patch(parent,"HelmetReferenceVisor",48,12,func(u: float,v: float) -> Vector3:
		var a: float = lerpf(-OPENING+0.030,OPENING-0.030,u)
		var y: float = lerpf(bounds(a).x+0.005,bounds(a).y-0.005,v)
		return point(a,y)+outward(a,y)*0.001,func(u: float,v: float) -> Vector3:
		var a: float = lerpf(-OPENING+0.030,OPENING-0.030,u)
		return outward(a,lerpf(bounds(a).x,bounds(a).y,v)),lens,simple)
	G.patch(parent,"HelmetReferenceBrow",48,4,func(u: float,v: float) -> Vector3:
		var a: float = lerpf(-OPENING,OPENING,u)
		var y: float = bounds(a).y+v*0.009
		return point(a,y)+outward(a,y)*sin(v*PI)*0.002,func(u: float,v: float) -> Vector3:
		var a: float = lerpf(-OPENING,OPENING,u)
		return outward(a,bounds(a).y+v*0.009),shell,simple)
	G.patch(parent,"HelmetReferenceLowerBinding",64,4,func(u: float,v: float) -> Vector3:
		var a: float = u*TAU
		var y: float = base_height(a)
		return point(a,y)-outward(a,y)*v*0.005+Vector3.DOWN*(0.002+v*0.009),func(u: float,_v: float) -> Vector3: return outward(u*TAU,base_height(u*TAU)),rubber,simple)
	G.patch(parent,"HelmetReferenceNeckLining",64,6,func(u: float,v: float) -> Vector3:
		var a: float = u*TAU
		var edge: Vector3 = point(a,base_height(a))-outward(a,base_height(a))*0.005+Vector3.DOWN*0.011
		var neck := Vector3(sin(a)*0.070,0.825,0.255-cos(a)*0.060)
		return edge.lerp(neck,v)+Vector3.UP*sin(v*PI)*0.006,func(_u: float,_v: float) -> Vector3: return Vector3.DOWN,lining,simple)
	G.patch(parent,"HelmetReferenceChinIntake",24,4,func(u: float,v: float) -> Vector3:
		var a: float = lerpf(-0.30,0.30,u)
		var y: float = lerpf(0.805,0.815,v)+absf(a)*0.008
		return point(a,y)+outward(a,y)*0.0015,func(u: float,v: float) -> Vector3:
		return outward(lerpf(-0.30,0.30,u),lerpf(0.805,0.815,v)),rubber,simple)
	for side: float in [-1.0,1.0]:
		G.patch(parent,"HelmetReferenceCrownIntake"+str(side),16,4,func(u: float,v: float) -> Vector3:
			var a: float = side*lerpf(0.30,0.56,u)
			var y: float = 1.065+u*0.025+lerpf(-0.003,0.003,v)*pow(sin(u*PI),0.7)
			return point(a,y)+outward(a,y)*0.0015,func(u: float,v: float) -> Vector3:
			return outward(side*lerpf(0.30,0.56,u),1.065+u*0.025+lerpf(-0.003,0.003,v)*pow(sin(u*PI),0.7)),lining,simple)
		G.patch(parent,"HelmetReferenceRearExtractor"+str(side),20,4,func(u: float,v: float) -> Vector3:
			var a: float = side*lerpf(2.05,2.58,u)
			var y: float = lerpf(1.050,1.057,v)+sin(u*PI)*0.006
			return point(a,y)+outward(a,y)*0.0015,func(u: float,v: float) -> Vector3:
			return outward(side*lerpf(2.05,2.58,u),lerpf(1.050,1.057,v)),lining,simple)
		var carrier: Array[Vector3] = []
		for station: Vector2 in [Vector2(1.35,0.975),Vector2(1.10,0.938),Vector2(1.31,0.925)]:
			var a: float = side*station.x
			carrier.append(point(a,station.y)+outward(a,station.y)*0.003)
		for link: int in range(2):
			var tangent: Vector3 = (carrier[link+1]-carrier[link]).normalized()
			var normal: Vector3 = outward(side*1.23,0.951)
			var across: Vector3 = tangent.cross(normal).normalized()
			var plate: MeshInstance3D = G.rounded(parent,"HelmetReferenceVisorLink",(carrier[link]+carrier[link+1])*0.5,Vector3(0.012,carrier[link].distance_to(carrier[link+1])+0.012,0.004),0.002,rubber,simple)
			plate.basis = Basis(across,tangent,across.cross(tangent).normalized())
		for pivot: Vector3 in [Vector3(1.35,0.975,0.017),Vector3(1.10,0.938,0.012)]:
			var a: float = side*pivot.x
			var normal: Vector3 = outward(a,pivot.y)
			var pin: Vector3 = point(a,pivot.y)+normal*0.005
			var washer := VisualGeometry.cylinder(parent,pivot.z+0.004,0.006,pin,rubber,true)
			washer.quaternion = Quaternion(Vector3.UP,normal)
			var bolt := VisualGeometry.cylinder(parent,pivot.z*0.63,0.008,pin+normal*0.003,fastener,true)
			bolt.quaternion = washer.quaternion
		var rivet_angle: float = side*1.27
		var rivet_normal: Vector3 = outward(rivet_angle,0.873)
		var rivet: MeshInstance3D = G.lathe(parent,"HelmetReferenceCheekVent",[Vector2(0,0.0035),Vector2(0,0.006),Vector2(0.002,0.006),Vector2(0.002,0.0035),Vector2(0,0.0035)],fastener,simple)
		rivet.position = point(rivet_angle,0.873)+rivet_normal*0.001
		rivet.quaternion = Quaternion(Vector3.RIGHT,rivet_normal)
