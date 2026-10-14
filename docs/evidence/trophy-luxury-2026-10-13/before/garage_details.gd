class_name GarageDetails
extends RefCounted
## Original workshop accessories, complete spare wheels and empty award display.
const TROPHY_CENTER := Vector3(-10.25,2.30,2.8)
const TROPHY_CAMERA := Vector3(-3.6,2.30,2.8)

static func build(root: Node3D) -> void:
	_trophy_wall(root)
	GarageWorkshop.build(root)

static func _trophy_wall(root: Node3D) -> void:
	var cabinet := Node3D.new()
	cabinet.name = "GarageTrophyWall"
	cabinet.position = TROPHY_CENTER
	cabinet.rotation.y = -PI * 0.5
	root.add_child(cabinet)
	var dark: Material = GarageMaterials.finish("displayfelt","303b41",0.0,0.87,4)
	var trim: Material = GarageEnvironment.surface("displaytrim","b59b64",0.55,0.38)
	var wood: Material = GarageEnvironment.surface("displaywood","403e38",0.18,0.64)
	var lit: Material = GarageEnvironment.surface("displaylight","ffe4a0",0,0.4,1.5)
	var charcoal: Material = GarageMaterials.finish("displaycabinet","26333a",0.16,0.58,2)
	var leaf_finish: Material = GarageEnvironment.surface("laurelleaf","c9a759",0.45,0.45)
	leaf_finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	# One uninterrupted alcove, with deep returns and a lit perimeter.
	GarageEnvironment.box(cabinet,Vector3.ZERO,Vector3(8.0,2.86,0.28),wood)
	GarageEnvironment.box(cabinet,Vector3(0,0,-0.16),Vector3(7.65,2.58,0.025),dark)
	for x: float in [-3.92,3.92]:
		GarageEnvironment.box(cabinet,Vector3(x,0,-0.42),Vector3(0.13,2.84,0.86),wood)
		GarageEnvironment.box(cabinet,Vector3(x,0,-0.86),Vector3(0.035,2.80,0.025),trim)
	for y: float in [-1.40,1.40]:
		GarageEnvironment.box(cabinet,Vector3(0,y,-0.42),Vector3(7.92,0.12,0.86),wood)
		GarageEnvironment.box(cabinet,Vector3(0,y,-0.87),Vector3(7.80,0.025,0.025),trim)
		GarageEnvironment.box(cabinet,Vector3(0,y-0.018,-0.905),Vector3(7.73,0.015,0.035),lit)
	# Display table and four restrained handleless lower storage fronts.
	GarageEnvironment.box(cabinet,Vector3(0,-1.52,-0.43),Vector3(7.82,0.14,0.97),trim)
	GarageEnvironment.box(cabinet,Vector3(0,-1.90,-0.39),Vector3(7.77,0.66,0.84),charcoal)
	for index: int in range(4):
		var x: float = (index-1.5)*1.91
		GarageEnvironment.box(cabinet,Vector3(x,-1.89,-0.83),Vector3(1.88,0.59,0.035),charcoal)
		GarageEnvironment.box(cabinet,Vector3(x,-1.61,-0.856),Vector3(1.70,0.022,0.018),GarageEnvironment.surfaces.inset)
	GarageEnvironment.box(cabinet,Vector3(0,-2.26,-0.36),Vector3(7.6,0.12,0.75),GarageEnvironment.surfaces.inset)
	# A permanent brand mural, not an invented earned award.
	var title := Label3D.new()
	title.name = "TrophyWallSign"
	title.text = "BEAT\nMY TRACK"
	title.font = MenuStyle.DISPLAY
	title.font_size = 64
	title.pixel_size = 0.0050
	title.modulate = Color("c8ad67")
	title.outline_size = 0
	title.rotation.y = PI
	title.position = Vector3(0,0.32,-0.24)
	cabinet.add_child(title)
	_laurel(cabinet)
	# Quiet architectural reveals give the uninterrupted display a built finish.
	for x: float in [-2.55,2.55]:
		GarageEnvironment.box(cabinet,Vector3(x,0,-0.181),Vector3(0.012,2.40,0.009),trim)
	for y: float in [-1.20,1.20]:
		GarageEnvironment.box(cabinet,Vector3(0,y,-0.183),Vector3(7.28,0.012,0.009),trim)
	# Six future-award bases; no race grants or trophy ownership are fabricated.
	for index: int in range(6):
		var slot := Node3D.new()
		slot.name = "AwardSlot_%d" % index
		slot.position = Vector3((index-2.5)*1.13,-1.39,-0.48)
		cabinet.add_child(slot)
		GarageEnvironment.box(slot,Vector3(0,0.06,0),Vector3(0.66,0.08,0.44),GarageEnvironment.surfaces.inset)
		GarageEnvironment.box(slot,Vector3(0,0.107,0),Vector3(0.62,0.014,0.40),trim)
		GarageEnvironment.box(slot,Vector3(0,0.132,0),Vector3(0.58,0.038,0.36),charcoal)
		GarageEnvironment.box(slot,Vector3(0,0.025,-0.20),Vector3(0.29,0.032,0.008),trim)
	for x: float in [-2.7,0.0,2.7]:
		GarageEnvironment.box(cabinet,Vector3(x,1.26,-0.53),Vector3(0.20,0.12,0.22),charcoal)
		GarageEnvironment.box(cabinet,Vector3(x,1.19,-0.53),Vector3(0.13,0.02,0.14),lit)
		GarageWorkshop._spot(cabinet,Vector3(x,1.16,-0.57),Vector3(x,-0.66,-0.12),1.65,3.8,48.0)

static func _laurel(parent: Node3D) -> void:
	# Original relief: continuous curved stems, pointed folded leaves and midribs.
	var gold: Material = GarageEnvironment.surface("reliefgold","c4a66b",0.65,0.43)
	gold.cull_mode = BaseMaterial3D.CULL_DISABLED
	var edge: Material = GarageEnvironment.surface("reliefedge","8d7548",0.55,0.55)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: int in [-1,1]:
		var previous := Vector3(side*0.20,-0.74,-0.245)
		for index: int in range(25):
			var t: float = index/24.0
			var point := Vector3(side*(0.20+0.87*sin(t*1.73)), -0.74+t*1.76,-0.245)
			if index > 0:
				GarageWorkshop._beam(parent,previous,point,0.018,edge)
			previous = point
		for index: int in range(11):
			var t: float = (index+0.5)/11.0
			var base := Vector3(side*(0.20+0.87*sin(t*1.73)),-0.74+t*1.76,-0.25)
			for outward: int in [-1,1]:
				var direction := Vector2(side*outward*(0.75-t*0.23),0.70+t*0.38).normalized()
				var across := Vector2(-direction.y,direction.x)
				var length: float = 0.25-t*0.065
				var ridge := base+Vector3(direction.x,direction.y,-0.13)*length*0.52
				for segment: int in range(8):
					var a: float = segment/8.0
					var b: float = (segment+1)/8.0
					for half: int in [-1,1]:
						var ca := base+Vector3(direction.x*length*a,direction.y*length*a,-sin(a*PI)*0.020)
						var cb := base+Vector3(direction.x*length*b,direction.y*length*b,-sin(b*PI)*0.020)
						var ea := base+Vector3(direction.x*length*a+across.x*sin(a*PI)*0.050*half,direction.y*length*a+across.y*sin(a*PI)*0.050*half,0)
						var eb := base+Vector3(direction.x*length*b+across.x*sin(b*PI)*0.050*half,direction.y*length*b+across.y*sin(b*PI)*0.050*half,0)
						var points: Array[Vector3] = [ca,ea,eb,cb]
						GarageEnvironment._polygon(tool,points,Vector3.FORWARD)
				GarageWorkshop._beam(parent,base+Vector3(0,0,-0.003),ridge+Vector3(0,0,-0.003),0.006,edge)
	tool.index()
	var relief := MeshInstance3D.new()
	relief.name = "SculptedBrandLaurel"
	relief.mesh = tool.commit()
	relief.material_override = gold
	relief.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(relief)

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
		var spoke: MeshInstance3D = GarageFurnishings.forged_face(node,Vector3(0,0,-0.185),PackedVector2Array([Vector2(-0.044,0.055),Vector2(0.044,0.055),Vector2(0.025,0.235),Vector2(0,0.266),Vector2(-0.025,0.235)]),0.033,rim)
		spoke.rotation.z = -angle
		var lug := GarageEnvironment.cylinder(node,Vector3(sin(angle)*0.047,cos(angle)*0.047,-0.224),0.012,0.015,GarageEnvironment.surfaces.inset)
		lug.rotation.x = PI*0.5
	for index: int in range(18):
		var angle: float = index*TAU/18.0
		GarageFurnishings.tube(node,Vector3(sin(angle)*0.205,cos(angle)*0.205,-0.156),Vector3(sin(angle)*0.205,cos(angle)*0.205,-0.161),0.009,GarageEnvironment.surfaces.inset,12)
	for z: float in [-0.174,0.174]:
		GarageFurnishings.ring(node,Vector3(0,0,z),0.302,0.307,GarageEnvironment.surface("tiresidemould","34383b",0,0.91))
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
