extends "res://tests/test_garage_preload.gd"
func _initialize() -> void:
	var script: Script=load("res://ui/garage_preloaded_studio.gd")
	var code: String=FileAccess.get_file_as_string("res://ui/garage_preloaded_studio.gd")
	var marker: String='"key":_geometry_key(node)'
	assert(code.count(marker)==1)
	script.source_code=code.replace(marker,'"key":preload("res://race/world_render_preparation.gd")._key(node)')
	assert(script.reload(true)==OK)
	super._initialize()
