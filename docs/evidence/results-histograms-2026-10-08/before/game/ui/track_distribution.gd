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
	var window: Vector2i = display_window(bins)
	var first: int = window.x
	var last: int = window.y
	var maximum: float = 1.0
	for index: int in range(first,last+1): maximum = maxf(maximum,float(bins[index]))
	var count: int = last-first+1
	var width: float = (size.x-16)/count
	var baseline: float = size.y-24
	var player: int = int(snapshot.get("player_bin",-1))
	for index: int in range(first,last+1):
		var height: float = maxf(0,float(bins[index]))/maximum*(baseline-30)
		var bar_width: float = minf(32,width-3) if count == 1 else maxf(1,width-3)
		var center: float = 8+(index-first+0.5)*width
		draw_rect(Rect2(center-bar_width*0.5,baseline-height,bar_width,height),MenuStyle.ACCENT if index == player else bar_color)
	if player >= 0:
		var outside: bool = player < first or player > last
		var x: float = clampf(8+(player-first+0.5)*width,8,size.x-8)
		draw_line(Vector2(x,24),Vector2(x,baseline),MenuStyle.ACCENT,1.5,true)
		draw_circle(Vector2(x,baseline),3,MenuStyle.ACCENT,true,-1,true)
		var caption: String = str(snapshot.get("marker_label","YOU"))
		if outside: caption = ("< " if player < first else "")+caption+(" >" if player > last else "")
		var label_width: float = MenuStyle.BODY.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
		draw_string(MenuStyle.BODY,Vector2(clampf(x-label_width*0.5,4,maxf(4,size.x-label_width-4)),14),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,11,MenuStyle.ACCENT)
	draw_line(Vector2(8,baseline),Vector2(size.x-8,baseline),MenuStyle.BORDER)
	var low: float = float(snapshot.get("min_ms",0))
	var high: float = float(snapshot.get("max_ms",0))
	var edges: Array = snapshot.get("edges_ms",[])
	var shown_low: float = float(edges[first]) if edges.size() == bins.size()+1 else lerpf(low,high,float(first)/maxi(1,bins.size()-1))
	var shown_high: float = float(edges[last+1]) if edges.size() == bins.size()+1 else lerpf(low,high,float(last)/maxi(1,bins.size()-1))
	var left_text: String = ("< " if first > 0 else "")+MenuStyle.time_text(shown_low/1000)
	var right_text: String = MenuStyle.time_text(shown_high/1000)+(" >" if last < bins.size()-1 else "")
	if is_equal_approx(shown_low,shown_high):
		var label_width: float = MenuStyle.BODY.get_string_size(MenuStyle.time_text(shown_low/1000),HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		draw_string(MenuStyle.BODY,Vector2((size.x-label_width)*0.5,size.y-3),MenuStyle.time_text(shown_low/1000),HORIZONTAL_ALIGNMENT_LEFT,-1,12,MenuStyle.MUTED)
	else:
		draw_string(MenuStyle.BODY,Vector2(8,size.y-3),left_text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,MenuStyle.MUTED)
		var label_width: float = MenuStyle.BODY.get_string_size(right_text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		draw_string(MenuStyle.BODY,Vector2(size.x-label_width-8,size.y-3),right_text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,MenuStyle.MUTED)

static func display_window(bins: Array) -> Vector2i:
	# Crop only the view. Counts, population and rank remain untouched.
	var total: int = 0
	var occupied: Array[int] = []
	for index: int in range(bins.size()):
		total += maxi(0,int(bins[index]))
		if int(bins[index]) > 0: occupied.append(index)
	if occupied.is_empty(): return Vector2i(0,maxi(0,bins.size()-1))
	var first: int = occupied[0]
	var last: int = occupied[-1]
	if total < 4: return Vector2i(first,last)
	var q1: int = _quantile_bin(bins,total,0.25)
	var q3: int = _quantile_bin(bins,total,0.75)
	var spread: int = maxi(1,q3-q1)
	var low: int = _quantile_bin(bins,total,0.025) if total >= 40 else first
	var high: int = _quantile_bin(bins,total,0.975) if total >= 40 else last
	# Tukey fences also catch isolated long tails in small samples.
	if spread > 0:
		low = maxi(low,ceili(q1-1.5*spread))
		high = mini(high,floori(q3+1.5*spread))
	for index: int in occupied:
		if index >= low:
			first = index
			break
	for offset: int in range(occupied.size()-1,-1,-1):
		if occupied[offset] <= high:
			last = occupied[offset]
			break
	return Vector2i(first,maxi(first,last))

static func _quantile_bin(bins: Array, total: int, fraction: float) -> int:
	var target: int = maxi(1,ceili(total*fraction))
	var cumulative: int = 0
	for index: int in range(bins.size()):
		cumulative += maxi(0,int(bins[index]))
		if cumulative >= target: return index
	return maxi(0,bins.size()-1)
