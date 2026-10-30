class_name GarageEnvironment
extends RefCounted
## Original authored workshop and motorised display deck. Menu-only geometry.
const DECK_HEIGHT: float = 0.22
const DECK_RADIUS: float = 3.65
const ROOF_CUTAWAY_HEIGHT: float = 4.95
static var surfaces: Dictionary = {}
static var architecture_scene: PackedScene
static var cabinet_meshes: Dictionary = {}

static func deck_finish() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://ui/garage_deck.gdshader")
	return material

static func surface(id: String, color: String, metal: float = 0.0, roughness: float = 0.8, glow: float = 0.0) -> StandardMaterial3D:
	if surfaces.has(id): return surfaces[id]
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(color)
	result.metallic = metal
	result.roughness = roughness
	result.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	if glow > 0:
		result.emission_enabled = true
		result.emission = Color(color)
		result.emission_energy_multiplier = glow
	surfaces[id] = result
	return result

static func box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = bevel_box(size)
	node.position = at
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 96
	node.mesh = mesh
	node.position = at
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func ring(parent: Node3D, radius: float, y: float, thickness: float, material: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 96
	mesh.ring_segments = 8
	node.mesh = mesh
	node.position.y = y
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)

static func build(world: Node3D, car: CarVisual, thumbnail: bool) -> Node3D:
	var shell := Node3D.new()
	shell.name = "GarageArchitecture"
	world.add_child(shell)
	var wall: Material = GarageMaterials.finish("garagewall","26323b",0.03,0.82,0)
	var inset := surface("inset", "141e27")
	var steel := surface("steel", "414d54", 0.4, 0.7)
	var edges := surface("edges", "657079", 0.5, 0.6)
	var yellow := surface("yellow", "b49445", 0.1)
	var lamp := surface("lamp", "f0dfbd", 0, 0.8, 1.2)
	var floor := MeshInstance3D.new()
	floor.name = "GarageConcrete"
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(48, 44)
	floor.mesh = floor_mesh
	var finish := ShaderMaterial.new()
	finish.shader = preload("res://ui/garage_floor.gdshader")
	floor.material_override = finish
	floor.position.y = -0.025
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(floor)
	if architecture_scene != null:
		shell.add_child(architecture_scene.instantiate())
	else:
		var roof := Node3D.new()
		roof.name = "GarageRoof"
		shell.add_child(roof)
		box(shell, Vector3(0, 3.1, 9), Vector3(21.6, 6.2, 0.3), wall)
		box(shell, Vector3(-10.6, 3.1, 0), Vector3(0.3, 6.2, 18), wall)
		box(shell, Vector3(10.6, 3.1, 0), Vector3(0.3, 6.2, 18), wall)
		box(roof, Vector3(0, 5.84, 0), Vector3(21.2, 0.12, 18), inset)
		# Recessed sectional door, inset reveals, runners, bottom gasket and handle.
		box(shell, Vector3(0, 2.4, 8.79), Vector3(8.8, 4.8, 0.12), inset)
		for index: int in range(20):
			box(shell, Vector3(0, 0.12 + index * 0.225, 8.67), Vector3(8.25, 0.203, 0.08), GarageMaterials.finish("shuttersteel","414d54",0.35,0.59,1))
			box(shell, Vector3(0, 0.195 + index * 0.225, 8.615), Vector3(8.25, 0.016, 0.012), edges)
		for x: float in [-4.3, 4.3]:
			box(shell, Vector3(x, 2.4, 8.55), Vector3(0.10, 4.8, 0.22), edges)
		box(shell, Vector3(0, 0.055, 8.57), Vector3(8.25, 0.11, 0.12), inset)
		box(shell, Vector3(0, 0.8, 8.48), Vector3(0.62, 0.045, 0.10), edges)
		box(shell, Vector3(0, 4.85, 8.43), Vector3(8.9, 0.24, 0.42), inset)
		# Repeating structural bays and a quiet warm dado line unify the room.
		for x: float in [-10.3, -4.55, 4.55, 10.3]:
			box(shell, Vector3(x, 2.8, 8.55), Vector3(0.26, 5.6, 0.46), steel)
			box(shell, Vector3(x, 0.38, 8.27), Vector3(0.39, 0.76, 0.12), yellow)
		for x: float in [-7.4, 7.4]:
			box(shell, Vector3(x, 0.085, 8.64), Vector3(5.5, 0.045, 0.10), yellow)
		for z: float in [1.0, 5.5, 8.3]:
			box(roof, Vector3(0, 5.65, z), Vector3(21.2, 0.24, 0.25), steel)
			box(roof, Vector3(0, 5.48, z), Vector3(6.5, 0.05, 0.34), lamp)
		_workbench(shell, Vector3(6.35, 0, 7.65))
		_cabinet(shell, Vector3(-6.9, 0, 7.65))
		_tyre_rack(shell, Vector3(9.2, 0, 7.6))
		GarageDetails.build(shell)
		GarageDrain.build(shell)
		preload("res://ui/garage_record_station.gd").build(shell)
		_batch(roof)
		_batch(shell)
		_set_owner(shell, shell)
		var prepared := PackedScene.new()
		if prepared.pack(shell) == OK: architecture_scene = prepared
	build_lighting(world, thumbnail)
	return build_pedestal(world, car)

static func build_lighting(world: Node3D, thumbnail: bool, transparent: bool = false) -> WorldEnvironment:
	var environment := WorldEnvironment.new()
	environment.name = "GarageEnvironment"
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.TRANSPARENT if transparent else Color("101923")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b6c5d0")
	environment.environment.ambient_light_energy = 0.34
	if ShowroomStudio.cached_sky == null:
		ShowroomStudio.cached_sky = Sky.new()
		ShowroomStudio.cached_sky.radiance_size = Sky.RADIANCE_SIZE_128
		var sky_finish := ShaderMaterial.new()
		sky_finish.shader = preload("res://ui/studio_sky.gdshader")
		ShowroomStudio.cached_sky.sky_material = sky_finish
	environment.environment.sky = ShowroomStudio.cached_sky
	environment.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.name = "GarageKey"
	key.rotation_degrees = Vector3(-65, -38, 0)
	key.light_color = Color("f7e8cf")
	key.light_energy = 0.78
	key.shadow_enabled = not thumbnail
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 12.0
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.name = "GarageFill"
	fill.rotation_degrees = Vector3(-30, 135, 0)
	fill.light_color = Color("96b3ce")
	fill.light_energy = 0.18
	world.add_child(fill)
	var rim := SpotLight3D.new()
	rim.name = "GarageRim"
	rim.position = Vector3(-4, 5.2, 5)
	rim.light_color = Color("d6e6f0")
	rim.light_energy = 1.05
	rim.spot_range = 16
	rim.spot_angle = 54
	world.add_child(rim)
	rim.look_at(Vector3(0, 0.8, 0))
	return environment

static func build_pedestal(world: Node3D, car: CarVisual) -> Node3D:
	var inset: Material = surfaces.inset
	var steel: Material = surfaces.steel
	var edges: Material = surfaces.edges
	var stage := Node3D.new()
	stage.name = "Turntable"
	world.add_child(stage)
	var radius: float = DECK_RADIUS
	cylinder(stage, Vector3(0, 0.035, 0), radius + 0.13, 0.07, inset)
	cylinder(stage, Vector3(0, 0.11, 0), radius, 0.17, steel)
	cylinder(stage, Vector3(0, 0.205, 0), radius - 0.055, 0.03, deck_finish())
	ring(stage, radius + 0.018, 0.085, 0.014, surface("rimlight", "d8ba64", 0.1, 0.65, 0.45))
	ring(stage, radius - 0.04, 0.216, 0.015, edges)
	for index: int in range(24):
		var angle: float = index * TAU / 24.0
		var mark := box(stage, Vector3(sin(angle) * (radius - 0.2), 0.222, cos(angle) * (radius - 0.2)), Vector3(0.035, 0.003, 0.11), inset)
		mark.rotation.y = angle
	_batch(stage)
	car.reparent(stage)
	car.position.y = DECK_HEIGHT
	ShowroomStudio._studio_glass(car, {})
	ShowroomStudio._contact(stage, Vector3(0, DECK_HEIGHT + 0.003, 0), Vector2(2.4, 4.7) * HandlingConfig.BODY_SCALE, 0.40)
	for wheel: Vector3 in car.wheel_rest_positions:
		ShowroomStudio._contact(stage, Vector3(wheel.x * HandlingConfig.BODY_SCALE, DECK_HEIGHT + 0.006, wheel.z * HandlingConfig.BODY_SCALE), Vector2(0.6, 0.8), 0.65)
	ShowroomStudio._contact(stage, Vector3(0, 0.002, 0), Vector2.ONE * (radius * 2.2), 0.52)
	return stage

static func _workbench(root: Node3D, position: Vector3) -> void:
	var bench := Node3D.new()
	bench.name = "GarageWorkbench"
	bench.position = position
	bench.scale = Vector3.ONE * 0.83
	root.add_child(bench)
	GarageFurnishings.workbench(bench)

static func _cabinet(root: Node3D, position: Vector3) -> void:
	var cabinet := Node3D.new()
	cabinet.name = "GarageToolStorage"
	cabinet.position = position
	root.add_child(cabinet)
	GarageFurnishings.cabinet(cabinet)

static func _tyre_rack(root: Node3D, position: Vector3) -> void:
	var rack := Node3D.new()
	rack.name = "GarageTyreRack"
	rack.position = position
	root.add_child(rack)
	GarageFurnishings.tyre_rack(rack)

static func _batch(root: Node3D) -> void:
	var groups: Dictionary = {}
	_collect(root, Transform3D.IDENTITY, groups)
	for source: Material in groups:
		var merged := MeshInstance3D.new()
		merged.name = "PreparedGarageMesh"
		merged.mesh = (groups[source] as SurfaceTool).commit()
		merged.material_override = source
		merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(merged)

static func _collect(node: Node3D, transform: Transform3D, groups: Dictionary) -> void:
	for child: Node in node.get_children():
		if not child is Node3D: continue
		if child.name in ["GarageRoof","GarageVinyl","GarageRecordSleeves"]: continue
		var local: Transform3D = transform * child.transform
		if child is MeshInstance3D:
			var material: Material = child.material_override
			if not groups.has(material):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[material] = tool
			(groups[material] as SurfaceTool).append_from(child.mesh, 0, local)
			node.remove_child(child)
			child.queue_free()
		else: _collect(child, local, groups)

static func _set_owner(node: Node, owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner
		_set_owner(child, owner)

static func bevel_box(dimensions: Vector3) -> ArrayMesh:
	if cabinet_meshes.has(dimensions): return cabinet_meshes[dimensions]
	var half: Vector3 = dimensions * 0.5
	var bevel: float = minf(0.025, minf(half.x, minf(half.y, half.z)) * 0.18)
	var core: Vector3 = half - Vector3.ONE * bevel
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sign_axis: float in [-1.0, 1.0]:
		_polygon(tool, [Vector3(sign_axis*half.x,-core.y,-core.z),Vector3(sign_axis*half.x,core.y,-core.z),Vector3(sign_axis*half.x,core.y,core.z),Vector3(sign_axis*half.x,-core.y,core.z)], Vector3(sign_axis,0,0))
		_polygon(tool, [Vector3(-core.x,sign_axis*half.y,-core.z),Vector3(core.x,sign_axis*half.y,-core.z),Vector3(core.x,sign_axis*half.y,core.z),Vector3(-core.x,sign_axis*half.y,core.z)], Vector3(0,sign_axis,0))
		_polygon(tool, [Vector3(-core.x,-core.y,sign_axis*half.z),Vector3(core.x,-core.y,sign_axis*half.z),Vector3(core.x,core.y,sign_axis*half.z),Vector3(-core.x,core.y,sign_axis*half.z)], Vector3(0,0,sign_axis))
	for a: float in [-1.0,1.0]:
		for b: float in [-1.0,1.0]:
			_polygon(tool,[Vector3(-core.x,a*half.y,b*core.z),Vector3(core.x,a*half.y,b*core.z),Vector3(core.x,a*core.y,b*half.z),Vector3(-core.x,a*core.y,b*half.z)],Vector3(0,a,b))
			_polygon(tool,[Vector3(a*half.x,-core.y,b*core.z),Vector3(a*half.x,core.y,b*core.z),Vector3(a*core.x,core.y,b*half.z),Vector3(a*core.x,-core.y,b*half.z)],Vector3(a,0,b))
			_polygon(tool,[Vector3(a*half.x,b*core.y,-core.z),Vector3(a*half.x,b*core.y,core.z),Vector3(a*core.x,b*half.y,core.z),Vector3(a*core.x,b*half.y,-core.z)],Vector3(a,b,0))
			for c: float in [-1.0,1.0]:
				_polygon(tool,[Vector3(a*half.x,b*core.y,c*core.z),Vector3(a*core.x,b*half.y,c*core.z),Vector3(a*core.x,b*core.y,c*half.z)],Vector3(a,b,c))
	tool.index()
	var result: ArrayMesh = tool.commit()
	cabinet_meshes[dimensions] = result
	return result

static func _polygon(tool: SurfaceTool, points: Array[Vector3], outward: Vector3) -> void:
	var normal: Vector3 = outward.normalized()
	var reverse: bool = (points[1]-points[0]).cross(points[2]-points[0]).dot(normal) > 0.0
	for triangle: int in range(1, points.size()-1):
		for index: int in ([0,triangle+1,triangle] if reverse else [0,triangle,triangle+1]):
			tool.set_normal(normal)
			tool.set_uv(Vector2(points[index].x, points[index].z))
			tool.add_vertex(points[index])
