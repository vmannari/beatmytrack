extends SceneTree
const FILES: Array[String]=["garage_floor","garage_deck","garage_surface_finish","garage_audio_wood","garage_display_stone","garage_plant_leaf","garage_vinyl"]
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var program_path: String="res://../docs/evidence/garage-first-entry-2026-10-27/room_program.gdshader"
	var scene_path: String="res://../docs/evidence/garage-first-entry-2026-10-27/workshop_shared.scn"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--program-path="): program_path=argument.trim_prefix("--program-path=")
		if argument.begins_with("--scene-output="): scene_path=argument.trim_prefix("--scene-output=")
	var room: Node=load(GarageEnvironment.PREPARED_ARCHITECTURE).instantiate()
	var shader: Shader=load(program_path)
	var changed: Dictionary={}
	for node: MeshInstance3D in room.find_children("*","MeshInstance3D",true,false):
		for index: int in range(node.mesh.get_surface_count()):
			var material: Material=node.get_active_material(index)
			if not material is ShaderMaterial or material.shader==null or changed.has(material): continue
			var family: int=FILES.find(material.shader.resource_path.get_file().get_basename())
			if family<0: continue
			var values: Dictionary={}
			for uniform: Dictionary in material.shader.get_shader_uniform_list(): values[uniform.name]=material.get_shader_parameter(uniform.name)
			material.shader=shader
			material.set_shader_parameter("garage_finish_family",family)
			for uniform: String in values:
				if values[uniform]!=null: material.set_shader_parameter(uniform,values[uniform])
			changed[material]=true
	var scene:=PackedScene.new()
	assert(scene.pack(room)==OK)
	assert(ResourceSaver.save(scene,scene_path,ResourceSaver.FLAG_COMPRESS)==OK)
	print("SHARED_ROOM_BAKE ",changed.size())
	room.free();quit()
