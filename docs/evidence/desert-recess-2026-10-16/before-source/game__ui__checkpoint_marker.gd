class_name CheckpointMarker
extends MeshInstance3D
## Presentation only: a missed road gate, with no floating text or collision.
const AMBER := Color("ffb632")
const SHOW_DEVELOPMENT_MARGINS: bool = false
var margins: Array[MeshInstance3D] = []
var previous_gate: int = -2
var chevrons: MeshInstance3D
var road_quads: Array[PackedVector3Array] = []
var road_span: float = 0.0

func line_material(alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(AMBER,alpha)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _ready() -> void:
	material_override = line_material(0.92)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chevrons = MeshInstance3D.new()
	chevrons.material_override = line_material(0.42)
	chevrons.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(chevrons)
	for side: int in range(2):
		var margin := MeshInstance3D.new()
		var margin_mesh := BoxMesh.new()
		margin_mesh.size = Vector3(1,0.02,0.14)
		margin.mesh = margin_mesh
		margin.material_override = line_material(0.22)
		margin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(margin)
		margins.append(margin)
	visible = false

func present(session: TrackSession, track: NativeTrack, bridge: BridgePresentation) -> void:
	visible = session.missed_checkpoint >= 0 and not session.finished
	if not visible or previous_gate == session.missed_checkpoint: return
	previous_gate = session.missed_checkpoint
	var center: Vector2 = session.checkpoint_road_center(track)
	var direction: Vector2 = session.checkpoint_direction(track)
	var road: Vector2 = session.checkpoint_road_spans(track)
	var accepted: Vector2 = session.checkpoint_acceptance_spans(track)
	var shift: float = (road.y-road.x)*0.5
	var route_index: int = track.nearest_route(center)
	var layer: int = 1 if session.checkpoint_elevated() else 0
	position = VisualGeometry.world(center+direction.orthogonal()*shift)
	position.y = bridge.height_at(center,route_index,layer)+0.12
	rotation.y = -atan2(direction.x,direction.y)
	road_span = road.x+road.y
	road_quads.clear()
	var stripe := SurfaceTool.new()
	stripe.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dash_count: int = maxi(2,ceili(road_span/1.2))
	var pitch: float = road_span/(dash_count-0.28)
	for index: int in range(dash_count):
		var low: float = -road.x+index*pitch
		var high: float = minf(road.y,low+pitch*0.72)
		var quad := PackedVector3Array()
		for point: Vector2 in [Vector2(low,-0.16),Vector2(high,-0.16),Vector2(high,0.16),Vector2(low,0.16)]:
			quad.append(_road_point(center,direction,point,bridge,route_index,layer))
		road_quads.append(quad)
		_quad(stripe,quad)
	mesh = stripe.commit()
	var arrows := SurfaceTool.new()
	arrows.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: float = minf(1.35,minf(road.x,road.y)*0.45)
	# Two approach chevrons point through the gate in the accepted direction.
	for distance: float in [2.5,5.0]:
		for side: float in [-1.0,1.0]:
			var quad := PackedVector3Array()
			for point: Vector2 in [Vector2(0,-distance+0.7),Vector2(side*half,-distance-0.35),Vector2(side*half,-distance-1.1),Vector2(0,-distance-0.05)]:
				quad.append(_road_point(center,direction,point,bridge,route_index,layer))
			_quad(arrows,quad)
	chevrons.mesh = arrows.commit()
	for side: int in range(2):
		var span: float = maxf(0.0,accepted[side]-road[side])
		margins[side].visible = SHOW_DEVELOPMENT_MARGINS and span > 0.001
		(margins[side].mesh as BoxMesh).size.x = maxf(0.001,span)
		var sign_value: float = -1.0 if side == 0 else 1.0
		margins[side].position.x = sign_value*(road[side]+span*0.5)-shift

func _road_point(center: Vector2, direction: Vector2, offset: Vector2, bridge: BridgePresentation, route_index: int, layer: int) -> Vector3:
	var point: Vector2 = center+direction.orthogonal()*offset.x+direction*offset.y
	return to_local(VisualGeometry.world(point)+Vector3.UP*(bridge.height_at(point,route_index,layer)+0.12))

func _quad(surface: SurfaceTool, points: PackedVector3Array) -> void:
	for index: int in [0,1,2,0,2,3]: surface.add_vertex(points[index])
