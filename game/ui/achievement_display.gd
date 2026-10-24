extends RefCounted
## Forty permanent wall positions, five featured medals, six major trophies.
## All faces share a static atlas; unchanged cached progress never rebuilds them.
static var _cup: ArrayMesh
static var _handle: TorusMesh
static var _face: ShaderMaterial
static var _disc: CylinderMesh

static func update(showroom: CarShowroom, service: Node) -> void:
	if service == null: return
	var wall: Node3D = showroom.find_child("GarageTrophyWall",true,false)
	if wall == null: return
	var earned: Array[Dictionary] = []
	var featured: Array[Dictionary] = []
	var collection: Array[Dictionary] = []
	var choices: Array = service.featured()
	var world: Dictionary = showroom.get_meta("world_ranking_honors",{})
	for honor: Array in [["season_titles","Season champion"],["weeks_no1","World No. 1"],["weeks_top100","World Top 100"]]:
		if int(world.get(honor[0],0)) > 0:
			earned.append({"id":"world_"+str(honor[0]),"title":str(honor[1]),"tier":1,"prestige":true})
	for index: int in range(AchievementProgress.catalog().families.size()):
		var f: Dictionary = AchievementProgress.catalog().families[index]
		var level: int = AchievementProgress.tier(f,service.source(f))
		var item: Dictionary = {"id":f.id,"title":f.title,"tier":level,"prestige":f.prestige,"index":index}
		collection.append(item)
		if level == 0: continue
		if f.id in choices: featured.append(item)
		if f.prestige or (level >= 3 and f.id in ["races","clean","tracks"]): earned.append(item)
	var signature: String = JSON.stringify([collection,featured,world])
	if wall.get_meta("achievement_signature","") == signature: return
	wall.set_meta("achievement_signature",signature)
	var old: Node = wall.get_node_or_null("EarnedAchievements")
	if old != null:
		wall.remove_child(old)
		old.queue_free()
	var root := Node3D.new()
	root.name = "EarnedAchievements"
	wall.add_child(root)
	var wall_faces: Array[Dictionary] = []
	for item: Dictionary in collection:
		var index: int = item.index
		var within: int = index%20
		var at := Vector3((3.48 if index < 20 else -1.80)-(within%5)*0.42,0.79-(within/5)*0.42,-0.25)
		var slot := Node3D.new()
		slot.name = "AchievementSlot_"+item.id
		slot.position = at
		slot.set_meta("family",item.id)
		slot.set_meta("tier",item.tier)
		slot.set_meta("hit_radius",0.20)
		root.add_child(slot)
		wall_faces.append({"item":item,"at":at})
	_medals(root,wall_faces,"CollectionMedalFaces",0.40)
	_caption(root,"CAREER MILESTONES",Vector3(2.64,1.075,-0.255),0.0023)
	_caption(root,"MASTERY & HONORS",Vector3(-2.64,1.075,-0.255),0.0023)
	_caption(root,"FEATURED",Vector3(0,0.035,-0.255),0.0019)
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
	var featured_faces: Array[Dictionary] = []
	for i: int in range(5):
		var at := Vector3((i-2)*0.49,-0.28,-0.28)
		if i >= featured.size():
			# Recessed mounts stay empty until the player features an earned medal.
			var mount: MeshInstance3D = GarageEnvironment.cylinder(root,at,0.12,0.008,GarageEnvironment.surface("featuredempty","1d2d33",0.12,0.72))
			mount.rotation.x = PI*0.5
			continue
		var item: Dictionary = featured[i]
		var medal := Node3D.new()
		medal.name = "FeaturedMedal_"+item.id
		medal.position = at
		medal.set_meta("family",item.id)
		medal.set_meta("tier",item.tier)
		medal.set_meta("hit_radius",0.23)
		root.add_child(medal)
		featured_faces.append({"item":item,"at":at})
	_medals(root,featured_faces,"FeaturedMedalFaces",0.46)
	showroom.invalidate_render()

static func pick(showroom: CarShowroom, point: Vector2) -> String:
	var wall: Node3D = showroom.find_child("GarageTrophyWall",true,false)
	if wall == null or not showroom.trophy_view: return ""
	var display: Node3D = wall.get_node_or_null("EarnedAchievements")
	if display == null: return ""
	var scale: Vector2 = showroom.size/Vector2(showroom.showroom_viewport.size)
	var nearest: float = INF
	var result: String = ""
	# Only on a completed tap: at most forty family and five featured positions.
	for slot: Node in display.get_children():
		if not slot.has_meta("family"): continue
		var position: Vector3 = (slot as Node3D).global_position
		if showroom.camera.is_position_behind(position): continue
		var center: Vector2 = showroom.camera.unproject_position(position)*scale
		var edge: Vector2 = showroom.camera.unproject_position(position+Vector3.UP*float(slot.get_meta("hit_radius")))*scale
		var radius: float = maxf(22.0,center.distance_to(edge))
		var distance: float = point.distance_to(center)
		if distance <= radius and distance < nearest:
			nearest = distance
			result = str(slot.get_meta("family"))
	return result

static func _medals(root: Node3D, items: Array[Dictionary], label: String, width: float) -> void:
	if items.is_empty(): return
	if _face == null:
		_face = ShaderMaterial.new()
		_face.shader = preload("res://ui/achievement_wall.gdshader")
		_face.set_shader_parameter("medals",AchievementBadge.ATLAS)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*width
	var faces := MultiMesh.new()
	faces.transform_format = MultiMesh.TRANSFORM_3D
	faces.use_custom_data = true
	faces.mesh = quad
	faces.instance_count = items.size()
	var metals: Dictionary = {}
	for i: int in range(items.size()):
		var item: Dictionary = items[i].item
		var at: Vector3 = items[i].at
		faces.set_instance_transform(i,Transform3D(Basis(Vector3.UP,PI),at))
		faces.set_instance_custom_data(i,Color(item.index,item.tier,0.48 if item.tier == 0 else 1.0,0))
		if item.tier == 0: continue
		var metal: int = 3 if item.prestige else item.tier
		if not metals.has(metal): metals[metal] = []
		metals[metal].append(at+Vector3(0,width*0.055,0.015))
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = faces
	instance.material_override = _face
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instance)
	# Shared minted edges give the earned pieces actual relief and thickness.
	if _disc == null:
		_disc = CylinderMesh.new()
		_disc.top_radius = 0.35
		_disc.bottom_radius = 0.34
		_disc.height = 0.045
		_disc.radial_segments = 32
	for metal: int in metals:
		var discs := MultiMesh.new()
		discs.transform_format = MultiMesh.TRANSFORM_3D
		discs.mesh = _disc
		discs.instance_count = metals[metal].size()
		for i: int in range(metals[metal].size()):
			discs.set_instance_transform(i,Transform3D(Basis(Vector3.RIGHT,PI*0.5).scaled(Vector3.ONE*width),metals[metal][i]))
		var edges := MultiMeshInstance3D.new()
		edges.name = label+"Edges"+str(metal)
		edges.multimesh = discs
		edges.material_override = GarageEnvironment.surface("medalrim"+str(metal),AchievementBadge.METALS[metal].to_html(false),0.65,0.34)
		edges.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(edges)

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
