extends SceneTree
## Original numerical material atlas. RG slope, B concrete tone, A roughness.
const SIZE: int = 512
const DESTINATION: String = "res://assets/textures/parking_concrete_v1.png"

func _initialize() -> void:
	var fields: Array[Image] = []
	for index: int in range(3):
		var noise := FastNoiseLite.new()
		noise.seed = [57183,38127,91743][index]
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = [0.009,0.035,0.19][index]
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = [4,3,2][index]
		noise.fractal_gain = 0.5
		fields.append(noise.get_seamless_image(SIZE,SIZE))
	var height := PackedFloat32Array()
	height.resize(SIZE*SIZE)
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			height[y*SIZE+x] = fields[0].get_pixel(x,y).r*0.25+fields[1].get_pixel(x,y).r*0.30+fields[2].get_pixel(x,y).r*0.45
	var result := Image.create(SIZE,SIZE,false,Image.FORMAT_RGBA8)
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			var coarse: float = fields[0].get_pixel(x,y).r
			var middle: float = fields[1].get_pixel(x,y).r
			var fine: float = fields[2].get_pixel(x,y).r
			var dx: float = height[y*SIZE+posmod(x+1,SIZE)]-height[y*SIZE+posmod(x-1,SIZE)]
			var dz: float = height[posmod(y+1,SIZE)*SIZE+x]-height[posmod(y-1,SIZE)*SIZE+x]
			var tone: float = clampf(0.5+(coarse-0.5)*0.64+(middle-0.5)*0.48+(fine-0.5)*0.28,0.0,1.0)
			var roughness: float = clampf(0.84+(fine-0.5)*0.18+(coarse-0.5)*0.10,0.72,0.98)
			result.set_pixel(x,y,Color(0.5-dx*0.9,0.5-dz*0.9,tone,roughness))
	var destination: String = DESTINATION
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): destination = argument.trim_prefix("--output=")
	var error: Error = result.save_png(destination)
	print("PARKING_CONCRETE_BAKE: original512x512 RG slope/B tone/A roughness; error=%s sha256=%s" % [error_string(error),FileAccess.get_sha256(destination) if error == OK else ""])
	quit(0 if error == OK else 1)
