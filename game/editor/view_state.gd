extends RefCounted
## Transient editing preferences. Never part of the saved track or race format.
const FIELDS: Array[String] = [
	"zoom","pan","mode","selected","selected_object","selected_piece",
	"multi_select","object_snap","stamp_kind","stamp_rotation","stamp_scale",
	"stamp_span","stamp_length","stamp_jump_profile","stamp_container_color","run_shape","free_run",
	"brush_surface","brush_width","brush_shape","paint_mode","protect_road",
	"snap_enabled","piece_kind","spline_point","navigation_override"
]

static func capture(canvas: EditorCanvas, detailed_scenery: bool) -> Dictionary:
	var result: Dictionary = {"detailed_scenery":detailed_scenery,"selected_objects":canvas.object_indices().duplicate()}
	for key: String in FIELDS: result[key] = canvas.get(key)
	return result

static func restore(canvas: EditorCanvas, state: Dictionary) -> void:
	for key: String in FIELDS:
		if state.has(key): canvas.set(key,state[key])
	canvas.selected = clampi(canvas.selected,-1,canvas.document.points.size()-1)
	canvas.selected_piece = clampi(canvas.selected_piece,-1,canvas.document.pieces.size()-1)
	var indices: Array[int] = []
	for index: int in state.get("selected_objects",[]):
		if index >= 0 and index < canvas.document.objects.size(): indices.append(index)
	canvas.selected_objects.assign(indices)
	canvas.selected_object = clampi(canvas.selected_object,-1,canvas.document.objects.size()-1)
	canvas.fitted = true
