extends SceneTree

const Icons = preload("res://ui/header_car_icons.gd")
const Build = preload("res://core/build_identity.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func fake_build(id: String, revision: String = "") -> Script:
	var script := GDScript.new()
	script.source_code = "extends RefCounted\nconst ID: String = \""+id+"\"\n"
	if not revision.is_empty(): script.source_code += "const HEADER_PREVIEW_SHA256: String = \""+revision+"\"\n"
	check(script.reload() == OK,"test build identity compiles")
	return script

func run() -> void:
	var first := LocalRecords.new("user://header-revision-first/records.json")
	var second := LocalRecords.new("user://header-revision-second/records.json")
	var build_script: Script = Build
	var expected_revision: String = str(build_script.get_script_constant_map().get("HEADER_PREVIEW_SHA256",Build.ID))
	Icons._visual_revision = ""
	var actual: String = Icons.appearance_key("compact",first)
	var expected: String = JSON.stringify([Icons.VERSION,expected_revision,RenderingServer.get_current_rendering_method(),first.path,"compact",VehicleLivery.for_car(first.settings,"compact"),VehicleCustomisation.for_car(first.settings,"compact")],"",true).sha256_text()
	check(actual == expected,"generated visual identity, or the conservative old-build fallback, is used")
	var old_build: Script = fake_build("build-one","a".repeat(64))
	var new_build: Script = fake_build("build-two","a".repeat(64))
	Icons._visual_revision = Icons._source_revision(old_build)
	var old_key: String = Icons.appearance_key("compact",first)
	Icons._visual_revision = Icons._source_revision(new_build)
	check(Icons.appearance_key("compact",first) == old_key,"different full builds with identical visuals keep the same picture")
	check(Icons._source_revision(fake_build("legacy")) == "legacy","old generated identities retain the full-build fallback")
	check(Icons._source_revision(fake_build("broken","bad")) == "broken","invalid generated visual identities fall back safely")
	Icons._visual_revision = "a".repeat(64)
	var baseline: String = Icons.appearance_key("compact",first)
	check(Icons.appearance_key("compact",first) == baseline,"unchanged visual dependencies reuse the same picture")
	check(Icons.appearance_key("compact",second) != baseline,"different records owners do not share pictures")
	check(Icons.appearance_key("pickup",first) != baseline,"different cars do not share pictures")
	var paint: Dictionary = VehicleLivery.defaults("compact")
	paint.colors.body = "c82e37"
	first.settings.vehicle_liveries = {"compact":paint}
	check(Icons.appearance_key("compact",first) != baseline,"an equipped paint change invalidates the picture")
	first.settings.erase("vehicle_liveries")
	var parts: Dictionary = VehicleCustomisation.defaults()
	parts.hood = "cowl"
	first.settings.vehicle_customisation = {"compact":parts}
	check(Icons.appearance_key("compact",first) != baseline,"a fitted-part change invalidates the picture")
	first.settings.erase("vehicle_customisation")
	Icons._visual_revision = "b".repeat(64)
	check(Icons.appearance_key("compact",first) != baseline,"a visual dependency change invalidates the picture")
	Icons._visual_revision = ""
	print("HEADER_REVISION_KEY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
