extends RefCounted
## Restrained formed decks and earth rises, sampled from the drivable profile.
static func build(tool: SurfaceTool, object: Dictionary) -> void:
	var profile: String = JumpProfiles.id(object)
	var half: Vector2 = CreatorObjects.size_of(object)*0.5
	var scale_value: float = float(object.get("scale",1.0))
	var earth: bool = JumpProfiles.rounded(profile)
	var sand: bool = profile == "dune_v1"
	var color := Color("bc965c") if sand else Color("89734f") if earth else Color("626a69")
	# No scaffold, upright rails or oversized arrow. Broad smooth shoulders
	# meet the road at both ends of bumps and along their transverse edges.
	var rows: int = 40
	var columns: int = 20 if earth else 1
	for row: int in range(rows):
		for column: int in range(columns):
			var x0: float = lerpf(-half.x,half.x,float(row)/rows)
			var x1: float = lerpf(-half.x,half.x,float(row+1)/rows)
			var z0: float = lerpf(-half.y,half.y,float(column)/columns)
			var z1: float = lerpf(-half.y,half.y,float(column+1)/columns)
			var a: Vector3 = _point(object,x0,z0)
			var b: Vector3 = _point(object,x1,z0)
			var c: Vector3 = _point(object,x1,z1)
			var d: Vector3 = _point(object,x0,z1)
			_quad(tool,a,b,c,d,color)
		if earth: continue
		for side: float in [-1.0,1.0]:
			var x0: float = lerpf(-half.x,half.x,float(row)/rows)
			var x1: float = lerpf(-half.x,half.x,float(row+1)/rows)
			_quad(tool,Vector3(x0,0.04,side*half.y),_point(object,x0,side*half.y),_point(object,x1,side*half.y),Vector3(x1,0.04,side*half.y),color.darkened(0.14))
	if earth: return
	_quad(tool,_point(object,half.x,-half.y),Vector3(half.x,0.04,-half.y),Vector3(half.x,0.04,half.y),_point(object,half.x,half.y),color.darkened(0.18))
	# Narrow edge paint and three fitted deck seams give direction at race scale.
	for side: float in [-1.0,1.0]:
		for row: int in range(rows):
			var x0: float = lerpf(-half.x,half.x,float(row)/rows)
			var x1: float = lerpf(-half.x,half.x,float(row+1)/rows)
			var z: float = side*(half.y-0.12*scale_value)
			_quad(tool,_point(object,x0,z-0.025*scale_value,0.003),_point(object,x1,z-0.025*scale_value,0.003),_point(object,x1,z+0.025*scale_value,0.003),_point(object,x0,z+0.025*scale_value,0.003),Color("b7b29a"))
	for u: float in [0.3,0.6,0.85]:
		var x: float = lerpf(-half.x,half.x,u)
		_quad(tool,_point(object,x-0.008*scale_value,-half.y,0.002),_point(object,x+0.008*scale_value,-half.y,0.002),_point(object,x+0.008*scale_value,half.y,0.002),_point(object,x-0.008*scale_value,half.y,0.002),color.darkened(0.15))

static func _point(object: Dictionary, x: float, z: float, offset: float = 0.0) -> Vector3:
	return Vector3(x,0.04+JumpProfiles.height(object,Vector2(x,z))+offset,z)

static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	# Clockwise front faces keep the exposed deck normals pointing upward.
	for vertex: Vector3 in [a,b,c,a,c,d]:
		tool.set_color(Color(color.r,color.g,color.b,smoothstep(0.001,0.035,vertex.y-0.04)))
		tool.add_vertex(vertex)
