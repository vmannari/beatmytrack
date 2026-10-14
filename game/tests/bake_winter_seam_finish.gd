extends SceneTree
## Offline ridge extraction from original artwork. RG slopes/B frost retained.
func _initialize() -> void:
	var source := Image.load_from_file("res://assets/textures/winter_ice_v1.png")
	source.resize(512,512,Image.INTERPOLATE_LANCZOS)
	var packed := Image.load_from_file("res://assets/textures/winter_ice_finish_v3.png")
	var elongated := PackedFloat32Array()
	elongated.resize(512*512)
	for y: int in range(512):
		for x: int in range(512):
			var value: float = 0.0
			for offset: int in range(-12,13):
				value += source.get_pixel(x,posmod(y+offset,512)).r
			elongated[y*512+x] = value/25.0
	var active: int = 0
	var average: float = 0.0
	for y: int in range(512):
		for x: int in range(512):
			var surrounding: float = 0.0
			for offset: int in [-8,-5,-3,3,5,8]:
				surrounding += elongated[y*512+posmod(x+offset,512)]
			var seam: float = smoothstep(0.014,0.048,elongated[y*512+x]-surrounding/6.0)
			var pixel: Color = packed.get_pixel(x,y)
			pixel.a = seam
			packed.set_pixel(x,y,pixel)
			average += seam
			if seam > 0.5: active += 1
	assert(packed.save_png("res://assets/textures/winter_ice_seam_finish_v4.png") == OK)
	print("WINTER_SEAM_MASK: coverage=",float(active)/262144.0," average=",average/262144.0)
	quit()
