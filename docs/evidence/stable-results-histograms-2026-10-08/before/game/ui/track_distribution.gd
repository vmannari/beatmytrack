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
	if snapshot.has("markers"):
		_draw_comparison(bins)
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

func _draw_comparison(bins: Array) -> void:
	var geometry: Dictionary = comparison_geometry(snapshot,size.x)
	var window: Vector2i = geometry.window
	var edges: Array = geometry.edges
	var markers: Array = snapshot.get("markers",[])
	var baseline: float = size.y-24
	var top: float = 52
	var maximum: float = 1.0
	for index: int in range(window.x,window.y+1): maximum = maxf(maximum,float(bins[index]))
	var current: float = float(markers[0].value_ms) if not markers.is_empty() else -1.0
	for index: int in range(window.x,window.y+1):
		var left: float = _time_x(float(edges[index]),geometry.low,geometry.high,size.x)
		var right: float = _time_x(float(edges[index+1]),geometry.low,geometry.high,size.x)
		var height: float = maxf(0,float(bins[index]))/maximum*maxf(1,baseline-top)
		var color: Color = MenuStyle.ACCENT if current >= float(edges[index]) and current < float(edges[index+1]) else bar_color
		draw_rect(Rect2(left+1.5,baseline-height,maxf(1,right-left-3),height),color)
	draw_line(Vector2(8,baseline),Vector2(size.x-8,baseline),MenuStyle.BORDER)
	var tied: bool = markers.size() == 2 and roundi(float(markers[0].value_ms)) == roundi(float(markers[1].value_ms))
	for index: int in range(markers.size()):
		if tied and index > 0: continue
		var marker: Dictionary = markers[index]
		var x: float = float(geometry.marker_x[index])
		var color: Color = marker.get("color",MenuStyle.ACCENT)
		var caption: String = ("THIS RACE / YOUR BEST" if tied else str(marker.label))+"  "+MenuStyle.time_text(float(marker.value_ms)/1000.0)
		var label_width: float = MenuStyle.BODY.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		draw_string(MenuStyle.BODY,Vector2(clampf(x-label_width*0.5,4,maxf(4,size.x-label_width-4)),14+index*18),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
		if index == 0:
			draw_line(Vector2(x,top-7),Vector2(x,baseline),color,2.5,true)
			draw_colored_polygon(PackedVector2Array([Vector2(x-5,top-10),Vector2(x+5,top-10),Vector2(x,top-3)]),color)
		else:
			draw_dashed_line(Vector2(x,top-7),Vector2(x,baseline),color,2.0,5,true)
			draw_circle(Vector2(x,top-6),4,color,true,-1,true)
		draw_circle(Vector2(x,baseline),3.5,color,true,-1,true)
	var low_text: String = ("< " if window.x > 0 else "")+MenuStyle.time_text(float(geometry.low)/1000.0)
	var high_text: String = MenuStyle.time_text(float(geometry.high)/1000.0)+(" >" if window.y < bins.size()-1 else "")
	draw_string(MenuStyle.BODY,Vector2(8,size.y-3),low_text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,MenuStyle.MUTED)
	var high_width: float = MenuStyle.BODY.get_string_size(high_text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
	draw_string(MenuStyle.BODY,Vector2(size.x-high_width-8,size.y-3),high_text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,MenuStyle.MUTED)

static func comparison_geometry(data: Dictionary, width: float) -> Dictionary:
	var bins: Array = data.get("bins",[])
	var window: Vector2i = display_window(bins)
	var edges: Array = data.get("edges_ms",[]).duplicate()
	if edges.size() != bins.size()+1:
		edges.clear()
		for index: int in range(bins.size()+1):
			edges.append(lerpf(float(data.get("min_ms",0)),float(data.get("max_ms",0)),float(index)/maxi(1,bins.size())))
	var markers: Array = data.get("markers",[])
	for marker: Dictionary in markers:
		for index: int in range(bins.size()):
			if float(marker.value_ms) >= float(edges[index]) and float(marker.value_ms) < float(edges[index+1]):
				window.x = mini(window.x,index)
				window.y = maxi(window.y,index)
	var low: float = float(edges[window.x])
	var high: float = float(edges[window.y+1])
	for marker: Dictionary in markers:
		low = minf(low,float(marker.value_ms))
		high = maxf(high,float(marker.value_ms))
	var padding: float = maxf(1,(high-low)*0.025)
	low = maxf(0,low-padding)
	high += padding
	var marker_x: Array[float] = []
	for marker: Dictionary in markers: marker_x.append(_time_x(float(marker.value_ms),low,high,width))
	return {"window":window,"low":low,"high":high,"edges":edges,"marker_x":marker_x}

static func _time_x(value: float, low: float, high: float, width: float) -> float:
	return 8+(width-16)*clampf((value-low)/maxf(1,high-low),0,1)

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
