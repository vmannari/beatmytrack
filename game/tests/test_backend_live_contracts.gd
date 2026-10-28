extends SceneTree
## Read-only deployment acceptance through the actual game ticket validator.
const CLOUD = preload("res://backend/cloud_tracks.gd")
var checks: int = 0
var failures: int = 0

class ProbeClient:
	extends Node
	var player: Dictionary = {"id":"owned-local-contract-probe"}
	var safety: Node
	func signed_in() -> bool: return true
	func new_operation_key() -> String: return "probe-"+str(Time.get_ticks_usec())
	func base_url() -> String: return "https://owned-read-only-probe.invalid"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var path: String = OS.get_environment("BMT_LIVE_CONTRACTS")
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not source is Array or source.is_empty():
		push_error("Missing public contract fixture")
		quit(1)
		return
	var client := ProbeClient.new()
	root.add_child(client)
	var cloud := CLOUD.new()
	cloud.client = client
	cloud.root_override = OS.get_environment("BMT_CONTRACT_PROBE_ROOT")
	root.add_child(cloud)
	for entry: Dictionary in source:
		var track := NativeTrack.new()
		track.content_hash = str(entry.manifest.track_content_hash)
		track.metadata = {"cloud_version":entry.version_id}
		for vehicle_id: String in VehicleCatalog.IDS:
			checks += 1
			if not entry.manifest.get("vehicles",{}).has(vehicle_id):
				failures += 1
				continue
			var manifest: Dictionary = entry.manifest.duplicate(true)
			manifest.vehicle_id = vehicle_id
			manifest.handling_version = entry.manifest.vehicles[vehicle_id].handling_version
			manifest.config_hash = entry.manifest.vehicles[vehicle_id].config_hash
			var issued: Dictionary = {"ticket_id":"owned-local-probe", "version_id":entry.version_id, "manifest":manifest}
			var value: Dictionary = await cloud.ticket(track,false,vehicle_id,null,issued)
			if value.is_empty():
				failures += 1
				print("CONTRACT_REJECTED: ",vehicle_id," ",cloud.last_error)
	cloud.queue_free()
	client.queue_free()
	await process_frame
	await process_frame
	print("LIVE_CONTRACTS: %s checks, %s failures" % [checks,failures])
	quit(1 if failures else 0)
