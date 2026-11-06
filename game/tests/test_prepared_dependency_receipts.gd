extends SceneTree
## Runs only in the tiny task-owned project seeded by the Python wrapper.
const Sources=preload("res://vehicle/prepared_asset_sources.gd")
const IDS: Array[String]=["compact","kart","forklift","electric","hovercraft"]
var checks: int=0
var failures: int=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("RECEIPT_FAIL ",label)
func snapshots() -> Dictionary:
	Sources._file_hashes.clear();Sources._snapshots.clear()
	Sources._runtime_snapshots.clear()
	var result: Dictionary={}
	for id: String in IDS: result[id]=Sources.hashes(id)
	return result
func write(path: String,value: String) -> void:
	var file:=FileAccess.open("res://"+path,FileAccess.WRITE)
	assert(file!=null);file.store_string(value);file.close()
func changed(before: Dictionary,after: Dictionary,expected: Array,label: String) -> void:
	for id: String in IDS: check((before[id]!=after[id])==(id in expected),label+" "+id)
func edit(path: String,value: String,expected: Array,label: String) -> void:
	var before: Dictionary=snapshots()
	write(path,value)
	changed(before,snapshots(),expected,label)
func run() -> void:
	if ProjectSettings.get_setting("application/config/name","")!="Prepared dependency receipt fixture":
		printerr("Use scripts/test_prepared_dependency_receipts.py; never mutate the game project.")
		quit(1);return
	var before: Dictionary=snapshots()
	for id: String in IDS: check(Sources.runtime_projection(before[id])==Sources.runtime_hashes(id),"runtime guard preserves all code/configuration leaves "+id)
	changed(before,snapshots(),[],"unchanged inputs")
	edit("vehicle/electric_body_kits.gd","# electric changed",["electric"],"local builder")
	edit("vehicle/compact_detail.gd","# tyre helper changed",["compact","electric","forklift"],"shared tyre helper")
	edit("vehicle/electric_glass.gdshader","# shared glass changed",["electric","hovercraft"],"shared glass")
	edit("assets/vehicles/electric_rear_lamp_gaps_v1/mesh.res","mesh changed",["electric"],"mesh bytes covered by tree digest")
	before=snapshots()
	write("assets/vehicles/electric_rear_lamp_gaps_v1/renamed.res","mesh changed")
	check(DirAccess.remove_absolute("res://assets/vehicles/electric_rear_lamp_gaps_v1/mesh.res")==OK,"remove owned fixture mesh")
	changed(before,snapshots(),["electric"],"mesh path covered by tree digest")
	before=snapshots()
	check(DirAccess.remove_absolute("res://assets/vehicles/electric_rear_lamp_gaps_v1/renamed.res")==OK,"delete owned fixture mesh")
	changed(before,snapshots(),["electric"],"deleted input changes tree digest")
	edit("assets/liveries/fixture.svg","livery changed",IDS,"shared artwork tree")
	edit("assets/fonts/fixture.ttf","font changed",IDS,"shared font tree")
	edit("resources/cars/kart.tres","kart config changed",["kart"],"per-car resource tree")
	edit("vehicle/unknown_geometry.gd","# unknown helper",IDS,"unknown helper remains shared")
	edit("assets/vehicles/modular_car_bases_v1/compact.scn","generated base",[],"generated scene excluded")
	var value: Dictionary=Sources.hashes("electric")
	value.clear()
	check(not Sources.hashes("electric").is_empty(),"caller cannot mutate cached snapshot")
	print("PREPARED_DEPENDENCY_RECEIPTS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
