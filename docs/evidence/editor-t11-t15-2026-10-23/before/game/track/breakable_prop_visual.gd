class_name BreakablePropVisual
extends RefCounted
## Prepared damage meshes and two debris batches; never changes canonical state.
static var debris_meshes: Dictionary = {}
static var damage_meshes: Dictionary = {}
static var shared_material: StandardMaterial3D

static func build(node: Node3D, kit: Node, kind: String, scale: float) -> void:
	node.set_meta("breakable_kind",kind)
	node.set_meta("authored_yaw",node.rotation.y)
	for phase: int in range(1 if kind in PropWinterCraft.BREAKABLE else 3):
		var key: String = CreatorPropVisual.VERSION+"/"+kind+"/"+str(phase)
		if not damage_meshes.has(key):
			var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			if phase == 0: CreatorPropVisual.append(tool,kit,kind,Vector3.ZERO,1,0)
			elif kind == "hay_bale": PropEquipment.hay(tool,phase)
			else: _damaged_crate(tool,phase)
			if kind not in PropWinterCraft.BREAKABLE: tool.generate_normals()
			tool.index()
			if damage_meshes.size() >= 12: damage_meshes.erase(damage_meshes.keys()[0])
			damage_meshes[key] = PropGeometry.commit(tool)
		var mesh := MeshInstance3D.new()
		mesh.name = "DamagePhase"+str(phase); mesh.mesh = damage_meshes[key]
		mesh.material_override = PropWinterCraft.material(kind=="ice_lantern") if kind in PropWinterCraft.BREAKABLE else material()
		mesh.scale = Vector3.ONE*scale
		mesh.visible = phase == 0
		node.add_child(mesh)

static func material() -> StandardMaterial3D:
	if shared_material == null:
		shared_material = VisualGeometry.material(Color.WHITE)
		shared_material.vertex_color_use_as_albedo = true; shared_material.vertex_color_is_srgb = true
		shared_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return shared_material

static func present(node: Node3D, row: Array, integrity: float) -> void:
	var kind: String = node.get_meta("breakable_kind")
	node.visible = integrity > 0
	node.scale = Vector3.ONE*BreakableProps.size_fraction(kind,integrity)
	node.rotation.y = float(node.get_meta("authored_yaw"))+float(row[4])
	node.rotation.z = clampf(float(row[2])*0.012,-0.12,0.12)
	node.rotation.x = clampf(float(row[3])*0.012,-0.12,0.12)
	var phase: int = 0 if kind in PropWinterCraft.BREAKABLE or integrity > 0.96 else 1 if integrity > 0.38 else 2
	for child: MeshInstance3D in node.get_children(): child.visible = child.name == "DamagePhase"+str(phase)

static func _damaged_crate(tool: SurfaceTool, phase: int) -> void:
	var wood := PropEquipment.WOOD
	# Open interior, missing/split boards and broken diagonal braces.
	for i: int in range(5): PropGeometry.box(tool,Vector3(-0.43+i*0.215,0.055,0),Vector3(0.195,0.07,1.06),wood.darkened(0.16),0.008)
	for side: float in [-1.0,1.0]:
		for i: int in range(5):
			if i == 1 or (phase == 2 and i == 3): continue
			var height: float = 0.92 if i%2 == 0 else 0.56
			PropGeometry.box(tool,Vector3(-0.43+i*0.215,height*0.5+0.06,side*0.525),Vector3(0.196,height,0.04),wood.lightened((i%3)*0.03),0.008)
			PropGeometry.box(tool,Vector3(side*0.525,height*0.5+0.06,-0.43+i*0.215),Vector3(0.04,height,0.196),wood,0.008)
		PropGeometry.box(tool,Vector3(0,0.14,side*0.56),Vector3(1.10,0.13,0.07),wood.lightened(0.10),0.012)
		PropGeometry.beam(tool,Vector3(-0.42,0.27,side*0.56),Vector3(-0.05,0.47,side*0.56),0.12,0.06,wood.lightened(0.08))
		PropGeometry.beam(tool,Vector3(0.18,0.62,side*0.56),Vector3(0.41,0.81,side*0.56),0.12,0.06,wood.lightened(0.08))
	for i: int in [0,2,4]:
		if phase == 2 and i == 2: continue
		PropGeometry.box(tool,Vector3(-0.43+i*0.215,0.93-i*0.025,0.17),Vector3(0.196,0.055,0.71),wood.lightened(0.05),0.009)

static func ensure_debris(parent: Node3D, winter: bool = false) -> void:
	for kind: int in ([BreakableProps.HAY,BreakableProps.WOOD,BreakableProps.SNOW,BreakableProps.ICE,BreakableProps.POWDER] if winter else [BreakableProps.HAY,BreakableProps.WOOD]):
		var name: String = _debris_name(kind)
		if parent.has_node(name): continue
		var node := MultiMeshInstance3D.new(); node.name = name
		node.multimesh = MultiMesh.new(); node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		node.multimesh.use_custom_data = kind==BreakableProps.POWDER
		node.multimesh.mesh = _debris_mesh(kind)
		if kind==BreakableProps.POWDER:
			var powder:=ShaderMaterial.new(); powder.shader=preload("res://track/winter_break_powder.gdshader")
			node.material_override=powder
		else: node.material_override = PropWinterCraft.material(kind==BreakableProps.ICE) if kind>=BreakableProps.SNOW else material()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)

static func _debris_name(kind: int) -> String:
	return ["LooseHayFragments","WoodFragments","SnowChunks","IceShards","SnowPowder"][kind]

static func _debris_mesh(kind: int) -> ArrayMesh:
	if debris_meshes.has(kind): return debris_meshes[kind]
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	if kind==BreakableProps.POWDER:
		var quad:=QuadMesh.new(); quad.size=Vector2.ONE
		tool.create_from(quad,0)
	elif kind==BreakableProps.SNOW:
		PropWinterCraft.ball(tool,Vector3(0,0.25,0),Vector3(0.53,0.36,0.47),PropWinterCraft.SNOW,12,6)
	elif kind==BreakableProps.ICE:
		var points: Array[Vector3]=[Vector3(-0.55,0.02,-0.35),Vector3(0.55,0.02,-0.20),Vector3(0.22,0.05,0.41),Vector3(-0.21,0.03,0.30),Vector3(-0.13,0.79,-0.02)]
		for i: int in range(4): PropGeometry.face(tool,[points[i],points[(i+1)%4],points[4]],PropWinterCraft.ICE,Vector3(points[i].x,0.2,points[i].z))
		PropGeometry.face(tool,[points[3],points[2],points[1],points[0]],PropWinterCraft.ICE,Vector3.DOWN)
	elif kind == BreakableProps.WOOD:
		PropGeometry.box(tool,Vector3(0,0.03,0),Vector3(1,0.06,1),PropEquipment.WOOD,0.012)
		for side: float in [-1.0,1.0]:
			PropGeometry.face(tool,[Vector3(side*0.50,0.004,-0.46),Vector3(side*0.56,0.031,0.15),Vector3(side*0.50,0.058,0.46)],PropEquipment.WOOD.lightened(0.18))
	else:
		for i: int in range(40):
			var a: float = i*2.4
			var p := Vector3(cos(a)*0.35,0.01,sin(a)*0.35)
			var reach := Vector3(cos(a+0.8)*0.32,0.012+(i%3)*0.012,sin(a+0.8)*0.32)
			var side := Vector3(-sin(a)*0.026,0,cos(a)*0.026)
			PropGeometry.face(tool,[p-side,p+reach,p+side],Color("a68c55").lightened((i%3)*0.055))
	tool.generate_normals(); tool.index(); debris_meshes[kind] = tool.commit()
	return debris_meshes[kind]

static func update_debris(parent: Node3D, state: VehicleState) -> void:
	if not parent.has_node("WoodFragments"): return
	var groups: Dictionary={}
	for row: Array in state.prop_fragments:
		var kind: int=int(row[0])
		if not groups.has(kind): groups[kind]=[]
		groups[kind].append(row)
	for kind: int in [BreakableProps.HAY,BreakableProps.WOOD,BreakableProps.SNOW,BreakableProps.ICE,BreakableProps.POWDER]:
		if not parent.has_node(_debris_name(kind)): continue
		var node: MultiMeshInstance3D = parent.get_node(_debris_name(kind))
		var pieces: Array = groups.get(kind,[])
		if node.multimesh.instance_count != pieces.size(): node.multimesh.instance_count = pieces.size()
		var cache: Dictionary = node.get_meta("debris_draw_state",{})
		if cache.get("resource") != node.multimesh.get_instance_id() or cache.get("count") != pieces.size():
			cache = {"resource":node.multimesh.get_instance_id(),"count":pieces.size(),"poses":{}}
			node.set_meta("debris_draw_state",cache)
		for i: int in range(pieces.size()):
			var row: Array = pieces[i]
			var size := Vector3(float(row[8]),1,float(row[9]))
			var height: float=0.023
			if parent is NativeTrackVisual and parent.desert_relief != null: height += parent.desert_relief.height(Vector2(row[2],row[3]))
			var basis:=Basis(Vector3.UP,float(row[6]))
			if kind>=BreakableProps.SNOW:
				var age: float=maxf(0.0,float(row[10])-float(row[11]))
				var life: float=clampf(float(row[11])/float(row[10]),0.0,1.0)
				if kind==BreakableProps.POWDER:
					size=Vector3.ONE*float(row[8])*(2.5+age*4.5)
					height=0.16+age*0.70
					node.multimesh.set_instance_custom_data(i,Color(1,1,1,life))
				else:
					var fade: float=smoothstep(0.0,0.65,float(row[11]))
					size=Vector3(float(row[8]),float(row[8]),float(row[9]))*fade
					height+=maxf(0.0,(2.0+(i%3)*0.45)*age-4.9*age*age)
					basis=basis*Basis(Vector3.RIGHT,age*(i%2*2-1)*3.0*maxf(0.0,1.0-age*1.4))
			var pose := Transform3D(basis.scaled(size),Vector3(row[2],height,-float(row[3])))
			if cache.poses.get(i) == pose: continue
			cache.poses[i] = pose
			node.multimesh.set_instance_transform(i,pose)
