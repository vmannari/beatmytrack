class_name TrackDistribution
extends Control
## Explicitly scoped distributions; callers label local samples separately from players.
var snapshot: Dictionary = {}
var bar_color: Color = Color("41667b")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var bins: Array = snapshot.get("bins",[])
	if bins.is_empty():
		draw_string(MenuStyle.BODY,Vector2(4,size.y*0.5),str(snapshot.get("empty_text","No comparison data")),HORIZONTAL_ALIGNMENT_LEFT,size.x-8,13,MenuStyle.MUTED)
		draw_string(MenuStyle.BODY,Vector2(4,size.y*0.5+22),str(snapshot.get("empty_detail","Online records required")),HORIZONTAL_ALIGNMENT_LEFT,size.x-8,12,MenuStyle.MUTED)
		return
	var maximum: float = 1.0
	for count: Variant in bins: maximum = maxf(maximum,float(count))
	var width: float = (size.x-8)/bins.size()
	var baseline: float = size.y-22
	for index: int in range(bins.size()):
		var height: float = maxf(0,float(bins[index]))/maximum*(baseline-18)
		var yours: bool = index == int(snapshot.get("player_bin",-1))
		draw_rect(Rect2(4+index*width,baseline-height,maxf(1,width-2),height),MenuStyle.ACCENT if yours else bar_color)
		if yours:
			var x: float = 4+(index+0.5)*width
			draw_line(Vector2(x,22),Vector2(x,baseline),MenuStyle.ACCENT,1.5,true)
			draw_circle(Vector2(x,baseline),3,MenuStyle.ACCENT,true,-1,true)
			var caption: String = str(snapshot.get("marker_label","YOU"))
			var label_width: float = MenuStyle.BODY.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
			draw_string(MenuStyle.BODY,Vector2(clampf(x-label_width*0.5,4,maxf(4,size.x-label_width-4)),14),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,11,MenuStyle.ACCENT)
	draw_line(Vector2(4,baseline),Vector2(size.x-4,baseline),MenuStyle.BORDER)
	draw_string(MenuStyle.BODY,Vector2(4,size.y-3),MenuStyle.time_text(float(snapshot.get("min_ms",0))/1000),HORIZONTAL_ALIGNMENT_LEFT,-1,12,MenuStyle.MUTED)
	draw_string(MenuStyle.BODY,Vector2(size.x-78,size.y-3),MenuStyle.time_text(float(snapshot.get("max_ms",0))/1000),HORIZONTAL_ALIGNMENT_LEFT,-1,12,MenuStyle.MUTED)
