extends SceneTree
## Offline numerical derivative/frost/roughness data. No runtime image processing.
func _initialize() -> void:
	var source := Image.load_from_file("res://assets/textures/winter_ice_v2.png")
	source.resize(512,512,Image.INTERPOLATE_LANCZOS)
	var packed := Image.create(512,512,false,Image.FORMAT_RGBA8)
	for y: int in range(512):
		for x: int in range(512):
			var center: Color = source.get_pixel(x,y)
			var gx: float = source.get_pixel((x+1)%512,y).r-source.get_pixel((x+511)%512,y).r
			var gy: float = source.get_pixel(x,(y+1)%512).r-source.get_pixel(x,(y+511)%512).r
			var frost: float = smoothstep(0.42,0.80,center.r)
			packed.set_pixel(x,y,Color(clampf(0.5+gx,0.0,1.0),clampf(0.5+gy,0.0,1.0),frost,lerpf(0.28,0.84,frost)))
	assert(packed.save_png("res://assets/textures/winter_ice_finish_v2.png") == OK)
	print("WINTER_ICE_FINISH_BAKED: 512x512 RG slopes, B frost, A roughness")
	quit()
