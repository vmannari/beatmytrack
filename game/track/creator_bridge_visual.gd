class_name CreatorBridgeVisual
extends RefCounted
## Original ramp/deck/rail meshes; footprint matches the native upper layer.

const RAIL_TOP: Color = Color("858681")
const RAIL_SIDE: Color = Color("60635f")

static func build(parent: Node3D, bridges: Array, theme: String = "pine") -> void:
	if bridges.is_empty(): return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var deck := SurfaceTool.new()
	deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	for span: Dictionary in bridges:
		var count: int = ceili(float(span.length)/0.5)
		var half: float = float(span.width)*0.5
		for i: int in range(count):
			var a: float = float(span.length)*i/count
			var b: float = float(span.length)*(i+1)/count
			strip(deck,span,a,b,-half,half,0.025,Color("343638"))
			for side: float in [-1.0,1.0]:
				var inner: float = half*side
				var outer: float = (half+CreatorBridges.RAIL)*side
				# Broad concrete footing, plain grey steel handrail. Both remain
				# inside the existing solid rail footprint; the underpass stays open.
				strip(tool,span,a,b,inner,outer,0.10,Color("afb1a5"))
				wall(tool,span,a,b,inner,0.025,0.10,Color("626e70"))
				wall(tool,span,a,b,outer,-0.42,0.10,Color("817e70"))
				strip(tool,span,a,b,(half+0.63)*side,outer,-0.40,Color("b6ae99"))
				wall(tool,span,a,b,outer,-0.42,-0.34,Color("403f38"))
				var rail: float = (half+0.14)*side
				var back: float = (half+0.34)*side
				# One plain rectangular handrail, 20 cm higher than the old crown.
				strip(tool,span,a,b,rail,back,0.85,RAIL_TOP)
				wall(tool,span,a,b,rail,0.65,0.85,RAIL_SIDE)
				wall(tool,span,a,b,back,0.65,0.85,RAIL_SIDE)
				strip(tool,span,a,b,rail,back,0.65,RAIL_SIDE)
				strip(tool,span,a,b,(half-0.30)*side,(half-0.18)*side,0.033,Color("d9d8cc"))
			strip(tool,span,a,b,-half-CreatorBridges.RAIL,half+CreatorBridges.RAIL,-0.42,Color("293e4a"))
		# Sparse slim steel uprights, all within the existing solid rail strip.
		var posts: int = maxi(1,ceili(float(span.length)/8.0))
		for i: int in range(posts+1):
			var a: float = clampf(float(span.length)*i/posts,0,float(span.length)-0.24)
			var b: float = a+0.24
			for side: float in [-1.0,1.0]:
				var inner: float = (half+0.16)*side
				var outer: float = (half+0.32)*side
				strip(tool,span,a,b,inner,outer,0.85,RAIL_SIDE)
				wall(tool,span,a,b,inner,0.10,0.85,RAIL_SIDE)
				wall(tool,span,a,b,outer,-0.42,0.85,RAIL_SIDE)
				quad(tool,vertex(span,a,inner,0.10),vertex(span,a,outer,0.10),vertex(span,a,outer,0.85),vertex(span,a,inner,0.85),RAIL_SIDE)
				quad(tool,vertex(span,b,inner,0.10),vertex(span,b,outer,0.10),vertex(span,b,outer,0.85),vertex(span,b,inner,0.85),RAIL_SIDE)
		# Recessed expansion joints at the crest of each ramp.
		for u: float in [CreatorBridges.RAMP,float(span.length)-CreatorBridges.RAMP]:
			strip(tool,span,u,u+0.055,-half,half,0.034,Color("182c37"))
			strip(tool,span,u+0.055,u+0.085,-half,half,0.035,Color("788382"))
		# Plain end caps close the handrail.
		for u: float in [0.0,float(span.length)]:
			for side: float in [-1.0,1.0]:
				quad(tool,vertex(span,u,(half+0.14)*side,0.65),vertex(span,u,(half+0.34)*side,0.65),vertex(span,u,(half+0.34)*side,0.85),vertex(span,u,(half+0.14)*side,0.85),RAIL_SIDE)
		# Small approach markings explain which ends can be driven onto.
		for u: float in [2.0,float(span.length)-2.0]:
			for side: float in [-1.0,1.0]: strip(tool,span,u,u+0.18,side*1.0,side*2.0,0.04,Color("d5d6bb"))
	tool.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "BridgeSteelAndFascia"
	mesh.mesh = tool.commit()
	var material := VisualGeometry.material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	parent.add_child(mesh)
	deck.generate_normals()
	var road := MeshInstance3D.new()
	road.name = "BridgeAsphalt"
	road.mesh = deck.commit()
	var asphalt := ShaderMaterial.new()
	asphalt.shader = preload("res://track/bridge_road.gdshader")
	asphalt.set_shader_parameter("surface_factors", preload("res://assets/textures/surface_factors_v1.png"))
	asphalt.set_shader_parameter("road_color",TrackTheme.palette(theme)[0])
	asphalt.set_shader_parameter("icy_road",theme == "winter")
	asphalt.set_shader_parameter("wet_road",theme == "storm")
	asphalt.set_shader_parameter("packed_sand",theme == "desert")
	road.material_override = asphalt
	parent.add_child(road)

static func vertex(span: Dictionary, along: float, across: float, offset: float) -> Vector3:
	var p: Vector2 = Vector2(span.position[0],span.position[1])+Vector2(along,across).rotated(deg_to_rad(float(span.heading)))
	return VisualGeometry.world(p)+Vector3.UP*(CreatorBridges.height(span,p)+offset)

static func strip(tool: SurfaceTool, span: Dictionary, a: float, b: float, left: float, right: float, offset: float, color: Color) -> void:
	quad(tool,vertex(span,a,left,offset),vertex(span,b,left,offset),vertex(span,b,right,offset),vertex(span,a,right,offset),color)

static func quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	tool.set_color(color)
	for v: Vector3 in [a,c,b,a,d,c]: tool.add_vertex(v)

static func wall(tool: SurfaceTool, span: Dictionary, a: float, b: float, across: float, low: float, high: float, color: Color) -> void:
	quad(tool,vertex(span,a,across,low),vertex(span,b,across,low),vertex(span,b,across,high),vertex(span,a,across,high),color)
