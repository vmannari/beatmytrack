class_name CompactFrontLamps
extends RefCounted
## Classic clear sealed beams, recessed reflectors and a small central bulb cap.
const OFFSET: float = 0.652
const CENTER: float = 0.798
const RADIUS: float = 0.132
static var meshes: Dictionary = {}

static func point(side: float, radius: float, angle: float, depth: float) -> Vector3:
	var p := Vector2(side*OFFSET+cos(angle)*radius,CENTER+sin(angle)*radius)
	return CompactGrille.point(p,depth)

static func build(car: CarVisual, cooperate: Callable = Callable()) -> void:
	var gasket := CompactFinish.rubber(Color("182327"))
	var chrome := CompactFinish.alloy(Color("b9c4c3"))
	chrome.metallic = 0.90
	chrome.roughness = 0.21
	var bowl := CompactFinish.alloy(Color("aab7b8"))
	bowl.metallic = 0.78
	bowl.roughness = 0.25
	var shade := CompactFinish.alloy(Color("28343a"))
	shade.roughness = 0.43
	var lens := ShaderMaterial.new()
	lens.shader = preload("res://vehicle/compact_headlamp.gdshader")
	var suffix: String = "_simple" if car.simple_model else ""
	var segments: int = 32 if car.simple_model else 40
	for kind: String in ["Gaskets","Bezels","Reflectors","OpticalShades","Lenses"]:
		var key: String = "FrontLamp"+kind+suffix
		if not meshes.has(key):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			for side: float in [-1.0,1.0]:
				var complete: bool = true
				match kind:
					"Gaskets":
						complete = await _revolve(tool,side,[Vector2(0.119,-0.027),Vector2(RADIUS,-0.010),Vector2(RADIUS,0.003)],segments,true,false,cooperate)
					"Bezels":
						complete = await _revolve(tool,side,[Vector2(0.119,-0.039),Vector2(0.128,-0.029),Vector2(0.121,-0.024)],segments,true,true,cooperate)
					"Reflectors":
						complete = await _revolve(tool,side,[Vector2(0,0.004),Vector2(0.084,-0.018),Vector2(0.119,-0.036)],segments,false,true,cooperate)
						# Only the visible bulb cap; the opaque dish closes the back.
						if complete: complete = await _revolve(tool,side,[Vector2(0,-0.045),Vector2(0.012,-0.042),Vector2(0.018,-0.036)],segments/2,false,true,cooperate)
					"OpticalShades":
						# A round stamped shade retains the original central dark ring.
						# Its hidden return is unnecessary in front of the closed dish.
						complete = await _revolve(tool,side,[Vector2(0.019,-0.038),Vector2(0.028,-0.034)],segments/2,false,true,cooperate)
					"Lenses":
						complete = await _revolve(tool,side,[Vector2(0,-0.054),Vector2(0.084,-0.047),Vector2(0.117,-0.037)],segments,false,true,cooperate)
				if not complete: return
			tool.index()
			tool.generate_tangents()
			meshes[key] = tool.commit()
			meshes[key].set_meta("car_authored_far",true)
		var part := MeshInstance3D.new()
		part.name = "FrontLamp"+kind
		part.mesh = meshes[key]
		part.material_override = {"Gaskets":gasket,"Bezels":chrome,"Reflectors":bowl,"OpticalShades":shade,"Lenses":lens}[kind]
		if kind=="Lenses": part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		car.body.add_child(part)

static func _revolve(tool: SurfaceTool, side: float, profile: Array[Vector2], segments: int, closed: bool, smooth: bool = false, cooperate: Callable = Callable()) -> bool:
	for row: int in range(profile.size() if closed else profile.size()-1):
		var p: Vector2 = profile[row]
		var q: Vector2 = profile[(row+1)%profile.size()]
		for segment: int in range(segments):
			if not cooperate.is_null() and (not cooperate.is_valid() or not await cooperate.call()): return false
			var a: float = segment*TAU/segments
			var b: float = (segment+1)*TAU/segments
			var corners: Array[Vector3] = [point(side,p.x,a,p.y),point(side,p.x,b,p.y),point(side,q.x,b,q.y),point(side,q.x,a,q.y)]
			var normals: Array[Vector3] = []
			for corner: int in range(4):
				var angle: float = a if corner in [0,3] else b
				var slope: Vector2 = q-p
				var station: int = row if corner in [0,1] else (row+1)%profile.size()
				if smooth:
					var before: Vector2 = profile[posmod(station-1,profile.size())] if closed else profile[maxi(0,station-1)]
					var after: Vector2 = profile[(station+1)%profile.size()] if closed else profile[mini(profile.size()-1,station+1)]
					slope = after-before
				var n := Vector3(slope.y*cos(angle),slope.y*sin(angle),-slope.x).normalized()
				if not closed and profile[station].x==0: n = Vector3.FORWARD
				var at: Vector3 = corners[corner]
				var dx: float = (CompactCoachwork.front_skin(at.x+0.0001,at.y)-CompactCoachwork.front_skin(at.x-0.0001,at.y))/0.0002
				var dy: float = (CompactCoachwork.front_skin(at.x,at.y+0.0001)-CompactCoachwork.front_skin(at.x,at.y-0.0001))/0.0002
				n = Vector3(n.x-n.z*dx,n.y-n.z*dy,n.z).normalized()
				normals.append(n)
			for triangle: Array in [[0,1,2],[0,2,3]]:
				var face: Vector3 = (corners[triangle[1]]-corners[triangle[0]]).cross(corners[triangle[2]]-corners[triangle[0]])
				if face.length_squared()<1e-18: continue
				var order: Array = triangle.duplicate()
				if face.dot(normals[triangle[0]]+normals[triangle[1]]+normals[triangle[2]])>0: order.reverse()
				for index: int in order:
					tool.set_normal(normals[index])
					tool.set_uv(Vector2((corners[index].x-side*OFFSET)/0.234+0.5,(corners[index].y-CENTER)/0.234+0.5))
					tool.add_vertex(corners[index])
	return true
