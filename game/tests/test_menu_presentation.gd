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
	store.settings["last_track"] = "starter_circuit"
	store.settings["favorites"] = ["starter_circuit"]
	store.settings["steering_haptics"] = 0.0
	check(store.save_records() == OK,"resume identity and favorites share the recoverable save")
	var reloaded := LocalRecords.new(store.path)
	reloaded.load_records()
	check(reloaded.settings.get("last_track") == "starter_circuit","the last raced circuit survives relaunch")
	check(reloaded.settings.get("steering_haptics") == 0.0,"disabled haptics survives relaunch")
	store.settings.steering_haptics = 0.5
	check(store.save_records() == OK,"haptic strength can be saved")
	reloaded.load_records()
	check(reloaded.settings.get("steering_haptics") == 0.5,"custom haptic strength survives relaunch")
	store.settings.steering_haptics = 1.1
	check(store.save_records() == ERR_INVALID_DATA and store.settings.steering_haptics == 0.5,"invalid haptic strength rolls back to committed value")
	store.settings["last_track"] = "../outside"
	check(store.save_records() == ERR_INVALID_DATA and store.settings.get("last_track") == "starter_circuit","invalid resume identifiers cannot overwrite saved preferences")
	var provider := TrackDiscoveryProvider.new()
	check(provider.record_snapshot("missing").is_empty(),"missing cloud data stays unavailable")
	check(TrackDiscoveryProvider.is_rival({"time_beaten":true}),"beaten PB marks rival")
	check(TrackDiscoveryProvider.is_rival({"previous_top_percent":10,"current_top_percent":10.1}),"crossing exact decile marks rival")
	check(not TrackDiscoveryProvider.is_rival({"previous_top_percent":11,"current_top_percent":19}),"movement within decile does not mark rival")
	check(not TrackDiscoveryProvider.is_rival({"previous_top_percent":21,"current_top_percent":19}),"improving percentile does not mark rival")
	var catalog := TrackCatalog.new(TrackLibrary.new(folder))
	catalog.entries.assign([{"id":"a","name":"Alpha","creator":"Mika","source":"saved","theme":"pine"},{"id":"b","name":"Beta","creator":"Jen","source":"saved","theme":"pine"}])
	provider.track_stats = {"a":{"score":2,"plays":30},"b":{"score":5,"plays":10,"friend_created":true}}
	check(provider.query(catalog,{"sort":"score"},[])[0].id == "b","score sorts descending")
	check(provider.query(catalog,{"sort":"plays"},[])[0].id == "a","playthroughs sort descending")
	check(provider.query(catalog,{"search":"mika"},[]).size() == 1,"unified search finds creator")
	check(provider.query(catalog,{"feed":"friends"},[]).is_empty(),"offline friend feed cannot invent entries")
	provider.available = true
	check(provider.query(catalog,{"feed":"friends"},[])[0].id == "b","friend feed uses supplied metadata")
	check(provider.query(catalog,{"section":"favorites","feed":"friends"},["a"])[0].id == "a","favorites independent of discovery feed")
	catalog.entries.append({"id":"c","name":"Cloud","creator":"Mika","source":"cloud","theme":"desert","rating_average":4.1,"owned":true})
	catalog.entries.append({"id":"d","name":"Unrated","creator":"Jen","source":"cloud","theme":"winter","rating_average":null})
	var local_ratings: Dictionary = {"a":4,"b":5}
	check(provider.query(catalog,{"minimum_rating":4.1},[],local_ratings).size() == 2,"fractional rating includes the exact aggregate boundary and excludes lower local ratings")
	check(provider.query(catalog,{"minimum_rating":4.2},[],local_ratings).size() == 1,"next tenth excludes a 4.1 aggregate")
	check(provider.query(catalog,{"minimum_rating":0.0},[],local_ratings).size() == 4,"Any rating includes unrated tracks")
	check(provider.query(catalog,{"minimum_rating":4.1,"theme":"desert","search":"mika"},[],local_ratings)[0].id == "c","rating biome and creator search combine")
	check(provider.query(catalog,{"minimum_rating":4.5,"section":"favorites"},["a"],local_ratings).is_empty(),"favorites do not bypass rating constraints")
	check(provider.query(catalog,{"sort":"score"},[],local_ratings)[1].id == "c","rating order uses card values across local and cloud tracks")
	check(provider.query(catalog,{"race_count":"low"},[]).is_empty(),"missing race counts are not treated as zero")
	provider.track_stats.a.plays = 9
	provider.track_stats.b.plays = 10
	provider.track_stats.c = {"plays":50}
	check(provider.query(catalog,{"race_count":"low"},[])[0].id == "a","Low ends at nine races")
	check(provider.query(catalog,{"race_count":"medium"},[])[0].id == "b","Medium starts at ten races")
	check(provider.query(catalog,{"race_count":"high"},[])[0].id == "c","High starts at fifty races")
	for filename: String in DirAccess.open(folder).get_files(): DirAccess.remove_absolute(folder.path_join(filename))
	DirAccess.remove_absolute(folder)
	print("MENU_PRESENTATION_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
