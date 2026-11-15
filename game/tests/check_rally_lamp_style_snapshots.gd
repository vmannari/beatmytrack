extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var checks: int=0
	for mode: String in ["stock","fitted","full"]:
		var model: Node3D=load("res://../build/rally-lamp-style-2026-11-15/compact-"+mode+"-before.scn").instantiate()
		root.add_child(model)
		assert(model.scale.is_equal_approx(Vector3.ONE*HandlingConfig.BODY_SCALE))
		ShowroomStudio._studio_glass(model,{})
		var count: int=0
		for part: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			var material: Material=part.get_active_material(0)
			if material is ShaderMaterial and material.shader.code==preload("res://vehicle/window_reflection.gdshader").code:
				assert(material.get_shader_parameter("studio_mode")==true,"The detached reference retains showroom glazing uniforms")
				count+=1;checks+=1
		assert(count>0)
		model.free()
	print("RALLY_FRONT_REFERENCE_UNIFORMS ",checks," checks, 0 failures");quit()
