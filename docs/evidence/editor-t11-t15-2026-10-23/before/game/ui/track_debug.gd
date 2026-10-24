class_name TrackDebug
extends Control
## Development overview; gameplay keeps its existing high-oblique follow camera.

var track: NativeTrack
var state: VehicleState
var detail: int = 0
var origin := Vector2.ZERO
var zoom: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func screen_point(p: Vector2) -> Vector2:
	return origin + Vector2(p.x + track.half_extent.x, track.half_extent.y - p.y) * zoom


func _draw() -> void:
	if track == null:
		return
	zoom = minf((size.x - 80) / (track.half_extent.x * 2), (size.y - 190) / (track.half_extent.y * 2))
	origin = Vector2((size.x - track.half_extent.x * 2 * zoom) * 0.5, 115)
	draw_rect(Rect2(Vector2.ZERO, size), Color("172129"))
	for layer: Array in [track.rectangles, track.deck_rectangles]:
		for r: Array in layer:
			if int(r[4]) < 0:
				continue
			var color: Color = NativeTrackVisual.COLORS[int(r[4])]
			if layer == track.deck_rectangles:
				color = color.lightened(0.17)
			draw_rect(Rect2(origin + Vector2(r[0], r[1]) * track.cell_size * zoom, Vector2(r[2], r[3]) * track.cell_size * zoom), color)
	for i: int in range(track.route.size()):
		draw_line(screen_point(track.route[i]), screen_point(track.route[(i + 1) % track.route.size()]), Color("66bdd0"), 1.5)
	for i: int in range(track.checkpoints.size()):
		var rect: Rect2 = track.checkpoints[i]
		var screen := Rect2(screen_point(Vector2(rect.position.x, rect.end.y)), rect.size * zoom)
		draw_rect(screen, Color(0.9, 0.75, 0.3, 0.12))
		draw_rect(screen, Color("dec269"), false, 1.5)
		draw_string(ThemeDB.fallback_font, screen.position + Vector2(3, 15), "CP " + str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("fff0b0"))
	if detail > 0 and track.metadata.has("debug"):
		for q: Dictionary in track.metadata.debug.computer_points:
			var a := Vector2(q.effect_a.x, q.effect_a.y)
			var b := Vector2(q.effect_b.x, q.effect_b.y)
			draw_rect(Rect2(origin + a * track.cell_size * zoom, (b-a) * track.cell_size * zoom), Color(0.9, 0.5, 0.6, 0.35), false)
			draw_circle(origin + Vector2(q.target.x, q.target.y) * track.cell_size * zoom, 3, Color("ee92ad"))
	if detail > 1 and track.metadata.has("debug"):
		for b: Array in track.metadata.debug.blocks:
			var rect := Rect2(origin + Vector2(b[0],b[1]) * track.cell_size * zoom, Vector2(b[2],b[3]) * track.cell_size * zoom)
			draw_rect(rect, Color(1, 1, 1, 0.2), false)
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(0,9), str(int(b[4])), HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
	var start: Vector2 = screen_point(track.spawn)
	var side := Vector2(track.finish_forward.y, -track.finish_forward.x) * track.finish_half_width
	draw_line(screen_point(track.finish_center - side), screen_point(track.finish_center + side), Color.WHITE, 2)
	draw_circle(start, 5, Color.WHITE)
	draw_line(start, start + Vector2(sin(track.spawn_heading), -cos(track.spawn_heading)) * 22, Color.WHITE, 3)
	if state != null:
		var p: Vector2 = screen_point(state.position)
		draw_circle(p, 5, Color("f38652"))
		draw_line(p, p + Vector2(state.forward().x, -state.forward().y) * 14, Color("f38652"), 3)
	draw_string(ThemeDB.fallback_font, Vector2(30,32), track.identity + " | DEBUG TOP-DOWN | F4 drive / overview", HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	draw_string(ThemeDB.fallback_font, Vector2(30,60), "Cyan: native route  Gold: ordered source CPs  White: source start  Orange: car", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	draw_string(ThemeDB.fallback_font, Vector2(30,84), "F7 overlays: " + str(detail) + " (0 route, 1 source AI regions/targets, 2 block bounds/IDs)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
