extends SceneTree
const STREAMS = preload("res://editor/road_sections.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func run() -> void:
	var native: RefCounted = preload("res://track/geometry_acceleration.gd").roads()
	check(native != null and native.has_method("editor_split") and native.has_method("editor_append"),"current native stream kernels load")
	var timing: Array = []
	for indexed: bool in [false,true]:
		for count: int in [3,300,12288,12300,48000]:
			var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			for index: int in range(count):
				tool.set_normal(Vector3.UP); tool.set_color(Color(float(index%13)/13.0,0.25,0.75,1))
				tool.set_uv(Vector2(index%19,index%31)); tool.set_uv2(Vector2(index%41,index%53))
				tool.add_vertex(Vector3(float(index%120)-60,float(index%3)*0.01,float(index/120)-80))
			if indexed: tool.index()
			var arrays: Array = tool.commit_to_arrays()
			for tile: float in [16.0,32.0,100000.0]:
				STREAMS.native_streams = false
				var began: int = Time.get_ticks_usec(); var expected: Array = STREAMS.split(arrays,tile)
				var old_ms: float = (Time.get_ticks_usec()-began)/1000.0
				STREAMS.native_streams = true
				began = Time.get_ticks_usec(); var actual: Array = STREAMS.split(arrays,tile)
				var new_ms: float = (Time.get_ticks_usec()-began)/1000.0
				check(var_to_bytes(expected) == var_to_bytes(actual),"split retains exact ordered streams %s/%s/%s" % [indexed,count,tile])
				timing.append({"indexed":indexed,"vertices":count,"tile":tile,"script_ms":old_ms,"native_ms":new_ms})
			STREAMS.native_streams = false
			var reference := SurfaceTool.new(); reference.begin(Mesh.PRIMITIVE_TRIANGLES); STREAMS.append_arrays(reference,arrays)
			STREAMS.native_streams = true
			var rebuilt := SurfaceTool.new(); rebuilt.begin(Mesh.PRIMITIVE_TRIANGLES); STREAMS.append_arrays(rebuilt,arrays)
			check(var_to_bytes(reference.commit_to_arrays()) == var_to_bytes(rebuilt.commit_to_arrays()),"append retains complete attributes and order")
	var file := FileAccess.open("res://../docs/evidence/track-editor-fixes-2026-10-28/streams.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"timing":timing},"\t")); file.close()
	print("EDITOR_STREAMS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
