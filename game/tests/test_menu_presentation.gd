extends SceneTree

var checks: int = 0
var failures: int = 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: "+description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(RaceDebrief.feedback(100,0,true,true,false).title == "FIRST TIME SET","first finish gives a real benchmark without inventing a rival")
	var faster: Dictionary = RaceDebrief.feedback(99.816,100,true,true,false)
	check(faster.title == "PERSONAL BEST" and faster.detail.begins_with("0.184 s faster"),"new PB reports the precise improvement")
	var slower: Dictionary = RaceDebrief.feedback(100.184,100,true,true,false)
	check(slower.title == "RACE COMPLETE" and slower.detail.begins_with("+0.184 s off"),"a slower finish provides a precise retry target")
	check(RaceDebrief.feedback(100.0004,100,true,true,false).title == "MATCHED YOUR BEST","sub-millisecond changes follow stored timing precision")
	check(RaceDebrief.feedback(90,100,false,true,false).title == "PRACTICE COMPLETE","practice results never claim a personal best")
	check(RaceDebrief.feedback(90,100,true,false,false).title == "TIME NOT SAVED","failed persistence never celebrates a saved PB")
	check(RaceDebrief.feedback(90,100,false,true,true).title == "TEST DRIVE COMPLETE","editor runs explain their separate return path")
	check(MenuStyle.time_text(59.9996) == "01:00.000","timer formatting carries rounded milliseconds into minutes")
	var folder: String = "user://menu_presentation_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var store := LocalRecords.new(folder.path_join("records.json"))
	store.settings["last_track"] = "slicks_freeway_test"
	store.settings["favorites"] = ["slicks_1way_test"]
	check(store.save_records() == OK,"resume identity and favorites share the recoverable save")
	var reloaded := LocalRecords.new(store.path)
	reloaded.load_records()
	check(reloaded.settings.get("last_track") == "slicks_freeway_test","the last raced circuit survives relaunch")
	store.settings["last_track"] = "../outside"
	check(store.save_records() == ERR_INVALID_DATA and store.settings.get("last_track") == "slicks_freeway_test","invalid resume identifiers cannot overwrite saved preferences")
	for filename: String in DirAccess.open(folder).get_files(): DirAccess.remove_absolute(folder.path_join(filename))
	DirAccess.remove_absolute(folder)
	print("MENU_PRESENTATION_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
