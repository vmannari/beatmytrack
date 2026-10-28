extends SceneTree
## Blend preparation must release every piece's replaced default Dictionary.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func emit_many(native: RefCounted, blend: Dictionary, tool: SurfaceTool, count: int) -> Dictionary:
	var result: Dictionary = {}
	for _index: int in range(count):
		# Empty output isolates Blend::load from mesh, renderer and cache growth.
		result = native.call("road_emit",[],[],[],blend,"pine",0,0.0,Geometry2D,tool,Callable())
	return result

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--native-extension="):
			check(GDExtensionManager.load_extension(arg.trim_prefix("--native-extension=")) == GDExtensionManager.LOAD_STATUS_OK,"isolated native control loads")
	check(ClassDB.class_exists("BmtTrackGeometry"),"native geometry is available")
	if not ClassDB.class_exists("BmtTrackGeometry"): quit(1); return
	var native: RefCounted = ClassDB.instantiate("BmtTrackGeometry")
	var tool := SurfaceTool.new()
	for pieces: int in [0,1,7,33]:
		var blend: Dictionary = {"points":{},"settings":{}}
		for piece: int in range(pieces):
			blend.points[piece] = PackedVector2Array([Vector2.ZERO,Vector2.ONE])
			blend.settings[piece] = {"desert_piece_index":piece,"asphalt":"dry"}
		emit_many(native,blend,tool,20)
		var before: int = OS.get_static_memory_usage()
		emit_many(native,blend,tool,200)
		var growth: int = OS.get_static_memory_usage()-before
		print("NATIVE_BLEND_MEMORY pieces=",pieces," calls=200 growth=",growth)
		check(growth == 0,"repeated blend preparation releases all replaced dictionaries: "+str(pieces))
		check(emit_many(native,blend,tool,1) == {"count":0},"empty output remains exact: "+str(pieces))
	print("NATIVE_BLEND_MEMORY_RESULT: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
