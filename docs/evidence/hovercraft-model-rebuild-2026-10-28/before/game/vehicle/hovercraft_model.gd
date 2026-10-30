extends RefCounted
## Original compact recreational hovercraft. Model metres; bow -Z, fan aft.
static func build(car: CarVisual) -> void:
	var paint: StandardMaterial3D = VisualGeometry.material(Color("698d87"))
	var accent: StandardMaterial3D = VisualGeometry.material(Color("d9d0b7"))
	var rubber: StandardMaterial3D = VisualGeometry.material(Color("252d30"))
	var seam: StandardMaterial3D = VisualGeometry.material(Color("151e22"))
	var glass: StandardMaterial3D = VisualGeometry.material(Color("304957"))
	var metal: StandardMaterial3D = VisualGeometry.material(Color("83918f"))
	car.paint_materials = {"body":paint,"accent":accent,"detail":metal}
	var segments: int = 40 if car.simple_model else 64
	# A closed, rounded bag skirt with raised deck lip; no wheels hidden inside.
	_loft(car,segments,[Vector2(0.94,0.12),Vector2(1.0,0.24),Vector2(1.0,0.43),Vector2(0.92,0.59)],rubber)
	_loft(car,segments,[Vector2(0.925,0.57),Vector2(0.93,0.65),Vector2(0.83,0.78)],paint)
	for index: int in range(0,segments,2):
		var angle: float = TAU*index/segments
		car._seam(car.body,_outline(angle,1.002,0.26),_outline(angle,0.965,0.52),0.009,seam)
	# Broad solid foredeck and aft deck support the inset glazed cockpit.
	var deck: Array[Vector3] = []
	for index: int in range(segments): deck.append(_outline(TAU*index/segments,0.83,0.78))
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(segments):
		for point: Vector3 in [Vector3(0,0.78,0),deck[(index+1)%segments],deck[index]]:
			top.set_normal(Vector3.UP)
			top.add_vertex(point)
	var top_mesh := MeshInstance3D.new()
	top_mesh.mesh = top.commit()
	top_mesh.material_override = paint
	car.body.add_child(top_mesh)
	_loft(car,segments,[Vector2(0.83,0.785),Vector2(0.81,0.80)],accent)
	# Low forward cabin, sloping windshield and cream canopy perimeter.
	VehicleModels._cabin(car,0.62,0.78,1.37,-1.18,0.43,-0.63,0.16,paint,glass,seam)
	VisualGeometry.box(car.body,Vector3(1.05,0.055,0.75),Vector3(0,1.395,-0.23),accent)
	for side: float in [-1.0,1.0]:
		VisualGeometry.box(car.body,Vector3(0.11,0.035,0.58),Vector3(side*0.78,0.80,-0.48),metal)
		VisualGeometry.box(car.body,Vector3(0.27,0.06,0.10),Vector3(side*0.64,0.76,-1.62),accent)
		VisualGeometry.box(car.body,Vector3(0.19,0.075,0.06),Vector3(side*0.64,0.75,1.68),car.brake_material)
		car._seam(car.body,Vector3(side*0.59,0.78,0.80),Vector3(side*0.46,1.23,1.37),0.07,seam)
	# Open duct with visible inner wall and protective front/rear grilles.
	var center := Vector3(0,1.34,1.18)
	_duct(car,center,0.66,0.57,0.38,accent,segments)
	for z: float in [-0.205,0.205]:
		for bar: int in range(-3,4):
			var x: float = bar*0.15
			var extent: float = sqrt(0.56*0.56-x*x)
			car._seam(car.body,center+Vector3(x,-extent,z),center+Vector3(x,extent,z),0.012,metal)
	var fan := Node3D.new()
	fan.name = "FanRotor"
	fan.position = center
	car.body.add_child(fan)
	var hub := VisualGeometry.cylinder(fan,0.115,0.14,Vector3.ZERO,seam)
	hub.rotation.x = PI*0.5
	for blade: int in range(5):
		var piece := VisualGeometry.box(fan,Vector3(0.15,0.42,0.035),Vector3.ZERO,seam)
		var angle: float = blade*TAU/5.0
		piece.position = Vector3(-sin(angle),cos(angle),0)*0.31
		piece.rotation = Vector3(0.18,0,angle)
	for side: float in [-1.0,1.0]:
		var rudder := Node3D.new()
		rudder.name = "RudderLeft" if side < 0.0 else "RudderRight"
		rudder.position = center+Vector3(side*0.29,0,0.28)
		car.body.add_child(rudder)
		VisualGeometry.box(rudder,Vector3(0.045,0.86,0.30),Vector3.ZERO,paint)

static func _outline(angle: float, size: float, height: float) -> Vector3:
	var x: float = sin(angle)
	var z: float = cos(angle)
	return Vector3(signf(x)*pow(absf(x),0.63)*1.16*(0.90 if z < 0.0 else 1.0)*size,height,signf(z)*pow(absf(z),0.72)*2.13*size)

static func _loft(car: CarVisual, segments: int, rings: Array[Vector2], material: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring: int in range(rings.size()-1):
		for index: int in range(segments):
			var a: float = TAU*index/segments
			var b: float = TAU*(index+1)/segments
			_quad(tool,[_outline(a,rings[ring].x,rings[ring].y),_outline(b,rings[ring].x,rings[ring].y),_outline(b,rings[ring+1].x,rings[ring+1].y),_outline(a,rings[ring+1].x,rings[ring+1].y)],Vector3(sin((a+b)*0.5),0.35,cos((a+b)*0.5)).normalized())
	_publish(car,tool,material)

static func _duct(car: CarVisual, center: Vector3, outer: float, inner: float, depth: float, material: Material, segments: int) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(segments):
		var a: float = TAU*index/segments
		var b: float = TAU*(index+1)/segments
		var p := Vector3(sin(a),cos(a),0)
		var q := Vector3(sin(b),cos(b),0)
		var front := Vector3(0,0,-depth*0.5)
		var back := -front
		_quad(tool,[center+p*outer+front,center+q*outer+front,center+q*outer+back,center+p*outer+back],(p+q).normalized())
		_quad(tool,[center+p*inner+front,center+q*inner+front,center+q*inner+back,center+p*inner+back],-(p+q).normalized())
		for end: Vector3 in [front,back]:
			_quad(tool,[center+p*inner+end,center+q*inner+end,center+q*outer+end,center+p*outer+end],end.normalized())
	_publish(car,tool,material)

static func _quad(tool: SurfaceTool, points: Array[Vector3], normal: Vector3) -> void:
	var indices: Array[int] = [0,1,2,0,2,3]
	if (points[1]-points[0]).cross(points[2]-points[0]).dot(normal) > 0.0: indices = [0,2,1,0,3,2]
	for index: int in indices:
		tool.set_normal(normal)
		tool.add_vertex(points[index])

static func _publish(car: CarVisual, tool: SurfaceTool, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.mesh = tool.commit()
	node.material_override = material
	car.body.add_child(node)
