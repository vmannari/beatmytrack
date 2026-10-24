extends Node3D
## Connected garden hose with short ballistic droplets; no cone or ribbon surfaces.
const Geometry = preload("res://ui/garage_hose_geometry.gd")
const WashGeometry = preload("res://ui/garage_wash_geometry.gd")
const LAYERS: int = 1 | GarageReflections.ROOM_LAYER | GarageReflections.CAR_LAYER
const REEL_POSITION := Vector3(2.65,0.22,1.0)
const REEL_OUTLET := Vector3(0.245,0.43,-0.14)
const SPRAY_COUNT: int = 256
var nozzle: Node3D
var reel: Node3D
var cable: MeshInstance3D
var cable_points := PackedVector3Array()
var spray: MultiMeshInstance3D

func _ready() -> void:
	name = "ConnectedWashHose"
	nozzle = Node3D.new()
	nozzle.name = "SprayNozzle"
	add_child(nozzle)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("607477")
	steel.metallic = 0.55
	steel.roughness = 0.44
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color("263536")
	rubber.roughness = 0.82
	_part(nozzle,"Nozzle",WashGeometry.nozzle(),steel)
	_part(nozzle,"Grip",Geometry.grip(),rubber)
	reel = Node3D.new()
	reel.name = "HoseReel"
	add_child(reel)
	reel.position = REEL_POSITION
	_part(reel,"ReelFrame",Geometry.reel(),steel)
	_part(reel,"CoiledHose",Geometry.coil(),rubber)
	var cable_finish := ShaderMaterial.new()
	cable_finish.shader = preload("res://ui/garage_hose_cable.gdshader")
	cable = _part(self,"ContinuousHose",Geometry.cable(),cable_finish)
	var spray_finish := ShaderMaterial.new()
	spray_finish.shader = preload("res://ui/garage_hose_spray.gdshader")
	spray = MultiMeshInstance3D.new()
	spray.name = "FlowingWaterDroplets"
	spray.multimesh = MultiMesh.new()
	spray.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	spray.multimesh.use_custom_data = true
	spray.multimesh.mesh = Geometry.droplet()
	spray.multimesh.instance_count = SPRAY_COUNT
	spray.material_override = spray_finish
	spray.layers = LAYERS
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(spray)
	for index: int in range(SPRAY_COUNT):
		spray.multimesh.set_instance_transform(index,Transform3D.IDENTITY)
		spray.multimesh.set_instance_custom_data(index,Color(fposmod(float(index)*0.618034,1.0),fposmod(float(index)*0.754878,1.0),fposmod(float(index)*0.56984,1.0),fposmod(float(index)*0.438579,1.0)))
	cable_points.resize(49)

func _part(parent: Node3D, label: String, mesh: Mesh, finish: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.material_override = finish
	part.layers = LAYERS
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part

func aim(surface: Dictionary, frame: Basis, time: float) -> void:
	var source: Vector3 = surface.position+frame.y*0.75+frame.x*0.50
	source.y = maxf(0.8,source.y)
	var direction: Vector3 = (surface.position-source).normalized()
	nozzle.global_transform = Transform3D(Basis.looking_at(direction,frame.z),source)
	var origin: Vector3 = source+direction*0.12
	var radius: float = float(surface.get("radius",0.95))
	var finish: ShaderMaterial = spray.material_override
	finish.set_shader_parameter("flow",time)
	finish.set_shader_parameter("source",origin)
	finish.set_shader_parameter("target",surface.position)
	finish.set_shader_parameter("spread_x",frame.x*radius*0.94)
	finish.set_shader_parameter("spread_z",frame.z*radius*0.94)
	spray.custom_aabb = AABB(to_local(origin),Vector3.ZERO).expand(to_local(surface.position)).grow(radius+0.12)
	_route_hose(surface)

func _route_hose(surface: Dictionary) -> void:
	var start: Vector3 = nozzle.global_transform*Vector3(0,0,0.10)
	var bounds: AABB = surface.get("car_bounds",AABB(Vector3(-1,0.2,-2.3),Vector3(2,1.6,4.6)))
	var safe_x: float = bounds.position.x-0.55 if start.x < bounds.position.x else maxf(REEL_POSITION.x,bounds.end.x+0.55)
	var ground := Vector3(safe_x,0.24,start.z+0.40)
	var end: Vector3 = reel.global_transform*REEL_OUTLET
	var knots: Array[Vector3] = [ground]
	if safe_x < 0.0:
		var front: float = bounds.position.z-0.65
		knots.append(Vector3(safe_x,0.24,front))
		knots.append(Vector3(REEL_POSITION.x,0.24,front))
	knots.append(Vector3(REEL_POSITION.x+0.30,0.24,end.z))
	knots.append(end)
	var floor_tangent: Vector3 = (knots[1]-ground).normalized()*0.30
	var box := AABB(to_local(start),Vector3.ZERO)
	for index: int in range(49):
		var phase: float = float(index)/48.0
		var at: Vector3
		if phase <= 0.60:
			at = start.bezier_interpolate(start+nozzle.global_basis.z*0.20,ground-floor_tangent,ground,phase/0.60)
		else:
			var along: float = (phase-0.60)/0.40*float(knots.size()-1)
			var segment: int = mini(int(along),knots.size()-2)
			at = knots[segment].cubic_interpolate(knots[segment+1],knots[maxi(segment-1,0)],knots[mini(segment+2,knots.size()-1)],along-float(segment))
		at.y = maxf(0.24,at.y)
		cable_points[index] = to_local(at)
		box = box.expand(cable_points[index])
	cable.custom_aabb = box.grow(0.04)
	(cable.material_override as ShaderMaterial).set_shader_parameter("cable_points",cable_points)
