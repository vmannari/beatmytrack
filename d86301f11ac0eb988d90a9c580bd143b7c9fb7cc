extends RefCounted
## Original moulded kart panels: broad planes, shoulder breaks and small edge rolls.
const G = preload("res://vehicle/kart_geometry.gd")

static func _station(profile: Array[Vector4], v: float) -> Vector4:
	var at: float = clampf(v,0,1)*(profile.size()-1)
	var row: int = mini(int(at),profile.size()-2)
	return profile[row].lerp(profile[row+1],at-row)

static func _point(station: Vector4, section: Vector2, vertical: bool) -> Vector3:
	return Vector3(section.x*station.y,station.x,station.z+section.y*station.w) if vertical else Vector3(section.x*station.y,station.z+section.y*station.w,station.x)

static func formed(parent: Node3D, label: String, profile: Array[Vector4], material: Material, simple: bool, vertical: bool = false) -> MeshInstance3D:
	return G.attach(parent,label+"|formed-v1|"+str(profile)+"|"+str(vertical)+("|simple" if simple else "|full"),material,func() -> ArrayMesh:
		# Eight design planes with short quadratic fillets; no swollen elliptical crown.
		var corners: Array[Vector2] = [Vector2(0.70,1),Vector2(0.94,0.72),Vector2(1,-0.28),Vector2(0.80,-0.86),Vector2(-0.80,-0.86),Vector2(-1,-0.28),Vector2(-0.94,0.72),Vector2(-0.70,1)]
		var ring: Array[Vector2] = []
		for index: int in range(corners.size()):
			var corner: Vector2 = corners[index]
			var a: Vector2 = corner.lerp(corners[posmod(index-1,corners.size())],0.12)
			var b: Vector2 = corner.lerp(corners[(index+1)%corners.size()],0.12)
			for step: int in range(2 if simple else 3):
				var t: float = float(step)/(1 if simple else 2)
				ring.append(a.lerp(corner,t).lerp(corner.lerp(b,t),t))
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side: int in range(ring.size()):
			var a: Vector2 = ring[side]
			var b: Vector2 = ring[(side+1)%ring.size()]
			var middle: Vector2 = (a+b)*0.5
			var mesh: ArrayMesh = G.surface(1,profile.size()-1,func(u: float,v: float) -> Vector3:
				return _point(_station(profile,v),a.lerp(b,u),vertical),func(_u: float,_v: float) -> Vector3:
				return Vector3(middle.x,0,middle.y) if vertical else Vector3(middle.x,middle.y,0))
			tool.append_from(mesh,0,Transform3D.IDENTITY)
		for end: float in [0.0,1.0]:
			var station: Vector4 = profile[0] if end==0 else profile[-1]
			var center: Vector3 = _point(station,Vector2.ZERO,vertical)
			var cap: ArrayMesh = G.surface(ring.size(),1,func(u: float,v: float) -> Vector3:
				var at: float = u*ring.size()
				var i: int = mini(int(at),ring.size()-1)
				return center.lerp(_point(station,ring[i].lerp(ring[(i+1)%ring.size()],at-i),vertical),v),func(_u: float,_v: float) -> Vector3:
				return Vector3(0,-1 if end==0 else 1,0) if vertical else Vector3(0,0,-1 if end==0 else 1))
			tool.append_from(cap,0,Transform3D.IDENTITY)
		return tool.commit())
