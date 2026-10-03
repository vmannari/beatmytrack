class_name ContactShading
extends RefCounted
## Cosmetic depth projections. No collision, timing or canonical-state writes.
const VERSION: String = "contact-lighting-11"
const CAR_DIMENSIONS: Dictionary = {"compact":Vector2(2.35,4.8),"pickup":Vector2(2.6,5.8),"classic":Vector2(2.5,4.6),"formula":Vector2(2.7,5.0),"kart":Vector2(2.0,3.2)}
const STATIC_KINDS: Array[String] = ["tree","broadleaf","bush","rock","boulder","slate","cliff","barrier","log","parked_car","van","container","shed","hut","grandstand"]

static func material() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = preload("res://track/contact_shadow.gdshader")
	result.render_priority = -108
	return result

static func car_shadow(parent: Node3D) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = "CarContactShadow"
	result.add_to_group("contact_lighting")
	result.mesh = BoxMesh.new() # Unit projection volume; no shadow-map caster.
	(result.mesh as BoxMesh).size = Vector3.ONE
	result.material_override = material()
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(result)
	return result

static func present_car(shadow: MeshInstance3D, car: CarVisual, state: VehicleState, point: Vector2, heading: float, track: NativeTrack, bridge: BridgePresentation) -> void:
	var dimensions: Vector2 = CAR_DIMENSIONS.get(car.vehicle_id,CAR_DIMENSIONS.compact)
	dimensions *= HandlingConfig.BODY_SCALE
	var support: float = 0.0
	var slope: float = 0.0
	if track != null:
		var axle := Vector2(sin(heading),cos(heading))*dimensions.y*0.35
		var layer: int = 1 if state.track_elevated else 0
		var front: float = bridge.height_at(point+axle,state.route_index,layer)
		var rear: float = bridge.height_at(point-axle,state.route_index,layer)
		if not state.track_elevated:
			front += TrackHazards.ramp_height(point+axle,track.hazard_objects)
			rear += TrackHazards.ramp_height(point-axle,track.hazard_objects)
		support = (front+rear)*0.5
		slope = atan2(front-rear,axle.length()*2.0)
	shadow.position = VisualGeometry.world(point)+Vector3.UP*(support+0.03)
	shadow.rotation = Vector3(slope,-heading,0)
	var air: float = maxf(state.jump_height,car.ramp_lift)
	var spread: float = 1.0+minf(air,2.0)*0.10
	shadow.scale = Vector3(dimensions.x*spread,0.55,dimensions.y*spread)
	shadow.visible = track == null or track.water_depth(point) <= 0.0
	(shadow.material_override as ShaderMaterial).set_shader_parameter("strength",0.34/(1.0+air*1.8))

static func build_props(parent: Node3D, track: NativeTrack) -> void:
	# Spatial batches bound draw calls and let the renderer cull distant groups.
	var groups: Dictionary = {}
	for object: Dictionary in track.metadata.get("creator_document",{}).get("objects",[])+track.metadata.get("scenery_objects",[]):
		if str(object.kind) not in STATIC_KINDS: continue
		var point := Vector2(float(object.position[0]),float(object.position[1]))
		var key := Vector2i(floori(point.x/32.0),floori(point.y/32.0))
		var size: Vector2 = CreatorObjects.size_of(object)
		# Trunk contact stays much smaller than the foliage canopy.
		if object.kind in ["tree","broadleaf"]: size *= 0.40
		size += Vector2.ONE*0.65
		var basis := Basis(Vector3.UP,deg_to_rad(float(object.rotation)))*Basis.from_scale(Vector3(size.x,0.5,size.y))
		var pose := Transform3D(basis,VisualGeometry.world(point)+Vector3.UP*0.025)
		if not groups.has(key): groups[key] = []
		groups[key].append(pose)
	var surface: ShaderMaterial = material()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = surface
	for key: Vector2i in groups:
		var batch := MultiMeshInstance3D.new()
		batch.name = "PropContactShadows"
		batch.add_to_group("contact_lighting")
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh = box
		batch.multimesh.instance_count = groups[key].size()
		for index: int in range(groups[key].size()): batch.multimesh.set_instance_transform(index,groups[key][index])
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(batch,true)

static func build_bridges(parent: Node3D, bridges: Array) -> void:
	for span: Dictionary in bridges:
		var shade := MeshInstance3D.new()
		shade.name = "BridgeUnderShadow"
		shade.add_to_group("contact_lighting")
		var mesh := BoxMesh.new()
		mesh.size = Vector3(float(span.length),CreatorBridges.HEIGHT+0.2,float(span.width)+CreatorBridges.RAIL*2.0+1.7)
		shade.mesh = mesh
		var midpoint: Vector2 = Vector2(float(span.position[0]),float(span.position[1]))+Vector2(float(span.length)*0.5,0).rotated(deg_to_rad(float(span.heading)))
		shade.position = VisualGeometry.world(midpoint)+Vector3.UP*(CreatorBridges.HEIGHT*0.5)
		shade.rotation.y = deg_to_rad(float(span.heading))
		var surface := ShaderMaterial.new()
		surface.shader = preload("res://track/bridge_shadow.gdshader")
		surface.render_priority = -109
		surface.set_shader_parameter("span_length",float(span.length))
		surface.set_shader_parameter("span_width",float(span.width))
		surface.set_shader_parameter("bridge_height",CreatorBridges.HEIGHT)
		surface.set_shader_parameter("ramp_length",CreatorBridges.RAMP)
		shade.material_override = surface
		shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(shade,true)

static func cloud_shadow(camera: Camera3D) -> MeshInstance3D:
	var shade := MeshInstance3D.new()
	shade.name = "GrassCloudShadows"
	shade.add_to_group("contact_lighting")
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2,2)
	shade.mesh = mesh
	shade.position.z = -1.0
	shade.extra_cull_margin = 16384.0
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var surface := ShaderMaterial.new()
	surface.shader = preload("res://track/cloud_shadow.gdshader")
	surface.render_priority = -110
	shade.material_override = surface
	camera.add_child(shade)
	return shade
