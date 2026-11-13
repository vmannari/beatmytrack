extends SceneTree
var checks: int=0
var failures: int=0
var identity: RefCounted
func _initialize()->void:run.call_deferred()
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures+=1;printerr("TEXTURE_KEY_FAIL ",label)
func value_key(value: Variant)->Variant:return identity.call("value_key",value)
func run()->void:
	# Compile the exact fixture helper independently of concurrent game scripts.
	var source: String=FileAccess.get_file_as_string("res://tests/test_modular_car_assets.gd")
	var start: int=source.find("func value_key(");var end: int=source.find("func material_key(")
	var script:=GDScript.new();script.source_code="extends RefCounted\n"+source.substr(start,end-start)
	if script.reload()!=OK:quit(1);return
	identity=script.new()
	var pixels:=Image.create(2,2,false,Image.FORMAT_RGBA8);pixels.fill(Color("456789"))
	var a:=ImageTexture.create_from_image(pixels);var b:=ImageTexture.create_from_image(pixels)
	a.take_over_path("user://alias-source.res::ImageTexture_a");b.take_over_path("user://alias-prepared.scn::ImageTexture_b")
	check(a.resource_path!=b.resource_path and value_key(a)==value_key(b),"embedded addresses differ while complete image identity remains exact")
	pixels.set_pixel(0,0,Color.WHITE);b.update(pixels)
	check(value_key(a)!=value_key(b),"a single changed image pixel is still rejected")
	var other:=Image.create(1,4,false,Image.FORMAT_RGBA8);other.fill(Color("456789"));b.set_image(other)
	check(a.get_image().get_data()==b.get_image().get_data() and value_key(a)!=value_key(b),"same raw bytes with different dimensions remain rejected")
	print("TEXTURE_KEYS ",checks," checks, ",failures," failures");quit(1 if failures else 0)
