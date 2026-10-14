class_name GarageDetails
extends RefCounted
## Original workshop accessories, complete spare wheels and empty award display.
const TROPHY_CENTER := Vector3(-9.45,1.50,6.0)
const TROPHY_CAMERA := Vector3(-3.85,1.70,5.7)

static func build(root: Node3D) -> void:
	_trophy_wall(root)
	var dark: Material = GarageEnvironment.surfaces.inset
	var metal: Material = GarageEnvironment.surfaces.edges
	var timber: Material = GarageEnvironment.surface("shelfwood","675647")
	# Wall utility panels, cable tray, fixtures and a recognisable compressor.
	for x: float in [-10.7,10.5]:
		GarageEnvironment.box(root,Vector3(x,2.15,8.4),Vector3(1.15,1.30,0.14),dark)
		GarageEnvironment.box(root,Vector3(x,2.15,8.30),Vector3(0.97,1.10,0.06),metal)
		for y: float in [1.9,2.25]: GarageEnvironment.box(root,Vector3(x+0.28,y,8.24),Vector3(0.08,0.03,0.07),dark)
	GarageEnvironment.box(root,Vector3(0,4.45,8.38),Vector3(25,0.13,0.14),metal)
	for x: float in [-10.7,10.5]: GarageEnvironment.box(root,Vector3(x,3.48,8.38),Vector3(0.07,1.9,0.10),metal)
	for y: float in [1.45,2.20,2.95]:
		GarageEnvironment.box(root,Vector3(7.0,y,7.8),Vector3(3.8,0.07,0.74),timber)
		for x: float in [5.4,8.6]: GarageEnvironment.box(root,Vector3(x,y-0.12,8.03),Vector3(0.065,0.30,0.52),metal)
		for index: int in range(5):
			var x: float = 5.65 + index*0.64
			GarageEnvironment.box(root,Vector3(x,y+0.24,7.76),Vector3(0.36,0.43,0.38),GarageEnvironment.surface("supply","5c6e74"))
			GarageEnvironment.box(root,Vector3(x,y+0.12,7.54),Vector3(0.22,0.04,0.015),metal)
	var compressor := Node3D.new()
	compressor.name = "GarageCompressor"
	compressor.position = Vector3(-8.7,0,-1.5)
	root.add_child(compressor)
	var tank := GarageEnvironment.cylinder(compressor,Vector3(0,0.62,0),0.40,1.25,GarageEnvironment.surface("compressor","704738",0.12))
	tank.rotation.z = PI*0.5
	for x: float in [-0.5,0.5]:
		GarageEnvironment.box(compressor,Vector3(x,0.18,0),Vector3(0.10,0.36,0.50),dark)
	GarageEnvironment.box(compressor,Vector3(0,1.15,0),Vector3(0.70,0.27,0.46),metal)
	GarageEnvironment.box(compressor,Vector3(0.45,1.41,0),Vector3(0.10,0.25,0.10),dark)
	for index: int in range(8): GarageEnvironment.box(compressor,Vector3(-0.25+index*0.07,1.30,-0.05),Vector3(0.024,0.08,0.33),dark)

static func _trophy_wall(root: Node3D) -> void:
	var cabinet := Node3D.new()
	cabinet.name = "GarageTrophyWall"
	cabinet.position = TROPHY_CENTER
	cabinet.rotation.y = -PI * 0.5
	root.add_child(cabinet)
	var dark: Material = GarageEnvironment.surface("displayfelt","15232c")
	var trim: Material = GarageEnvironment.surface("displaytrim","85714f",0.5,0.5)
	var wood: Material = GarageEnvironment.surface("displaywood","53473d")
	var lit: Material = GarageEnvironment.surface("displaylight","e6d2a2",0,0.7,0.85)
	GarageEnvironment.box(cabinet,Vector3.ZERO,Vector3(4.8,2.65,0.34),wood)
	GarageEnvironment.box(cabinet,Vector3(0,0,-0.19),Vector3(4.48,2.36,0.035),dark)
	for x: float in [-2.32,2.32]: GarageEnvironment.box(cabinet,Vector3(x,0,-0.31),Vector3(0.08,2.62,0.45),trim)
	for y: float in [-1.27,1.27]: GarageEnvironment.box(cabinet,Vector3(0,y,-0.31),Vector3(4.7,0.08,0.45),trim)
	for y: float in [-1.15,0.0,1.15]:
		GarageEnvironment.box(cabinet,Vector3(0,y,-0.42),Vector3(4.45,0.06,0.66),wood)
		GarageEnvironment.box(cabinet,Vector3(0,y+0.018,-0.73),Vector3(4.34,0.015,0.018),trim)
		if y> -1:
			GarageEnvironment.box(cabinet,Vector3(0,y-0.055,-0.45),Vector3(4.2,0.018,0.22),lit)
	for x: float in [-0.76,0.76]: GarageEnvironment.box(cabinet,Vector3(x,0,-0.41),Vector3(0.035,2.27,0.50),trim)
	var title := Label3D.new()
	title.name = "TrophyWallSign"
	title.text = "TROPHIES"
	title.font = MenuStyle.DISPLAY
	title.font_size = 64
	title.pixel_size = 0.0046
	title.modulate = Color("ddc697")
	title.outline_size = 0
	title.rotation.y = PI
	title.position = Vector3(0,1.58,-0.28)
	cabinet.add_child(title)
	var light := SpotLight3D.new()
	light.name = "TrophyWallLight"
	light.position = Vector3(0,2.45,-1.3)
	light.light_color = Color("eedbb6")
	light.light_energy = 0.65
	light.spot_range = 5
	light.spot_angle = 60
	cabinet.add_child(light)
	light.look_at(cabinet.global_position)
	# Six empty display cells. No unearned race trophies are fabricated.
	for row: int in range(2):
		for col: int in range(3):
			var slot := Node3D.new()
			slot.name = "AwardSlot_%d" % (row*3+col)
			slot.position = Vector3((col-1)*1.49,-1.06+row*1.15,-0.42)
			cabinet.add_child(slot)
			GarageEnvironment.box(slot,Vector3(0,0.065,0),Vector3(0.68,0.13,0.40),GarageEnvironment.surfaces.inset)

static func wheel(parent: Node3D, position: Vector3) -> void:
	var node := Node3D.new()
	node.name = "PreparedSpareWheel"
	node.position = position
	parent.add_child(node)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile: Array[Vector2] = [Vector2(-0.17,0.26),Vector2(-0.17,0.36),Vector2(-0.12,0.46),Vector2(-0.05,0.48),Vector2(0.05,0.48),Vector2(0.12,0.46),Vector2(0.17,0.36),Vector2(0.17,0.26)]
	for row: int in range(profile.size()):
		var next: int = (row+1)%profile.size()
		var direction: Vector2 = profile[next]-profile[row]
		var n := Vector2(direction.x,-direction.y).normalized()
		for segment: int in range(48):
			var a: float = segment*TAU/48.0
			var b: float = (segment+1)*TAU/48.0
			var points: Array[Vector3] = [Vector3(sin(a)*profile[row].y,cos(a)*profile[row].y,profile[row].x),Vector3(sin(b)*profile[row].y,cos(b)*profile[row].y,profile[row].x),Vector3(sin(b)*profile[next].y,cos(b)*profile[next].y,profile[next].x),Vector3(sin(a)*profile[next].y,cos(a)*profile[next].y,profile[next].x)]
			var outward := Vector3(sin((a+b)*0.5)*n.x,cos((a+b)*0.5)*n.x,n.y)
			GarageEnvironment._polygon(tool,points,outward)
	tool.index()
	var tire := MeshInstance3D.new()
	tire.name = "ProfiledTireCasing"
	tire.mesh = tool.commit()
	tire.material_override = GarageEnvironment.surface("tirecasing","24272a",0,0.9)
	tire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(tire)
	var rim: Material = GarageEnvironment.surface("wheelfinish","a1a5a7",0.65,0.5)
	var brake := GarageEnvironment.cylinder(node,Vector3(0,0,-0.13),0.24,0.05,GarageEnvironment.surface("brake","52565a",0.5))
	brake.rotation.x = PI*0.5
	var hub := GarageEnvironment.cylinder(node,Vector3(0,0,-0.18),0.075,0.07,rim)
	hub.rotation.x = PI*0.5
	for index: int in range(5):
		var angle: float = index*TAU/5.0
		var spoke := GarageEnvironment.box(node,Vector3(sin(angle)*0.16,cos(angle)*0.16,-0.185),Vector3(0.065,0.27,0.035),rim)
		spoke.rotation.z = -angle
		var lug := GarageEnvironment.cylinder(node,Vector3(sin(angle)*0.047,cos(angle)*0.047,-0.224),0.012,0.015,GarageEnvironment.surfaces.inset)
		lug.rotation.x = PI*0.5
	var lip := MeshInstance3D.new()
	var shape := TorusMesh.new()
	shape.inner_radius = 0.245
	shape.outer_radius = 0.277
	shape.rings = 48
	shape.ring_segments = 8
	lip.mesh = shape
	lip.rotation.x = PI*0.5
	lip.position.z = -0.185
	lip.material_override = rim
	lip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(lip)
	for index: int in range(36):
		var angle: float = index*TAU/36.0
		for z: float in [-0.055,0.055]:
			var tread := GarageEnvironment.box(node,Vector3(sin(angle)*0.479,cos(angle)*0.479,z),Vector3(0.048,0.012,0.068),GarageEnvironment.surface("tread","191c1f"))
			tread.rotation.z = -angle
