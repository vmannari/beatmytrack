extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var path: String=ProjectSettings.globalize_path("res://../build/memory-drift-2026-10-26").simplify_path()
	assert(GDExtensionManager.load_extension(path.path_join("heap_probe_v3.gdextension"))==GDExtensionManager.LOAD_STATUS_OK)
	var heap: RefCounted=ClassDB.instantiate("BmtHeapProbe"); assert(heap.start(64)==4)
	var begin: int=Time.get_ticks_msec()
	for _index: int in range(200000):
		var scratch := PackedByteArray(); scratch.resize(4096); scratch.fill(171)
	var held := PackedByteArray(); held.resize(4096); held.fill(205)
	heap.dump(path.path_join("heap-selftest-held.tsv"),"held")
	held.clear()
	heap.dump(path.path_join("heap-selftest-freed.tsv"),"freed")
	print("HEAP_SELFTEST ",Time.get_ticks_msec()-begin," ms; ",JSON.stringify(heap.queue_info(self)))
	quit()
