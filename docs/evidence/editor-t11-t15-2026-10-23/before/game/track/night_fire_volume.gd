class_name NightFireVolume
extends RefCounted
## One shared32-cubed periodic noise field; no frame textures or live viewports.
static var field: ImageTexture3D
static func material() -> ShaderMaterial:
	if field==null:
		var rng:=RandomNumberGenerator.new(); rng.seed=928371
		var layers: Array[Image]=[]
		for z: int in range(32):
			var bytes:=PackedByteArray(); bytes.resize(32*32*4)
			for i: int in range(bytes.size()): bytes[i]=rng.randi()&255
			layers.append(Image.create_from_data(32,32,false,Image.FORMAT_RGBA8,bytes))
		field=ImageTexture3D.new(); field.create(Image.FORMAT_RGBA8,32,32,32,false,layers)
	var result:=ShaderMaterial.new(); result.shader=preload("res://track/night_fire_volume.gdshader")
	result.resource_local_to_scene=true; result.set_shader_parameter("flow_noise",field)
	return result
