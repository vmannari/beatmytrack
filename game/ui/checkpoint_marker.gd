class_name CheckpointMarker
extends MeshInstance3D
## Only a missed gate gets a world marker; the minimap has no waypoint marker.
## Temporary development overlay; disable this flag to hide acceptance margins.
const SHOW_DEVELOPMENT_MARGINS: bool = true
var label: Label3D
var margins: Array[MeshInstance3D] = []
var previous_gate: int = -2
func line_material(alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0,0.8,0.286,alpha)
	return material
func _ready() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(1,0.025,0.24)
	mesh = box
	material_override = line_material(0.65)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side: int in range(2):
		var margin := MeshInstance3D.new()
		var margin_mesh := BoxMesh.new()
		margin_mesh.size = Vector3(1,0.02,0.14)
		margin.mesh = margin_mesh
		margin.material_override = line_material(0.22)
		margin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(margin)
		margins.append(margin)
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.pixel_size = 0.025
	label.outline_size = 10
	label.modulate = Color("ffdf77")
	label.position.y = 2.2
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.text = "Missed checkpoint"
	add_child(label)
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
	position = VisualGeometry.world(center+direction.orthogonal()*shift)
	position.y = bridge.height_at(center,route_index)+0.12
	rotation.y = -atan2(direction.x,direction.y)
	(mesh as BoxMesh).size.x = road.x+road.y
	for side: int in range(2):
		var span: float = maxf(0.0,accepted[side]-road[side])
		margins[side].visible = SHOW_DEVELOPMENT_MARGINS and span > 0.001
		(margins[side].mesh as BoxMesh).size.x = maxf(0.001,span)
		var sign_value: float = -1.0 if side == 0 else 1.0
		margins[side].position.x = sign_value*(road[side]+span*0.5)-shift
