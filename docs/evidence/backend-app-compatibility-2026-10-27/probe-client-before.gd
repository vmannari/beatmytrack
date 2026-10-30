extends "res://backend/runner.gd"
## Diagnostic only: exercises the actual ticket gate without a server or player saves.
const Cloud = preload("res://backend/cloud_tracks.gd")
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/backend-app-compatibility-2026-10-27/client.json"

class LocalClient extends Node:
	var player: Dictionary = {"id":"compatibility-audit-only"}
	var safety: Node
	func signed_in() -> bool: return true
	func new_operation_key() -> String: return "compatibility-audit-operation"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	var active: Dictionary = manifest()
	var client := LocalClient.new()
	var cloud := Cloud.new()
	cloud.client = client
	var track := NativeTrack.new()
	track.content_hash = "a".repeat(64)
	track.metadata["cloud_version"] = "compatibility-audit-version"
	var rows: Array[Dictionary] = []
	var cases: Array[Dictionary] = [
		{"name":"identical","changes":{},"accept":true},
		{"name":"informational_app_build","changes":{"client_build":"different-art-and-ui-build"},"accept":true},
		{"name":"extra_server_metadata","changes":{"future_optional_field":"ignored"},"accept":true},
		{"name":"engine_build_label","changes":{"engine_version":str(active.engine_version)+"-repack"},"accept":false},
		{"name":"physics_label","changes":{"physics_version":"arcade-planar-0.74"},"accept":false},
		{"name":"compiler_label_same_track_hash","changes":{"compiler_version":"creator-compiler-0"},"accept":false},
		{"name":"rules_label","changes":{"rules_key":"standing-5-road-gates-v22"},"accept":false},
		{"name":"tick_rate","changes":{"tick_rate":60},"accept":false},
		{"name":"track_schema","changes":{"track_schema":"creator-track-future"},"accept":false},
		{"name":"replay_schema","changes":{"replay_schema":"bmt-replay-future"},"accept":false},
		{"name":"verifier_label","changes":{"verifier_version":"canonical-verifier-2"},"accept":false},
		{"name":"track_hash","changes":{"track_content_hash":"b".repeat(64)},"accept":false},
		{"name":"selected_car_hash","changes":{"config_hash":"c".repeat(64)},"accept":false}
	]
	for vehicle: String in VehicleCatalog.IDS:
		var pinned: Dictionary = active.duplicate(true)
		pinned.erase("vehicles")
		pinned.merge(active.vehicles[vehicle],true)
		pinned["vehicle_id"] = vehicle
		pinned["track_content_hash"] = track.content_hash
		for scenario: Dictionary in cases:
			var manifest: Dictionary = pinned.duplicate(true)
			manifest.merge(scenario.changes,true)
			cloud.last_error = ""
			var issued: Dictionary = {"ticket_id":"compatibility-audit-ticket","manifest":manifest}
			var result: Dictionary = await cloud.ticket(track,false,vehicle,null,issued)
			var accepted: bool = not result.is_empty()
			checks += 1
			if accepted != bool(scenario.accept):
				failures += 1
				print("FAIL: ",vehicle," ",scenario.name," ",cloud.last_error)
			rows.append({"vehicle":vehicle,"case":scenario.name,"accepted":accepted,"error":cloud.last_error})
	var report: Dictionary = {"checks":checks,"failures":failures,"manifest":active,"rows":rows,
		"scope":"Actual CloudTracks.ticket with supplied tickets; no HTTP, geometry validation, player saves or device test"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output).get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null:
		failures += 1
	else:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	cloud.free()
	client.free()
	print("COMPATIBILITY_AUDIT: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
