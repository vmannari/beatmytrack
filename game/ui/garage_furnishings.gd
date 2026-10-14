class_name GarageFurnishings
extends RefCounted
## Original fabricated workshop props. Prepared into the Garage material batches.
static var meshes: Dictionary = {}
static var timber: ShaderMaterial

static func metal() -> Material: return GarageMaterials.finish("workshopalloy","9da7ac",0.72,0.38,1)
static func steel() -> Material: return GarageMaterials.finish("workshopsteel","34434b",0.48,0.54,2)
static func rubber() -> Material: return GarageMaterials.finish("workshoprubber","172025",0.0,0.86,5)
static func paint() -> Material: return GarageMaterials.finish("workshopred","874a3f",0.18,0.45,2)
static func wood() -> Material:
	if timber == null:
		timber = ShaderMaterial.new()
		timber.shader = preload("res://ui/garage_timber.gdshader")
	return timber

static func box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	return GarageEnvironment.box(parent,at,size,material)

static func mesh(parent: Node3D, at: Vector3, shape: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = material
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func tube(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material, sides: int = 20) -> MeshInstance3D:
	var length: float = a.distance_to(b)
	var key := Vector3(radius,length,sides)
	if not meshes.has(key):
		var shape := CylinderMesh.new()
		shape.top_radius = radius
		shape.bottom_radius = radius
		shape.height = length
		shape.radial_segments = sides
		meshes[key] = shape
	var node: MeshInstance3D = mesh(parent,(a+b)*0.5,meshes[key],material)
	node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	return node

static func ring(parent: Node3D, at: Vector3, inner: float, outer: float, material: Material) -> MeshInstance3D:
	var key := Vector2(inner,outer)
	if not meshes.has(key):
		var shape := TorusMesh.new()
		shape.inner_radius = inner
		shape.outer_radius = outer
		shape.rings = 32
		shape.ring_segments = 8
		meshes[key] = shape
	var node: MeshInstance3D = mesh(parent,at,meshes[key],material)
	node.rotation.x = PI*0.5
	return node

static func lathe(parent: Node3D, at: Vector3, profile: Array[Vector2], material: Material) -> MeshInstance3D:
	var key: PackedByteArray = var_to_bytes(profile)
	if not meshes.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row: int in range(profile.size()-1):
			var ta: Vector2 = profile[mini(row+1,profile.size()-1)]-profile[maxi(0,row-1)]
			var tb: Vector2 = profile[mini(row+2,profile.size()-1)]-profile[row]
			var na: Vector2 = Vector2(ta.y,-ta.x).normalized()
			var nb: Vector2 = Vector2(tb.y,-tb.x).normalized()
			for segment: int in range(48):
				var a: float = segment*TAU/48.0
				var b: float = (segment+1)*TAU/48.0
				var points: Array[Vector3] = [Vector3(sin(a)*profile[row].x,profile[row].y,cos(a)*profile[row].x),Vector3(sin(b)*profile[row].x,profile[row].y,cos(b)*profile[row].x),Vector3(sin(b)*profile[row+1].x,profile[row+1].y,cos(b)*profile[row+1].x),Vector3(sin(a)*profile[row+1].x,profile[row+1].y,cos(a)*profile[row+1].x)]
				var normals: Array[Vector3] = [Vector3(sin(a)*na.x,na.y,cos(a)*na.x),Vector3(sin(b)*na.x,na.y,cos(b)*na.x),Vector3(sin(b)*nb.x,nb.y,cos(b)*nb.x),Vector3(sin(a)*nb.x,nb.y,cos(a)*nb.x)]
				var direction: Vector3 = (points[1]-points[0]).cross(points[2]-points[0])
				if direction.length_squared() < 0.000000001: direction = (points[2]-points[0]).cross(points[3]-points[0])
				var order: PackedInt32Array = PackedInt32Array([0,2,1,0,3,2]) if direction.dot(normals[2]) > 0 else PackedInt32Array([0,1,2,0,2,3])
				for index: int in order:
					tool.set_normal(normals[index])
					tool.set_uv(Vector2(points[index].x,points[index].y))
					tool.add_vertex(points[index])
		tool.index()
		meshes[key] = tool.commit()
	return mesh(parent,at,meshes[key],material)

static func forged_face(parent: Node3D, at: Vector3, outline: PackedVector2Array, depth: float, material: Material) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	for side: int in [-1,1]:
		for index: int in range(0,triangles.size(),3):
			var points: Array[Vector3] = []
			for corner: int in range(3):
				var point: Vector2 = outline[triangles[index+corner]]
				points.append(Vector3(point.x,point.y,side*depth*0.5))
			GarageEnvironment._polygon(tool,points,Vector3(0,0,side))
	for index: int in range(outline.size()):
		var a: Vector2 = outline[index]
		var b: Vector2 = outline[(index+1)%outline.size()]
		var normal := Vector3(b.y-a.y,a.x-b.x,0).normalized()
		GarageEnvironment._polygon(tool,[Vector3(a.x,a.y,-depth*0.5),Vector3(b.x,b.y,-depth*0.5),Vector3(b.x,b.y,depth*0.5),Vector3(a.x,a.y,depth*0.5)],normal)
	tool.index()
	return mesh(parent,at,tool.commit(),material)

static func bolt(parent: Node3D, at: Vector3, radius: float = 0.018) -> void:
	tube(parent,at-Vector3(0,0,0.005),at+Vector3(0,0,0.005),radius,metal(),6)
	box(parent,at-Vector3(0,0,0.006),Vector3(radius*0.8,0.004,0.006),rubber())

static func handle(parent: Node3D, a: Vector3, b: Vector3, depth: float = 0.045, radius: float = 0.014) -> void:
	var front_a: Vector3 = a-Vector3(0,0,depth)
	var front_b: Vector3 = b-Vector3(0,0,depth)
	tube(parent,a,front_a,radius,metal())
	tube(parent,b,front_b,radius,metal())
	tube(parent,front_a,front_b,radius,metal())

static func case_model(parent: Node3D, at: Vector3) -> void:
	var case_root := Node3D.new()
	case_root.name = "WorkshopStorageCase"
	case_root.position = at
	parent.add_child(case_root,true)
	var polymer: Material = GarageMaterials.finish("casepolymer","29363e",0.04,0.65,2)
	box(case_root,Vector3(0,-0.035,0),Vector3(0.53,0.19,0.36),polymer)
	box(case_root,Vector3(0,0.079,0),Vector3(0.545,0.017,0.375),rubber())
	box(case_root,Vector3(0,0.109,0),Vector3(0.53,0.045,0.36),polymer)
	# Moulded protective corners and reinforcing ribs, inset lid panel.
	for x: float in [-0.247,0.247]:
		for z: float in [-0.164,0.164]: box(case_root,Vector3(x,-0.02,z),Vector3(0.05,0.20,0.046),rubber())
	for x: float in [-0.16,-0.08,0.0,0.08,0.16]:
		box(case_root,Vector3(x,-0.045,-0.182),Vector3(0.014,0.12,0.012),polymer)
		box(case_root,Vector3(x,0.134,0.035),Vector3(0.012,0.015,0.20),polymer)
	box(case_root,Vector3(0,0.14,-0.105),Vector3(0.25,0.008,0.065),rubber())
	for x: float in [-0.19,0.19]:
		box(case_root,Vector3(x,0.069,-0.195),Vector3(0.036,0.077,0.016),metal())
		bolt(case_root,Vector3(x,0.048,-0.209),0.009)
		tube(case_root,Vector3(x-0.024,0.102,0.184),Vector3(x+0.024,0.102,0.184),0.012,metal())
	# Open carry handle stays within the previously cleared 0.22m envelope.
	for x: float in [-0.085,0.085]: box(case_root,Vector3(x,0.171,0),Vector3(0.026,0.073,0.026),rubber())
	box(case_root,Vector3(0,0.201,0),Vector3(0.194,0.027,0.031),rubber())
	box(case_root,Vector3(0,-0.059,-0.193),Vector3(0.17,0.040,0.004),metal())
	for index: int in range(3): box(case_root,Vector3(-0.055+index*0.042,-0.059,-0.197),Vector3(0.021,0.008,0.003),rubber())

static func bottle(parent: Node3D, at: Vector3, height: float) -> void:
	var plastic: Material = GarageEnvironment.surface("servicebottle","a08a47",0.03,0.62)
	var profile: Array[Vector2] = [Vector2(0,0),Vector2(0.075,0),Vector2(0.085,0.02),Vector2(0.085,height*0.65),Vector2(0.082,height*0.72),Vector2(0.046,height*0.85),Vector2(0.040,height*0.87),Vector2(0.040,height*0.97),Vector2(0,height*0.97)]
	lathe(parent,at,profile,plastic)
	lathe(parent,at+Vector3(0,height*0.89,0),[Vector2(0,0),Vector2(0.045,0),Vector2(0.045,height*0.10),Vector2(0,height*0.10)],rubber())
	for index: int in range(12):
		var angle: float = index*TAU/12.0
		box(parent,at+Vector3(sin(angle)*0.045,height*0.94,cos(angle)*0.045),Vector3(0.006,height*0.07,0.006),rubber())
	box(parent,at+Vector3(0,height*0.42,-0.085),Vector3(0.105,height*0.36,0.008),GarageEnvironment.surface("servicelabel","c6c7b9",0,0.85))
	box(parent,at+Vector3(0,height*0.50,-0.091),Vector3(0.085,height*0.045,0.006),steel())
	box(parent,at+Vector3(0,height*0.36,-0.091),Vector3(0.066,height*0.045,0.006),steel())

static func shelves(root: Node3D) -> void:
	var support: Material = steel()
	for x: float in [-8.5,-5.3]:
		box(root,Vector3(x,3.28,8.12),Vector3(0.10,2.72,0.08),support)
		for index: int in range(18): box(root,Vector3(x,2.08+index*0.14,8.075),Vector3(0.036,0.037,0.008),rubber())
		for y: float in [2.08,4.47]: bolt(root,Vector3(x,y,8.066),0.020)
	for y: float in [2.45,3.20,3.95]:
		box(root,Vector3(-6.9,y,7.77),Vector3(3.8,0.085,0.72),wood())
		box(root,Vector3(-6.9,y+0.032,7.40),Vector3(3.80,0.037,0.025),support)
		for x: float in [-8.5,-5.3]:
			box(root,Vector3(x,y-0.06,7.83),Vector3(0.10,0.07,0.60),support)
			GarageWorkshop._beam(root,Vector3(x,y-0.31,8.08),Vector3(x,y-0.085,7.51),0.035,support)
			bolt(root,Vector3(x,y-0.15,8.065),0.018)
	# Deliberately different stock and spacing on each shelf.
	bottle(root,Vector3(-8.18,2.493,7.66),0.35)
	bottle(root,Vector3(-7.78,2.493,7.72),0.29)
	_service_can(root,Vector3(-6.88,2.493,7.74))
	_tin(root,Vector3(-5.93,2.493,7.73),0.14,0.34)
	_tin(root,Vector3(-5.47,2.493,7.66),0.105,0.25)
	case_model(root,Vector3(-8.10,3.372,7.73))
	_storage_bin(root,Vector3(-7.14,3.243,7.78))
	_brake_package(root,Vector3(-5.81,3.243,7.77))
	_tool_bag(root,Vector3(-7.98,3.993,7.77))
	box(root,Vector3(-7.14,4.12,7.77),Vector3(0.60,0.25,0.45),GarageMaterials.finish("carton","8e7756",0,0.86,4))
	box(root,Vector3(-7.14,4.248,7.77),Vector3(0.12,0.008,0.45),GarageEnvironment.surface("packingtape","ae976b"))
	for index: int in range(2): _tin(root,Vector3(-6.22+index*0.37,3.993,7.72),0.10,0.29+index*0.07)

static func drawer(parent: Node3D, at: Vector3, width: float, height: float, material: Material) -> void:
	box(parent,at,Vector3(width,height,0.055),material)
	box(parent,at-Vector3(0,0,0.031),Vector3(width-0.065,height-0.045,0.016),material)
	box(parent,at+Vector3(0,height*0.33,-0.045),Vector3(width*0.62,0.048,0.024),rubber())
	handle(parent,at+Vector3(-width*0.27,height*0.34,-0.049),at+Vector3(width*0.27,height*0.34,-0.049),0.025,0.014)
	for x: float in [-width*0.37,width*0.37]: bolt(parent,at+Vector3(x,height*0.34,-0.044),0.010)
	box(parent,at+Vector3(width*0.33,-height*0.18,-0.051),Vector3(width*0.14,0.032,0.008),metal())

static func _stock(parent: Node3D, at: Vector3, name: String) -> Node3D:
	var node := Node3D.new()
	node.name = name
	node.position = at
	parent.add_child(node,true)
	return node

static func _service_can(parent: Node3D, at: Vector3) -> void:
	var node: Node3D = _stock(parent,at,"WorkshopFluidCan")
	var plastic: Material = GarageMaterials.finish("coolantcan","516b74",0.0,0.71,2)
	box(node,Vector3(0,0.18,0),Vector3(0.27,0.36,0.20),plastic)
	box(node,Vector3(0,0.15,-0.105),Vector3(0.19,0.23,0.012),GarageEnvironment.surface("fluidlabel","c1c1ad"))
	for x: float in [-0.07,0.07]: box(node,Vector3(x,0.401,0),Vector3(0.030,0.095,0.030),plastic)
	box(node,Vector3(0,0.443,0),Vector3(0.17,0.025,0.033),plastic)
	tube(node,Vector3(0.09,0.36,-0.035),Vector3(0.09,0.40,-0.035),0.034,rubber())
	for index: int in range(3): box(node,Vector3(0,0.11+index*0.035,-0.115),Vector3(0.13-index*0.02,0.009,0.004),steel())

static func _tin(parent: Node3D, at: Vector3, radius: float, height: float) -> void:
	var node: Node3D = _stock(parent,at,"WorkshopServiceTin")
	lathe(node,Vector3.ZERO,[Vector2(0,0),Vector2(radius*0.94,0),Vector2(radius,0.015),Vector2(radius,height-0.025),Vector2(radius*0.93,height),Vector2(0,height)],GarageMaterials.finish("servicetin","9a9e9b",0.55,0.48,1))
	lathe(node,Vector3(0,height,0),[Vector2(0,0),Vector2(radius*0.90,0),Vector2(radius*0.90,0.020),Vector2(0,0.020)],rubber())
	box(node,Vector3(0,height*0.45,-radius),Vector3(radius*1.36,height*0.35,0.008),GarageEnvironment.surface("tinlabel","746d55"))
	box(node,Vector3(0,height*0.49,-radius-0.009),Vector3(radius*1.11,0.025,0.005),metal())

static func _storage_bin(parent: Node3D, at: Vector3) -> void:
	var node: Node3D = _stock(parent,at,"WorkshopPartsBin")
	var plastic: Material = GarageMaterials.finish("partsbin","6d736d",0,0.78,2)
	box(node,Vector3(0,0.025,0),Vector3(0.69,0.05,0.46),plastic)
	box(node,Vector3(0,0.18,0.21),Vector3(0.69,0.31,0.035),plastic)
	for x: float in [-0.33,0.33]: box(node,Vector3(x,0.18,0),Vector3(0.035,0.30,0.45),plastic)
	box(node,Vector3(0,0.097,-0.21),Vector3(0.69,0.14,0.035),plastic)
	box(node,Vector3(0,0.155,-0.232),Vector3(0.21,0.065,0.016),metal())
	for index: int in range(6):
		var nut: MeshInstance3D = ring(node,Vector3(-0.23+index%3*0.18,0.073,index/3*0.12-0.04),0.018,0.034,metal())
		nut.rotation.x = 0

static func _brake_package(parent: Node3D, at: Vector3) -> void:
	var node: Node3D = _stock(parent,at,"WorkshopBrakePackage")
	var carton: Material = GarageMaterials.finish("brakecarton","83745b",0,0.88,4)
	box(node,Vector3(0,0.019,0),Vector3(0.73,0.038,0.42),carton)
	box(node,Vector3(0,0.23,0.18),Vector3(0.73,0.43,0.035),carton)
	for x: float in [-0.35,0.35]: box(node,Vector3(x,0.14,0),Vector3(0.035,0.27,0.42),carton)
	lathe(node,Vector3(0,0.23,-0.04),[Vector2(0.07,-0.012),Vector2(0.205,-0.012),Vector2(0.205,0.012),Vector2(0.07,0.012),Vector2(0.07,-0.012)],metal()).rotation.x = PI*0.5
	for x: float in [-0.17,0.17]: box(node,Vector3(x,0.07,-0.16),Vector3(0.22,0.075,0.06),rubber())

static func _tool_bag(parent: Node3D, at: Vector3) -> void:
	var node: Node3D = _stock(parent,at,"WorkshopToolBag")
	var cloth: Material = GarageMaterials.finish("toolbag","5d645a",0,0.94,4)
	var body: MeshInstance3D = lathe(node,Vector3(0,0.17,0),[Vector2(0,-0.37),Vector2(0.13,-0.35),Vector2(0.17,-0.29),Vector2(0.17,0.29),Vector2(0.13,0.35),Vector2(0,0.37)],cloth)
	body.rotation.z = PI*0.5
	body.scale.z = 0.92
	for x: float in [-0.20,0.20]:
		ring(node,Vector3(x,0.17,0),0.167,0.180,rubber()).rotation.y = PI*0.5
		tube(node,Vector3(x,0.30,-0.05),Vector3(x,0.42,-0.05),0.014,rubber())
	tube(node,Vector3(-0.20,0.42,-0.05),Vector3(0.20,0.42,-0.05),0.014,rubber())
	box(node,Vector3(0,0.15,-0.166),Vector3(0.22,0.10,0.009),rubber())

static func _ratchet(parent: Node3D, at: Vector3) -> void:
	_stock(parent,at,"WorkshopRatchet")
	tube(parent,at-Vector3(0,0.18,0),at+Vector3(0,0.17,0),0.024,metal())
	tube(parent,at-Vector3(0,0.23,0),at-Vector3(0,0.09,0),0.034,rubber())
	tube(parent,at+Vector3(0,0.19,0.02),at+Vector3(0,0.19,-0.025),0.061,metal())
	box(parent,at+Vector3(0,0.19,-0.03),Vector3(0.048,0.011,0.012),rubber())

static func _pliers(parent: Node3D, at: Vector3) -> void:
	_stock(parent,at,"WorkshopPliers")
	var grip: Material = GarageMaterials.finish("pliersgrip","94513f",0,0.78,2)
	for side: int in [-1,1]:
		tube(parent,at+Vector3(side*0.10,-0.23,0),at+Vector3(-side*0.025,0.04,0),0.017,metal())
		tube(parent,at+Vector3(side*0.10,-0.23,0),at+Vector3(side*0.045,-0.10,0),0.030,grip)
		var jaw: MeshInstance3D = box(parent,at+Vector3(side*0.025,0.11,0),Vector3(0.04,0.18,0.025),metal())
		jaw.rotation.z = -side*0.14
	bolt(parent,at-Vector3(0,0,0.022),0.027)

static func _hammer(parent: Node3D, at: Vector3) -> void:
	_stock(parent,at,"WorkshopHammer")
	tube(parent,at-Vector3(0,0.24,0),at+Vector3(0,0.18,0),0.024,wood())
	tube(parent,at+Vector3(-0.12,0.20,0),at+Vector3(0.09,0.20,0),0.038,metal())
	tube(parent,at+Vector3(-0.13,0.20,0),at+Vector3(-0.16,0.20,0),0.052,metal())
	for z: float in [-0.015,0.015]: tube(parent,at+Vector3(0.08,0.20,z),at+Vector3(0.16,0.145,z),0.020,metal())

static func _square(parent: Node3D, at: Vector3) -> void:
	_stock(parent,at,"WorkshopSquare")
	box(parent,at,Vector3(0.045,0.46,0.016),metal())
	box(parent,at+Vector3(0.105,-0.20,0),Vector3(0.23,0.06,0.026),rubber())
	for index: int in range(12): box(parent,at+Vector3(0,-0.16+index*0.031,-0.010),Vector3(0.013 if index%3 else 0.024,0.003,0.003),steel())

static func cabinet(parent: Node3D) -> void:
	box(parent,Vector3(0,0.86,0),Vector3(3.9,1.55,0.98),steel())
	box(parent,Vector3(0,1.67,0),Vector3(4.00,0.13,1.08),metal())
	box(parent,Vector3(0,1.741,-0.015),Vector3(3.86,0.025,0.95),GarageEnvironment.surface("counterrubber","303b40",0.14,0.63))
	box(parent,Vector3(0,1.79,0.46),Vector3(3.88,0.10,0.035),metal())
	for col: int in range(3):
		var x: float = (col-1)*1.29
		box(parent,Vector3(x,0.83,-0.495),Vector3(1.25,1.44,0.035),rubber())
		for row: int in range(5): drawer(parent,Vector3(x,0.28+row*0.29,-0.522),1.19,0.246,paint())
		box(parent,Vector3(x,0.11,-0.516),Vector3(1.23,0.09,0.045),metal())
	for side: int in [-1,1]:
		box(parent,Vector3(side*1.94,0.86,0),Vector3(0.046,1.44,0.90),paint())
		for index: int in range(9): box(parent,Vector3(side*1.969,1.18-index*0.07,0.19),Vector3(0.016,0.025,0.38),rubber())
		for z: float in [-0.35,0.35]:
			var at := Vector3(side*1.65,0.105,z)
			var wheel: MeshInstance3D = lathe(parent,at,[Vector2(0,-0.035),Vector2(0.095,-0.035),Vector2(0.115,-0.025),Vector2(0.115,0.025),Vector2(0.095,0.035),Vector2(0,0.035)],rubber())
			wheel.rotation.z = PI*0.5
			tube(parent,at-Vector3(0.05,0,0),at+Vector3(0.05,0,0),0.038,metal())
			box(parent,at+Vector3(0,0.13,0),Vector3(0.16,0.06,0.14),metal())
	var toolbox := Node3D.new()
	toolbox.name = "GarageCounterToolbox"
	toolbox.position = Vector3(0,1.905,-0.05)
	parent.add_child(toolbox)
	case_model(toolbox,Vector3.ZERO)

static func workbench(parent: Node3D) -> void:
	var frame: Material = steel()
	box(parent,Vector3(0,1.15,0),Vector3(4.4,0.16,1.3),wood())
	box(parent,Vector3(0,1.057,0),Vector3(4.33,0.042,1.22),frame)
	for x: float in [-2,2]:
		for z: float in [-0.46,0.46]:
			box(parent,Vector3(x,0.57,z),Vector3(0.105,1.02,0.105),frame)
			box(parent,Vector3(x,0.035,z),Vector3(0.16,0.06,0.16),rubber())
			bolt(parent,Vector3(x,0.92,z-0.059),0.02)
	box(parent,Vector3(0,0.17,0.32),Vector3(4.20,0.055,0.38),frame)
	box(parent,Vector3(0,0.97,0.50),Vector3(4.20,0.08,0.08),frame)
	box(parent,Vector3(1.23,0.61,-0.04),Vector3(1.37,0.80,1.0),frame)
	for index: int in range(3): drawer(parent,Vector3(1.23,0.36+index*0.235,-0.568),1.26,0.204,GarageEnvironment.surface("benchdrawers","3b5661",0.22,0.50))
	# Framed perforated backboard with varied full-sized hand tools.
	box(parent,Vector3(0,2.14,0.59),Vector3(4.20,1.36,0.07),frame)
	box(parent,Vector3(0,2.14,0.542),Vector3(4.00,1.18,0.035),GarageEnvironment.surface("toolboard","47565e",0.25,0.58))
	for row: int in range(7):
		for col: int in range(26):
			tube(parent,Vector3(-1.9+col*0.151,1.61+row*0.174,0.520),Vector3(-1.9+col*0.151,1.61+row*0.174,0.515),0.011,rubber(),12)
	for x: float in [-1.96,1.96]:
		for y: float in [1.61,2.67]: bolt(parent,Vector3(x,y,0.505),0.016)
	_spanner(parent,Vector3(-1.65,2.13,0.48),0.42,true)
	_spanner(parent,Vector3(-1.34,2.08,0.48),0.34,false)
	_ratchet(parent,Vector3(-0.97,2.14,0.48))
	_pliers(parent,Vector3(-0.52,2.10,0.48))
	_hammer(parent,Vector3(0.02,2.10,0.48))
	_square(parent,Vector3(0.58,2.15,0.48))
	for index: int in range(2): _screwdriver(parent,Vector3(1.26+index*0.28,2.12,0.48),index)
	_socket_rail(parent,Vector3(-0.7,1.72,0.46))
	box(parent,Vector3(1.71,1.74,0.465),Vector3(0.34,0.24,0.07),rubber())
	for index: int in range(4): tube(parent,Vector3(1.60+index*0.073,1.70,0.409),Vector3(1.60+index*0.073,1.82,0.409),0.018,metal())
	_vice(parent,Vector3(-1.30,1.24,-0.24))
	case_model(parent,Vector3(0.42,1.36,0.12))

static func _spanner(parent: Node3D, at: Vector3, length: float, open_end: bool) -> void:
	box(parent,at,Vector3(0.040,length,0.025),metal())
	box(parent,at-Vector3(0,0,0.014),Vector3(0.023,length*0.7,0.008),steel())
	ring(parent,at-Vector3(0,length*0.5,0),0.036,0.057,metal())
	var head: Vector3 = at+Vector3(0,length*0.5,0)
	if open_end:
		forged_face(parent,head,PackedVector2Array([Vector2(-0.040,-0.034),Vector2(0.040,-0.034),Vector2(0.076,0.042),Vector2(0.057,0.075),Vector2(0.037,0.034),Vector2(-0.037,0.034),Vector2(-0.057,0.075),Vector2(-0.076,0.042)]),0.027,metal())
	else: ring(parent,head,0.040,0.064,metal())
	tube(parent,head+Vector3(0,0.03,0.025),head+Vector3(0,0.03,-0.04),0.009,rubber())

static func _screwdriver(parent: Node3D, at: Vector3, index: int) -> void:
	var grip: Material = GarageEnvironment.surface("toolgrip","a8893f",0.0,0.66)
	tube(parent,at-Vector3(0,0.15,0),at+Vector3(0,0.19,0),0.012,metal())
	var body: MeshInstance3D = lathe(parent,at-Vector3(0,0.25,0),[Vector2(0,0),Vector2(0.020,0),Vector2(0.032,0.023),Vector2(0.032,0.115),Vector2(0.023,0.140),Vector2(0,0.140)],grip if index%2 == 0 else rubber())
	body.name = "MouldedScrewdriverGrip"
	for side: float in [-0.018,0.018]: box(parent,at+Vector3(side,-0.178,-0.029),Vector3(0.006,0.080,0.006),rubber())
	box(parent,at+Vector3(0,0.20,0),Vector3(0.027,0.03,0.010),metal())

static func _socket_rail(parent: Node3D, at: Vector3) -> void:
	box(parent,at,Vector3(1.58,0.04,0.08),rubber())
	for index: int in range(7):
		var radius: float = 0.022+index*0.0026
		var height: float = 0.10+index%3*0.028
		lathe(parent,at+Vector3(-0.64+index*0.21,0.03,-0.055),[Vector2(radius,0),Vector2(radius,height),Vector2(radius*0.70,height),Vector2(radius*0.70,0.025),Vector2(radius,0)],metal())

static func _vice(parent: Node3D, at: Vector3) -> void:
	var cast: Material = GarageEnvironment.surface("castvice","3a6570",0.38,0.51)
	box(parent,at,Vector3(0.48,0.07,0.38),cast)
	for x: float in [-0.18,0.18]: bolt(parent,at+Vector3(x,0.007,-0.197),0.025)
	lathe(parent,at+Vector3(0,0.04,0),[Vector2(0,0),Vector2(0.18,0),Vector2(0.18,0.045),Vector2(0.14,0.06),Vector2(0,0.06)],cast)
	box(parent,at+Vector3(0,0.18,0.025),Vector3(0.25,0.20,0.33),cast)
	for z: float in [-0.17,0.065]:
		box(parent,at+Vector3(0,0.32,z),Vector3(0.43,0.13,0.115),cast)
		box(parent,at+Vector3(0,0.354,z-0.062),Vector3(0.40,0.06,0.018),metal())
		for index: int in range(14): box(parent,at+Vector3(-0.18+index*0.027,0.354,z-0.073),Vector3(0.005,0.047,0.004),steel())
	tube(parent,at+Vector3(0,0.205,-0.27),at+Vector3(0,0.205,0.22),0.031,metal())
	for index: int in range(10): ring(parent,at+Vector3(0,0.205,-0.27+index*0.017),0.027,0.034,steel())
	tube(parent,at+Vector3(-0.20,0.205,-0.31),at+Vector3(0.20,0.205,-0.31),0.013,metal())
	for x: float in [-0.20,0.20]: tube(parent,at+Vector3(x,0.205,-0.32),at+Vector3(x,0.205,-0.30),0.025,metal())

static func tyre_rack(parent: Node3D) -> void:
	for x: float in [-1.12,1.12]:
		box(parent,Vector3(x,1.14,0.22),Vector3(0.08,2.27,0.08),steel())
		box(parent,Vector3(x,0.04,0),Vector3(0.27,0.08,0.74),steel())
		for y: float in [0.28,1.34,2.10]: bolt(parent,Vector3(x,y,0.165),0.025)
	for y: float in [0.16,1.24]:
		box(parent,Vector3(0,y,0),Vector3(2.30,0.065,0.72),steel())
		box(parent,Vector3(0,y+0.04,-0.32),Vector3(2.30,0.045,0.035),metal())
		for x: float in [-0.56,0.56]: GarageDetails.wheel(parent,Vector3(x,y+0.48,0))
	GarageWorkshop._beam(parent,Vector3(-1.08,0.23,0.33),Vector3(1.08,2.18,0.33),0.035,steel())
	GarageWorkshop._beam(parent,Vector3(1.08,0.23,0.33),Vector3(-1.08,2.18,0.33),0.035,steel())

static func compressor(parent: Node3D) -> void:
	var tank_finish: Material = GarageMaterials.finish("compressortank","57777e",0.25,0.49,2)
	var profile: Array[Vector2] = []
	for index: int in range(10):
		var angle: float = index*PI/18.0
		profile.append(Vector2(sin(angle)*0.24,-0.25-cos(angle)*0.23))
	for index: int in range(10):
		var angle: float = (9-index)*PI/18.0
		profile.append(Vector2(sin(angle)*0.24,0.25+cos(angle)*0.23))
	var tank: MeshInstance3D = lathe(parent,Vector3(0,0.36,0),profile,tank_finish)
	tank.rotation.z = PI*0.5
	for x: float in [-0.28,0.28]:
		box(parent,Vector3(x,0.10,0.07),Vector3(0.10,0.20,0.36),steel())
		var wheel: MeshInstance3D = lathe(parent,Vector3(x,0.13,0.21),[Vector2(0,-0.04),Vector2(0.10,-0.04),Vector2(0.13,-0.028),Vector2(0.13,0.028),Vector2(0.10,0.04),Vector2(0,0.04)],rubber())
		wheel.rotation.x = PI*0.5
		tube(parent,Vector3(x,0.13,0.24),Vector3(x,0.13,0.27),0.047,metal())
	box(parent,Vector3(0,0.615,0),Vector3(0.61,0.04,0.40),steel())
	box(parent,Vector3(0.16,0.725,0.03),Vector3(0.24,0.18,0.28),GarageMaterials.finish("pumpcasting","6d7980",0.55,0.60,3))
	for index: int in range(9): box(parent,Vector3(0.16,0.653+index*0.020,0.03),Vector3(0.29,0.012,0.32),metal())
	tube(parent,Vector3(-0.31,0.73,0.03),Vector3(-0.03,0.73,0.03),0.123,steel())
	for index: int in range(11): ring(parent,Vector3(-0.03-index*0.022,0.73,0.03),0.115,0.128,steel()).rotation.y = PI*0.5
	var fan: MeshInstance3D = lathe(parent,Vector3(-0.32,0.73,0.03),[Vector2(0,-0.01),Vector2(0.115,-0.01),Vector2(0.13,0),Vector2(0.13,0.035),Vector2(0,0.035)],rubber())
	fan.rotation.z = PI*0.5
	box(parent,Vector3(0.40,0.56,-0.10),Vector3(0.12,0.12,0.14),steel())
	tube(parent,Vector3(0.35,0.59,-0.12),Vector3(0.35,0.76,-0.12),0.025,metal())
	# Actual dial face with ticks and needle, regulator knob and wound hose.
	tube(parent,Vector3(0.35,0.75,-0.12),Vector3(0.35,0.75,-0.19),0.067,metal())
	tube(parent,Vector3(0.35,0.75,-0.193),Vector3(0.35,0.75,-0.202),0.057,GarageEnvironment.surface("gaugedial","d7d7c8",0,0.68))
	for index: int in range(9):
		var angle: float = -PI*0.72+index*PI*1.44/8
		tube(parent,Vector3(0.35+sin(angle)*0.040,0.75+cos(angle)*0.040,-0.206),Vector3(0.35+sin(angle)*0.049,0.75+cos(angle)*0.049,-0.206),0.003,rubber(),8)
	tube(parent,Vector3(0.35,0.75,-0.208),Vector3(0.38,0.782,-0.208),0.004,paint(),8)
	tube(parent,Vector3(0.42,0.59,-0.14),Vector3(0.42,0.66,-0.14),0.035,rubber())
	for index: int in range(4): ring(parent,Vector3(0.45,0.39,-0.04-index*0.035),0.145,0.159,rubber())
	tube(parent,Vector3(0.42,0.59,-0.18),Vector3(0.52,0.52,-0.18),0.012,rubber())
	box(parent,Vector3(0,0.36,-0.245),Vector3(0.23,0.10,0.006),metal())
	for index: int in range(4): box(parent,Vector3(-0.073+index*0.047,0.36,-0.252),Vector3(0.024,0.009,0.005),steel())
