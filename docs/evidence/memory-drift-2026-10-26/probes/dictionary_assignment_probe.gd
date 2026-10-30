extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var directory: String=ProjectSettings.globalize_path("res://../build/memory-drift-2026-10-26").simplify_path()
	assert(GDExtensionManager.load_extension(directory.path_join("heap_probe_v4.gdextension"))==GDExtensionManager.LOAD_STATUS_OK)
	var heap: RefCounted=ClassDB.instantiate("BmtHeapProbe")
	heap.dictionary_assignment(1,false); heap.dictionary_assignment(1,true)
	for move: bool in [false,true,false,true]:
		var before: int=OS.get_static_memory_usage(); heap.dictionary_assignment(1000,move)
		var delta: int=OS.get_static_memory_usage()-before
		print("DICTIONARY_ASSIGNMENT move=",move," delta=",delta)
		assert(delta==(128000 if move else 0))
	print("DICTIONARY_ASSIGNMENT_RESULT: 4 exact checks pass"); quit()
