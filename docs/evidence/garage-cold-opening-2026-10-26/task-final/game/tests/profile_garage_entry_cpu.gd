extends "res://tests/test_garage_cold_opening.gd"
func _initialize() -> void:
	var script: Script=load("res://ui/garage_page.gd")
	var code: String=FileAccess.get_file_as_string("res://ui/garage_page.gd")
	var begin: int=code.find("func _ready() -> void:")
	var end: int=code.find("\nfunc ",begin+1)
	var ready: String=code.substr(begin,end-begin)
	ready=ready.replace("func _ready() -> void:","func _ready() -> void:\n\tvar cpu_start: int=Time.get_ticks_usec()")
	for marker: String in ["_create_showroom()","_build_view_controls()","_build_carousel()","_new_menu_panels()","_show_section(\"cars\")"]:
		ready=ready.replace("\t"+marker,"\tprint(\"ENTRY_CPU "+marker.replace("\"", "'")+" \",(Time.get_ticks_usec()-cpu_start)/1000.0)\n\t"+marker)
	code=code.substr(0,begin)+ready+code.substr(end)
	script.source_code=code
	assert(script.reload(true)==OK)
	super._initialize()
