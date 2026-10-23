extends RefCounted
## At most five featured medals and six earned major trophies, rebuilt on change.
static var _cup: ArrayMesh
static var _handle: TorusMesh
static func update(showroom: CarShowroom, service: Node) -> void:
	if service == null: return
	var wall: Node3D = showroom.find_child("GarageTrophyWall",true,false)
	if wall == null: return
	var earned: Array[Dictionary] = []
	var featured: Array[Dictionary] = []
	for f: Dictionary in AchievementProgress.catalog().families:
		var level: int = AchievementProgress.tier(f,service.source(f))
		if level == 0: continue
		var item: Dictionary = {"id":f.id,"title":f.title,"tier":level,"prestige":f.prestige}
		if f.id in service.featured(): featured.append(item)
		if f.prestige or (level >= 3 and f.id in ["races","clean","tracks"]): earned.append(item)
	var signature: String = JSON.stringify([earned,featured])
	if wall.get_meta("achievement_signature","") == signature: return
	wall.set_meta("achievement_signature",signature)
	var old: Node = wall.get_node_or_null("EarnedAchievements")
	if old != null:
		wall.remove_child(old)
		old.queue_free()
	var root := Node3D.new()
	root.name = "EarnedAchievements"
	wall.add_child(root)
	for i: int in range(mini(earned.size(),6)):
		var item: Dictionary = earned[i]
		var trophy := Node3D.new()
		trophy.name = "EarnedTrophy_"+item.id
		trophy.position = Vector3((i-2.5)*1.13,-1.20,-0.48)
		root.add_child(trophy)
		var metal: Material = GarageEnvironment.surface("achievementmetal"+str(item.tier)+str(item.prestige),AchievementBadge.METALS[3 if item.prestige else item.tier].to_html(false),0.58,0.34)
		GarageEnvironment.cylinder(trophy,Vector3(0,0.04,0),0.18,0.08,metal)
		GarageEnvironment.cylinder(trophy,Vector3(0,0.19,0),0.055,0.23,metal)
		_mesh(trophy,_cup_mesh(),Vector3.ZERO,metal)
		if _handle == null:
			_handle = TorusMesh.new()
			_handle.inner_radius = 0.065
			_handle.outer_radius = 0.085
			_handle.rings = 20
			_handle.ring_segments = 8
		for x: float in [-0.20,0.20]:
			var handle: MeshInstance3D = _mesh(trophy,_handle,Vector3(x,0.40,0),metal)
			handle.rotation.x = PI*0.5
		_caption(trophy,item.title,Vector3(0,-0.10,-0.25),0.0014)
	for i: int in range(mini(featured.size(),5)):
		var item: Dictionary = featured[i]
		var medal := Node3D.new()
		medal.name = "FeaturedMedal_"+item.id
		medal.position = Vector3(-3.18 if i < 3 else 3.18,0.78-(i%3)*0.68,-0.28)
		root.add_child(medal)
		var face: Material = GarageEnvironment.surface("achievementmedal"+str(item.tier)+str(item.prestige),AchievementBadge.METALS[3 if item.prestige else item.tier].to_html(false),0.48,0.43)
		var disc: MeshInstance3D = GarageEnvironment.cylinder(medal,Vector3.ZERO,0.18,0.035,face)
		disc.rotation.x = PI*0.5
		var monogram: String = ""
		for word: String in str(item.title).split(" "):
			if not word.is_empty() and monogram.length() < 3: monogram += word[0].to_upper()
		_caption(medal,monogram,Vector3(0,-0.035,-0.027),0.0021)
		_caption(medal,item.title,Vector3(0,-0.27,-0.045),0.00125)
	showroom.invalidate_render()

static func _caption(root: Node3D, text: String, at: Vector3, pixels: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = MenuStyle.DISPLAY
	label.font_size = 40
	label.pixel_size = pixels
	label.outline_size = 0
	label.modulate = MenuStyle.TEXT
	label.position = at
	label.rotation.y = PI
	root.add_child(label)

static func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

static func _cup_mesh() -> ArrayMesh:
	if _cup != null: return _cup
	# One shared, actually hollow turned cup, including the inner wall and rim.
	var profile: Array[Vector2] = [Vector2(0.045,0.27),Vector2(0.11,0.30),Vector2(0.175,0.39),Vector2(0.20,0.50),Vector2(0.18,0.50),Vector2(0.155,0.39),Vector2(0.09,0.32),Vector2(0.0,0.31)]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band: int in range(profile.size()-1):
		for i: int in range(24):
			var vertices: Array[Vector3] = []
			for spec: Vector2i in [Vector2i(band,i),Vector2i(band,i+1),Vector2i(band+1,i+1),Vector2i(band+1,i)]:
				var point: Vector2 = profile[spec.x]
				var angle: float = TAU*spec.y/24.0
				vertices.append(Vector3(point.x*cos(angle),point.y,point.x*sin(angle)))
			for index: int in [0,2,1,0,3,2]: tool.add_vertex(vertices[index])
	tool.generate_normals()
	_cup = tool.commit()
	return _cup
