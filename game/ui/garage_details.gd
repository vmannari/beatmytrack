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
	var dark := ShaderMaterial.new()
	dark.shader = preload("res://ui/garage_display_backing.gdshader")
	var trim: Material = GarageEnvironment.surface("displaychampagnesatin","c8b386",0.58,0.34)
	var wood := ShaderMaterial.new()
	wood.shader = preload("res://ui/garage_display_stone.gdshader")
	var lit: Material = GarageEnvironment.surface("displaylightrefined","f5dfb5",0,0.4,0.85)
	var charcoal: Material = GarageMaterials.finish("displaycabinet","26333a",0.16,0.58,2)
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
	GarageEnvironment.box(cabinet,Vector3(0,-1.52,-0.43),Vector3(7.82,0.14,0.97),wood)
	GarageEnvironment.box(cabinet,Vector3(0,-1.90,-0.39),Vector3(7.77,0.66,0.84),charcoal)
	for index: int in range(4):
		var x: float = (index-1.5)*1.91
		GarageEnvironment.box(cabinet,Vector3(x,-1.89,-0.83),Vector3(1.88,0.59,0.035),charcoal)
		GarageEnvironment.box(cabinet,Vector3(x,-1.61,-0.856),Vector3(1.70,0.022,0.018),GarageEnvironment.surfaces.inset)
	GarageEnvironment.box(cabinet,Vector3(0,-2.26,-0.36),Vector3(7.6,0.12,0.75),GarageEnvironment.surfaces.inset)
	# A permanent brand mural, not an invented earned award.
	var title := MeshInstance3D.new()
	var lettering := TextMesh.new()
	title.name = "TrophyWallSign"
	lettering.text = "BEAT\nMY TRACK"
	lettering.font = MenuStyle.DISPLAY
	lettering.font_size = 48
	lettering.pixel_size = 0.0067
	lettering.depth = 0.024
	lettering.curve_step = 0.7
	title.mesh = lettering
	title.material_override = GarageEnvironment.surface("brandlettergold","e0c797",0.22,0.44,0.12)
	title.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	title.rotation.y = PI
	title.position = Vector3(0,0.16,-0.252)
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
		GarageEnvironment.box(slot,Vector3(0,0.056,-0.225),Vector3(0.24,0.026,0.009),trim)
	for x: float in [-2.7,0.0,2.7]:
		_round_light(cabinet,Vector3(x,1.24,-0.53),trim,lit)

static func _round_light(parent: Node3D, at: Vector3, trim: Material, lit: Material) -> void:
	var fixture := Node3D.new()
	fixture.name = "RoundGallerySpot"
	fixture.position = at
	parent.add_child(fixture)
	var body: Material = GarageMaterials.finish("galleryspotbody","2d3439",0.58,0.36,1)
	GarageEnvironment.cylinder(fixture,Vector3(0,0.075,0),0.095,0.035,trim)
	GarageEnvironment.cylinder(fixture,Vector3(0,0.018,0),0.078,0.08,body)
	GarageEnvironment.cylinder(fixture,Vector3(0,-0.034,0),0.082,0.018,trim)
	GarageEnvironment.cylinder(fixture,Vector3(0,-0.046,0),0.066,0.014,GarageEnvironment.surfaces.inset)
	GarageEnvironment.cylinder(fixture,Vector3(0,-0.055,0),0.052,0.008,lit)
	GarageWorkshop._spot(parent,at+Vector3(0,-0.067,-0.015),Vector3(at.x,-0.45,-0.12),1.45,3.8,50.0)
	var light: SpotLight3D = parent.get_child(parent.get_child_count()-1)
	light.name = "GalleryWallWash"
	light.light_color = Color("ffebc7")
	light.spot_attenuation = 1.25

static func _laurel(parent: Node3D) -> void:
	# Original relief: continuous curved stems, pointed folded leaves and midribs.
	var gold: Material = GarageEnvironment.surface("refinedreliefgold","d4b984",0.42,0.36)
	gold.cull_mode = BaseMaterial3D.CULL_DISABLED
	var edge: Material = GarageEnvironment.surface("refinedreliefedge","b39b6d",0.40,0.48)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: int in [-1,1]:
		var previous := Vector3(side*1.12*sin(0.12),0.22-0.97*cos(0.12),-0.245)
		for index: int in range(25):
			var theta: float = 0.12+index/24.0*2.30
			var point := Vector3(side*1.12*sin(theta),0.22-0.97*cos(theta),-0.245)
			if index > 0:
				GarageFurnishings.tube(parent,previous,point,0.009,edge,12)
			previous = point
		for index: int in range(12):
			var t: float = (index+0.5)/12.0
			var theta: float = 0.12+t*2.30
			var base := Vector3(side*1.12*sin(theta),0.22-0.97*cos(theta),-0.25)
			var tangent := Vector2(side*1.12*cos(theta),0.97*sin(theta)).normalized()
			var radial := Vector2(side*sin(theta),-cos(theta)).normalized()
			for outward: int in [-1,1]:
				var direction := (tangent*0.80+radial*outward*0.60).normalized()
				var across := Vector2(-direction.y,direction.x)
				var length: float = 0.235-t*0.035
				var ridge := base+Vector3(direction.x,direction.y,-0.13)*length*0.52
				for segment: int in range(8):
					var a: float = segment/8.0
					var b: float = (segment+1)/8.0
					for half: int in [-1,1]:
						var ca := base+Vector3(direction.x*length*a,direction.y*length*a,-sin(a*PI)*0.020)
						var cb := base+Vector3(direction.x*length*b,direction.y*length*b,-sin(b*PI)*0.020)
						var ea := base+Vector3(direction.x*length*a+across.x*pow(sin(a*PI),0.85)*0.043*half,direction.y*length*a+across.y*pow(sin(a*PI),0.85)*0.043*half,0)
						var eb := base+Vector3(direction.x*length*b+across.x*pow(sin(b*PI),0.85)*0.043*half,direction.y*length*b+across.y*pow(sin(b*PI),0.85)*0.043*half,0)
						var points: Array[Vector3] = [ca,ea,eb,cb]
						_leaf_patch(tool,points)
				GarageFurnishings.tube(parent,base+Vector3(0,0,-0.003),ridge+Vector3(0,0,-0.003),0.003,edge,8)
	tool.index()
	var relief := MeshInstance3D.new()
	relief.name = "SculptedBrandLaurel"
	relief.mesh = tool.commit()
	relief.material_override = gold
	relief.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(relief)

static func _leaf_patch(tool: SurfaceTool, points: Array[Vector3]) -> void:
	# Relief geometry needs its folded face normals, rather than a flat mural normal.
	for indices: Vector3i in [Vector3i(0,1,2),Vector3i(0,2,3)]:
		var face: Array[Vector3] = [points[indices.x],points[indices.y],points[indices.z]]
		var normal: Vector3 = (face[1]-face[0]).cross(face[2]-face[0])
		if normal.length_squared() < 0.000000000001: continue
		if normal.z > 0: normal = -normal
		GarageEnvironment._polygon(tool,face,normal.normalized())

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
