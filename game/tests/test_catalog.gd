extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: "+label)

func run() -> void:
	var folder: String = "user://catalog_tests_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var library := TrackLibrary.new(folder)
	var catalog := TrackCatalog.new(library)
	var doc: Dictionary = TrackDocument.create_default()
	doc["creator"] = "Mira"
	doc.name = "Harbor Loop"
	var validation: Array[String] = TrackDocument.validate(doc)
	check(validation.is_empty(),"creator display names are valid authoring metadata: "+str(validation))
	if not validation.is_empty():
		quit(1)
		return
	check(library.save_document(doc) == OK and library.revision == 1,"save invalidates the session metadata index")
	catalog.add_local(str(doc.id))
	check(catalog.entries.size() == 1 and catalog.entries[0].creator == "Mira","catalog reads creator and name without compiling the route")
	var restored: Dictionary = library.load_document(doc.id)
	check(restored.creator == "Mira","creator survives the exact local share document")
	check(catalog.resolve(catalog.entries[0]) != null,"selected metadata resolves through full validation and native compilation")
	var invalid: Dictionary = doc.duplicate(true)
	invalid["creator"] = "bad\ncreator"
	check(not TrackDocument.validate(invalid).is_empty() and TrackCatalog.local_metadata(invalid).is_empty(),"control characters are rejected in creator labels")
	invalid["creator"] = 123
	check(not TrackDocument.validate(invalid).is_empty(),"nontext creator is rejected")
	invalid = doc.duplicate(true)
	invalid.erase("creator")
	check(TrackCatalog.local_metadata(invalid).creator == "Unknown creator","tracks without creator labels remain searchable without fabricated attribution")
	catalog.entries.clear()
	var favorites: Array = []
	for i: int in range(5000):
		var entry: Dictionary = {"id":"creator_track_%d"%i,"name":"Circuit %d"%i,"creator":"Mira" if i%2 == 0 else "Alex",
			"theme":"pine" if i%3 == 0 else "coast","source":"saved","points":doc.points}
		catalog.entries.append(entry)
		if i%10 == 0: favorites.append(entry.id)
	var started: int = Time.get_ticks_usec()
	var matches: Array[Dictionary] = catalog.query({"name":"CIRCUIT 49","creator":"mIrA"},[])
	check(matches.size() == 55,"combined case-insensitive name and creator query reaches the entire 5000-track catalog")
	check(catalog.query({"section":"favorites"},favorites).size() == 500,"favorites are an independently queryable collection")
	check(catalog.query({"section":"favorites","creator":"Alex"},favorites).is_empty(),"creator search intersects favorites rather than broadening it")
	matches = catalog.query({"theme":"pine","creator":"Alex","sort":"creator"},[])
	check(matches.size() == 833,"theme and creator filters compose across thousands of entries")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var picked: Dictionary = TrackCatalog.random_entry(matches,matches[0].id,rng)
	check(picked in matches and picked.id != matches[0].id,"random picks from filtered results and avoids immediate repeat when possible")
	check(TrackCatalog.random_entry([],"",rng).is_empty(),"random on empty results cannot produce an invalid track")
	var one: Array[Dictionary] = [picked]
	check(TrackCatalog.random_entry(one,picked.id,rng) == picked,"a single matching favorite remains playable")
	var all: Array[Dictionary] = catalog.query({},[])
	check(all[2].name == "Circuit 2" and all[4999].name == "Circuit 4999","natural name sorting keeps numbered tracks in readable order")
	print("CATALOG_5000_QUERY_US: ",Time.get_ticks_usec()-started)
	var state: Dictionary = {"name":"","creator":"","section":"all","page":833}
	# Actual UI receives the cached large catalog with bounded visible cards.
	catalog.indexed_revision = library.revision
	var browser := TrackBrowser.new()
	browser.library = library
	browser.catalog = catalog
	browser.records = LocalRecords.new(folder.path_join("favorites.json"))
	browser.state = state
	browser.selected_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	root.size = Vector2i(1280,720)
	root.add_child(browser)
	await process_frame
	await process_frame
	check(browser.grid.get_child_count() <= 12 and browser.matches.size() == 5000,"5000-track carousel bounds active cards to twelve")
	browser.gallery.scroll_horizontal = int(browser.gallery.get_h_scroll_bar().max_value)
	await process_frame
	browser._render_tiles()
	var last: TrackTile = browser.grid.get_child(browser.grid.get_child_count()-1)
	check(last.entry.id == all.back().id and browser.grid.get_child_count() <= 12,"scrolling reaches the final track while keeping card creation bounded")
	browser.queue_free()
	await process_frame
	for filename: String in DirAccess.open(folder).get_files(): DirAccess.remove_absolute(folder.path_join(filename))
	DirAccess.remove_absolute(folder)
	print("CATALOG_TESTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
