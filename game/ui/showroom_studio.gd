class_name ShowroomStudio
extends RefCounted
## Original, seamless 360-degree studio. Only menu worlds own this scene.
static var cached_sky: Sky

static func build(world: Node3D, car: CarVisual) -> void:
	var environment := WorldEnvironment.new()
	environment.name = "StudioEnvironment"
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("111922")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b6c0d0")
	environment.environment.ambient_light_energy = 0.42
	environment.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	if cached_sky == null:
		cached_sky = Sky.new()
		cached_sky.radiance_size = Sky.RADIANCE_SIZE_128
		cached_sky.process_mode = Sky.PROCESS_MODE_QUALITY
		var material := ShaderMaterial.new()
		material.shader = preload("res://ui/studio_sky.gdshader")
		cached_sky.sky_material = material
	environment.environment.sky = cached_sky
	world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.name = "StudioKey"
	key.rotation_degrees = Vector3(-58,-38,0)
	key.light_color = Color("fff0db")
	key.light_energy = 0.82
	# The parked model's soft studio ground shadow is prepared once below.
	key.shadow_enabled = false
	key.directional_shadow_max_distance = 18.0
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.name = "StudioFill"
	fill.rotation_degrees = Vector3(-24,140,0)
	fill.light_color = Color("abc9ec")
	fill.light_energy = 0.3
	world.add_child(fill)
	var rim := SpotLight3D.new()
	rim.name = "StudioRim"
	rim.position = Vector3(-3.0,4.5,3.5)
	rim.light_energy = 1.5
	rim.light_color = Color("dce9ff")
	rim.spot_range = 14
	rim.spot_angle = 48
	world.add_child(rim)
	rim.look_at(Vector3(0,0.65,0))
	_cove(world)
	_studio_glass(car,{})
	_project_shadow(world,car,-key.global_basis.z)
	_contact(world,Vector3(0,0.004,0),Vector2(2.4,4.7)*HandlingConfig.BODY_SCALE,0.46)
	for wheel: Vector3 in car.wheel_rest_positions:
		_contact(world,Vector3(wheel.x*HandlingConfig.BODY_SCALE,0.007,wheel.z*HandlingConfig.BODY_SCALE),Vector2(0.60,0.8),0.66)

static func _studio_glass(node: Node, materials: Dictionary) -> void:
	if node is MeshInstance3D:
		var surface: Material = node.get_active_material(0)
		if surface is ShaderMaterial and surface.shader == preload("res://vehicle/window_reflection.gdshader"):
			if not materials.has(surface):
				var studio: ShaderMaterial = surface.duplicate() as ShaderMaterial
				studio.set_shader_parameter("studio_mode",true)
				materials[surface] = studio
			node.material_override = materials[surface]
	for child: Node in node.get_children(): _studio_glass(child,materials)

static func _project_shadow(world: Node3D, car: CarVisual, direction: Vector3) -> void:
	var points := PackedVector2Array()
	_shadow_points(car,direction,points)
	var hull: PackedVector2Array = Geometry2D.convex_hull(points)
	var bounds := Rect2(hull[0],Vector2.ZERO)
	for point: Vector2 in hull: bounds=bounds.expand(point)
	var support := PackedVector3Array()
	for index: int in range(24):
		var normal := Vector2(cos(index*TAU/24.0),sin(index*TAU/24.0))
		var maximum: float = -1000
		for point: Vector2 in hull: maximum=maxf(maximum,point.dot(normal))
		support.append(Vector3(normal.x,normal.y,maximum))
	var shadow := MeshInstance3D.new()
	shadow.name = "PreparedStudioShadow"
	var plane := PlaneMesh.new()
	plane.size = bounds.size+Vector2.ONE*0.6
	shadow.mesh=plane
	shadow.position=Vector3(bounds.get_center().x,0.003,bounds.get_center().y)
	shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var surface := ShaderMaterial.new()
	surface.shader=preload("res://ui/studio_projection.gdshader")
	surface.set_shader_parameter("support",support)
	shadow.material_override=surface
	world.add_child(shadow)

static func _shadow_points(node: Node, direction: Vector3, points: PackedVector2Array) -> void:
	if node is MeshInstance3D:
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				var position: Vector3 = node.global_transform*point
				position -= direction*(position.y/direction.y)
				points.append(Vector2(position.x,position.z))
	for child: Node in node.get_children(): _shadow_points(child,direction,points)

static func _cove(world: Node3D) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile: Array[Vector2] = [Vector2(0,0),Vector2(3,0),Vector2(6,0),Vector2(9,0)]
	for i: int in range(17):
		var angle: float = i*PI/32.0
		profile.append(Vector2(10+3*sin(angle),3*(1-cos(angle))))
	profile.append(Vector2(13,9))
	for row: int in range(profile.size()-1):
		for segment: int in range(96):
			var a: float = segment*TAU/96.0
			var b: float = (segment+1)*TAU/96.0
			var p: Vector2 = profile[row]
			var q: Vector2 = profile[row+1]
			var points: Array[Vector3] = [Vector3(sin(a)*p.x,p.y-0.014,cos(a)*p.x),Vector3(sin(b)*p.x,p.y-0.014,cos(b)*p.x),Vector3(sin(b)*q.x,q.y-0.014,cos(b)*q.x),Vector3(sin(a)*q.x,q.y-0.014,cos(a)*q.x)]
			for index: int in [0,1,2,0,2,3]:
				var angle: float = a if index in [0,3] else b
				var profile_index: int = row if index in [0,1] else row+1
				var tangent: Vector2 = (profile[mini(profile_index+1,profile.size()-1)]-profile[maxi(profile_index-1,0)]).normalized()
				tool.set_normal(Vector3(-sin(angle)*tangent.y,tangent.x,-cos(angle)*tangent.y))
				tool.add_vertex(points[index])
	var mesh := MeshInstance3D.new()
	mesh.name = "SeamlessStudioCove"
	mesh.mesh = tool.commit()
	var floor_material := ShaderMaterial.new()
	floor_material.shader = preload("res://ui/studio_floor.gdshader")
	mesh.material_override = floor_material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mesh)

static func _contact(world: Node3D, position: Vector3, dimensions: Vector2, strength: float) -> void:
	var shadow := MeshInstance3D.new()
	shadow.name = "StudioContact"
	var quad := QuadMesh.new()
	quad.size = dimensions
	shadow.mesh = quad
	shadow.rotation.x = -PI*0.5
	shadow.position = position
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var surface := ShaderMaterial.new()
	surface.shader = preload("res://ui/studio_contact.gdshader")
	surface.set_shader_parameter("strength",strength)
	shadow.material_override = surface
	world.add_child(shadow)
