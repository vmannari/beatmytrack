extends SceneTree
func _initialize() -> void:
	for method: Dictionary in ClassDB.class_get_method_list("RenderingServer"):
		if "shader" in str(method.name) and "default" in str(method.name): print("SHADER_DEFAULT_API ",JSON.stringify(method))
	var shader:=Shader.new()
	shader.code="shader_type spatial; uniform vec4 tint : source_color = vec4(0.79,0.86,0.84,1.0); uniform bool enabled=false; void fragment(){ALBEDO=tint.rgb;}"
	var material:=ShaderMaterial.new();material.shader=shader
	print("UNIFORMS ",shader.get_shader_uniform_list())
	for name: String in ["tint","enabled"]:
		print("DEFAULT_PROBE ",name," raw=",material.get_shader_parameter(name)," declared=",RenderingServer.shader_get_parameter_default(shader.get_rid(),name)," revert=",material.property_get_revert("shader_parameter/"+name)," can=",material.property_can_revert("shader_parameter/"+name))
	quit()
