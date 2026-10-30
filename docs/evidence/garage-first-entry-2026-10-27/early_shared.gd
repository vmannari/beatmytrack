extends RefCounted
const PROGRAM: String='load("res://../docs/evidence/garage-first-entry-2026-10-27/room_program.gdshader")'
static func install() -> void:
	var env: Script=load("res://ui/garage_environment.gd")
	var code: String=FileAccess.get_file_as_string("res://ui/garage_environment.gd")
	code=code.replace('const PREPARED_ARCHITECTURE: String="res://assets/garage/workshop_v1.scn"','const PREPARED_ARCHITECTURE: String="res://../docs/evidence/garage-first-entry-2026-10-27/workshop_shared.scn"')
	code=code.replace('material.shader = preload("res://ui/garage_deck.gdshader")','material.shader = '+PROGRAM+'\n\tmaterial.set_shader_parameter("garage_finish_family",1)')
	code=code.replace('finish.shader = preload("res://ui/garage_floor.gdshader")','finish.shader = '+PROGRAM+'\n\tfinish.set_shader_parameter("garage_finish_family",0)')
	env.source_code=code;assert(env.reload(true)==OK)
	var materials: Script=load("res://ui/garage_materials.gd")
	materials.source_code=FileAccess.get_file_as_string("res://ui/garage_materials.gd").replace('material.shader = preload("res://ui/garage_surface_finish.gdshader")','material.shader = '+PROGRAM+'\n\tmaterial.set_shader_parameter("garage_finish_family",2)')
	assert(materials.reload(true)==OK)
	var reflections: Script=load("res://ui/garage_reflections.gd")
	reflections.source_code=FileAccess.get_file_as_string("res://ui/garage_reflections.gd").replace('node.material_override.shader == preload("res://ui/garage_deck.gdshader")','node.material_override.shader == '+PROGRAM+' and node.material_override.get_shader_parameter("garage_finish_family")==1')
	assert(reflections.reload(true)==OK)
