extends "res://tests/test_menu_responsiveness.gd"
func _initialize() -> void: inspect.call_deferred()
func inspect() -> void:
	var scene: PackedScene = load(GarageEnvironment.PREPARED_ARCHITECTURE)
	GarageEnvironment.architecture_scene = null
	var world := Node3D.new()
	root.add_child(world)
	var car := CarVisual.new()
	world.add_child(car)
	GarageEnvironment.build(world,car,true,false)
	var fresh: Node = GarageEnvironment.architecture_scene.instantiate()
	var stored: Node = scene.instantiate()
	var a: Array = []
	var b: Array = []
	geometry(fresh,a)
	geometry(stored,b)
	var differences: Array[Dictionary] = []
	var names_only: int = 0
	for i: int in range(mini(a.size(),b.size())):
		if a[i] == b[i]: continue
		var automated: bool = a[i] is Array and b[i] is Array and a[i].size() == 2 and b[i].size() == 2 and a[i][0] is String and b[i][0] is String and a[i][0].begins_with("@") and b[i][0].begins_with("@") and a[i][1] == b[i][1]
		if automated: names_only += 1
		if differences.size() < 12:
			var row: Dictionary = {"index":i,"type":type_string(typeof(a[i])),"auto_name_only":automated}
			if a[i] is Array: row.lengths = [a[i].size(),b[i].size()]
			if automated: row.names = [a[i][0],b[i][0]]
			differences.append(row)
	var total: int = 0
	for i: int in range(mini(a.size(),b.size())):
		if a[i] != b[i]: total += 1
	var result: Dictionary = {"fresh_rows":a.size(),"prepared_rows":b.size(),"different_rows":total,"auto_names_only":names_only,"examples":differences}
	FileAccess.open("res://../build/garage-review3-2026-11-13/room-diff.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("ROOM_DIFF ",JSON.stringify(result))
	fresh.free()
	stored.free()
	world.free()
	quit()
