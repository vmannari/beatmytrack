extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: "+label)
func run() -> void:
	for dimensions: Vector2i in [Vector2i(1,1),Vector2i(1,13),Vector2i(15,1),Vector2i(17,13),Vector2i(64,48)]:
		for fixture: int in range(5):
			var kinds := PackedByteArray()
			kinds.resize(dimensions.x*dimensions.y)
			for y: int in range(dimensions.y):
				for x: int in range(dimensions.x):
					kinds[y*dimensions.x+x] = 2 if fixture == 0 else (x/8)%8 if fixture == 1 else (y/8)%8 if fixture == 2 else ((x/8)+(y/8))%8 if fixture == 3 else ((x*17+y*23)%8)
			var result: Dictionary = TerrainUniformRegions.build(kinds,dimensions.x,dimensions.y)
			var bytes: PackedByteArray = result.image.get_data()
			var eligible: int = 0
			for y: int in range(dimensions.y):
				for x: int in range(dimensions.x):
					var same: bool = true
					var kind: int = kinds[y*dimensions.x+x]
					for dy: int in range(-2,3):
						for dx: int in range(-2,3):
							if kinds[clampi(y+dy,0,dimensions.y-1)*dimensions.x+clampi(x+dx,0,dimensions.x-1)] != kind: same = false
					check(bytes[y*dimensions.x+x] == (kind+1 if same else 0),"exact five-cell footprint including clamped edges")
					if same: eligible += 1
			check(eligible == result.eligible,"linear run predicate matches exhaustive neighbourhoods")
	var kinds := PackedByteArray()
	kinds.resize(256)
	kinds.fill(7)
	var packed: Dictionary = TerrainUniformRegions.build(kinds,16,16,Vector4i(0,1,3,7))
	check(packed.image.get_data()[0] == 4 and packed.eligible == 256,"packed codes select the original packed slot")
	var high := Image.create(16,16,false,Image.FORMAT_RGBA8)
	for y: int in range(16):
		for x: int in range(16): high.set_pixel(x,y,Color(x/15.0,y/15.0,0.3,1))
	var material := ShaderMaterial.new()
	material.shader = preload("res://track/terrain.gdshader")
	material.set_shader_parameter("surface_low",ImageTexture.create_from_image(high))
	TerrainUniformRegions.bind(material,high,packed,true)
	check(material.get_shader_parameter("terrain_uniform_enabled") != true,"all occupied channels retain original fallback")
	high.set_pixel(0,0,Color(0,0,0,0))
	high.fill(Color(0.2,0.4,0,0))
	TerrainUniformRegions.bind(material,high,packed,true)
	var flags: Image = material.get_shader_parameter("surface_high").get_image()
	var channel: int = material.get_shader_parameter("terrain_region_channel")
	for y: int in range(16):
		for x: int in range(16):
			check(flags.get_pixel(x,y).r == high.get_pixel(x,y).r and flags.get_pixel(x,y).g == high.get_pixel(x,y).g,"active high-mask channels preserved exactly")
			check(flags.get_pixel(x,y)[channel] == 1.0,"nearest uniform-region predicate retained in unused channel")
	var original_low := Image.create(16,16,false,Image.FORMAT_RGBA8)
	original_low.fill(Color(0.2,0.4,0.6,0))
	high.fill(Color(0.2,0.4,0.6,0.8))
	material.set_shader_parameter("surface_low",ImageTexture.create_from_image(original_low))
	material.set_shader_parameter("surface_high",ImageTexture.create_from_image(high))
	TerrainUniformRegions.bind(material,high,packed,true)
	check(material.get_shader_parameter("terrain_region_low") == true,"occupied high mask uses an unused low-mask channel")
	flags = material.get_shader_parameter("surface_low").get_image()
	check(flags.get_pixel(0,0) == Color(original_low.get_pixel(0,0).r,original_low.get_pixel(0,0).g,original_low.get_pixel(0,0).b,1),"low-mask predicate preserves all active weight bytes")
	check(material.get_shader_parameter("surface_high").get_image().get_data() == high.get_data(),"low-mask predicate leaves the complete high mask untouched")
	print("TERRAIN_UNIFORM_REGIONS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
