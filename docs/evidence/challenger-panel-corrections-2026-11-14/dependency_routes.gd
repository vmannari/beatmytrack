extends SceneTree
func _initialize() -> void:
    var paths: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../build/challenger-panel-corrections-2026-11-14/all-prepared/reconcile-changes.json"))
    var result: Dictionary = {}
    for path: String in paths: result[path] = preload("res://vehicle/prepared_asset_sources.gd").vehicles_for(path)
    var file := FileAccess.open("res://../build/challenger-panel-corrections-2026-11-14/all-prepared/dependency-routes.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(result,"\t"));file.close()
    print("ACTUAL_MODEL_ROUTES ",JSON.stringify(result));quit()
