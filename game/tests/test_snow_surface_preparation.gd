extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func run() -> void:
	var source: String = FileAccess.get_file_as_string("res://tests/fixtures/gameplay_f04_f05_before/sand_dust.gd.txt").replace("\r\n","\n")
	var baseline := GDScript.new(); baseline.source_code = "extends Node3D\nvar _bank_visual_heights: Dictionary = {}\n"
	for name: String in ["configure_snow_surface","_is_snow_bank_material"]:
		var start: int = source.find("func "+name+"(")
		var end: int = source.find("\nfunc ",start+5)
		baseline.source_code += source.substr(start,(source.length() if end<0 else end)-start)+"\n"
	check(baseline.reload() == OK,"independent task-original snow preparation compiles")
	var visual := Node3D.new(); root.add_child(visual)
	visual.transform = Transform3D(Basis(Vector3.UP,0.3),Vector3(1,0.1,2))
	var node := MeshInstance3D.new(); visual.add_child(node)
	var shader := Shader.new(); shader.code = "shader_type spatial; uniform bool smooth_road_bank = true; void fragment(){ ALBEDO = vec3(smooth_road_bank ? 1.0 : 0.9); }"
	var material := ShaderMaterial.new(); material.shader = shader; node.material_override = material
	var points := PackedVector3Array()
	for index: int in range(120000): points.append(Vector3((index%128)*0.125,(index%11)*0.01,(index/128)*0.125))
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); node.mesh = mesh
	var original: Node3D = baseline.new(); root.add_child(original)
	original.configure_snow_surface(visual)
	var actual: SandDust = preload("res://vehicle/sand_dust.gd").new(); root.add_child(actual)
	var first_frame: int = Engine.get_process_frames()
	await actual.configure_snow_surface(visual,true)
	check(not actual._bank_visual_heights.is_empty(),"actual bank footprint is prepared")
	check(var_to_bytes(original._bank_visual_heights) == var_to_bytes(actual._bank_visual_heights),"sliced preparation retains byte-exact world-space heights and bucket order")
	check(Engine.get_process_frames()>first_frame,"large bank preparation allows UI frames")
	var visits: Array[int] = [0]
	await actual.configure_snow_surface(visual,true,func() -> bool: visits[0] += 1; return visits[0] < 2)
	check(visits[0] == 2 and actual._bank_visual_heights.size() < original._bank_visual_heights.size(),"obsolete bank preparation stops internally")
	original.free(); actual.free(); visual.free()
	await process_frame
	print("SNOW_SURFACE_PREPARATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
