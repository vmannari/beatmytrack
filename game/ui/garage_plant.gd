class_name GaragePlant
extends RefCounted
## Original code-authored rubber fig. Immutable meshes join the prepared room batches.
const LEAF_ROWS: int = 14
const LEAF_COLUMNS: int = 6
static var meshes: Array[ArrayMesh] = []
static var finishes: Array[Material] = []

static func build(root: Node3D) -> void:
	if meshes.is_empty(): _prepare()
	var plant := Node3D.new()
	plant.name = "GarageDisplayPlant"
	plant.position = Vector3(-9.55,0,-2.1)
	root.add_child(plant)
	for index: int in range(meshes.size()):
		var part := MeshInstance3D.new()
		part.name = ["SculptedCeramicPlanter","RecessedPottingSoil","SoilBarkAndMinerals","BranchingFigStems","SculptedFigLeaves"][index]
		part.mesh = meshes[index]
		part.material_override = finishes[index]
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		plant.add_child(part)
	ShowroomStudio._contact(plant,Vector3(0,0.002,0),Vector2(0.85,0.85),0.44)

static func _tool() -> SurfaceTool:
	var result := SurfaceTool.new()
	result.begin(Mesh.PRIMITIVE_TRIANGLES)
	return result

static func _prepare() -> void:
	var ceramic := _tool()
	# Closed turned profile: recessed foot, gently bellied shell, rolled lip and inner wall.
	var profile: Array[Vector2] = [Vector2(0,0.012),Vector2(0.216,0.012),Vector2(0.222,0.020),Vector2(0.222,0.045),Vector2(0.236,0.052),Vector2(0.242,0.065),Vector2(0.254,0.13),Vector2(0.272,0.29),Vector2(0.293,0.51),Vector2(0.295,0.569),Vector2(0.291,0.587),Vector2(0.282,0.598),Vector2(0.268,0.598),Vector2(0.258,0.589),Vector2(0.257,0.575),Vector2(0.256,0.53),Vector2(0.230,0.14),Vector2(0.210,0.09),Vector2(0,0.09)]
	_lathe(ceramic,profile)
	var soil := _tool()
	_lathe(soil,[Vector2(0,0.511),Vector2(0.250,0.511),Vector2(0.252,0.536),Vector2(0,0.542)])
	var dressing := _tool()
	# Seated, irregular bark/mineral chips; no floating decorative spheres.
	for index: int in range(45):
		var angle: float = index*2.399963
		var radius: float = 0.226*sqrt((index+0.5)/45.0)
		var centre := Vector3(sin(angle)*radius,0.540-radius*0.024,cos(angle)*radius)
		_chip(dressing,centre,0.008+0.009*_variation(index,2),angle,1.12 if index%7 == 0 else 0.24+0.38*_variation(index,3))
	var wood := _tool()
	var leaves := _tool()
	# Three unequal, gently bent leaders rooted inside the soil. Leaves emerge at nodes.
	for branch: int in range(3):
		var points: Array[Vector3] = []
		for row: int in range(19): points.append(_branch(branch,row/18.0))
		var bark_shade: float = 0.75+branch*0.10
		_tube(wood,points,0.018-branch*0.003,0.0035,Color(bark_shade,bark_shade,bark_shade))
		var count: int = [10,8,7][branch]
		for index: int in range(count):
			var t: float = 0.23+0.73*index/float(count-1)
			var angle: float = 0.75+index*2.399963+branch*1.82
			var direction := Vector3(sin(angle),0,cos(angle))
			var origin: Vector3 = _branch(branch,t)
			var petiole_length: float = 0.075+0.035*_variation(index,branch)
			var base: Vector3 = origin+direction*petiole_length+Vector3.UP*0.038
			_tube(wood,[origin,origin.lerp(base,0.5)+Vector3.UP*0.008,base],0.0045,0.0028,Color(0.95,0.95,0.95))
			var length: float = (0.32+0.11*_variation(index+branch*11,4))*(1.0-0.25*t)
			var width: float = length*(0.29+0.045*_variation(index,5))
			_leaf(leaves,base,direction,length,width,-0.055+0.16*_variation(index,branch+6),index+branch*11)
		# A narrow unfolding terminal leaf covers each growing tip.
		var tip_direction := Vector3(sin(branch*2.1),0,cos(branch*2.1))
		_leaf(leaves,_branch(branch,1.0),tip_direction,0.075,0.018,0.12,70+branch)
	for tool: SurfaceTool in [ceramic,soil,dressing,wood,leaves]:
		tool.index()
		meshes.append(tool.commit())
	var leaf := ShaderMaterial.new()
	leaf.shader = preload("res://ui/garage_plant_leaf.gdshader")
	var bark: StandardMaterial3D = GarageEnvironment.surface("figbark","646346",0,0.85)
	bark.vertex_color_use_as_albedo = true
	var chips: StandardMaterial3D = GarageEnvironment.surface("figchips","76634a",0,0.96)
	chips.vertex_color_use_as_albedo = true
	var pot := ShaderMaterial.new()
	pot.shader = preload("res://ui/garage_plant_ceramic.gdshader")
	finishes = [pot,GarageMaterials.finish("figsoil","282219",0,0.98,3),chips,bark,leaf]

static func _variation(index: int, salt: int) -> float:
	return fposmod(sin(index*73.17+salt*39.71)*4375.57,1.0)

static func _branch(branch: int, t: float) -> Vector3:
	var direction: Vector3 = [Vector3(0.13,0,-0.04),Vector3(-0.20,0,0.13),Vector3(0.12,0,0.23)][branch]
	var height: float = [1.48,1.12,0.91][branch]
	return direction*(t*t)+Vector3(0.025*sin(t*4.0+branch)*t,0.532+height*t,0)

static func _leaf_point(base: Vector3, direction: Vector3, length: float, width: float, rise: float, seed: int, t: float, s: float) -> Vector3:
	var across := Vector3(direction.z,0,-direction.x)
	# Oval lamina, narrow petiole seat, pointed drip tip, camber and asymmetric twist.
	var outline: float = pow(maxf(sin(PI*t),0),0.72)*(0.80+0.20*t)
	var centre: Vector3 = base+direction*(length*t)+Vector3.UP*(rise*t+0.055*sin(PI*t)-0.035*t*t)
	var roll: float = (0.024*sin(seed*1.71)+0.022*t)*s*outline
	return centre+across*(width*s*outline*(1.0+0.055*s*sin(seed+4*t)))+Vector3.UP*(-0.042*s*s*outline+roll)

static func _leaf(tool: SurfaceTool, base: Vector3, direction: Vector3, length: float, width: float, rise: float, seed: int) -> void:
	var top: Array[Vector3] = []
	var normals: Array[Vector3] = []
	for row: int in range(LEAF_ROWS+1):
		var t: float = row/float(LEAF_ROWS)
		for column: int in range(LEAF_COLUMNS+1):
			var s: float = column*2.0/LEAF_COLUMNS-1.0
			var point: Vector3 = _leaf_point(base,direction,length,width,rise,seed,t,s)
			var along: Vector3 = _leaf_point(base,direction,length,width,rise,seed,minf(t+0.001,0.9999),s)-_leaf_point(base,direction,length,width,rise,seed,maxf(t-0.001,0.0001),s)
			var across: Vector3 = _leaf_point(base,direction,length,width,rise,seed,clampf(t,0.001,0.999),s+0.001)-_leaf_point(base,direction,length,width,rise,seed,clampf(t,0.001,0.999),s-0.001)
			top.append(point)
			normals.append(along.cross(across).normalized())
	var shade: float = 0.82+0.27*_variation(seed,9)
	for side: int in [1,-1]:
		for row: int in range(LEAF_ROWS):
			for column: int in range(LEAF_COLUMNS):
				var a: int = row*(LEAF_COLUMNS+1)+column
				var b: int = a+LEAF_COLUMNS+1
				var order: Array = [a,b+1,b,a,a+1,b+1] if side == 1 else [a,b,b+1,a,b+1,a+1]
				for triangle: int in range(2):
					# The lamina closes to one point at both ends; omit collapsed pole faces.
					if (row == 0 and triangle == 1) or (row == LEAF_ROWS-1 and triangle == 0): continue
					for corner: int in range(3):
						var index: int = order[triangle*3+corner]
						tool.set_normal(normals[index]*side)
						tool.set_uv(Vector2((index%(LEAF_COLUMNS+1))/float(LEAF_COLUMNS),floorf(index/float(LEAF_COLUMNS+1))/LEAF_ROWS))
						tool.set_color(Color(shade,1.0 if side == 1 else 0.0,_variation(seed,8),1))
						tool.add_vertex(_leaf_skin(top,normals,index,side))
	# Join both sides at the real leaf edge, including its pointed ends.
	var boundary: Array[int] = []
	for row: int in range(LEAF_ROWS+1): boundary.append(row*(LEAF_COLUMNS+1))
	for row: int in range(LEAF_ROWS,-1,-1): boundary.append(row*(LEAF_COLUMNS+1)+LEAF_COLUMNS)
	for edge: int in range(boundary.size()):
		var a: int = boundary[edge]
		var b: int = boundary[(edge+1)%boundary.size()]
		_quad(tool,[_leaf_skin(top,normals,a,1),_leaf_skin(top,normals,b,1),_leaf_skin(top,normals,b,-1),_leaf_skin(top,normals,a,-1)],(top[b]-top[a]).cross(normals[a]).normalized(),Color(shade,0.5,0.5))

static func _leaf_skin(points: Array[Vector3], normals: Array[Vector3], index: int, side: int) -> Vector3:
	var t: float = floorf(index/float(LEAF_COLUMNS+1))/LEAF_ROWS
	var thickness: float = 0.0007*maxf(sin(PI*t),0.0)
	return points[index]+normals[index]*thickness*side

static func _lathe(tool: SurfaceTool, profile: Array[Vector2]) -> void:
	const SIDES: int = 64
	for row: int in range(profile.size()-1):
		for segment: int in range(SIDES):
			var points: Array[Vector3] = []
			var ns: Array[Vector3] = []
			for corner: int in range(4):
				var ring: int = row if corner < 2 else row+1
				var angle: float = (segment+(1 if corner in [1,2] else 0))*TAU/SIDES
				var p: Vector2 = profile[ring]
				var tangent: Vector2 = profile[mini(ring+1,profile.size()-1)]-profile[maxi(ring-1,0)]
				points.append(Vector3(sin(angle)*p.x,p.y,cos(angle)*p.x))
				ns.append(Vector3(sin(angle)*tangent.y,-tangent.x,cos(angle)*tangent.y).normalized())
			for order: Array in [[0,2,1],[0,3,2]]:
				if (points[order[1]]-points[order[0]]).cross(points[order[2]]-points[order[0]]).length_squared()<1e-19: continue
				for index: int in order:
					tool.set_normal(ns[index])
					tool.set_uv(Vector2(points[index].x,points[index].z))
					tool.set_color(Color.WHITE)
					tool.add_vertex(points[index])

static func _tube(tool: SurfaceTool, points: Array[Vector3], start_radius: float, end_radius: float, color: Color) -> void:
	for row: int in range(points.size()-1):
		var direction: Vector3 = (points[row+1]-points[row]).normalized()
		var across: Vector3 = direction.cross(Vector3.RIGHT).normalized()
		var other: Vector3 = direction.cross(across).normalized()
		for segment: int in range(8):
			var normal_a: Vector3 = across*cos(segment*TAU/8)+other*sin(segment*TAU/8)
			var normal_b: Vector3 = across*cos((segment+1)*TAU/8)+other*sin((segment+1)*TAU/8)
			var ra: float = lerpf(start_radius,end_radius,row/float(points.size()-1))
			var rb: float = lerpf(start_radius,end_radius,(row+1)/float(points.size()-1))
			_quad(tool,[points[row]+normal_a*ra,points[row]+normal_b*ra,points[row+1]+normal_b*rb,points[row+1]+normal_a*rb],(normal_a+normal_b).normalized(),color)
			if row == points.size()-2:
				_quad(tool,[points[row+1],points[row+1]+normal_a*rb,points[row+1]+normal_b*rb],direction,color)

static func _chip(tool: SurfaceTool, at: Vector3, size: float, angle: float, shade: float) -> void:
	var points: Array[Vector3] = []
	for index: int in range(5):
		var a: float = angle+index*TAU/5
		points.append(at+Vector3(sin(a)*size,0,cos(a)*size*0.65))
	for index: int in range(5):
		var peak: Vector3 = at+Vector3.UP*size*0.5
		var normal: Vector3 = (points[(index+1)%5]-peak).cross(points[index]-peak).normalized()
		_quad(tool,[peak,points[index],points[(index+1)%5]],normal,Color(shade,shade,shade))

static func _quad(tool: SurfaceTool, points: Array[Vector3], normal: Vector3, color: Color) -> void:
	var reverse: bool = (points[1]-points[0]).cross(points[2]-points[0]).dot(normal)>0
	for triangle: int in range(1,points.size()-1):
		if (points[triangle]-points[0]).cross(points[triangle+1]-points[0]).length_squared()<1e-19: continue
		for index: int in ([0,triangle+1,triangle] if reverse else [0,triangle,triangle+1]):
			tool.set_normal(normal)
			tool.set_uv(Vector2.ZERO)
			tool.set_color(color)
			tool.add_vertex(points[index])
