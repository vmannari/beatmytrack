extends SceneTree
func _initialize() -> void:
	var base: String="res://../docs/evidence/volt-reflection-smoothing-2026-11-15/garage-prepared-gl_compatibility-decorated/"
	for label: String in ["electric-stock-front"]:
		var a: Image=Image.load_from_file(base+label+"-before.png");var b: Image=Image.load_from_file(base+label+"-restored.png")
		if a==null or b==null:continue
		var count: int=0;var maximum: float=0;var low:=Vector2i(a.get_width(),a.get_height());var high:=Vector2i.ZERO
		for y: int in range(a.get_height()):
			for x: int in range(a.get_width()):
				var first: Color=a.get_pixel(x,y);var next: Color=b.get_pixel(x,y)
				var error: float=maxf(absf(first.r-next.r),maxf(absf(first.g-next.g),absf(first.b-next.b)))
				if error>0:count+=1;maximum=maxf(maximum,error);low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
		print("VSR_CONTROL_NOISE ",label," pixels=",count," max8=",maximum*255," region=",low,"..",high)
	quit()
