extends RefCounted
## Original abstract challenge display; no workshop assets or live reflections.
const DECK_HEIGHT: float = 0.22

static func build(world: Node3D, car: CarVisual) -> Node3D:
	var studio := Node3D.new()
	studio.name = "ChallengeAbstractStudio"
	world.add_child(studio)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("101b24")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c6d2d8")
	environment.environment.ambient_light_energy = 0.48
	studio.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48,-35,0)
	key.light_color = Color("fff0dc")
	key.light_energy = 0.94
	studio.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-22,145,0)
	fill.light_color = Color("a7c9d8")
	fill.light_energy = 0.38
	studio.add_child(fill)
	ShowroomStudio._cove(studio)
	var backdrop: MeshInstance3D = studio.get_node("SeamlessStudioCove")
	backdrop.name = "AbstractBackdrop"
	var finish := ShaderMaterial.new()
	finish.shader = preload("res://ui/challenge_studio.gdshader")
	backdrop.material_override = finish
	ShowroomStudio._contact(studio,Vector3(0,0.002,0),Vector2.ONE*7.6,0.42)
	return build_pedestal(world,car)

static func build_pedestal(world: Node3D, car: CarVisual) -> Node3D:
	var stage := Node3D.new()
	stage.name = "Turntable"
	world.add_child(stage)
	_disc(stage,3.22,0.08,0.04,Color("101c25"))
	_disc(stage,3.19,0.08,0.12,Color("75674e"))
	_disc(stage,3.17,0.06,0.19,Color("243743"))
	car.reparent(stage)
	car.position.y = DECK_HEIGHT
	ShowroomStudio._studio_glass(car,{})
	ShowroomStudio._contact(stage,Vector3(0,DECK_HEIGHT+0.003,0),Vector2(2.4,4.7)*HandlingConfig.BODY_SCALE,0.44)
	for wheel: Vector3 in car.wheel_rest_positions:
		ShowroomStudio._contact(stage,Vector3(wheel.x*HandlingConfig.BODY_SCALE,DECK_HEIGHT+0.006,wheel.z*HandlingConfig.BODY_SCALE),Vector2(0.6,0.8),0.68)
	return stage

static func _disc(parent: Node3D, radius: float, height: float, center: float, color: Color) -> void:
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 64
	disc.mesh = mesh
	disc.position.y = center
	var surface := StandardMaterial3D.new()
	surface.albedo_color = color
	surface.roughness = 0.82
	surface.metallic = 0.12
	disc.material_override = surface
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(disc)
