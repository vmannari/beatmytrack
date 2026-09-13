class_name CreatorBridgeVisual
extends RefCounted
## Original ramp/deck/rail meshes; footprint matches the native upper layer.

static func build(parent: Node3D, bridges: Array) -> void:
	if bridges.is_empty(): return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for span: Dictionary in bridges:
		var count: int = ceili(float(span.length)/0.5)
		var half: float = float(span.width)*0.5
		for i: int in range(count):
			var a: float = float(span.length)*i/count
			var b: float = float(span.length)*(i+1)/count
			strip(tool,span,a,b,-half,half,0.025,Color("3d494b"))
			for side: float in [-1.0,1.0]:
				var inner: float = half*side
				var outer: float = (half+CreatorBridges.RAIL)*side
				strip(tool,span,a,b,inner,outer,0.65,Color("c3c8bd"))
				quad(tool,vertex(span,a,inner,0.0),vertex(span,b,inner,0.0),vertex(span,b,inner,0.65),vertex(span,a,inner,0.65),Color("868e88"))
				quad(tool,vertex(span,a,outer,-0.2),vertex(span,b,outer,-0.2),vertex(span,b,outer,0.65),vertex(span,a,outer,0.65),Color("868e88"))
				strip(tool,span,a,b,(half-0.30)*side,(half-0.18)*side,0.033,Color("ececdf"))
			# The underside gives the span a readable thickness from racing.
			strip(tool,span,a,b,-half-CreatorBridges.RAIL,half+CreatorBridges.RAIL,-0.2,Color("626b69"))
		# Small approach markings explain which ends can be driven onto.
		for u: float in [2.0,float(span.length)-2.0]:
			for side: float in [-1.0,1.0]: strip(tool,span,u,u+0.18,side*1.0,side*2.0,0.04,Color("d5d6bb"))
	tool.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = tool.commit()
	var material := VisualGeometry.material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	parent.add_child(mesh)

static func vertex(span: Dictionary, along: float, across: float, offset: float) -> Vector3:
	var p: Vector2 = Vector2(span.position[0],span.position[1])+Vector2(along,across).rotated(deg_to_rad(float(span.heading)))
	return VisualGeometry.world(p)+Vector3.UP*(CreatorBridges.height(span,p)+offset)

static func strip(tool: SurfaceTool, span: Dictionary, a: float, b: float, left: float, right: float, offset: float, color: Color) -> void:
	quad(tool,vertex(span,a,left,offset),vertex(span,b,left,offset),vertex(span,b,right,offset),vertex(span,a,right,offset),color)

static func quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	tool.set_color(color)
	for v: Vector3 in [a,c,b,a,d,c]: tool.add_vertex(v)
