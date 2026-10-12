extends SceneTree
const Quality = preload("res://backend/client_quality.gd")
const Telemetry = preload("res://backend/product_telemetry.gd")
var checks: int = 0
var failures: int = 0
class Client extends Node:
	var player: Dictionary = {"id":"quality-fixture"}
	func quality_supported() -> bool: return true
	func telemetry_supported() -> bool: return true
	func signed_in() -> bool: return true
	func base_url() -> String: return "http://127.0.0.1:18181"
	func server_now() -> int: return 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: "+label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var client := Client.new(); root.add_child(client)
	var telemetry := Telemetry.new(); telemetry.client = client; root.add_child(telemetry)
	telemetry.set_process(false); telemetry._timer.stop()
	var quality := Quality.new(); quality.telemetry = telemetry
	for value: float in [8.0,9.0,12.0,17.0,25.0,34.0,35.0,50.0,51.0,100.0,101.0]: quality.sample_frame("race",value)
	quality.sample_frame("race",NAN)
	quality.flush_frames()
	var props: Dictionary = telemetry.queue[-1].event.properties
	check(props.samples == 11 and props.slow == 5,"inclusive histogram boundaries and no nonfinite frames")
	check(props.b0 == 1 and props.b1 == 2 and props.b7 == 1,"real bucket counts")
	check(not props.has("raw_frames"),"no per-frame trace")
	var version: String = Telemetry.uuid()
	for index: int in range(100): quality.sample_cell(version,index%32,Vector2(index*20.0,-index*20.0),index%2 == 0)
	check(quality.cells.size() == Quality.MAX_CELLS and quality.dropped_cell_samples > 0,"bounded spatial memory and recorded truncation")
	quality.flush_cells()
	check(quality.cells.is_empty(),"bounded cell observations enter existing outbox")
	check(telemetry.queue.size() <= 20,"capture remains within one 50-event batch")
	for entry: Dictionary in telemetry.queue: telemetry._persisted_ids[str(entry.event.id)] = true
	check(telemetry.batch_payload().events.size() == telemetry.queue.size() and telemetry.queue.size() <= 50,"persisted observations fit one bounded packet")
	print("QUALITY_BATCH_BYTES ",JSON.stringify(telemetry.batch_payload()).to_utf8_buffer().size())
	var start: int = Time.get_ticks_usec()
	for index: int in range(10000): quality.sample_frame("race",16.5)
	print("QUALITY_FRAME_MEAN_USEC ",(Time.get_ticks_usec()-start)/10000.0)
	start = Time.get_ticks_usec()
	for index: int in range(1000): quality.sample_cell(version,index%32,Vector2(index*20.0,-index*20.0),false)
	print("QUALITY_CELL_MEAN_USEC ",(Time.get_ticks_usec()-start)/1000.0)
	for entry: Dictionary in telemetry.queue:
		check(not entry.event.properties.has("position") and not entry.event.properties.has("device_id"),"no exact trajectory or device identity")
	print("Client quality: %d checks, %d failures" % [checks,failures])
	quality.free(); telemetry.queue_free(); client.queue_free()
	await process_frame
	quit(1 if failures else 0)
