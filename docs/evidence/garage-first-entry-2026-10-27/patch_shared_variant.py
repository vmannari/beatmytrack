from pathlib import Path
R=next(p for p in Path(__file__).resolve().parents if (p/'godot-version.txt').exists())
V=R/'build/garage-first-entry-variants/shared/ui'
program='preload("res://ui/room_program.gdshader")'
def replace(file,a,b):
 p=V/file;s=p.read_text();assert s.count(a)==1,(file,a);p.write_text(s.replace(a,b))
replace('garage_environment.gd','const PREPARED_ARCHITECTURE: String = "res://assets/garage/workshop_v1.scn"','const PREPARED_ARCHITECTURE: String = "res://ui/workshop_shared.scn"')
replace('garage_environment.gd','material.shader = preload("res://ui/garage_deck.gdshader")','material.shader = '+program+'\n\tmaterial.set_shader_parameter("garage_finish_family",1)')
replace('garage_environment.gd','finish.shader = preload("res://ui/garage_floor.gdshader")','finish.shader = '+program+'\n\tfinish.set_shader_parameter("garage_finish_family",0)')
replace('garage_materials.gd','material.shader = preload("res://ui/garage_surface_finish.gdshader")','material.shader = '+program+'\n\tmaterial.set_shader_parameter("garage_finish_family",2)')
replace('garage_reflections.gd','node.material_override.shader == preload("res://ui/garage_deck.gdshader")','node.material_override.shader == '+program+' and node.material_override.get_shader_parameter("garage_finish_family")==1')
