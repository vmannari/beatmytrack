extends SceneTree
func _initialize() -> void:
	var folder: String="res://../docs/evidence/challenger-nose-curve-2026-11-13/opaque-initial/"
	var a:=Image.load_from_file(folder+"full-front.png");var b:=Image.load_from_file(folder+"full-front-probe.png")
	var count: int=0;var maximum: float=0;var magenta: int=0
	var low: Vector2i=a.get_size();var high:=Vector2i(-1,-1)
	for y: int in range(a.get_height()):
		for x: int in range(a.get_width()):
			var p: Color=a.get_pixel(x,y);var q: Color=b.get_pixel(x,y)
			var d: float=maxf(absf(p.r-q.r),maxf(absf(p.g-q.g),absf(p.b-q.b)))
			if d>0:
				count+=1;maximum=maxf(maximum,d)
				low=Vector2i(mini(low.x,x),mini(low.y,y));high=Vector2i(maxi(high.x,x),maxi(high.y,y))
			if q.r>.8 and q.g<.2 and q.b>.7:magenta+=1
	var metrics: Dictionary={"changed_pixels":count,"maximum_channel_change_255":maximum*255,"magenta_pixels":magenta,"bounds":str(Rect2i(low,high-low+Vector2i.ONE))}
	var file:=FileAccess.open(folder+"difference.json",FileAccess.WRITE);file.store_string(JSON.stringify(metrics,"\t"));file.close()
	print("INITIAL_OPACITY_DIFFERENCE: ",JSON.stringify(metrics));quit()
